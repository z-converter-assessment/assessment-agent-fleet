# Agent Env Contract

agent 실행 시 필요한 환경 변수 명세. 값은 Ansible group_vars / host_vars / vault에서 주입.

## 키 (TBD — agent 사양에 따라 채움)

예시 구조

```
AGENT_ID
AGENT_LOG_LEVEL
AGENT_CONFIG_PATH
AGENT_INTERVAL_SEC
ENGINE_ENDPOINT
ENGINE_API_TOKEN
```

결정 필요
- 정확한 키 카탈로그
- 키 분류 (필수 / 선택 / secret)
- 외부 시스템 연결 키 (engine, broker, log forwarder 등)

## secret 처리
- 명명 컨벤션: `vault_<키>` 접두 (예: `vault_engine_api_token`)
- 저장 위치: `ansible/inventory/<env>/group_vars/vault.yml` (ansible-vault 로 암호화)
- 키 카탈로그: `ansible/inventory/<env>/group_vars/vault.yml.example` (평문 placeholder)
- template 참조: `assessment-agent.env.j2` 가 `{{ vault_xxx }}` 로 참조
- 평문 commit 금지. `vault.yml` 은 ansible-vault 로 암호화된 상태로만 commit

## 적용 위치
- 파일 경로: `/etc/assessment-agent.env`
- 권한: 0640, owner root, group `assessment-agent`
- systemd unit의 `EnvironmentFile=/etc/assessment-agent.env` 로 로드

## 의존
- ansible/roles/agent_env — 본 contract 구현 위치
- agent 바이너리의 env 사용 규약 (agent repo 문서)
