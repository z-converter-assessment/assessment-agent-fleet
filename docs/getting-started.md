# Getting Started

본 repo 를 처음 다루는 사람이 큰 그림을 잡기 위한 진행 순서. 키워드 중심으로 단계만 나열.

실제 명령은 README 의 "빠른 시작" 또는 `docs/operations/` 의 절차 문서 참조. 본 문서는 흐름만 안내.

## 0. 작업 환경 진입
- RDP / WindowApp -> Windows Server 2022 점프호스트
- 점프호스트에서 인프라 VM 생성 + ssh 셋업 (사이트 운영자 절차)
- ssh -> 인프라 VM (Ubuntu 또는 Debian)
- 인프라 VM toolchain 설치: `bash scripts/bootstrap.sh` (세부 [operations/bootstrap.md](operations/bootstrap.md))
- 사전 체크: [preflight.md](preflight.md)

## 1. credential / 인증
- application credential 발급 (Horizon) -> `~/.config/openstack/clouds.yaml` 0600 (세부 [architecture/credentials.md](architecture/credentials.md))
- `gh auth login` (HTTPS, web browser flow)
- `git config --global user.{name,email}`
- 검증: `openstack --os-cloud openstack token issue` / `gh auth status`

## 2. OpenStack 자산 (한 번만)
- ssh keypair `agent-fleet` 생성 + 등록
- `sg-agent` 의 ssh 22 ingress 를 target-vms 서브넷 (10.0.10.0/26) 으로 좁힘
- terraform state 용 cinder volume `tfstate-agent-fleet` 생성 + iac 에 attach + mount (세부 [adr/0005-terraform-state-backend.md](adr/0005-terraform-state-backend.md))

## 3. Terraform — fleet provisioning
- `terraform/environments/<env>/terraform.tfvars` 와 `backend.hcl` 채움
- `terraform init -backend-config=...` -> `plan` -> `apply`
- output 으로 fleet 멤버 IP / hostname 노출 (세부 [architecture/topology.md](architecture/topology.md))

## 4. Ansible — agent 배포
- `bash scripts/setup-ansible.sh` (한 번만, galaxy + vault password)
- `bash scripts/build-inventory.sh <env>` (terraform output -> hosts.json)
- `bash scripts/prepare-staging-vars.sh` (all.yml + sha256 자동 + vault dummy)
- `ansible-playbook -i inventory/<env>/hosts.json playbooks/site.yml`

세부 [operations/deploy.md](operations/deploy.md), [architecture/env-contract.md](architecture/env-contract.md).

## 5. 헬스 검증
- agent systemd active 상태 확인
- agent -> engine broker 도달 검증 (engine 인프라 별도 트랙)

## 6. 운영 루틴
- agent 버전 갱신: [operations/upgrade.md](operations/upgrade.md)
- env / secret 회전: [operations/rotate.md](operations/rotate.md)
- 인시던트 대응: [operations/runbook.md](operations/runbook.md)

## 7. 정리 (작업 종료)
- `bash scripts/teardown.sh` — 본 repo 가 만든 OpenStack 자원 + iac 산출물 일괄 제거
