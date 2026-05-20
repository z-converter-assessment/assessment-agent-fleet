# Staging multi-OS / multi-service / noise 시연 환경 재현

본 fleet 의 시연 환경을 zero 부터 8대 agent fleet + 서비스 + 노이즈 + agent worker 활성까지 재현하는 절차. 결정 history: [ADR 0008](../adr/0008-multi-os-demo.md).

## 0. 전제

iac VM (Debian 13 trixie) 에 본 repo clone 완료, [README](../../README.md) "빠른 시작" 1-2 단계 완료:
- `bash scripts/bootstrap.sh` (apt + terraform + docker)
- `~/.config/openstack/clouds.yaml` 배치 + `openstack token issue` 통과
- `gh auth login`, `git config --global user.{name,email}`

또 본 fleet 외부 의존:
- engine repo (`z-converter-assessment/assessment-engine`) clone 권장 — debugging 시 참조용. fleet 동작에 필수는 아님
- agent repo (`z-converter-assessment/assessment-agent`) clone — 빌드 산출물 archive 용 (`~/agent-binaries/latest/`)

## 1. OpenStack 자산 (한 번만)

```bash
# ssh keypair
ssh-keygen -t ed25519 -f ~/.ssh/agent-fleet -N "" -C "agent-fleet"
openstack keypair create --public-key ~/.ssh/agent-fleet.pub agent-fleet

# sg-agent (또는 agent-sg) 현재 룰 확인 — 사이트 운영자 정비 후 ssh 22 가 0.0.0.0/0 인지 좁혀진 상태인지
openstack security group rule list agent-sg

# cinder volume (terraform state 보관)
openstack volume create --size 1 --description "terraform state for assessment-agent-fleet" tfstate-agent-fleet
openstack server add volume IaC tfstate-agent-fleet
# iac VM 안에서
sudo mkfs.ext4 -L tfstate /dev/vdb
sudo mkdir -p /var/lib/terraform-state
sudo mount /dev/vdb /var/lib/terraform-state
echo "LABEL=tfstate /var/lib/terraform-state ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab
sudo chown $USER:$USER /var/lib/terraform-state
mkdir -p /var/lib/terraform-state/staging
```

자세히: [README](../../README.md) "빠른 시작" 3) OpenStack 자산.

## 2. agent 바이너리 빌드 + archive (사전)

```bash
cd ~/assessment-agent
bash scripts/build-linux.sh             # manylinux2014 컨테이너, 20-30분
cd ~/assessment-agent-fleet
bash scripts/archive-agent-build.sh     # dist/* -> ~/agent-binaries/dev-<sha8>/ + latest symlink
```

본 사이트 docker MTU 가 1450 인 경우 컨테이너 NAT 깨짐 — `scripts/build-linux.sh` 의 `docker run` 에 `--network host` 추가 (별도 트랙: agent repo PR).

자세히: [docs/operations/agent-binary-archive.md](agent-binary-archive.md).

## 3. broker 측 정보 확보

사이트 운영자 측에서 다음 정보 필요:

| 항목 | 값 (시연 환경 기준) |
|------|---------------------|
| broker host | `10.0.10.73` (mq-vm — 운영자 측에서 IP 변경 가능) |
| broker port | `5672` (plain AMQP) |
| vhost | `assessment` (leading slash 없음) |
| collector user | `assessment` |
| collector pass | `1234` |
| worker user | `assessment-worker` (broker 측 발급 필요) |
| worker pass | `1234` |
| allowed download hosts | `10.0.10.78,192.168.3.94` (engine bundle endpoint + ZDM) |

agent-sg 의 SG 룰:
- mq-sg ingress 5672 from agent-sg (broker 측 이미 등록)

worker user 발급은 운영자 측 RabbitMQ admin 작업. agent collector 만 활성하려면 worker credentials 비워두면 됨 (`vault_rabbitmq_worker_user: ""` -> agent 측 `worker disabled` 메시지).

## 4. terraform staging — 8 VM provisioning

```bash
cd ~/assessment-agent-fleet/terraform

# tfvars / backend.hcl (이미 있으면 skip)
cp environments/staging/terraform.tfvars.example environments/staging/terraform.tfvars
cp environments/staging/backend.hcl.example      environments/staging/backend.hcl

# init / plan / apply
terraform init -backend-config=environments/staging/backend.hcl
terraform plan  -var-file=environments/staging/terraform.tfvars
terraform apply -var-file=environments/staging/terraform.tfvars -auto-approve -parallelism=5
```

`parallelism=5` 는 compute scheduler 부담 완화 (이전에 30대 동시 apply 시 ERROR 19대 경험).

## 5. ansible 측 준비 (한 번만)

```bash
cd ~/assessment-agent-fleet
bash scripts/setup-ansible.sh      # apt ansible-core + jq, galaxy collection, .vault_pass.txt
```

자세히: [ansible/README.md](../../ansible/README.md).

## 6. group_vars 실값 + inventory

```bash
cd ~/assessment-agent-fleet
bash scripts/prepare-staging-vars.sh   # vars.yml + vault.yml (dummy credentials)
```

생성된 `ansible/inventory/staging/group_vars/all/vars.yml` 에서 다음 필드 운영 환경에 맞게 갱신:
- `rabbitmq_host`: 운영자가 알려준 broker IP
- `rabbitmq_vhost`: `assessment`
- `agent_worker_allowed_hosts`: 운영자 정책 — 예 `"10.0.10.78,192.168.3.94"`

`vault.yml` 갱신 (ansible-vault):
```bash
cd ansible
ansible-vault edit inventory/staging/group_vars/all/vault.yml
```
다음 4개 키 채움:
```yaml
vault_rabbitmq_user: "assessment"
vault_rabbitmq_pass: "1234"
vault_rabbitmq_worker_user: "assessment-worker"
vault_rabbitmq_worker_pass: "1234"
```

inventory 자동 생성:
```bash
cd ~/assessment-agent-fleet
bash scripts/build-inventory.sh staging
```

## 7. ansible-playbook site.yml — 8대 일괄 배포

```bash
cd ~/assessment-agent-fleet/ansible
sleep 60                            # cloud-init 부팅 여유 (terraform apply 직후)
ansible-playbook -i inventory/staging/hosts.json playbooks/site.yml
```

site.yml = deploy.yml + services.yml + noise.yml + health-check.yml. 8대 모두 동시 진행 (forks=10).

수행되는 단계:
- common: persistent journal (`/var/log/journal/<machine-id>` 자동 생성), machine-id reset (image clone 보정), swap (1GB host 만), apt update, user/group
- agent_binary: `~/agent-binaries/latest/assessment-agent-linux-x86_64` 를 host 로 copy + sha256 검증 + promote
- agent_env: `/etc/assessment-agent/{agent.env, agent.env.local}` render (worker credentials 포함)
- agent_service: systemd unit + start (`[worker] initialized` 출력 → agent worker 활성)
- service_*: host_vars 의 service_category 별로 nginx / postgresql / memcached / mosquitto / docker / podman / prometheus-node-exporter / apache2 install + start
- noise: host_vars 의 noise_profile 별로 stress-ng / restart timer / offline_once

## 8. 검증

### 8a. agent active + publish

```bash
cd ~/assessment-agent-fleet/ansible
ansible -i inventory/staging/hosts.json agent_workers -m shell --become -a '
  echo "agent=$(systemctl is-active assessment-agent) published=$(journalctl -u assessment-agent --no-pager | grep -c published) worker_init=$(journalctl -u assessment-agent --no-pager | grep -c "worker.*initialized")"
'
```

기대: 모든 host `agent=active`, `published >= 1`, `worker_init=1`.

### 8b. broker 측 queue 정합 (한 host 에서 pika 로)

```bash
ansible -i inventory/staging/hosts.json agent-debian12-web-01 -m apt -a "name=python3-pika state=present update_cache=yes" --become
ansible -i inventory/staging/hosts.json agent-debian12-web-01 -m shell --become -a '
python3 <<EOF
import pika
c = pika.BlockingConnection(pika.ConnectionParameters(
  host="10.0.10.73", port=5672, virtual_host="assessment",
  credentials=pika.PlainCredentials("assessment","1234"),
  socket_timeout=5))
ch = c.channel()
for q in ["server.inventory","server.metrics","server.error","worker.result"]:
    try:
        r = ch.queue_declare(queue=q, passive=True)
        print(f"{q:25s} OK  msg={r.method.message_count} consumers={r.method.consumer_count}")
    except Exception as e:
        print(f"{q:25s} FAIL: {str(e)[:60]}")
        c = pika.BlockingConnection(pika.ConnectionParameters(host="10.0.10.73", port=5672, virtual_host="assessment", credentials=pika.PlainCredentials("assessment","1234"))); ch = c.channel()
EOF
'
```

기대:
- `server.{inventory,metrics,error}` 각 consumers=1 (engine consumer)
- `worker.result` consumers=1 — engine 측 worker.result handler 활성 신호

### 8c. engine dashboard

운영자 측 engine web UI (또는 API) 에서 8대 서버 보임 + 서비스 카테고리 뱃지 + 자원 사용량 매트릭스 확인. 옛 instance row 가 보이면 운영자에게 옛 machine-id row 정리 요청:

```sql
TRUNCATE TABLE server_inventory RESTART IDENTITY CASCADE;
```

### 8d. task.install 발행 검증

운영자 측 engine web UI 에서 한 host (예: agent-debian12-web-01) 에 task.install 발행. agent worker 의 journal 에서 consume + extract + exec + task.result publish 확인:

```bash
ansible -i inventory/staging/hosts.json agent-debian12-web-01 -m shell --become -a 'journalctl -u assessment-agent -n 30 --no-pager | grep -E "(worker|task)"'
```

## 9. 매트릭스 (8대)

| host | OS | flavor | service | noise profile | 동작 |
|------|----|--------|---------|----|------|
| agent-alma9-db-01 | alma9 | c2_m4_r30 | postgresql | io_heavy | disk R/W 지속 |
| agent-debian12-container-01 | debian12 | c2_m2_r40 | docker | cpu_heavy | CPU 40% × 2 (안정 운영을 위해 80→40 완화) |
| agent-debian12-web-01 | debian12 | c1_m1_r30 | nginx | cpu_light | CPU 30% × 1 |
| agent-debian13-mq-01 | debian13 | c2_m2_r40 | mosquitto | mixed | CPU + 메모리 + IO 복합 (50MB로 완화) |
| agent-rocky9-cache-01 | rocky9 | c1_m1_r30 | memcached | mem_heavy | 메모리 40% + swap 압박 |
| agent-ubuntu20-mq-01 | ubuntu20 | c2_m2_r40 | prometheus-node-exporter | idle | 정상 대조군. service_category=monitor (인스턴스 이름 mq 는 destroy 회피로 유지) |
| agent-ubuntu24-app-01 | ubuntu24 | c2_m2_r40 | apache2 | agent_restart_demo | service_category=web (apache 도 engine 측 web 분류). 3분 주기 agent 재시작 → engine attention.agent_unstable 시연 |
| agent-ubuntu24-web-01 | ubuntu24 | c1_m1_r30 | nginx | offline_once | boot+5분 후 agent stop → engine gap_warnings 시연 |

7 OS / 7 service category / 8 noise profile.

## 10. 정리

```bash
cd ~/assessment-agent-fleet
bash scripts/teardown.sh                # terraform destroy + 임시 자원 + sg-agent 변경분 + 작업 산출물
sudo umount /var/lib/terraform-state 2>/dev/null
sudo sed -i '/LABEL=tfstate/d' /etc/fstab
sudo rmdir /var/lib/terraform-state 2>/dev/null
```

운영 측 DB cleanup (운영자 측):
```sql
TRUNCATE TABLE server_inventory RESTART IDENTITY CASCADE;
```

## 11. 알려진 함정

- **compute 자원 한계** — 본 사이트 동시 schedule 한계 ~11 vCPU. 30대 시도 시 ERROR. `parallelism=5` + 8대 매트릭스가 안전선
- **machine-id 중복** — debian/ubuntu cloud image 가 sealing 전 machine-id reset 안 함. common role 의 machine-id reset task 가 1회 reset (flag 로 idempotent)
- **journal volatile** — debian/ubuntu cloud image 가 `/var/log/journal` 미보유. common role 이 디렉토리 생성 + journald restart
- **RHEL 8 family (alma8/rocky8)** — platform-python(3.6) + python3-dnf 가 ansible-core 2.19 와 호환 안 됨. ansible-core 2.15 별도 venv 필요 (별도 트랙). 본 매트릭스는 RHEL 9 family 만 사용
- **본 사이트 RHEL 9 cloud image (redhat9)** — cloud-init keypair inject 실패 케이스 발견. 매트릭스에서 제외
- **broker IP 변경** — 운영자 측 mq-vm 재생성 시 IP 변경 가능. `rabbitmq_host` 갱신 필요
- **agent worker channel.close (basic.get)** — engine 측 task.install 발행 전엔 `agent.tasks.<machine_id>` queue 미존재. idle 패턴 정상

## 12. 관련 문서

- [README](../../README.md) — 본 repo 전체 흐름
- [ADR 0004](../adr/0004-topology.md) — 초기 3대 topology
- [ADR 0008](../adr/0008-multi-os-demo.md) — 본 8대 시연 매트릭스 결정 history
- [ADR 0006](../adr/0006-agent-release.md) — agent 빌드 / fetch path
- [docs/architecture/env-contract.md](../architecture/env-contract.md) — agent env 키 카탈로그
- [docs/operations/poc-temp-engine.md](poc-temp-engine.md) — 일회성 PoC (engine mockup) 절차
- [docs/operations/agent-binary-archive.md](agent-binary-archive.md) — agent dist archive
