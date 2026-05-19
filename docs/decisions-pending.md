# 결정 필요 항목

본 repo 의 코드와 docs 에 흩어진 TBD 를 한 곳에 모음.
결정 후 본 파일에서 항목 제거 + ADR 추가 + 해당 코드/docs 갱신.

## Topology (docs/architecture/topology.md)
staging 매트릭스는 [ADR 0004](adr/0004-topology.md) 로 확정. 남은 항목:
- prod 매트릭스 (개수, OS 다양화 여부) — staging 검증 통과 후 확정
- DNS / NTP 커스텀 (현재는 cloud-init 기본값 가닥)

## Terraform (terraform/README.md)
state backend 는 [ADR 0005](adr/0005-terraform-state-backend.md) 로 확정 (local + cinder volume). 남은 항목:
- network 모듈 추가 시점 — 현재는 기존 network 재사용으로 모듈 불필요. 새 network 생성 필요 시 결정
- security-group 모듈 추가 시점 — sg-agent 룰 수정으로 시작. terraform 으로 sg 자원 import 또는 module 화 시점 결정 필요
- prod backend.hcl 실값화 시점

## Agent Release / Env / Vault
- agent release: [ADR 0006](adr/0006-agent-release.md) 로 확정 (repo `z-converter-assessment/assessment-agent`, x86_64, 두 path 토글)
- env contract: agent repo 의 `.env.example` 단일 진실로 [docs/architecture/env-contract.md](architecture/env-contract.md) 에 반영
- ansible vault: [ADR 0007](adr/0007-ansible-vault.md) 로 확정 (ansible/.vault_pass.txt + ansible.cfg)

남은 항목:
- agent repo 의 `.github/workflows/release.yml` develop 머지 시점 — github_release path 전환
- cosign / gpg signature 도입 결정
- prod 환경 vault password 별도화 (vault-id) 여부 — 운영자 추가 시점 재검토

## RABBITMQ 연결 (PoC 단계)
- staging 의 `RABBITMQ_HOST` 실값 (mq-vm 10.0.10.110 가닥, 검증 필요)
- `RABBITMQ_VHOST`, `RABBITMQ_USER`, `RABBITMQ_PASS` 실값
- sg-mq 의 ingress 룰에 sg-agent (또는 target-vms CIDR) 추가 필요
- TLS (5671) 사용 여부 — 현재 staging plain (5672) 가닥

## Backup / 운영
- cinder volume `tfstate-agent-fleet` 의 snapshot 주기 / 보존 정책
- iac VM 자체 재구축 절차 (volume detach -> 신 iac 에 attach -> mount -> terraform 명령 복구)
- ansible vault password 백업 정책 (운영자 개인 vault — 별도 트랙)
