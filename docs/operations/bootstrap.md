# Bootstrap — 인프라 VM 초기 셋업

점프호스트 안 인프라 VM (Ubuntu 또는 Debian 안정 버전) 의 최초 toolchain 설치 절차.
`docs/preflight.md` 의 toolchain 항목을 실제 환경에 적용.

## 전제
- 점프호스트 (Windows Server 2022) RDP 접속 완료
- 인프라 VM ssh 접속 완료 (`docs/operations/infra-vm-create.md` 진행)
- sudo 권한 보유

## Debian 13 (trixie) 주의
Debian 13 이상은 PEP 668 (externally-managed-environment) 로 시스템 python 의 `pip install --user` 가 막힘.
본 문서는 apt 우선. pip 가 꼭 필요한 경우 pipx 또는 venv.

## 1) apt 패키지 (한 줄)

```bash
sudo apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl wget gnupg lsb-release \
  git openssh-client jq unzip \
  python3 python3-pip python3-venv pipx \
  python3-openstackclient \
  ansible-core \
  gh \
  docker.io
```

설치되는 도구:
- openstack CLI (+ openstacksdk, keystoneauth1 동반)
- ansible-core (2.19+)
- gh CLI
- docker.io
- jq, unzip 등 보조

## 2) terraform (binary install)

trixie apt 에 terraform 미가용. HashiCorp 공식 apt 리포지토리도 trixie codename 미지원 가능성. binary 가 가장 안전.

```bash
TF_VER=1.10.0
wget -q -O /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip"
sudo unzip -o /tmp/terraform.zip -d /usr/local/bin
sudo chmod 0755 /usr/local/bin/terraform
rm /tmp/terraform.zip
```

검증: `terraform version`.

## 3) docker 그룹

```bash
sudo usermod -aG docker $USER
newgrp docker   # 또는 재로그인
```

### docker MTU (사설망 환경)

OpenStack 사설망의 MTU 가 표준 1500 이 아닌 경우 (예: zconverter-private-net MTU 1450), docker bridge 기본 MTU 1500 과 미스매치 → 컨테이너에서 외부 도달 시 패킷 잘림 → connection reset.

대응:

```bash
echo '{"mtu": 1450}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
ip link show docker0 | grep mtu       # mtu 1450 확인
```

또는 영구 daemon.json 변경 대신 컨테이너 마다 `--network host` 사용 (호스트 NIC 직접).

## 4) gh 인증

```bash
gh auth login
```

- GitHub.com / HTTPS / Authenticate Git = Yes / Login with web browser
- device flow code 가 보이면 점프호스트 또는 맥 브라우저에서 `https://github.com/login/device` 로 입력

검증: `gh auth status`.

## 5) git identity

```bash
git config --global user.name  "<GitHub username>"
git config --global user.email "<commit 노출 이메일>"
```

## 6) Ansible collection + vault password

repo clone 후:

```bash
bash ~/assessment-agent-fleet/scripts/setup-ansible.sh
```

이 한 줄이:
- `ansible-galaxy collection install -r requirements.yml` (openstack.cloud / community.general / ansible.posix)
- `openssl rand -base64 32 > ansible/.vault_pass.txt` (0600)

## 7) Terraform state cinder volume (한 번만)

ADR 0005: terraform state 는 iac 에 attach 한 cinder volume mount 경로에 저장.

```bash
# OpenStack 측 volume 생성 + attach
openstack volume create --size 1 --description "terraform state for assessment-agent-fleet" tfstate-agent-fleet
openstack server add volume IaC tfstate-agent-fleet
lsblk    # /dev/vdb 1G 인식 확인

# iac 안에서 포맷 + mount + fstab
sudo mkfs.ext4 -L tfstate /dev/vdb
sudo mkdir -p /var/lib/terraform-state
sudo mount /dev/vdb /var/lib/terraform-state
echo "LABEL=tfstate /var/lib/terraform-state ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo chown $USER:$USER /var/lib/terraform-state
mkdir -p /var/lib/terraform-state/staging /var/lib/terraform-state/prod
```

## 8) 검증

```bash
terraform version
ansible --version
ansible-galaxy collection list | head -10
gh --version
jq --version
openstack --version
docker --version
ip link show docker0 | grep mtu
ls -la /var/lib/terraform-state/
```

## 다음 단계
- `docs/preflight.md` 의 OpenStack credential, ssh key 항목
- 이후 `docs/operations/deploy.md` 절차 진행
