#!/bin/bash
# prepare-staging-vars.sh — staging group_vars 실값화
#
# 사용:
#   bash scripts/prepare-staging-vars.sh
#
# 절차:
#   1. all.yml.example -> all.yml (덮어쓰기 안 함, 이미 있으면 skip)
#   2. agent_binary_local_sha256 을 agent repo dist/SHA256SUMS 에서 자동 추출
#   3. vault.yml dummy 생성 (PoC, ansible-vault encrypt)

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV_DIR="$REPO_ROOT/ansible/inventory/staging/group_vars/all"
# 빌드 산출물은 ~/agent-binaries/latest/ 로 따로 관리. agent repo dist/ 가 아님.
AGENT_DIST_SHA="$HOME/agent-binaries/latest/SHA256SUMS"

cd "$REPO_ROOT/ansible"

echo "=== 1) vars.yml 셋업 ==="
if [ -f "$ENV_DIR/vars.yml" ]; then
  echo "이미 존재: $ENV_DIR/vars.yml (건너뜀, 수동 갱신 필요 시 직접 편집)"
else
  cp "$ENV_DIR/vars.yml.example" "$ENV_DIR/vars.yml"
  echo "생성: $ENV_DIR/vars.yml"
fi

echo
echo "=== 2) agent_binary_local_sha256 자동 추출 ==="
if [ -f "$AGENT_DIST_SHA" ]; then
  sha=$(awk '{print $1; exit}' "$AGENT_DIST_SHA")
  echo "agent dist sha256: $sha"
  if grep -q "^agent_binary_local_sha256:" "$ENV_DIR/vars.yml"; then
    sed -i "s|^agent_binary_local_sha256:.*|agent_binary_local_sha256: \"$sha\"|" "$ENV_DIR/vars.yml"
    echo "vars.yml 의 agent_binary_local_sha256 갱신됨"
  fi
else
  echo "agent dist 미생성 ($AGENT_DIST_SHA). 빌드 완료 후 재실행 필요."
fi

echo
echo "=== 3) vault.yml (engine .env.example 기본 credentials) ==="
if [ -f "$ENV_DIR/vault.yml" ]; then
  echo "이미 존재: $ENV_DIR/vault.yml (건너뜀)"
else
  if [ ! -f .vault_pass.txt ]; then
    echo "ERROR: ansible/.vault_pass.txt 없음. scripts/setup-ansible.sh 먼저 실행." >&2
    exit 1
  fi
  # 시연 환경: mq-vm 의 RabbitMQ 가 engine .env.example 기본 credentials 사용 (assessment / assessment, vhost /assessment)
  cat > /tmp/vault.plain.yml <<'EOF'
vault_rabbitmq_user: "assessment"
vault_rabbitmq_pass: "assessment"
EOF
  ansible-vault encrypt --output "$ENV_DIR/vault.yml" /tmp/vault.plain.yml
  rm -f /tmp/vault.plain.yml
  echo "생성: $ENV_DIR/vault.yml (암호화)"
fi

echo
echo "=== verify ==="
echo "--- vars.yml 의 binary 관련 키 ---"
grep -E "^agent_binary_(source|local_path|local_sha256)" "$ENV_DIR/vars.yml" || true
echo "--- vault.yml 헤더 ---"
head -2 "$ENV_DIR/vault.yml"
