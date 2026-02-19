# Blog (front Pod: nginx+tomcat, db Pod: postgres)

## 1) WAR 빌드
```bash
cd blog
mvn -q -DskipTests package
```

## 2) 이미지 빌드 (Podman)

```bash
# Blog root directory에서 아래 명령어 실행
# API(Tomcat)
podman build -t localhost/blog-api-tomcat:latest -f api-tomcat/Containerfile blog

# Front(Nginx+React)
podman build -t localhost/blog-front-nginx:latest -f front-nginx/Containerfile .
```

## 3) 이미지 푸시
```bash
podman push localhost/blog-api-tomcat:latest
podman push localhost/blog-front-nginx:latest
```


## 4) 포드만에서 POD 기반으로 실행

```bash
podman volume create blog-db
podman pod create --name blog-pod \
  -p 80:80 \
  -p 8080:8080
podman run -d --name blog-db \
  --pod blog-pod \
  -e POSTGRES_DB=blog \
  -e POSTGRES_USER=blog \
  -e POSTGRES_PASSWORD=blogpass \
  -v blog-db:/var/lib/postgresql/data \
  docker.io/library/postgres:16-alpine
podman run -d --name blog-api \
  --pod blog-pod \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/blog \
  -e SPRING_DATASOURCE_USERNAME=blog \
  -e SPRING_DATASOURCE_PASSWORD=blogpass \
  localhost/blog-api-tomcat
podman run -d --name blog-front \
  --pod blog-pod \
  localhost/blog-front

podman pod ls
```