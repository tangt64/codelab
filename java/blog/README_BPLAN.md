# Blog (front Pod: nginx+tomcat, db Pod: postgres)

## 1) WAR 빌드
```bash
cd blog
mvn -q -DskipTests package
```

## 2) 이미지 빌드 (Podman)

```bash
# API(Tomcat)
podman build -t REGISTRY/blog-api-tomcat:latest -f api-tomcat/Containerfile blog

# Front(Nginx+React)
podman build -t REGISTRY/blog-front-nginx:latest -f front-nginx/Containerfile .
```

## 3) 이미지 푸시
```bash
podman push REGISTRY/blog-api-tomcat:latest
podman push REGISTRY/blog-front-nginx:latest
```

## 4) 배포
```bash
# k8s/blog-bplan.yaml 에서 REGISTRY 부분만 수정 후
kubectl apply -f k8s/blog-bplan.yaml
```
