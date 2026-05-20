# assessment-agent-fleet

OpenStack 환경에서 agent fleet 멤버 VM N대를 Terraform과 Ansible로 운영하는 인프라 repo.

fleet 멤버 = 평가 대상 시뮬레이션 VM. 각 멤버에 agent C11 바이너리 install -> agent 가 자신을 인벤토리/메트릭 수집 후 engine 으로 outbound 전송.

## 환경 전제
- 작업 거점: 점프호스트 (Windows Server 2022, RDP/WindowApp) -> ssh -> 인프라 VM (iac, Debian/Ubuntu)
- 인프라 VM 에서 OpenStack API 호출 + terraform/ansible 실행
- agent 바이너리는 별도 repo `z-converter-assessment/assessment-agent` 의 GitHub Release 또는 로컬 빌드 산출물

## 빠른 시작 (재현 흐름)

처음 셋업에서 fleet 운영까지 한 줄씩.

### 1) 인프라 VM toolchain (한 번만)

```bash
bash scripts/bootstrap.sh
```

설치: openstack CLI, terraform 1.10, ansible-core, gh, docker.io, jq 등. docker MTU 1450 설정 + 사용자 docker 그룹 추가. 자세히는 `docs/operations/bootstrap.md`.

### 2) credential / 인증 (수동, 한 번만)

```bash
# OpenStack application credential
# Horizon -> Identity -> Application Credentials -> Create -> clouds.yaml 다운로드
mkdir -p ~/.config/openstack
chmod 0700 ~/.config/openstack
# (다운로드 받은 clouds.yaml 을 ~/.config/openstack/ 으로 복사 후)
chmod 0600 ~/.config/openstack/clouds.yaml
openstack --os-cloud openstack token issue   # 검증

# GitHub
gh auth login                                # GitHub.com / HTTPS / web browser

# git identity
git config --global user.name  "<GitHub username>"
git config --global user.email "<commit 이메일>"

# 새 셸 (docker 그룹 활성)
newgrp docker
```

### 3) OpenStack 자산 (한 번만)

```bash
# ssh keypair
ssh-keygen -t ed25519 -f ~/.ssh/agent-fleet -N "" -C "agent-fleet"
openstack keypair create --public-key ~/.ssh/agent-fleet.pub agent-fleet

# sg-agent 의 ssh 22 ingress 를 target-vms 서브넷 CIDR 로 좁힘
# (기존 broad 룰 삭제 + 좁힌 룰 신규)
OLD_RULE=$(openstack security group rule list sg-agent -f value -c ID -c "Port Range" -c "IP Range" \
  | awk '$2 == "22:22" && $3 == "0.0.0.0/0" {print $1}')
[ -n "$OLD_RULE" ] && openstack security group rule delete "$OLD_RULE"
openstack security group rule create --proto tcp --dst-port 22 --remote-ip 10.0.10.0/26 sg-agent

# terraform state 용 cinder volume
openstack volume create --size 1 --description "terraform state for assessment-agent-fleet" tfstate-agent-fleet
openstack server add volume IaC tfstate-agent-fleet
lsblk    # /dev/vdb 1G 인식 확인 후
sudo mkfs.ext4 -L tfstate /dev/vdb
sudo mkdir -p /var/lib/terraform-state
sudo mount /dev/vdb /var/lib/terraform-state
echo "LABEL=tfstate /var/lib/terraform-state ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo chown $USER:$USER /var/lib/terraform-state
mkdir -p /var/lib/terraform-state/staging /var/lib/terraform-state/prod
```

### 4) terraform — fleet provisioning

```bash
cp terraform/environments/staging/terraform.tfvars.example terraform/environments/staging/terraform.tfvars
cp terraform/environments/staging/backend.hcl.example      terraform/environments/staging/backend.hcl
# 필요 시 매트릭스 / VM 개수 편집

cd terraform
terraform init -backend-config=environments/staging/backend.hcl
terraform plan  -var-file=environments/staging/terraform.tfvars
terraform apply -var-file=environments/staging/terraform.tfvars
cd ..
```

### 5) ansible 셋업 (한 번만)

```bash
bash scripts/setup-ansible.sh
```

설치: galaxy collection + vault password 파일 생성. 자세히는 `ansible/README.md`.

### 6) ansible — agent 배포

```bash
# inventory 자동 생성 (terraform output -> ansible hosts.json)
bash scripts/build-inventory.sh staging

# group_vars/all 채움 (agent_binary local_file path, vault dummy)
bash scripts/prepare-staging-vars.sh

# deploy + health-check
cd ansible
ansible-playbook -i inventory/staging/hosts.json playbooks/site.yml
```

agent 가 GitHub Release 가 아닌 로컬 빌드 산출물을 사용하려면 (개발 path):
- agent repo 에서 `bash scripts/build-linux.sh` 로 `dist/` 생성
- 본 repo 에서 `bash scripts/archive-agent-build.sh` 로 `~/agent-binaries/dev-<sha8>/` 로 archive + `latest` symlink 갱신
- `prepare-staging-vars.sh` 가 `~/agent-binaries/latest/SHA256SUMS` 에서 sha256 자동 추출 → `vars.yml` 갱신

archive 구조: `docs/operations/agent-binary-archive.md`.

정식 release path (`agent_binary_source: github_release`) 는 `ansible/inventory/<env>/group_vars/all/vars.yml` 에서 토글.

### 7) 정리 (teardown)

```bash
bash scripts/teardown.sh
sudo umount /var/lib/terraform-state 2>/dev/null
sudo sed -i '/LABEL=tfstate/d' /etc/fstab
sudo rmdir /var/lib/terraform-state 2>/dev/null
```

OpenStack 자원 (fleet VM, 임시 engine, sg-agent 변경분, cinder volume) + iac 작업 산출물 (.terraform, tfvars, inventory, vault.yml) 일괄 제거. keypair / sg-agent 자체 / toolchain / clouds.yaml 은 유지.

## scripts 목록

| script | 역할 | 실행 시점 |
|--------|------|----------|
| `bootstrap.sh` | iac toolchain 초기 셋업 | 처음 한 번 |
| `setup-ansible.sh` | ansible galaxy + vault password | 처음 한 번 |
| `archive-agent-build.sh` | agent dist/* 를 ~/agent-binaries/dev-<sha8>/ 로 archive + latest symlink | agent 빌드 후 매번 |
| `build-inventory.sh <env>` | terraform output -> ansible inventory | terraform apply 후 매번 |
| `prepare-staging-vars.sh` | group_vars/all 실값 + sha256 자동 추출 + vault dummy | archive 후 |
| `tf-output-to-inventory.sh` | inventory 변환 (build-inventory.sh 가 호출) | (내부) |
| `teardown.sh` | 본 repo 가 만든 OpenStack 자원 + 산출물 정리 | 종료 시 |

## 디렉토리

```
README.md                       이 파일
.claude/CLAUDE.md               Claude Code 진입 시 read
.gitignore
.github/                        PR template, lint CI
CHANGELOG.md
docs/
  getting-started.md            진입 순서 (키워드)
  preflight.md                  작업 전 체크리스트
  commit.md                     commit 규칙
  decisions-pending.md          잔여 TBD
  architecture/                 설계 단일 진실 (topology / credentials / agent-release / env-contract / inventory)
  operations/                   운영 절차 (bootstrap / deploy / upgrade / rotate / runbook / infra-vm-create)
  adr/                          결정 history
  ref/                          격리. 어떤 문서/코드도 참조 금지
terraform/                      VM provisioning
  versions.tf providers.tf variables.tf main.tf outputs.tf
  modules/vm/                   VM 단위 module (port + compute_instance)
  environments/{staging,prod}/  환경별 tfvars.example + backend.hcl.example
ansible/
  ansible.cfg                   roles_path + vault_password_file
  requirements.yml              galaxy collection
  playbooks/{site,deploy,services,noise,health-check}.yml
  roles/{common,agent_binary,agent_env,agent_service}/
  roles/service_{web,db,cache,mq,container,monitor,app}/  service install (OS family 분기)
  roles/noise{,_agent_restart,_offline_once}/              부하 패턴 (stress-ng / systemd timer / transient unit)
  inventory/{staging,prod}/
scripts/                        helper 스크립트 (위 표)
```

## 결정 history
- [ADR 0001](docs/adr/0001-tooling.md) — Terraform + Ansible
- [ADR 0002](docs/adr/0002-commit-convention.md) — commit message 규칙
- [ADR 0003](docs/adr/0003-credential-method.md) — OpenStack credential = application credential
- [ADR 0004](docs/adr/0004-topology.md) — fleet topology (target-vms 서브넷, c1_m1_r30, debian12, sg-agent)
- [ADR 0005](docs/adr/0005-terraform-state-backend.md) — terraform state = local + cinder volume
- [ADR 0006](docs/adr/0006-agent-release.md) — agent release (github_release / local_file 토글)
- [ADR 0007](docs/adr/0007-ansible-vault.md) — ansible vault password = repo 상대 파일
- [ADR 0008](docs/adr/0008-multi-os-demo.md) — multi-OS / multi-service / noise 시연 매트릭스 (8대)

## 잔여 결정
`docs/decisions-pending.md`.
