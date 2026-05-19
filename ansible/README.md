# ansible

agent 바이너리 install, env inject, systemd unit 관리.

## 구조
- `ansible.cfg` — 기본 설정
- `requirements.yml` — Galaxy collections
- `inventory/<env>/hosts.{json,yml}` — `scripts/tf-output-to-inventory.sh` 출력 또는 수동 작성 (`.example` 만 commit)
- `inventory/<env>/group_vars/` — 환경별 변수. `vault.yml` 은 ansible-vault 로 암호화 후 commit. `vault.yml.example` 가 키 카탈로그
- `playbooks/site.yml` — 전체 배포 흐름
- `playbooks/deploy.yml` — agent install
- `playbooks/health-check.yml` — systemd active 검증
- `roles/common` — OS prerequisites, system user
- `roles/agent_binary` — GitHub Release fetch + 검증
- `roles/agent_env` — `/etc/assessment-agent.env` 작성
- `roles/agent_service` — systemd unit + enable / start

## 사용 흐름
1. `terraform output -json > tf.json && ../scripts/tf-output-to-inventory.sh tf.json > inventory/<env>/hosts.json`
2. `inventory/<env>/group_vars/all.yml`, `vault.yml` 채움
3. `ansible-galaxy collection install -r requirements.yml`
4. `ansible-playbook -i inventory/<env>/hosts.yml playbooks/site.yml --check`
5. `ansible-playbook -i inventory/<env>/hosts.yml playbooks/site.yml`
6. `ansible-playbook -i inventory/<env>/hosts.yml playbooks/health-check.yml`

## 결정 필요
- Vault password 핸들링 (파일, env, helper script)
- agent release contract 확정 후 `roles/agent_binary` 의 sha256 / signature 검증 활성화

세부 contract 는 docs/architecture/ 참조.
