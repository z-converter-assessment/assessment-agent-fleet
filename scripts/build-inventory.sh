#!/bin/bash
# build-inventory.sh — terraform output 으로 ansible inventory 생성
#
# 사용:
#   bash scripts/build-inventory.sh <env>      # 예: staging, prod
#
# 절차:
#   1. cd terraform && terraform output -json > /tmp/tf-<env>.json
#   2. jq 변환 (또는 jq 없으면 python3 fallback) -> ansible/inventory/<env>/hosts.json
#
# inventory 구조:
#   - agent_workers      모든 fleet 멤버 (host_vars: ansible_host, ansible_user, agent_role, service_category, noise_profile)
#   - service_<category> service_category 별 추가 그룹 (none 카테고리는 추가 그룹 없음)
#   - noise_<profile>    noise_profile 별 추가 그룹 (idle 카테고리는 추가 그룹 없음)

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
  python3 - "$TF_JSON" > "$OUT_JSON" <<'PYEOF'
import json, sys
from collections import defaultdict
d = json.load(open(sys.argv[1]))
workers = d['agent_workers']['value']
hosts = {
    name: {
        'ansible_host': info['address'],
        'ansible_user': info.get('ssh_user') or 'debian',
        'agent_role': info['role'],
        'service_category': info.get('service_category') or 'none',
        'noise_profile': info.get('noise_profile') or 'idle',
    }
    for name, info in workers.items()
}
children = {'agent_workers': {'hosts': hosts}}
for key_attr, prefix, skip in (('service_category', 'service_', 'none'), ('noise_profile', 'noise_', 'idle')):
    by_val = defaultdict(dict)
    for name, info in hosts.items():
        v = info[key_attr]
        if v and v != skip:
            by_val[v][name] = {}
    for v, members in by_val.items():
        children[f'{prefix}{v}'] = {'hosts': members}
print(json.dumps({'all': {'children': children}}, indent=2))
PYEOF
fi

echo "=== $OUT_JSON (groups) ==="
if command -v jq >/dev/null 2>&1; then
  jq '.all.children | keys' "$OUT_JSON"
  echo "host count: $(jq '.all.children.agent_workers.hosts | length' "$OUT_JSON")"
else
  python3 -c "import json; d=json.load(open('$OUT_JSON')); print('groups:', list(d['all']['children'])); print('host count:', len(d['all']['children']['agent_workers']['hosts']))"
fi
