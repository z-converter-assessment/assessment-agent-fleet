# Rotate — env / secret 회전

## env 키 추가 또는 변경

1. agent 사양 또는 외부 시스템 변경 시 `docs/architecture/env-contract.md` 갱신
2. `ansible/roles/agent_env/templates/assessment-agent.env.j2` 에 라인 추가
3. `ansible/inventory/<env>/group_vars/all.yml` 또는 host_vars 에 값 추가
4. 평문 secret 은 `ansible/inventory/<env>/group_vars/vault.yml` 에 ansible-vault 로 보관
5. deploy 재실행 (template 변경 시 systemd restart 자동 트리거)

## secret 회전

1. 새 secret 발급 (외부 시스템)
2. vault 갱신

```bash
ansible-vault edit ansible/inventory/<env>/group_vars/vault.yml
```

3. 영향 받는 host 한정 deploy

```bash
ansible-playbook -i inventory/<env>/hosts.yml \
  --ask-vault-pass \
  playbooks/deploy.yml \
  --limit <hosts> --diff
```

4. 외부 시스템에서 기존 secret 회수
5. health-check 로 정상 동작 확인

## Vault password 회전

```bash
ansible-vault rekey ansible/inventory/<env>/group_vars/vault.yml
```

새 password 배포 후 기존 password 폐기.
