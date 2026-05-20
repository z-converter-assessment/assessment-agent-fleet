# 0006. agent release contract

- Status: Accepted
- Date: 2026-05-19

## Context
fleet 멤버에 install 할 agent C11 바이너리의 fetch / 검증 / 빌드 방법 결정 필요. `docs/decisions-pending.md` 의 Agent Release 항목.

agent repo (`z-converter-assessment/assessment-agent`) 정찰 결과:
- 빌드 시스템: GNU Make + 정적 vendor (cJSON / rabbitmq-c / libcurl / libarchive / OpenSSL / zlib)
- `USE_VENDORED=1` 정적 링크. glibc 만 동적 (libc / libpthread / libdl / libm / libresolv / librt)
- 빌드 환경: manylinux2014 컨테이너 (CentOS 7 base, glibc 2.17) — `scripts/build-linux.sh` 한 줄 진입점
- verify 통과 조건: GLIBC 2.17 clean / ldd 화이트리스트 / forbidden API 미사용
- 산출물: `dist/assessment-agent-linux-x86_64` (~6.4MB PIE) + `dist/SHA256SUMS`
- arch: x86_64 only (agent repo README 명시)
- `.github/workflows/release.yml` 은 현재 `feature/agent-v3` 브랜치에만 존재 — develop 미머지

## Decision

### repo 좌표
`z-converter-assessment/assessment-agent`. fleet 의 `agent_release_repo` 기본값.

### arch
`x86_64` 단일. asset 명: `assessment-agent-linux-x86_64`.

### fetch path 두 가지 (ansible role 토글)
- `agent_binary_source: github_release` (정식 path) — `ansible.builtin.get_url` 로 release asset download
- `agent_binary_source: local_file` (개발 / PoC path) — controller (iac) 측 빌드 산출물을 `ansible.builtin.copy` 로 fleet 멤버 로 push

### 빌드 절차
agent repo 의 `scripts/build-linux.sh` 한 줄. host 측엔 Docker 만 필요. 컨테이너 안에서 build-prep + vendor-fetch + vendor-build + USE_VENDORED=1 release 일괄.

### 무결성 검증
- 현재: sha256 (`dist/SHA256SUMS` 첫 컬럼). local_file path 에선 ansible copy 의 `checksum` 인자
- 향후: cosign / gpg 도입 시 본 fleet role 에 검증 task 추가

## Consequences
- agent repo 가 release tag 발급하기 전에도 fleet 측에서 PoC 가능 (local_file path)
- release.yml 머지 + tag 발급 시점부터 github_release path 자동 동작 (변수 토글만)
- ABI 호환성: GLIBC 2.17 baseline 으로 debian 11+ / CentOS 7+ / RHEL 8+ / Amazon Linux 2 모두 동작
- 빌드 호스트가 manylinux2014 컨테이너로 표준화 — iac 에 docker 만 있으면 누가 빌드해도 동일 결과 (호스트 OS 무관, ABI 일관성)
- arch 단일 (x86_64) — terraform fleet 의 flavor 도 amd64 instance 만. 향후 arm64 추가 시 본 ADR Supersede

## Alternatives
- 호스트 직접 빌드 (manylinux 컨테이너 미사용): iac (debian13 / glibc 2.38) 에서 빌드 시 GLIBC 2.17 baseline 깨짐. agent repo verify 통과 못함
- agent repo 의 release.yml 머지 + tag 발급 후 시작: agent 개발 진행 중이라 즉시 release 발급 어려움. local_file path 가 즉시 진행 path
- 정적 musl + alpine: agent repo 의 default 가 glibc baseline. musl 전환 시 agent repo 측 변경 필요
- arch 다중화 (arm64 추가): agent repo 가 x86_64 only 라 본 fleet 도 일치 유지

## 후속 항목
- agent repo 의 release.yml 이 develop 으로 머지 + 첫 tag (예: `v0.1.0-dev`) 발급 시점 → local_file path 사용 종료, github_release path 로 전환
- cosign / gpg signature 도입 결정 (별도 ADR)
