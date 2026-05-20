# Upgrade — agent 버전 갱신

agent 새 release 가 출시되었을 때 fleet 멤버 VM 의 바이너리 교체.

## 절차

1. release tag 확인

```bash
gh release list --repo <owner>/assessment-agent
```

2. group_vars 갱신

```yaml
# ansible/inventory/<env>/group_vars/all.yml
agent_version: "v1.2.4"
```

3. PR 검토 후 머지

4. dry-run

```bash
cd ansible
ansible-playbook -i inventory/<env>/hosts.yml \
  --ask-vault-pass \
  playbooks/deploy.yml --check --diff
```

5. rollout

```bash
ansible-playbook -i inventory/<env>/hosts.yml \
  --ask-vault-pass \
  playbooks/deploy.yml --diff
```

bulk 적용이 부담스러우면 `--limit <host>` 로 batch 분리.

6. 검증

```bash
ansible-playbook -i inventory/<env>/hosts.yml \
  playbooks/health-check.yml
```

## 롤백
`group_vars/all.yml` 의 `agent_version` 을 이전 값으로 되돌리고 같은 절차 반복.
