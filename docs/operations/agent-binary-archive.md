# Agent Binary Archive

agent 빌드 산출물을 agent repo 의 working tree 와 분리해서 따로 보관.

## 목적
- agent repo dist/ 와 fleet 의 ansible 변수 분리 → agent repo 가 변경/재clone 돼도 빌드 결과 유지
- 버전별 보관 → 새 빌드 후에도 옛 산출물 retain (롤백/비교 용도)
- ansible 의 `agent_binary_local_path` 를 안정적인 경로로 고정 (symlink) → 새 빌드 시 ansible 변수 변경 불필요

## 구조

```
~/agent-binaries/
  dev-<sha8>/                              # 빌드별 디렉토리
    assessment-agent-linux-x86_64          # PIE binary
    SHA256SUMS                             # agent repo 의 release target 출력
    BUILD_INFO                             # 빌드 메타데이터
  dev-<another-sha8>/                      # 다음 빌드
  ...
  latest -> dev-<sha8>                      # 가장 최근 빌드 가리키는 symlink
```

`BUILD_INFO` 내용:
- `build_date` (UTC)
- `agent_repo`, `agent_repo_commit`, `agent_repo_branch`
- `builder` (스크립트 경로)
- `arch`, `glibc_baseline`
- `sha256`, `tag`

## 새 빌드 archive

agent repo 에서 빌드 완료 후 fleet repo 의 helper 한 줄:

```bash
cd ~/assessment-agent
bash scripts/build-linux.sh                                          # dist/* 생성
cd ~/assessment-agent-fleet
bash scripts/archive-agent-build.sh                                  # ~/agent-binaries/dev-<sha8>/ archive + latest 갱신
```

특정 tag 명시:

```bash
ARCHIVE_TAG=v0.1.0-dev bash scripts/archive-agent-build.sh
```

다른 agent repo 위치 또는 archive 위치:

```bash
AGENT_REPO=/path/to/agent ARCHIVE_ROOT=/var/lib/agent-binaries \
  bash scripts/archive-agent-build.sh
```

## ansible 연동

`ansible/inventory/<env>/group_vars/all/vars.yml.example` 의 default:

```yaml
agent_binary_local_path: "{{ lookup('env', 'HOME') }}/agent-binaries/latest/assessment-agent-linux-x86_64"
```

운영자별 `$HOME` 이 다를 수 있어 `lookup('env', 'HOME')` 로 해석. `~/agent-binaries/latest/` symlink 가 항상 최신 빌드 가리킴.

`agent_binary_local_sha256` 은 `~/agent-binaries/latest/SHA256SUMS` 첫 컬럼에서 추출. `scripts/prepare-staging-vars.sh` 가 자동 추출.

## 롤백

특정 옛 빌드로 되돌리려면 symlink 만 갱신:

```bash
ln -sfn dev-<old-sha8> ~/agent-binaries/latest
bash scripts/prepare-staging-vars.sh                                 # sha256 재추출 + vars.yml 갱신
cd ansible && ansible-playbook -i inventory/staging/hosts.json playbooks/site.yml
```

## github_release path 사용 시

`agent_binary_source: github_release` 인 경우 본 archive 불필요. agent repo 의 GitHub Release 에서 직접 download (ansible role 의 `get_url`).

local archive 는 dev / PoC 환경의 standard. 정식 운영은 github_release 권장.
