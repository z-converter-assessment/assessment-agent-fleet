#!/bin/bash
# setup-ansible.sh — ansible 초기 셋업 (한 번만)
#
# 절차:
#   1. ansible-core + jq 설치 (apt, sudo)
#   2. galaxy collection install
#   3. vault password 파일 생성 (32B base64, 0600)
#
# Idempotent: 이미 설치된 항목은 skip.

set -euo pipefail

REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "=== 1) apt install (ansible-core + jq) ==="
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  ansible-core jq

echo
echo "=== 2) ansible-galaxy collection install ==="
cd "$REPO_ROOT/ansible"
ansible-galaxy collection install -r requirements.yml

echo
echo "=== 3) vault password 파일 ==="
if [ -f "$REPO_ROOT/ansible/.vault_pass.txt" ]; then
  echo "이미 존재: $REPO_ROOT/ansible/.vault_pass.txt (건너뜀)"
else
  openssl rand -base64 32 > "$REPO_ROOT/ansible/.vault_pass.txt"
  chmod 0600 "$REPO_ROOT/ansible/.vault_pass.txt"
  echo "생성: $REPO_ROOT/ansible/.vault_pass.txt"
fi

echo
echo "=== verify ==="
ansible --version | head -1
jq --version
ls -la "$REPO_ROOT/ansible/.vault_pass.txt"
