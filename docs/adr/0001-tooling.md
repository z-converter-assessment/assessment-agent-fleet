# 0001. Terraform + Ansible 선택

- Status: Accepted
- Date: 2026-05-19

## Context
OpenStack 환경에서 agent 워커 VM N대 provisioning과, OS 측에서 바이너리 install, env 주입, systemd unit 관리가 필요.

## Decision
인프라 layer는 Terraform (OpenStack provider). 구성 관리 layer는 Ansible.

## Consequences
- 두 도구를 인프라 VM에 모두 설치
- terraform state와 ansible inventory 간 연계 절차 필요 (terraform output -> inventory 변환)
- IaC layer와 구성 관리 layer가 분리되어 책임 경계 명확

## Alternatives
- Terraform 단독 + cloud-init: provisioning은 단순하나 OS 변경 반복 적용 어려움
- Ansible 단독 + openstack.cloud 모듈: 한 도구로 처리 가능하지만 state 추적 약함
- SaltStack: master/minion 모델. 소규모 fleet에는 오버스펙
- Pulumi: 범용 언어 기반 IaC. 팀 경험 부족
