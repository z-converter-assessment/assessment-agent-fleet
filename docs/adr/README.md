# ADR — Architecture Decision Records

본 repo의 의사결정 history. 새 결정마다 새 파일 추가. 기존 결정은 수정하지 않고 Superseded 표기로 대체.

## 파일 명명
`NNNN-제목.md` (NNNN: 0001 부터 4자리 zero-padded)

## 템플릿
[template.md](template.md) 참조.

## 목록
- [0001-tooling.md](0001-tooling.md) — Terraform + Ansible 선택
- [0002-commit-convention.md](0002-commit-convention.md) — commit message 규칙
- [0003-credential-method.md](0003-credential-method.md) — OpenStack credential 방식: application credential
- [0004-topology.md](0004-topology.md) — fleet topology
- [0005-terraform-state-backend.md](0005-terraform-state-backend.md) — Terraform state backend: local + cinder volume
- [0006-agent-release.md](0006-agent-release.md) — agent release contract
- [0007-ansible-vault.md](0007-ansible-vault.md) — Ansible vault password 핸들링
