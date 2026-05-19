# Agent Release Contract

agent C11 바이너리는 별도 repo의 GitHub Release에서 fetch.

## 기대 형식
- repo: (TBD — owner / repo 결정 필요)
- tag: semver (예: `v1.2.3`)
- asset 명: `assessment-agent-linux-<arch>` (arch: amd64, arm64 등)
- 첨부 sha256: `assessment-agent-linux-<arch>.sha256`
- 첨부 signature (선택): `assessment-agent-linux-<arch>.sig`

결정 필요
- 정확한 repo 좌표
- 지원 arch 목록
- signature 검증 정책 (cosign, gpg, 또는 미적용)

## fetch 방법
Ansible role `agent_binary`에서 처리.
- 우선 `gh release download --repo <owner>/<repo> --pattern <asset>`
- 대안: `ansible.builtin.get_url` + sha256 검증

## 인증
- private repo: gh CLI 인증 또는 fine-grained PAT
- public repo: 무인증

## 의존
- ansible/roles/agent_binary — 본 contract 구현 위치
- topology.md 의 워커 VM arch — fetch 대상 arch 결정
