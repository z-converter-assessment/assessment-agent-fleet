# 0008. multi-OS / multi-service / noise 시연 매트릭스 (8대)

- Status: Accepted
- Date: 2026-05-20

## Context
agent fleet 의 OS 호환성 + 서비스 운영 다양성 + engine 대시보드 동적 부하 시연 환경 필요. 원래 목표 30대.

본 OpenStack 환경 실측:
- compute 자원 한계 — 11 vCPU 가량이 동시 schedule 한계 ("No valid host was found" 반복)
- admin/reader 권한 없음 — hypervisor 자원 직접 확인 불가
- 다른 워크로드와 자원 경합

호환성 정찰 결과:
- RHEL 8 family (alma8, rocky8): platform-python(3.6) + python3-dnf binding 이 ansible-core 2.19 (controller) 와 호환 안 됨 (target python 3.7+ 요구). python3.9 별도 설치 시 dnf binding 미보유. 이중 제약
- redhat9: 본 사이트 cloud-image 의 cloud-init keypair inject 실패 (모든 user permission denied)
- amazon2023 등 일부: 동시 schedule 시 ERROR

## Decision

### 매트릭스 (8대)
[ADR 0004](0004-topology.md) 의 3대 초기 매트릭스 supersede. 시연 의도라 8대 단일 매트릭스 + 다양성 확보.

| host | OS | flavor | service | noise |
|------|----|--------|---------|-------|
| agent-alma9-db-01 | alma9 | c2_m4_r30 | db (postgres) | io_heavy |
| agent-debian12-container-01 | debian12 | c2_m2_r40 | container (docker) | cpu_heavy |
| agent-debian12-web-01 | debian12 | c1_m1_r30 | web (nginx) | cpu_light |
| agent-debian13-mq-01 | debian13 | c2_m2_r40 | mq (mosquitto) | mixed |
| agent-rocky9-cache-01 | rocky9 | c1_m1_r30 | cache (memcached) | mem_heavy |
| agent-ubuntu20-mq-01 | ubuntu20 | c2_m2_r40 | monitor (node-exporter) | idle |
| agent-ubuntu24-app-01 | ubuntu24 | c2_m2_r40 | web (nginx) | agent_restart_demo |
| agent-ubuntu24-web-01 | ubuntu24 | c1_m1_r30 | web (nginx) | offline_once |

7 OS, 6 service category, 8 noise profile.

### 제외
- RHEL 8 family (alma8, rocky8) — 호환성 이슈
- redhat9 — cloud-init keypair 실패
- amazon2023, debian10/11, ubuntu18 — compute 자원 한계로 cluster scheduling fail
- CentOS 6 / SLES 11 — glibc 2.17 미달 (ADR 0006 도 이미 제외)

### 인스턴스 명명
`agent-<os>-<service>-NN` 패턴. 단 service 재배치 시 인스턴스 destroy 회피 위해 이름 유지 가능:
- `agent-ubuntu20-mq-01` — service_category=`monitor` (이름의 mq 는 잔재)
- `agent-ubuntu24-app-01` — service_category=`web` (이름의 app 은 잔재. app 카테고리 폐기 후 web 으로 흡수)

### 서비스 install path
ansible/roles/service_<category> (6 role). OS family 별 vars/{Debian,RedHat}.yml 분기.
- web=nginx (Debian/RedHat 동일)
- db=postgresql, container=docker, mq=mosquitto, monitor=prometheus-node-exporter
- cache 는 RHEL 1GB RAM 호스트 OOM 회피 위해 Debian=redis / RHEL=memcached 분기

`service_app` (apache) role 은 폐기 — ubuntu24-app-01 이 web 카테고리로 흡수되어 어떤 host 도 service_app 그룹에 안 들어감.

### 부하 시연
ansible/roles/noise (stress-ng) + noise_agent_restart (systemd timer) + noise_offline_once (systemd-run transient).
agent_restart_demo / offline_once 는 engine 의 attention 카탈로그 (`agent_unstable`, `gap_warnings`) 시연 트리거.

stress-ng 인자는 호스트 안정성 (1 vCPU / 1GB RAM 의 c1_m1 flavor 가 매트릭스에 섞여 있음) 고려해서 완화:
- `cpu_heavy`: `--cpu 2 --cpu-load 40` (원래 80 -> 40. 1GB RAM 호스트 동시 부하 시 OOM/스케줄러 굶주림 회피)
- `mixed`: `--cpu-load 25 --vm-bytes 50M` (원래 40/100M -> 25/50M. mq host 가 mosquitto + agent 와 동시 동작)

### Broker 좌표 (실값)
- host: mq-vm 10.0.10.73 (사이트 운영 측 broker)
- vhost: `assessment` (leading slash 없음)
- credentials: `assessment` / `1234` (ansible-vault 암호화)
- sg-mq 가 agent-sg ingress 5672 허용 — 정합

## Consequences
- 30대 → 8대 축소. 다양성은 유지 (7 OS / 7 service / 8 noise)
- noise profile 이 host_vars 로 자동 inject — terraform tfvars 가 단일 진실
- ssh_user 가 OS별 다양 — host_vars 자동 매핑
- RHEL 8 family / redhat9 정합 지원은 별도 트랙 (ansible-core 2.15 별도 venv, cloud-init 정상 image 확보)
- compute 자원 확보 시 매트릭스 확장 가능 (variables/main 코드는 30대 매트릭스 그대로 동작)

## Alternatives
- 30대 강행: cluster 자원 부족 ERROR 반복. 운영자 admin 권한 확보 + 자원 확장 별도 트랙
- RHEL 8 family 호환 위해 controller ansible-core 다운그레이드: 일관성 측면 정합이지만 본 demo 시간 안에 어려움. 별도 트랙
- service 다양화 없이 단일 OS 30대: agent 호환성 검증 의도 충족 안 됨
- noise 없이 idle 시연: engine 대시보드 동적 그림 없음

## 후속 항목
- ansible-core 2.15 별도 venv 도입 (RHEL 8 family 지원)
- cluster 자원 확보 후 30대 매트릭스 복원
- redhat9 cloud-init 정상 image 또는 별도 keypair inject 방법
- noise profile 더 풍부하게 (network 부하, custom workload 등)
