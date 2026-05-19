# Deploy

신규 환경 (staging / prod) 의 fleet 배포 절차. README 의 "빠른 시작" 을 절차 형태로 풀어쓴 것.

## 전제
- [docs/preflight.md](../preflight.md) 통과
- iac toolchain 셋업 완료 (`bash scripts/bootstrap.sh`)
- credential 활성화 (`~/.config/openstack/clouds.yaml` 0600, `openstack token issue` 정상)
- ssh keypair 등록 (`agent-fleet`) + cinder volume mount (`/var/lib/terraform-state`)
- ADR 0004 의 매트릭스 (또는 환경별 수정안) 합의됨

## 1) terraform.tfvars / backend.hcl

```bash
cp terraform/environments/<env>/terraform.tfvars.example terraform/environments/<env>/terraform.tfvars
cp terraform/environments/<env>/backend.hcl.example      terraform/environments/<env>/backend.hcl
# 필요 시 매트릭스 / VM 개수 편집 (특히 prod 환경)
```

## 2) terraform apply

```bash
cd terraform
terraform init -backend-config=environments/<env>/backend.hcl
terraform plan  -var-file=environments/<env>/terraform.tfvars
terraform apply -var-file=environments/<env>/terraform.tfvars
cd ..
```

## 3) ansible 셋업 (한 번만)

```bash
bash scripts/setup-ansible.sh
```

이 단계는 환경 무관 (한 iac VM 에 한 번). collection install + `.vault_pass.txt` 생성.

## 4) inventory 자동 생성

```bash
bash scripts/build-inventory.sh <env>
```

`terraform output -json` 을 `ansible/inventory/<env>/hosts.json` 으로 변환.

## 5) group_vars 채움

```bash
bash scripts/prepare-staging-vars.sh   # staging 한정 helper. prod 는 수동
```

이 helper 는:
- `all/vars.yml.example -> all/vars.yml` (이미 있으면 skip)
- agent dist `SHA256SUMS` 에서 sha256 자동 추출 + `all/vars.yml` 의 `agent_binary_local_sha256` 갱신
- `all/vault.yml` 을 dummy credentials 로 ansible-vault 암호화 생성 (PoC 가정)

prod 환경 또는 실제 credentials 사용 시:
```bash
cd ansible
cp inventory/prod/group_vars/all.yml.example inventory/prod/group_vars/all/vars.yml
# 편집

ansible-vault create inventory/prod/group_vars/all/vault.yml
# vault_rabbitmq_user, vault_rabbitmq_pass 채움
```

vault password 는 `ansible.cfg` 의 `vault_password_file = .vault_pass.txt` 가 자동 로드.

## 6) dry-run (선택)

```bash
cd ansible
ansible-playbook -i inventory/<env>/hosts.json playbooks/site.yml --check
```

## 7) apply

```bash
ansible-playbook -i inventory/<env>/hosts.json playbooks/site.yml
```

이 한 줄로 common -> agent_binary -> agent_env -> agent_service -> health-check 까지 실행.

## 8) 검증

```bash
ansible-playbook -i inventory/<env>/hosts.json playbooks/health-check.yml

# 또는 직접 한 호스트만
ssh -i ~/.ssh/agent-fleet debian@<ip> 'sudo systemctl status assessment-agent --no-pager | head -10'
ssh -i ~/.ssh/agent-fleet debian@<ip> 'sudo journalctl -u assessment-agent -n 30 --no-pager'
```

agent → broker 까지 검증하려면 [poc-temp-engine.md](poc-temp-engine.md) 참조 (engine 인프라 별도일 때).

## prod 환경

staging 검증 통과 후 동일 절차의 `<env>` 를 `prod` 로 치환. terraform / ansible 변경은 환경별로 같은 PR 안에서 일관 적용.

## 정리

작업 종료 시 [scripts/teardown.sh](../../scripts/teardown.sh):

```bash
bash scripts/teardown.sh
```

OpenStack 자원 (fleet VM, 임시 engine, sg-agent 변경분, cinder volume) + iac 산출물 일괄 제거.
