# PoC — 임시 engine 으로 fleet end-to-end 검증

agent fleet 의 staging 적용이 완료된 상태에서, 별도 engine 인프라가 없는 환경에서 1-VM docker compose engine 을 임시로 띄워 agent → broker 발행까지 end-to-end 검증.

본 절차는 일회성 PoC. 운영용 engine 인프라는 별개 트랙.

## 전제
- 본 repo 의 [README](../../README.md) "빠른 시작" 의 1~6 단계 완료 (fleet VM 3대 ACTIVE, agent systemd active)
- agent repo (`/home/whdcks/assessment-agent`) clone 완료
- engine repo (`/home/whdcks/assessment-engine`) clone 완료
- agent 바이너리 빌드 완료 (`/home/whdcks/assessment-agent/dist/assessment-agent-linux-x86_64`)

## 1) sg-agent 에 broker 포트 ingress 추가

임시 engine 도 같은 `sg-agent` 부착해서 통신 단순화 (fleet ↔ engine 모두 동일 SG). fleet → engine 의 AMQP 5672 + 관리 콘솔 15672 ingress 룰 추가.

```bash
openstack security group rule create --proto tcp --dst-port 5672  --remote-ip 10.0.10.0/26 --description "AMQP from target-vms (temp engine PoC)" sg-agent
openstack security group rule create --proto tcp --dst-port 15672 --remote-ip 10.0.10.0/26 --description "rabbitmq mgmt (temp engine PoC)" sg-agent
```

## 2) 임시 engine VM 생성

```bash
openstack server create \
  --image debian12_x64_uefi_3G \
  --flavor zdm \
  --key-name agent-fleet \
  --security-group sg-agent \
  --network zconverter-private-net \
  --wait \
  assessment-engine-temp

openstack server show assessment-engine-temp -f value -c addresses
# zconverter-private-net=10.0.10.x
```

`--network` 만 지정하면 OpenStack 이 network 안 첫 subnet 자동 선택 (보통 assessment-engine 서브넷 10.0.10.64/26). fleet 과 다른 subnet 이지만 같은 network 라 통신 가능.

특정 subnet 강제 시: `--nic net-id=<network-uuid>,v4-fixed-ip=<ip>`.

## 3) engine VM 측 셋업

cloud-init 부팅 대기 (~60s) 후 ssh:

```bash
EIP=<engine-vm-ip>
sleep 60
ssh -i ~/.ssh/agent-fleet -o StrictHostKeyChecking=accept-new debian@$EIP 'echo hostname=$(hostname)'

# docker + git + rsync 설치
ssh -i ~/.ssh/agent-fleet debian@$EIP \
  'sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq && \
   sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker.io git rsync curl'

# docker compose v2 plugin (apt 미가용 -> binary)
ssh -i ~/.ssh/agent-fleet debian@$EIP \
  'sudo mkdir -p /usr/local/lib/docker/cli-plugins && \
   sudo curl -fsSL -o /usr/local/lib/docker/cli-plugins/docker-compose \
     https://github.com/docker/compose/releases/download/v2.29.0/docker-compose-linux-x86_64 && \
   sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose && \
   docker compose version'

# docker MTU 1450 (사설망 정합)
ssh -i ~/.ssh/agent-fleet debian@$EIP \
  "echo '{\"mtu\": 1450}' | sudo tee /etc/docker/daemon.json && sudo systemctl restart docker"
```

## 4) engine repo 전송 + install.sh

iac 측에서 tar pipe (rsync 미설치 시 호환):

```bash
tar czf - -C /home/whdcks/assessment-engine \
  --exclude='.git' --exclude='__pycache__' --exclude='.venv' . | \
  ssh -i ~/.ssh/agent-fleet debian@$EIP 'mkdir -p ~/assessment-engine && tar xzf - -C ~/assessment-engine'

# engine VM 안에서 install
ssh -i ~/.ssh/agent-fleet debian@$EIP "cd ~/assessment-engine && sudo bash scripts/install.sh $EIP"
```

`install.sh` 가:
- `.env` 생성 (`.env.example` + `INSTALL_BUNDLE_URL` 주입)
- `docker compose up --build -d` (postgres / redis / rabbitmq / web / consumer / diagnostic-{scheduler,worker})
- web healthcheck (`http://$EIP:8000/health`)

기동 완료 후:
- Web UI: `http://<engine-ip>:8000/servers/`
- RabbitMQ 콘솔: `http://<engine-ip>:15672` (`assessment` / `assessment`)

## 5) fleet 측 연동

`ansible/inventory/staging/group_vars/all/` 의 변수 갱신:

```bash
cd ~/assessment-agent-fleet/ansible
# all.yml 의 broker 키
sed -i "s|^rabbitmq_host:.*|rabbitmq_host: \"$EIP\"|" inventory/staging/group_vars/all/vars.yml
sed -i 's|^rabbitmq_vhost:.*|rabbitmq_vhost: "/assessment"|' inventory/staging/group_vars/all/vars.yml

# vault.yml: assessment/assessment 로 교체
cat > /tmp/vault.plain.yml <<'EOF'
vault_rabbitmq_user: "assessment"
vault_rabbitmq_pass: "assessment"
EOF
ansible-vault encrypt --output inventory/staging/group_vars/all/vault.yml /tmp/vault.plain.yml
rm -f /tmp/vault.plain.yml

# fleet 재배포 (env 변경 -> systemd 재시작)
ansible-playbook -i inventory/staging/hosts.json playbooks/site.yml
```

## 6) 검증

```bash
# agent journal 에서 broker 발행 성공 확인
ssh -i ~/.ssh/agent-fleet debian@<fleet-ip> 'sudo journalctl -u assessment-agent -n 30 --no-pager'
# "[agent] published inventory" 메시지 보이면 OK

# engine 측 RabbitMQ 컨테이너 연결 확인
ssh -i ~/.ssh/agent-fleet debian@$EIP 'sudo docker exec assessment-engine-rabbitmq-1 rabbitmqctl list_connections name peer_host user state'

# engine 측 server 목록 (consumer 가 inventory 메시지를 DB 에 저장)
curl -fsSL http://$EIP:8000/api/servers/ | python3 -m json.tool | head -20
```

## 7) teardown

`scripts/teardown.sh` 가 임시 engine + sg-agent 변경분도 함께 정리. 별도 단계 불필요.

수동 정리 시:

```bash
openstack server delete assessment-engine-temp
openstack security group rule list sg-agent | grep -E "5672|15672"
openstack security group rule delete <rule-id-5672> <rule-id-15672>
```

## 한계
- dev 가정 docker compose. credentials 평문, TLS 미적용, ports 외부 노출 (사설망 내부 한정)
- engine repo 측 docker-compose.yml 변경 시 본 PoC 도 영향
- fleet 멤버 와 engine 이 같은 sg-agent 부착 — 운영 환경에선 분리 권장

정식 engine 인프라는 본 repo 범위 밖.

## 관련 문서
- 본 repo: `docs/architecture/agent-release.md`, `docs/architecture/env-contract.md`
- engine repo: `docs/ref/temp-engine-on-openstack.md` (동일 절차의 engine 측 시점 기록)
