# ansible

agent 바이너리 install, env inject, systemd unit 관리.

## 구조
- `ansible.cfg` — 기본 설정 + `vault_password_file = .vault_pass.txt`
- `requirements.yml` — Galaxy collections (openstack.cloud / community.general / ansible.posix)
- `inventory/<env>/hosts.{json,yml}` — `scripts/tf-output-to-inventory.sh` 출력 또는 수동 작성 (`.example` 만 commit)
- `inventory/<env>/group_vars/` — 환경별 변수
  - `all.yml` — 공통 변수 (non-secret). `all.yml.example` 가 표준
  - `vault.yml` — secret (`ansible-vault` 로 암호화 후 commit). `vault.yml.example` 가 키 카탈로그
- `.vault_pass.txt` — ansible-vault 복호화 password (0600, .gitignore 차단). 결정 history: [ADR 0007](../docs/adr/0007-ansible-vault.md)
- `playbooks/site.yml` — 전체 배포 흐름 (deploy + health-check)
- `playbooks/deploy.yml` — agent install
- `playbooks/health-check.yml` — systemd active 검증
- `roles/common` — OS prerequisites, system user + group, /var/lib/agent-worker
- `roles/agent_binary` — 바이너리 fetch + 검증 (github_release / local_file 토글). [ADR 0006](../docs/adr/0006-agent-release.md)
- `roles/agent_env` — `/etc/assessment-agent/{agent.env, agent.env.local}` 작성. 키 카탈로그: [docs/architecture/env-contract.md](../docs/architecture/env-contract.md)
- `roles/agent_service` — systemd unit + enable / start (agent repo 의 hardening 옵션 동일)

## 초기 셋업 (한 번)

```bash
# 1. ansible 설치
sudo apt-get install -y ansible-core

# 2. collections
cd ansible
ansible-galaxy collection install -r requirements.yml

# 3. vault password 파일
openssl rand -base64 32 > .vault_pass.txt
chmod 0600 .vault_pass.txt

# 4. inventory 자동 생성
cd ../terraform
terraform output -json > /tmp/tf-output-staging.json
../scripts/tf-output-to-inventory.sh /tmp/tf-output-staging.json \
  > ../ansible/inventory/staging/hosts.json

# 5. group_vars 실값화
cd ../ansible
cp inventory/staging/group_vars/all.yml.example inventory/staging/group_vars/all.yml
# all.yml 의 RABBITMQ_HOST 등 환경별 값 수정

# 6. vault 생성 (secret 입력)
ansible-vault create inventory/staging/group_vars/vault.yml
# vault_rabbitmq_user, vault_rabbitmq_pass 등 채움
```

## 배포 흐름

```bash
cd ansible
ansible-playbook -i inventory/staging/hosts.json playbooks/site.yml --check    # dry-run
ansible-playbook -i inventory/staging/hosts.json playbooks/site.yml             # 적용
ansible-playbook -i inventory/staging/hosts.json playbooks/health-check.yml     # 검증
```

vault password 는 `.vault_pass.txt` 가 자동 로드. `--ask-vault-pass` 불필요.

## 결정 필요
잔여 항목은 [docs/decisions-pending.md](../docs/decisions-pending.md) 참조.

세부 contract 는 [docs/architecture/](../docs/architecture/) 참조.
