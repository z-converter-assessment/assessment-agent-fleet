# Bootstrap — 인프라 VM 초기 셋업

점프호스트 안 인프라 VM (Ubuntu 또는 Debian) 의 최초 toolchain 설치 절차.
`docs/preflight.md` 의 toolchain 항목을 실제 환경에 적용.

## 전제
- 점프호스트 (Windows Server 2022) RDP 접속 완료
- 인프라 VM ssh 접속 완료 (`docs/operations/infra-vm-create.md` 진행)
- sudo 권한 보유

## 패키지

```bash
sudo apt-get update
sudo apt-get install -y \
  ca-certificates curl gnupg lsb-release software-properties-common \
  git openssh-client jq \
  python3 python3-pip python3-venv
```

## python openstacksdk

```bash
python3 -m pip install --user openstacksdk
```

## gh CLI

```bash
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt-get update
sudo apt-get install -y gh
gh auth login
```

## terraform

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt-get update
sudo apt-get install -y terraform
```

## ansible-core + ansible-lint

```bash
python3 -m pip install --user ansible-core ansible-lint
```

`~/.local/bin` 이 PATH 에 포함되어야 한다 (`.bashrc` 또는 `.zshrc`).

## 검증

```bash
terraform version
ansible --version
ansible-lint --version
gh --version
jq --version
openstack --version
```

## 다음 단계
- `docs/preflight.md` 의 OpenStack credential, ssh key, repo 항목으로 이동
- 이후 `docs/operations/deploy.md` 절차 진행
