\## 사용방법



```bash

\# (WSL2의 AlmaLinux 쉘에서)

chmod +x setup.sh

./setup.sh



\# 기본값(리전 ap-northeast-2 등)을 바꾸고 싶으면 실행 전에 export로 덮어쓰기:

export REGION=ap-northeast-1

export HZ\_NAME=example.net

./setup.sh

```



1. VPC / 퍼블릭 2개(AZ a,c), 프라이빗 1개(AZ a) 서브넷 생성

2\. IGW, NAT 게이트웨이(퍼블릭 서브넷), 라우팅 테이블 연결

3\. 퍼블릭/프라이빗 보안그룹, 퍼블릭 인스턴스(lab-www1), 프라이빗 인스턴스(lab-www3)

4\. Route 53 프라이빗 호스팅 존(example.com) + www A레코드(프라이빗 인스턴스 IP)

5\. ALB(HTTP) + Target Group + 리스너(퍼블릭 인스턴스를 타깃으로 등록)

6\. 실행 결과는 setup\_summary.json에 깔끔히 정리해서 ID/주소 한 번에 확인 가능

