# Runbook — 인시던트 대응

## agent 가 active 가 아님

1. 대상 호스트 상태 식별

```bash
ansible -i inventory/<env>/hosts.yml agent_workers \
  -m systemd_service -a "name=assessment-agent"
```

2. 로그 확인

```bash
ansible -i inventory/<env>/hosts.yml <host> \
  -m shell -a "journalctl -u assessment-agent -n 200 --no-pager"
```

3. 원인 분류
   - env 누락 또는 값 오류 -> rotate.md 절차로 env 갱신
   - 바이너리 실행 실패 -> upgrade.md 절차로 재배포
   - 외부 시스템 연결 실패 -> network, security group, credential 점검

4. 재시작

```bash
ansible -i inventory/<env>/hosts.yml <host> \
  -m systemd_service -a "name=assessment-agent state=restarted"
```

5. 해소 안 되면 host 격리 후 재 provisioning 검토

## OpenStack API 도달 실패

```bash
openstack token issue
openstack server list
```

- credential 만료 -> Horizon 에서 application credential 재발급
- network 경로 -> 인프라 VM 의 OpenStack endpoint 도달성 확인

## Terraform state drift

```bash
terraform plan -var-file=environments/<env>/terraform.tfvars
```

- 의도된 drift -> `terraform apply` 로 동기화
- 의도 외 drift -> state 와 실제 자원 모두 점검 후 결정

## 워커 VM 강제 종료

```bash
terraform destroy \
  -target='module.vm["<name>"]' \
  -var-file=environments/<env>/terraform.tfvars
```

prod 에서는 즉시 실행 금지. PR + 두 명 합의 후 진행.
