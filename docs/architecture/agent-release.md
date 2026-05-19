# Agent Release Contract

agent C11 바이너리 fetch 방식 명세. 결정 history 는 [ADR 0006](../adr/0006-agent-release.md) (예정).

## repo 좌표
- agent repo: `z-converter-assessment/assessment-agent`
- 본 fleet 의 `agent_release_repo` 변수 기본값

## fetch path 두 가지

### local_file (개발/PoC path)
- 컨테이너 빌드 결과 (`agent repo 의 dist/assessment-agent-linux-x86_64`) 를 controller (iac) 측 파일로 inject
- ansible role `agent_binary` 의 `agent_binary_source: local_file` 토글
- agent_binary_local_path: controller 측 절대 경로
- agent_binary_local_sha256: 무결성 검증 (선택). dist/SHA256SUMS 의 첫 컬럼

### github_release (정식 path)
- agent repo 의 GitHub Release 에서 download
- ansible role `agent_binary` 의 `agent_binary_source: github_release` 토글 (기본)
- agent_version: tag 명 (예: `v1.2.3`)
- agent_release_repo: `z-converter-assessment/assessment-agent`
- agent_arch: `x86_64` (asset 명: `assessment-agent-linux-x86_64`)

## 빌드 절차 (agent repo 측)

agent repo 의 빌드는 manylinux2014 컨테이너 안에서 USE_VENDORED=1 release path 만 사용. 결과 바이너리는 GLIBC 2.17 baseline 통과 (CentOS 7+ / debian 11+ 동작 보장).

```bash
# agent repo root 에서
./scripts/build-linux.sh
```

산출물:
- `dist/assessment-agent-linux-x86_64` (6.4MB PIE, 정적 링크: cJSON/rabbitmq-c/libcurl/libarchive/OpenSSL/zlib)
- `dist/SHA256SUMS` (sha256sum 형식)

verify 통과 조건:
- GLIBC 2.17 clean (2.18+ 심볼 미사용)
- ldd 화이트리스트 (libc/libpthread/libdl/libm/libresolv/librt 만 허용)
- forbidden API 미사용 (getrandom, statx, memfd_create, renameat2, copy_file_range, pidfd_*)

## arch
- 현재: x86_64 단일 (agent repo README 명시 "아키텍처: x86_64 only")
- arm64 지원 여부는 agent repo 의 후속 결정

## signature 정책
- 현재: sha256 만 (SHA256SUMS 파일). gpg / cosign 미적용
- agent repo 가 cosign / gpg 도입 시 본 fleet 의 agent_binary role 에 검증 task 추가

## 인증
- 현재: agent repo public 여부 확인 후 결정. private repo 인 경우 gh CLI 인증 (이미 iac 에 셋업 완료) 또는 fine-grained PAT
- local_file path 는 인증 불필요

## 의존
- ansible/roles/agent_binary — 본 contract 구현 위치 (두 path 토글)
- topology.md 의 fleet 멤버 arch (x86_64 단일) — fetch 대상 arch 결정
- agent repo 의 `.github/workflows/release.yml` (현재 feature/agent-v3 브랜치, develop 미머지) — tag 발급 시 자동 release
