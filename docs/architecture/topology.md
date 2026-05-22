# Topology

fleet 멤버 VM 매트릭스와 네트워크 구조. Terraform input 의 단일 진실. 결정 history 는 [ADR 0004](../adr/0004-topology.md).

## 정체성
fleet 멤버 = 평가 대상 시뮬레이션 VM. 각 멤버에 agent C11 바이너리 install -> agent 가 자신을 인벤토리/메트릭 수집 -> engine 으로 outbound 전송. listening port 없음.

## VM 매트릭스

`terraform/environments/<env>/terraform.tfvars` 의 `agent_workers` 가 단일 진실. flavor 는 `c1` 일괄 적용 (자원 최소). image / service_category / noise_profile 은 host 별 다양화.

시연 매트릭스 (multi-OS / multi-service / noise 8대) 는 [ADR 0008](../adr/0008-multi-os-demo.md) 참조. prod 매트릭스는 staging 검증 통과 후 확정.

네이밍 컨벤션: `agent-<os>-<service>-NN` (예: `agent-debian12-web-01`).

## 네트워크

- network: `zconverter-private-net` (기존 자산 재사용)
- subnet: `target-vms` (10.0.10.0/26)
- floating IP: 미할당. fleet 멤버는 사설망 only
- DNS / NTP: cloud-init 기본값 (서브넷 DHCP 가 공급하는 값)

### iac 와의 네트워크 관계
- iac VM 은 dual NIC: 사설망(10.0.10.27, target-vms) + 외부망(192.168.3.80)
- fleet 멤버는 사설망 단일 NIC
- iac 와 fleet 멤버가 같은 서브넷 (target-vms 10.0.10.0/26) 에 있으므로 L2 직접 통신. 라우터 hop 없음
- 운영자 접근: 점프호스트 (외부망) -> iac.nic2 (외부망) -> ssh -> fleet 멤버 (사설망). iac 가 bastion 역할
- fleet 멤버는 라우터의 SNAT 통해 외부 인터넷 도달 가능해야 agent 가 GitHub Release fetch 가능. 라우터 default route + SNAT 동작은 별도 검증 필요

## Security group

`sg-agent` 재사용 + 룰 갱신.

| direction | proto | port | remote | 의도 |
|-----------|-------|------|--------|------|
| ingress | tcp | 22 | 10.0.10.0/26 | iac (10.0.10.27) 에서 ansible ssh. fleet 내부 통신도 허용 |
| egress | any | any | 0.0.0.0/0 | agent outbound (engine, GitHub release fetch, 운영 패키지) |
| egress | any | any | ::/0 | IPv6 outbound (기본) |

기존 sg-agent 의 `ssh 22 from 0.0.0.0/0` 룰은 삭제 후 위 룰로 교체.

## SSH key

- OpenStack keypair 이름: `agent-fleet`
- private key 위치 (iac): `~/.ssh/agent-fleet` (0600)
- public key 등록: iac 에서 `openstack keypair create --public-key ~/.ssh/agent-fleet.pub agent-fleet`
- 키 회전: 새 keypair 생성 -> terraform `keypair_name` 변수 갱신 -> 신규 멤버 부터 적용. 기존 인스턴스는 cloud-init 으로 재주입 불가하므로 `authorized_keys` 를 ansible 로 갱신

## 의존
- credentials.md — OpenStack API 접근 방식
- terraform/variables.tf — 본 문서의 매트릭스를 변수로 표현
- terraform/modules/vm — VM 단위 module
