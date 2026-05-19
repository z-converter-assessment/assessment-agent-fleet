# 결정 필요 항목

본 repo 의 코드와 docs 에 흩어진 TBD 를 한 곳에 모음.
결정 후 본 파일에서 항목 제거 + ADR 추가 + 해당 코드/docs 갱신.

## Topology (docs/architecture/topology.md)
- 워커 VM 개수
- OS 분포 (단일 또는 다양)
- flavor 종류 (CPU, RAM, disk)
- 역할 정의 (web, db, cache, mq, app 등)
- 네이밍 컨벤션 (`<role>-NN`, `<host>-NN` 등)
- 기존 network join 또는 신규 생성
- 서브넷 CIDR 할당
- security group rule 매트릭스 (ingress / egress, 포트)
- floating IP 필요 여부
- DNS, NTP server
- OpenStack keypair 이름
- 워커 VM 에 inject 할 public key 경로

## Credentials (docs/architecture/credentials.md)
- clouds.yaml 또는 application credential 중 채택

## Agent Release (docs/architecture/agent-release.md)
- repo 좌표 (`OWNER/REPO`)
- 지원 arch 목록
- signature 검증 정책 (cosign, gpg, 또는 미적용)

## Env Contract (docs/architecture/env-contract.md)
- 정확한 키 카탈로그
- 키 분류 (필수 / 선택 / secret)
- 외부 시스템 연결 키 (engine, broker, log forwarder 등)

## Terraform (terraform/README.md)
- state backend 종류 (swift, s3 호환, local)
- network 모듈 추가 시점
- security-group 모듈 추가 시점
- floating IP 정책

## Ansible (ansible/README.md)
- Vault password 핸들링 (파일, env, helper script)
- agent release contract 확정 후 `roles/agent_binary` 의 sha256 / signature 검증 활성화
