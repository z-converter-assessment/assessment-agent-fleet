# Deploy

신규 환경 배포 절차. staging 환경 PoC 기준.

## 전제
- docs/preflight.md 통과
- docs/architecture/topology.md 의 VM 매트릭스 결정
- docs/architecture/agent-release.md 의 release 좌표 결정
- docs/architecture/env-contract.md 의 키 카탈로그 결정

## 절차

1. credential 활성화

```bash
export OS_CLIENT_CONFIG_FILE=$HOME/clouds.yaml
openstack token issue
```

2. terraform.tfvars 작성

```bash
cd terraform/environments/staging
cp terraform.tfvars.example terraform.tfvars
# 편집
```

3. backend 설정 (선택)

```bash
cp backend.hcl.example backend.hcl
# 편집
```

4. terraform apply

```bash
cd ../..
terraform init -backend-config=environments/staging/backend.hcl
terraform plan  -var-file=environments/staging/terraform.tfvars
terraform apply -var-file=environments/staging/terraform.tfvars
```

5. ansible inventory 자동 생성

```bash
terraform output -json > /tmp/tf-output.json
../../scripts/tf-output-to-inventory.sh /tmp/tf-output.json \
  > ../../ansible/inventory/staging/hosts.json
```

스크립트 출력은 JSON 형식. Ansible 은 JSON inventory 도 정상 수용.
공통 변수 (ansible_user 등) 는 `inventory/staging/group_vars/all.yml` 에서 정의.

6. ansible group_vars / vault 작성

```bash
cd ../../ansible/inventory/staging/group_vars
cp all.yml.example all.yml
# 편집

# vault.yml.example 을 암호화하여 vault.yml 생성
ansible-vault encrypt --output vault.yml vault.yml.example
# 또는 처음부터 암호화 생성
#   ansible-vault create vault.yml
# 이후 편집은
#   ansible-vault edit vault.yml
```

7. ansible collections 설치

```bash
cd ../../..
ansible-galaxy collection install -r requirements.yml
```

8. dry-run

```bash
ansible-playbook -i inventory/staging/hosts.yml \
  --ask-vault-pass \
  playbooks/site.yml --check --diff
```

9. apply

```bash
ansible-playbook -i inventory/staging/hosts.yml \
  --ask-vault-pass \
  playbooks/site.yml
```

10. 검증

```bash
ansible-playbook -i inventory/staging/hosts.yml \
  playbooks/health-check.yml
```

## prod 환경
staging 검증 통과 후 동일 절차를 `environments/prod` 와 `inventory/prod` 에 반복. 변경은 환경별로 같은 PR 안에서 일관 적용.
