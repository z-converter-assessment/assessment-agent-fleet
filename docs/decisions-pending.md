# 결정 필요 항목

본 repo 의 코드와 docs 에 흩어진 TBD 를 한 곳에 모음.
결정 후 본 파일에서 항목 제거 + ADR 추가 + 해당 코드/docs 갱신.

## Topology
- staging 초기 3대 매트릭스: [ADR 0004](adr/0004-topology.md)
- staging multi-OS / service / noise 시연 매트릭스 (8대): [ADR 0008](adr/0008-multi-os-demo.md)

남은 항목:
- prod 매트릭스 — staging 시연 검증 통과 후 확정
- DNS / NTP 커스텀 (현재는 cloud-init 기본값)
- compute 자원 확보 시 30대 매트릭스 복원 (운영자 admin 권한 확보 트랙)

## Terraform
- state backend: [ADR 0005](adr/0005-terraform-state-backend.md) — local + cinder volume

남은 항목:
- network / security-group module 화 시점 (현재는 기존 자산 재사용)
- prod backend.hcl 실값화 시점

## Agent Release / Env / Vault
- agent release: [ADR 0006](adr/0006-agent-release.md)
- env contract: [docs/architecture/env-contract.md](architecture/env-contract.md)
- ansible vault: [ADR 0007](adr/0007-ansible-vault.md)

남은 항목:
- agent repo 의 release.yml develop 머지 시점 — github_release path 전환
- cosign / gpg signature 도입 결정
- prod 환경 vault-id 분리 — 운영자 추가 시점

## RABBITMQ 연결 (시연 환경 확정)
- `RABBITMQ_HOST` = `10.0.10.73` (mq-vm)
- `RABBITMQ_VHOST` = `assessment` (leading slash 없음)
- `RABBITMQ_USER` = `assessment`, `RABBITMQ_PASS` = `1234`
- sg-mq 가 agent-sg ingress 5672 허용 — 정합
- TLS (5671) 도입 여부는 prod 환경 결정

## OS 호환성 / Ansible (별도 트랙)
- **ansible-core 2.15 별도 venv** (RHEL 8 family 지원) — controller 측 pipx venv. ansible-core 2.19 와 분리 운영
- redhat9 cloud-init 정상 image 확보 — 본 사이트 운영자 협의
- amazon2023 등 compute scheduling fail 케이스 — 자원 확보 후 재시도

## Backup / 운영
- cinder volume `tfstate-agent-fleet` snapshot 주기 / 보존 정책
- iac VM 자체 재구축 절차
- ansible vault password 백업 정책 (운영자 개인 vault)
