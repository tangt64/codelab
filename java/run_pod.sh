#!/usr/bin/env bash
set -euo pipefail

# Run Blog (front+api+db) with Podman Pod
# - Front: http://<host>/  (host port 80)
# - API inside pod: http://localhost:8080/ and exposed via nginx /api/
# - DB inside pod: localhost:5432
#
# Images are tagged as localhost/blog-api:latest and localhost/blog-front:latest

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/6] Build WAR (skip tests)"
(cd "$ROOT_DIR/blog/blog" && mvn -DskipTests clean package)

echo "[2/6] Build images"
podman build --no-cache -t localhost/blog-api:latest -f "$ROOT_DIR/blog/api-tomcat/Containerfile" "$ROOT_DIR"
podman build --no-cache -t localhost/blog-front:latest -f "$ROOT_DIR/blog/front-nginx/Containerfile" "$ROOT_DIR"

echo "[3/6] Recreate pod + containers"
podman rm -f blog-front blog-api blog-db >/dev/null 2>&1 || true
podman pod rm -f blog-pod >/dev/null 2>&1 || true
podman volume rm blog-db >/dev/null 2>&1 || true

podman volume create blog-db >/dev/null
podman pod create --name blog-pod -p 80:80 >/dev/null

echo "[4/6] Start PostgreSQL (init tables on first boot)"
podman run -d --name blog-db --pod blog-pod \
  -e POSTGRES_DB=blog \
  -e POSTGRES_USER=blog \
  -e POSTGRES_PASSWORD=blogpass \
  -v blog-db:/var/lib/postgresql/data \
  -v "$ROOT_DIR/blog/blog/docker/create_tables.sql":/docker-entrypoint-initdb.d/001_create_tables.sql:ro \
  docker.io/library/postgres:16-alpine >/dev/null

echo "[5/6] Start API (Tomcat on 8080 inside the pod)"
podman run -d --name blog-api --pod blog-pod \
  localhost/blog-api:latest >/dev/null

echo "[6/6] Start Front (nginx on 80 inside the pod)"
podman run -d --name blog-front --pod blog-pod \
  localhost/blog-front:latest >/dev/null

echo
echo "Done!"
echo "- UI:  http://$(hostname -I 2>/dev/null | awk '{print $1}')/"
echo "- API: http://127.0.0.1/api/posts (via nginx)"
