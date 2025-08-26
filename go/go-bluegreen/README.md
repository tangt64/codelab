# Blue/Green + HPA + Prometheus + KEDA Demo (Gin)

간단한 Blue/Green 전환과 CPU/HPA, Prometheus 지표, KEDA(이벤트 기반) 오토스케일까지 한번에 실습하는 데모.

## 기능
- `?color=blue|green` 배경 전환
- 페이지에 Pod IP, Hostname, Namespace, Service, Version, 볼륨 정보 출력
- `/load`로 CPU 부하 발생 (HPA 테스트)
- `/metrics`로 Prometheus 지표 노출
- `bgdemo\_active\_workers` (현재 부하 워커 수)
- `bgdemo\_http\_requests\_total{path=...}`

## 사전 요구

- Kubernetes 1.23+
- NGINX Ingress Controller (or 다른 IngressClass)
- Metrics Server (HPA 필수)
- Prometheus Operator (`ServiceMonitor` 지원)
- KEDA (Operator)



> 설치 예시
> - Metrics Server: `kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml`
> - Ingress: NGINX Ingress Controller
> - Prometheus Operator: kube-prometheus-stack (Helm)
> - KEDA: `helm repo add kedacore https://kedacore.github.io/charts \&\& helm install keda kedacore/keda -n keda --create-namespace`

## 빌드/이미지
```bash
podman build -t YOUR\_REGISTRY/bgapp-gin:blue .
podman tag  YOUR\_REGISTRY/bgapp-gin:blue YOUR\_REGISTRY/bgapp-gin:green
podman push YOUR\_REGISTRY/bgapp-gin:blue
podman push YOUR\_REGISTRY/bgapp-gin:green
```
## 배포

```bash
kubectl apply -f k8s.yaml
```