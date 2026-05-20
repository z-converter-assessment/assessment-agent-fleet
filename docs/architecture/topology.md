# Topology

fleet 멤버 VM 매트릭스와 네트워크 구조. Terraform input 의 단일 진실. 결정 history 는 [ADR 0004](../adr/0004-topology.md).

## 정체성
fleet 멤버 = 평가 대상 시뮬레이션 VM. 각 멤버에 agent C11 바이너리 install -> agent 가 자신을 인벤토리/메트릭 수집 -> engine 으로 outbound 전송. listening port 없음.

## VM 매트릭스 (staging 초기)

| 이름 | OS | flavor | 역할 | 비고 |
|------|----|--------|------|------|
| agent-debian12-vm-01 | debian12_x64_uefi_3G | c1_m1_r30 | agent host | staging |
| agent-debian12-vm-02 | debian12_x64_uefi_3G | c1_m1_r30 | agent host | staging |
| agent-debian12-vm-03 | debian12_x64_uefi_3G | c1_m1_r30 | agent host | staging |

네이밍 컨벤션: `agent-<os>-vm-NN`. 향후 OS 다양화 (debian13, alma9, redhat9 등) 시 동일 패턴.

prod 매트릭스는 staging 검증 통과 후 확정.

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

## 현재 관찰된 환경 (2026-05-19)

본 프로젝트가 합류할 OpenStack project 의 실측. 결정 입력으로 사용. 재확인: `openstack --os-cloud openstack server list / network list / subnet list / flavor list / image list / security group list / keypair list`.

기존 인스턴스 7대:
- 평가 엔진 컴포넌트 (assessment-engine 서브넷 10.0.10.64/26): engine-main (10.0.10.90), api-vm (10.0.10.80), worker-vm (10.0.10.79), db-vm (10.0.10.108), mq-vm (10.0.10.110), cache-vm (10.0.10.86)
- 인프라 / 타겟 트랙 (target-vms 서브넷 10.0.10.0/26): IaC (10.0.10.27)

네트워크:
- `zconverter-private-net` (사설). 서브넷 2개:
  - `assessment-engine` 10.0.10.64/26 — 엔진 컴포넌트 트랙
  - `target-vms` 10.0.10.0/26 — 평가 대상 / 인프라 거점 트랙
- `external_net` — 외부 부착 트랙. dual NIC 인스턴스가 부착

flavor 5종 (`c<vCPU>_m<RAM>_r<disk>` 컨벤션):
- c1_m1_r30 (1/1/30), c2_m2_r40 (2/2/40), c2_m4_r30 (2/4/30), c4_m4_r50 (4/4/50), zdm (4/8/100)

base image 표준: `debian12_x64_uefi_3G`. debian13_x64_uefi_3G, alma9, redhat9 등 다수 가용.

기존 sg: db-sg, api-sg, cache-sg, mq-sg, worker-sg, sg-engine, sg-IaC-group, sg-agent (현재 미부착 — 본 fleet 용도로 미리 만들어둠), default. quota 10/10 중 9 사용.

기존 keypair: `engine-key`, `IaC`. fleet 용 `agent-fleet` 은 신규 생성 필요.

## 의존
- credentials.md — OpenStack API 접근 방식
- terraform/variables.tf — 본 문서의 매트릭스를 변수로 표현
- terraform/modules/vm — VM 단위 module
- inventory.md — terraform output 을 ansible inventory 로 변환하는 흐름
