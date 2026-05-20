# CLAUDE.md

## 정체성
assessment-agent-fleet — OpenStack 환경에서 agent fleet 멤버 VM N대를 Terraform과 Ansible로 provisioning, 운영하는 인프라 repo. fleet 멤버 = 평가 대상 시뮬레이션 VM (agent C11 install -> 자신을 인벤토리/메트릭 수집 후 engine 으로 outbound 전송).

## 작업 거점
- 진입 경로: 맥북 -> RDP/WindowApp -> Windows Server 2022 점프호스트 -> ssh -> 인프라 VM
- 인프라 VM: Ubuntu 또는 Debian 안정 버전. OpenStack API 호출 거점
- credential과 ssh 세션은 사전 셋업 완료 전제

## 도구
- Terraform: OpenStack provider로 VM, network, security group provisioning
- Ansible: agent 바이너리 install, env inject, systemd unit 관리

## 외부 의존
- agent C11 바이너리는 별도 repo의 GitHub Release. Ansible 단계에서 fetch (sha256 / signature 검증은 release contract 확정 후 활성화)
- 세부 contract: docs/architecture/agent-release.md

## 문서 분기 원칙
- CLAUDE.md는 컨텍스트 상주 시 항상 유의미한 정보만 보유
- 세부는 docs/ 분기
- 참조 방향: CLAUDE.md -> docs (단방향)
- docs/ref/ 는 격리. 어떤 문서나 코드도 참조 금지

## commit 규칙
- type prefix: feat / fix / chore / refactor / test 중 정확한 분류
- 한글 설명 (subject + body)
- 세부: docs/commit.md

## 변경 금지 (팀 결정 영역)
- `.github/PULL_REQUEST_TEMPLATE.md`

## 진입 시 first read
1. docs/getting-started.md — 키워드 중심 진행 순서
2. docs/preflight.md — 작업 전 체크리스트
3. docs/architecture/ — 설계 단일 진실 (토폴로지, credential, agent release, env contract)
4. docs/operations/ — 운영 절차 (bootstrap, deploy, upgrade, rotate, runbook)
5. docs/adr/ — 결정 history
6. docs/commit.md — commit 규칙
