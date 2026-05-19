#!/bin/bash
# bootstrap.sh — iac VM (Debian/Ubuntu) 초기 toolchain 셋업.
#
# 사용:
#   bash scripts/bootstrap.sh
#
# 설치:
#   - apt 패키지 (openstack CLI, ansible-core, gh, docker.io, jq, unzip 등)
#   - terraform 1.10.0 binary -> /usr/local/bin/terraform
#   - docker MTU 1450 daemon.json (사설망 zconverter-private-net 환경 가정)
#   - docker 그룹 멤버십 (재로그인 또는 newgrp docker 필요)
#
# 미설치 (운영자 직접):
#   - clouds.yaml (~/.config/openstack/clouds.yaml) — application credential
#   - gh auth login
#   - git config --global user.{name,email}
#   - ssh keypair 등록 + cinder volume — terraform first-run 단계

set -euo pipefail

echo "=========================================="
echo " 1) apt 패키지"
echo "=========================================="
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confold" \
  ca-certificates curl wget gnupg lsb-release \
  git openssh-client jq unzip rsync \
  python3 python3-pip python3-venv pipx \
  python3-openstackclient \
  ansible-core \
  gh \
  docker.io

echo
echo "=========================================="
echo " 2) terraform binary (1.10.0)"
echo "=========================================="
if command -v terraform >/dev/null 2>&1; then
  echo "이미 설치됨: $(terraform version | head -1)"
else
  TF_VER=1.10.0
  wget -q -O /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip"
  sudo unzip -o /tmp/terraform.zip -d /usr/local/bin
  sudo chmod 0755 /usr/local/bin/terraform
  rm -f /tmp/terraform.zip /usr/local/bin/LICENSE.txt
  terraform version | head -1
fi

echo
echo "=========================================="
echo " 3) docker MTU 1450 (사설망 환경)"
echo "=========================================="
if [ -f /etc/docker/daemon.json ] && grep -q '"mtu"' /etc/docker/daemon.json; then
  echo "이미 설정됨: $(cat /etc/docker/daemon.json)"
else
  echo '{"mtu": 1450}' | sudo tee /etc/docker/daemon.json
  sudo systemctl restart docker
fi

echo
echo "=========================================="
echo " 4) docker 그룹 멤버십"
echo "=========================================="
if groups | grep -q docker; then
  echo "이미 docker 그룹 멤버"
else
  sudo usermod -aG docker "$USER"
  echo "docker 그룹 추가됨. 'newgrp docker' 또는 재로그인 필요"
fi

echo
echo "=========================================="
echo " verify"
echo "=========================================="
terraform version | head -1
ansible --version | head -1
openstack --version
gh --version | head -1
jq --version
docker --version
echo
echo "다음 단계:"
echo "  1. clouds.yaml 배치 (~/.config/openstack/clouds.yaml, 0600)"
echo "  2. gh auth login"
echo "  3. git config --global user.name / user.email"
echo "  4. README.md 의 '재현' 섹션 따라 진행"
