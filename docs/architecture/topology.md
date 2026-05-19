# Topology

워커 VM 매트릭스와 네트워크 구조. Terraform input의 단일 진실.

## VM 매트릭스

| 이름 | OS | flavor | 역할 | 비고 |
|------|----|--------|------|------|
| (TBD) | (TBD) | (TBD) | (TBD) | (TBD) |

결정 필요
- 워커 VM 개수
- OS 분포 (단일 또는 다양)
- flavor 종류 (CPU, RAM, disk)
- 역할 정의 (web, db, cache, mq, app 등)
- 네이밍 컨벤션 (`role-NN`, `host-NN` 등)

## 네트워크

결정 필요
- 기존 network join 또는 신규 생성
- 서브넷 CIDR 할당
- security group rule 매트릭스 (ingress / egress, 포트)
- floating IP 필요 여부
- DNS, NTP server

## SSH key

- OpenStack keypair 이름
- 워커 VM에 inject할 public key 경로

## 의존
- credentials.md — OpenStack API 접근 방식
- terraform/variables.tf — 본 문서의 매트릭스를 변수로 표현
- terraform/modules/vm — VM 단위 module
