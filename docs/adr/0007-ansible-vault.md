# 0007. Ansible vault password 핸들링

- Status: Accepted
- Date: 2026-05-19

## Context
ansible-vault 로 암호화한 `vault.yml` (RABBITMQ_PASS 등 secret 포함) 의 복호화 password 핸들링 방식 결정 필요. `docs/decisions-pending.md` 의 Ansible 항목.

가능 후보:
- 파일 (`~/.ansible-vault-pass` 등)
- env 변수 (`ANSIBLE_VAULT_PASSWORD_FILE`)
- 대화식 (`--ask-vault-pass`)
- helper script (외부 KMS / vault 서버 호출)

운영 컨텍스트:
- 운영자 1인
- 단일 iac VM 에서 모든 ansible 실행
- staging / prod 환경 분리 (vault.yml 도 분리)

## Decision
ansible.cfg 상대 경로 password 파일. `ansible/ansible.cfg` 에 `vault_password_file = .vault_pass.txt` 박음. `.gitignore` 가 차단.

- 파일: `ansible/.vault_pass.txt`, 0600, owner 운영자
- staging / prod 공통 password (vault.yml 자체가 분리되어 secret 충격 범위 분리 효과 유지)
- 생성: `cd ansible && openssl rand -base64 32 > .vault_pass.txt && chmod 0600 .vault_pass.txt`
- 분실 시 모든 vault.yml secret 재발급 + 재암호화

## Consequences
- 운영자가 `ansible-playbook` 실행 시 추가 인자 / env 셋업 불필요. `ansible.cfg` 가 자동 적용
- repo 안에 password 파일이 위치하지만 `.gitignore` 로 git 추적 차단 — 실수 commit 방지
- 환경 (staging / prod) 단일 password 라 password 노출 시 양 환경 영향. 단 vault.yml 자체는 분리되어 prod secret 이 staging vault.yml 에 들어가지 않음
- 운영자 추가 합류 또는 prod 보안 강화 필요 시 `vault-id` 기능으로 환경별 password 분리 (별도 ADR)

## Alternatives
- env 변수 (`ANSIBLE_VAULT_PASSWORD_FILE`): shell rc / wrapper script 의존. ansible.cfg 단일 진실 깨짐. 운영자별 셋업 분기 늘어남
- 대화식 (`--ask-vault-pass`): 자동화 불가. 운영자 휴먼에러 지점
- 사용자 home (`~/.ansible-vault-pass-fleet`): repo 와 분리되지만 운영자별 path 분기. 단일 iac 운영자 1인 환경에선 분리 효과 없음
- helper script (KMS / Vault 서버): 외부 의존성 추가. 본 클라우드에 KMS 없음 (catalog 정찰 결과)
- vault-id 환경별 분리 (초기 도입): 1인 운영 + 단일 iac 에서 분리 부담만. 향후 확장 path 로 보류

## 후속 항목
- password 파일 백업 정책 (별도 보관처 — 1Password / Bitwarden 등 운영자 개인 vault) — 본 ADR 범위 밖
- 운영자 추가 시 vault-id 분리 재검토
