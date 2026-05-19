# assessment-agent-fleet

OpenStack 환경에서 agent 워커 VM N대를 Terraform과 Ansible로 운영하는 인프라 repo.

## 환경 전제
- 작업 거점: 점프호스트(Windows Server 2022, RDP/WindowApp 접속) 안의 인프라 VM (Ubuntu 또는 Debian)
- 인프라 VM에서 OpenStack API 호출하여 워커 VM provisioning
- agent C11 바이너리는 별도 repo의 GitHub Release에서 fetch

## 도구
- Terraform (OpenStack provider) — VM provisioning
- Ansible — agent install, systemd unit, env inject

## 시작
1. `docs/preflight.md` 체크리스트 통과
2. `docs/getting-started.md` 순서대로 진행
3. 신규 배포 절차: `docs/operations/deploy.md`
4. 설계 단일 진실: `docs/architecture/`
5. 의사결정 history: `docs/adr/`

## 디렉토리
- `README.md` — 본 파일
- `.claude/CLAUDE.md` — Claude Code 진입 시 read
- `.gitignore`
- `.github/` — PR template, lint CI
- `docs/` — 문서 (architecture, operations, adr, ref)
- `terraform/` — VM provisioning
- `ansible/` — agent install, env, systemd
