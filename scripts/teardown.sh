#!/bin/bash
# teardown.sh — 본 repo 가 만든 모든 OpenStack 자원 + iac 측 산출물 정리.
#
# 정리 대상:
#   1. terraform staging 인스턴스 (fleet VM 3대 + port 자원)
#   2. 임시 engine VM (assessment-engine-temp, 존재 시)
#   3. sg-agent 의 본 repo 변경분
#      - ssh 22 ingress from 10.0.10.0/26  (제거)
#      - tcp 5672 / 15672 ingress           (제거, 임시 engine 잔재)
#      - 원본 ssh 22 from 0.0.0.0/0 재생성 (sg-agent 의 처음 상태 복원)
#   4. cinder volume tfstate-agent-fleet (mount 해제 + detach + delete)
#   5. fstab line + /var/lib/terraform-state 디렉토리
#   6. terraform working tree (.terraform/, .terraform.lock.hcl)
#   7. ansible 측 작업 산출물
#      - inventory/staging/hosts.json
#      - inventory/staging/group_vars/all/{vars.yml, vault.yml}
#      - .vault_pass.txt
#      - 단, terraform.tfvars / backend.hcl 는 .example 보존 + 실값 파일 제거
#
# 유지:
#   - OpenStack keypair `agent-fleet` (다음 재실행 시 재사용)
#   - sg-agent 자체 (원래 자산)
#   - iac toolchain (terraform, ansible, docker, openstack CLI)
#   - clouds.yaml application credential
#   - repo commit 파일

set -uo pipefail
export OS_CLOUD=openstack
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)

echo "=========================================="
echo " 1) terraform destroy (staging)"
echo "=========================================="
cd "$REPO_ROOT/terraform"
if [ -d ".terraform" ]; then
  terraform destroy -var-file=environments/staging/terraform.tfvars -auto-approve 2>&1 | tail -20
else
  echo "(.terraform 없음, init 안 됨 — skip)"
fi

echo
echo "=========================================="
echo " 2) 임시 engine VM 삭제"
echo "=========================================="
if openstack server show assessment-engine-temp >/dev/null 2>&1; then
  openstack server delete --wait assessment-engine-temp
  echo "삭제됨: assessment-engine-temp"
else
  echo "(assessment-engine-temp 없음 — skip)"
fi

echo
echo "=========================================="
echo " 3) sg-agent 룰 원상복구"
echo "=========================================="
# 본 repo 가 추가/변경한 룰만 선별 제거 + 원본 ssh 0.0.0.0/0 재생성.
openstack security group rule list sg-agent --format json | python3 -c "
import json, subprocess, sys
rules = json.load(sys.stdin)
target_ports = {22, 5672, 15672}
restore_needed = False
for r in rules:
    direction = r.get('Direction')
    proto = r.get('IP Protocol')
    if direction != 'ingress' or proto != 'tcp':
        continue
    pr = r.get('Port Range', '')
    try:
        port = int(pr.split(':')[0]) if pr else None
    except (ValueError, AttributeError):
        port = None
    cidr = r.get('IP Range', '')
    if port == 22 and cidr == '10.0.10.0/26':
        print(f'remove ssh 22 from 10.0.10.0/26 (id={r[\"ID\"]})')
        subprocess.run(['openstack', 'security', 'group', 'rule', 'delete', r['ID']], check=False)
        restore_needed = True
    elif port in (5672, 15672):
        print(f'remove tcp {port} ingress (id={r[\"ID\"]})')
        subprocess.run(['openstack', 'security', 'group', 'rule', 'delete', r['ID']], check=False)
"
# 원본 ssh 22 from 0.0.0.0/0 룰 복원 (이미 있으면 중복 에러 무시).
openstack security group rule create --proto tcp --dst-port 22 --remote-ip 0.0.0.0/0 sg-agent 2>&1 | grep -E "id|already" | head -2

echo
echo "=========================================="
echo " 4) cinder volume mount 해제 + detach + delete"
echo "=========================================="
if mount | grep -q /var/lib/terraform-state; then
  sudo umount /var/lib/terraform-state && echo "umount OK" || echo "umount 실패"
fi
if grep -q "LABEL=tfstate" /etc/fstab 2>/dev/null; then
  sudo sed -i '/LABEL=tfstate/d' /etc/fstab && echo "fstab line 제거"
fi
if [ -d /var/lib/terraform-state ]; then
  sudo rmdir /var/lib/terraform-state 2>/dev/null && echo "/var/lib/terraform-state 디렉토리 제거" || echo "(/var/lib/terraform-state 비어있지 않음 — skip)"
fi
if openstack volume show tfstate-agent-fleet >/dev/null 2>&1; then
  openstack server remove volume IaC tfstate-agent-fleet 2>/dev/null && echo "detach OK"
  sleep 3
  openstack volume delete tfstate-agent-fleet && echo "volume 삭제 OK"
else
  echo "(volume tfstate-agent-fleet 없음 — skip)"
fi

echo
echo "=========================================="
echo " 5) 작업 산출물 정리"
echo "=========================================="
cd "$REPO_ROOT"
# terraform working tree
rm -rf terraform/.terraform terraform/.terraform.lock.hcl
echo "terraform/.terraform* 제거"
# environments tfvars/backend (실값)
rm -f terraform/environments/staging/terraform.tfvars terraform/environments/staging/backend.hcl
rm -f terraform/environments/prod/terraform.tfvars terraform/environments/prod/backend.hcl
echo "environments/*/terraform.tfvars + backend.hcl 제거"
# ansible inventory + vault — .example 은 보존, 실값 (.gitignore 차단) 만 제거
rm -f ansible/inventory/staging/hosts.json ansible/inventory/staging/hosts.yml
rm -f ansible/inventory/staging/group_vars/all/vars.yml
rm -f ansible/inventory/staging/group_vars/all/vault.yml
rm -f ansible/inventory/prod/hosts.json ansible/inventory/prod/hosts.yml
rm -f ansible/inventory/prod/group_vars/all/vars.yml
rm -f ansible/inventory/prod/group_vars/all/vault.yml
rm -f ansible/.vault_pass.txt
echo "ansible 실값 inventory + vault.yml + .vault_pass.txt 제거 (.example 보존)"
# ssh known_hosts 의 fleet 멤버 라인 (선택)
for ip in 10.0.10.13 10.0.10.8 10.0.10.56 10.0.10.117; do
  ssh-keygen -R "$ip" >/dev/null 2>&1 || true
done
echo "known_hosts fleet IP 제거"

echo
echo "=========================================="
echo " 정리 완료"
echo "=========================================="
echo "유지된 자산:"
echo "  - OpenStack keypair: agent-fleet"
echo "  - OpenStack sg     : sg-agent (원상복구 — ssh 22 from 0.0.0.0/0 + egress all)"
echo "  - clouds.yaml      : ~/.config/openstack/clouds.yaml"
echo "  - iac toolchain    : terraform, ansible, docker, openstack CLI, gh"
echo "  - 본 ssh 키        : ~/.ssh/agent-fleet (+ .pub)"
echo
echo "잔여 OpenStack 자원 확인:"
openstack server list -f value -c Name
echo
echo "재시작 시: README.md 의 '재현' 섹션 참조."
