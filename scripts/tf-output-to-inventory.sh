#!/usr/bin/env bash
#
# scripts/tf-output-to-inventory.sh
#
# terraform output -json 결과의 agent_workers 정보를 Ansible inventory (JSON) 로 변환.
# Ansible 은 JSON 형식 inventory 도 정상 수용.
#
# Usage:
#   cd terraform
#   terraform output -json > /tmp/tf-output.json
#   ../scripts/tf-output-to-inventory.sh /tmp/tf-output.json \
#     > ../ansible/inventory/staging/hosts.json
#
# Requires: jq

set -euo pipefail

input="${1:-/dev/stdin}"

if ! jq -e '.agent_workers.value' "$input" >/dev/null 2>&1; then
  echo "expected '.agent_workers.value' in terraform output" >&2
  exit 1
fi

jq '
{
  all: {
    children: {
      agent_workers: {
        hosts: (
          .agent_workers.value
          | to_entries
          | map({
              key,
              value: {
                ansible_host: .value.address,
                agent_role: .value.role
              }
            })
          | from_entries
        )
      }
    }
  }
}
' "$input"
