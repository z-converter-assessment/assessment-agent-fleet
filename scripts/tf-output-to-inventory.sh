#!/usr/bin/env bash
#
# scripts/tf-output-to-inventory.sh
#
# terraform output -json 결과의 agent_workers 정보를 Ansible inventory (JSON) 로 변환.
# - 모든 host 는 `agent_workers` 그룹 멤버
# - service_category 별로 `service_<category>` 추가 그룹 (web / db / cache / mq / container / monitor / app)
#   * "none" 카테고리는 추가 그룹 생성 안 함 (agent 만 install)
# - noise_profile 별로 `noise_<profile>` 추가 그룹 (cpu_light / cpu_heavy / mem_heavy / io_heavy / mixed / agent_restart_demo / offline_once)
#   * "idle" 카테고리는 추가 그룹 생성 안 함 (부하 없음)
# - host_vars: ansible_host, ansible_user, agent_role, service_category, noise_profile
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
  .agent_workers.value as $workers
  | {
      all: {
        children: (
          {
            agent_workers: {
              hosts: (
                $workers
                | to_entries
                | map({
                    key,
                    value: {
                      ansible_host: .value.address,
                      ansible_user: .value.ssh_user,
                      agent_role: .value.role,
                      service_category: .value.service_category,
                      noise_profile: (.value.noise_profile // "idle")
                    }
                  })
                | from_entries
              )
            }
          }
          + (
              $workers
              | to_entries
              | map(select(.value.service_category != "none" and .value.service_category != null))
              | group_by(.value.service_category)
              | map({
                  key: ("service_" + .[0].value.service_category),
                  value: {
                    hosts: (map({ key, value: {} }) | from_entries)
                  }
                })
              | from_entries
            )
          + (
              $workers
              | to_entries
              | map(select((.value.noise_profile // "idle") != "idle"))
              | group_by(.value.noise_profile)
              | map({
                  key: ("noise_" + .[0].value.noise_profile),
                  value: {
                    hosts: (map({ key, value: {} }) | from_entries)
                  }
                })
              | from_entries
            )
        )
      }
    }
' "$input"
