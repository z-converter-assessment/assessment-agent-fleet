# Agent Env Contract

agent 실행 시 필요한 환경 변수 명세. 값은 Ansible group_vars / host_vars / vault 에서 주입.
단일 진실: agent repo (`z-converter-assessment/assessment-agent`) 의 `.env.example`. 본 문서는 그 사본.

## 적용 위치
- 공통 (non-secret): `/etc/assessment-agent/agent.env`, 0640, owner root, group `assessment-agent`
- secret 분리: `/etc/assessment-agent/agent.env.local`, 0640, owner root, group `assessment-agent`
- systemd unit 의 `EnvironmentFile=` 가 두 파일을 순차 로드 (local 이 공통을 덮어씀)

## 키 카탈로그

### Broker connection (필수)
- `RABBITMQ_HOST` — RabbitMQ 호스트. dev `localhost`, prod 별도 브로커 호스트
- `RABBITMQ_PORT` — `5672` (plain) 또는 `5671` (AMQPS)
- `RABBITMQ_VHOST` — dev `/`, prod `/assessment`

### Credentials (필수 / secret)
- `RABBITMQ_USER` — agent-publisher role 사용자명
- `RABBITMQ_PASS` — 비밀번호 (vault, secret 분리 파일)

### Broker tuning (선택)
- `RABBITMQ_HEARTBEAT_SEC` — 기본 60 (RabbitMQ 권장)
- `RABBITMQ_CONFIRM_TIMEOUT_SEC` — publisher-confirm ACK 대기. 기본 5

### TLS (prod 필수)
- `RABBITMQ_TLS_ENABLED` — `1` 시 AMQPS. `RABBITMQ_PORT=5671` 동반 설정 필요
- `RABBITMQ_TLS_CA_PATH` — CA cert 경로 (`/etc/assessment-agent/ca.pem`)
- `RABBITMQ_TLS_VERIFY_PEER` — `1`
- `RABBITMQ_TLS_VERIFY_HOSTNAME` — `1`
- `RABBITMQ_TLS_CERT_PATH` — mTLS client cert (선택)
- `RABBITMQ_TLS_KEY_PATH` — mTLS client key (선택, secret)

### Routing contract (필수, consumer 와 일치)
- `RABBITMQ_EXCHANGE` — 기본 `assessment`
- `RABBITMQ_ROUTING_KEY_INVENTORY` — 기본 `server.inventory`
- `RABBITMQ_ROUTING_KEY_METRICS` — 기본 `server.metrics`
- `RABBITMQ_ROUTING_KEY_ERROR` — 기본 `server.error`

### Agent runtime (선택)
- `AGENT_INTERVAL_SEC` — 수집/전송 루프 주기 초. 기본 60. `0` 이면 one-shot (cron/systemd timer)
- `AGENT_EXTERNAL_IP` — 콤마 분리 외부 IP 목록. 미설정 시 cloud metadata (AWS IMDSv2/Azure/GCP) 1s timeout 으로 조회. 실패 시 `ip_external=null`

## 분류 요약

| 키 | 필수/선택 | secret | 비고 |
|----|-----------|--------|------|
| RABBITMQ_HOST | 필수 | no | |
| RABBITMQ_PORT | 필수 | no | |
| RABBITMQ_VHOST | 필수 | no | |
| RABBITMQ_USER | 필수 | yes | vault |
| RABBITMQ_PASS | 필수 | yes | vault |
| RABBITMQ_HEARTBEAT_SEC | 선택 | no | |
| RABBITMQ_CONFIRM_TIMEOUT_SEC | 선택 | no | |
| RABBITMQ_TLS_ENABLED | prod 필수 | no | |
| RABBITMQ_TLS_CA_PATH | prod 필수 | no | |
| RABBITMQ_TLS_VERIFY_PEER | prod 필수 | no | |
| RABBITMQ_TLS_VERIFY_HOSTNAME | prod 필수 | no | |
| RABBITMQ_TLS_CERT_PATH | 선택 | no | mTLS |
| RABBITMQ_TLS_KEY_PATH | 선택 | yes | mTLS, vault |
| RABBITMQ_EXCHANGE | 필수 | no | |
| RABBITMQ_ROUTING_KEY_* | 필수 | no | 4종 |
| AGENT_INTERVAL_SEC | 선택 | no | |
| AGENT_EXTERNAL_IP | 선택 | no | |

## secret 처리
- 명명 컨벤션: `vault_<키소문자>` 접두 (예: `vault_rabbitmq_pass`)
- 저장 위치: `ansible/inventory/<env>/group_vars/vault.yml` (ansible-vault 로 암호화)
- 키 카탈로그: `ansible/inventory/<env>/group_vars/vault.yml.example` (평문 placeholder)
- template 참조: `assessment-agent.env.local.j2` 가 `{{ vault_xxx }}` 로 참조
- 평문 commit 금지. `vault.yml` 은 ansible-vault 로 암호화된 상태로만 commit

## 의존
- ansible/roles/agent_env — 본 contract 구현 위치
- agent repo 의 `.env.example` — 본 문서의 단일 진실
- agent repo 의 `src/util.c` 의 env 로더 — 키 파싱 규약
