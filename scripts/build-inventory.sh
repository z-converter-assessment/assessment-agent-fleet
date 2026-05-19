#!/bin/bash
# build-inventory.sh — terraform output 으로 ansible inventory 생성
#
# 사용:
#   bash scripts/build-inventory.sh <env>      # 예: staging, prod
#
# 절차:
#   1. cd terraform && terraform output -json > /tmp/tf-<env>.json
#   2. jq 변환 (또는 jq 없으면 python3 fallback) -> ansible/inventory/<env>/hosts.json

set -euo pipefail

env="${1:-staging}"
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
TF_JSON="/tmp/tf-${env}.json"
OUT_JSON="$REPO_ROOT/ansible/inventory/${env}/hosts.json"

cd "$REPO_ROOT/terraform"
terraform output -json > "$TF_JSON"

if command -v jq >/dev/null 2>&1; then
  bash "$REPO_ROOT/scripts/tf-output-to-inventory.sh" "$TF_JSON" > "$OUT_JSON"
else
  python3 -c "
import json, sys
d = json.load(open('$TF_JSON'))
workers = d['agent_workers']['value']
out = {
    'all': {
        'children': {
            'agent_workers': {
                'hosts': {
                    name: {
                        'ansible_host': info['address'],
                        'agent_role': info['role'],
                    }
                    for name, info in workers.items()
                }
            }
        }
    }
}
print(json.dumps(out, indent=2))
" > "$OUT_JSON"
fi

echo "=== $OUT_JSON ==="
cat "$OUT_JSON"
