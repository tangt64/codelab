# Blog (Podman Pod: front+api+db)

이 문서는 **모든 포트를 8080 기준으로 통일**하고(= API/Tomcat 8080),
프론트(Nginx)는 80으로 서비스하며, 이미지 태그는 **전부 localhost**로 맞춘 실행 가이드입니다.

## 1) WAR 빌드
```bash
cd blog/blog
mvn -DskipTests package
```

## 2) 이미지 빌드 (Podman)
> 아래 명령은 **레포 루트**(blog 디렉터리가 보이는 위치)에서 실행합니다.

```bash
# 레포 루트로 이동
cd ..

# API (Tomcat)
podman build -t localhost/blog-api:latest -f blog/api-tomcat/Containerfile .

# Front (React build + Nginx)
podman build -t localhost/blog-front:latest -f blog/front-nginx/Containerfile .
```

## 3) Pod 기반 실행 (DB 포함)
```bash
# DB 데이터 영속 볼륨
podman volume create blog-db

# Pod 생성 (외부는 80만 오픈)
podman pod create --name blog-pod -p 8080:8080

# DB (PostgreSQL)
podman run -d --name blog-db --pod blog-pod   -e POSTGRES_DB=blog   -e POSTGRES_USER=blog   -e POSTGRES_PASSWORD=blogpass   -v blog-db:/var/lib/postgresql/data   docker.io/library/postgres:16-alpine

# API (Tomcat 8080)
podman run -d --name blog-api --pod blog-pod   -e SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/blog   -e SPRING_DATASOURCE_USERNAME=blog   -e SPRING_DATASOURCE_PASSWORD=blogpass   localhost/blog-api:latest

# Front (Nginx 80, /api -> localhost:8080 프록시)
podman run -d --name blog-front --pod blog-pod   localhost/blog-front:latest
```

### 접속
- UI: `http://<HOST>/`
- API(직접확인): `http://<HOST>/api/posts`  (GET)

## 4) Kubernetes로 옮길 준비: YAML 생성
```bash
podman generate kube blog-pod > blog-pod.yaml
```

> Kubernetes로 “정식 이사”할 때는 보통:
> - DB: StatefulSet + PVC
> - API/Front: Deployment
> - Ingress/Service로 노출
> 로 정리합니다.
