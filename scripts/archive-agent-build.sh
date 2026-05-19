#!/bin/bash
# archive-agent-build.sh — agent repo 의 dist/* 를 ~/agent-binaries/<version>/ 로 archive.
#
# 사용:
#   bash scripts/archive-agent-build.sh
#
# 절차:
#   1. agent repo dist/SHA256SUMS 첫 컬럼에서 sha256 short (8자) 추출
#   2. ~/agent-binaries/dev-<sha8>/ 디렉토리 생성 (또는 별도 tag 지정 시 그 값)
#   3. dist/* 복사 + BUILD_INFO 작성 (날짜, agent repo commit, branch, sha256)
#   4. ~/agent-binaries/latest -> dev-<sha8> symlink 갱신
#
# 환경변수:
#   ARCHIVE_TAG  지정 시 dev-<sha8> 대신 사용 (예: v0.1.0-dev)

set -euo pipefail

AGENT_REPO="${AGENT_REPO:-$HOME/assessment-agent}"
ARCHIVE_ROOT="${ARCHIVE_ROOT:-$HOME/agent-binaries}"

DIST_BIN="$AGENT_REPO/dist/assessment-agent-linux-x86_64"
DIST_SHA="$AGENT_REPO/dist/SHA256SUMS"

if [ ! -f "$DIST_BIN" ] || [ ! -f "$DIST_SHA" ]; then
  echo "ERROR: $AGENT_REPO/dist/ 의 산출물이 없다. 'bash scripts/build-linux.sh' 먼저 실행." >&2
  exit 1
fi

SHA256=$(awk '{print $1; exit}' "$DIST_SHA")
SHA_SHORT=${SHA256:0:8}
TAG="${ARCHIVE_TAG:-dev-${SHA_SHORT}}"
DEST="$ARCHIVE_ROOT/$TAG"

mkdir -p "$DEST"
cp -p "$DIST_BIN" "$DEST/"
cp -p "$DIST_SHA" "$DEST/"

cat > "$DEST/BUILD_INFO" <<EOF
build_date: $(date -u +%Y-%m-%dT%H:%M:%SZ)
agent_repo: z-converter-assessment/assessment-agent
agent_repo_commit: $(git -C "$AGENT_REPO" rev-parse HEAD)
agent_repo_branch: $(git -C "$AGENT_REPO" branch --show-current)
builder: scripts/build-linux.sh (manylinux2014, USE_VENDORED=1)
arch: x86_64
glibc_baseline: 2.17
sha256: $SHA256
tag: $TAG
EOF

ln -sfn "$TAG" "$ARCHIVE_ROOT/latest"

echo "archive 완료: $DEST"
echo "latest -> $TAG"
ls -la "$ARCHIVE_ROOT/"
