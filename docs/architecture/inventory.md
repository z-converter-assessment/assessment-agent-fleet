# Inventory

Ansible inventory 자동 생성과 구조 명세.

## 파일
- `ansible/inventory/<env>/hosts.json` — `scripts/tf-output-to-inventory.sh` 출력
- `ansible/inventory/<env>/hosts.yml` — 수동 작성용 (json 또는 yml 중 하나)
- `ansible/inventory/<env>/group_vars/all.yml` — 공통 변수
- `ansible/inventory/<env>/group_vars/vault.yml` — 암호화 secret

`.example` 파일만 commit. 실제 생성물은 `.gitignore` 차단.

## 자동 생성 흐름

```
terraform/outputs.tf agent_workers
        |
        | terraform output -json
        v
JSON
        |
        | scripts/tf-output-to-inventory.sh (jq required)
        v
ansible/inventory/<env>/hosts.json
```

terraform 출력의 `agent_workers.value.<name>` 은 `{hostname, address, role}` 형태.
스크립트 변환 결과 각 host 는 `{ansible_host: <address>, agent_role: <role>}` 형태.

## 변수 우선순위
1. host_vars > group_vars > role defaults
2. secret: `vault_<키>` 명명. template 에서 `{{ vault_xxx }}` 참조
3. 공통 (ansible_user, ansible_python_interpreter 등): `group_vars/all.yml`

## 그룹 컨벤션
- `agent_workers` — 모든 fleet 멤버
- 역할별 그룹 (예: `agent_app`, `agent_db`) 은 변환 스크립트 확장 시 자동 생성 가능

## 의존
- `scripts/tf-output-to-inventory.sh` (jq 의존)
- `terraform/outputs.tf` 의 `agent_workers` 구조
- `docs/architecture/env-contract.md` 의 vault 명명 컨벤션
