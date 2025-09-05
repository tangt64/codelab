# AWS API Workshop (교육용)

이 저장소는 AWS 기반 API 서버스 교육을 위한 예제 모음입니다.  
모든 예제는 **Go 언어**를 기반으로 작성되었으며, IaC는 CloudFormation 또는 OpenTofu(Terraform 호환)으로 변환 가능합니다.

## 디렉토리 구조
```
aws-api-workshop/
  00-bootstrap/           # 공통 VPC/IAM/키/Cloud9 옵션
  01-serverless-notes/    # API Gateway + Lambda + DynamoDB
  02-ecs-fargate-api/     # ECS(Fargate) + ALB
  03-eks-gin-hpa/         # EKS + ALB Ingress + HPA
  04-ec2-asg-rds/         # EC2 ASG + ALB + RDS
  05-aurora-data-api/     # Aurora Serverless v2 + Data API
  06-event-file-api/      # S3 Presign + SQS + Lambda
  common/                 # 공통 스크립트, IAM 정책, Makefile
```

## 실행 방법
### 준비 단계
1. AWS 계정 로그인 (ap-northeast-2 권장)
2. IAM 사용자/역할 생성 (Admin 권한, 교육용)
3. Cloud9 환경 생성 또는 로컬 환경 준비

### 공통 Makefile 사용
```bash
# 공통 준비 (VPC/IAM 등)
make bootstrap

# 1번 예제(Serverless Notes) 배포
make deploy-01

# 테스트
make test-01

# 정리
make clean-01

# 전체 정리
make clean-all
```

## 예제별 개요
### 01. Serverless Notes
- API Gateway + Lambda(Go) + DynamoDB
- `POST /notes`, `GET /notes` 구현

### 02. ECS Fargate API
- 컨테이너 기반 API (ALB → ECS 서비스)
- `GET /health`, `GET /api`

### 03. EKS + HPA
- Go Gin API 배포, HPA 스케일 아웃
- Ingress(ALB) 통한 외부 접근

### 04. EC2 ASG + RDS
- 전통형 아키텍처 (EC2 Auto Scaling + ALB + RDS)
- systemd 기반 서비스 실행

### 05. Aurora Data API
- Aurora Serverless v2 + Lambda
- SQL 쿼리 Data API로 실행

### 06. Event File API
- S3 Presign → 업로드 → S3 Event → SQS → Lambda
- 비동기 이벤트 기반 데이터 처리

## 청소 (비용 최소화)
- 각 예제 종료 후 반드시 `make clean-XX` 실행
- ALB, RDS, EKS 클러스터는 비용이 크므로 즉시 제거 권장
- S3 버킷은 객체 삭제 후 제거 필요

---
**작성자**: 국현 교육 과정 전용  
**도우미**: 아름이(아르테) ♥
