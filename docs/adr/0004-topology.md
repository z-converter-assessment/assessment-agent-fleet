# 0004. fleet topology

- Status: Accepted
- Date: 2026-05-19

## Context
본 repo 의 fleet 멤버 VM 매트릭스 결정 필요. `docs/architecture/topology.md` 의 결정 입력.

OpenStack 정찰 결과 (1회성 정찰):
- 기존 인스턴스 7대 — engine-main, api-vm, worker-vm, db-vm, mq-vm, cache-vm, IaC
- 네트워크 `zconverter-private-net` 에 서브넷 2개:
  - `assessment-engine` (10.0.10.64/26) — 평가 엔진 컴포넌트
  - `target-vms` (10.0.10.0/26) — IaC 와 평가 대상 트랙
- flavor 5종 (`c<vCPU>_m<RAM>_r<disk>` 컨벤션 + `zdm`)
- base image 표준: `debian12_x64_uefi_3G`
- 이미 존재하는 `sg-agent` (ingress ssh 22 from 0/0, egress all) — 본 fleet 용도로 미리 만들어진 sg, 현재 미부착

## Decision

### 정체성
fleet 멤버 = 평가 대상 시뮬레이션 VM. 각 VM 에 agent C11 바이너리 install -> agent 가 자신을 인벤토리/메트릭 수집 -> engine 으로 전송 (outbound-only 클라이언트).

### 위치
- 네트워크: `zconverter-private-net`
- 서브넷: `target-vms` (10.0.10.0/26)
- floating IP: 불필요 (outbound-only, 평가 대상 트랙)

### 형상
- flavor: `c1` (자원 최소 flavor)
- image: `debian12_x64_uefi_3G`
- 네이밍 컨벤션: `agent-<os>-vm-NN` (예: `agent-debian12-vm-01`)
- staging 초기 개수: 3대 (multi-instance 동작 검증용)

### 보안
- security group: 기존 `sg-agent` 재사용. 단 ssh 22 ingress 범위를 `0.0.0.0/0` 에서 `10.0.10.0/26` (target-vms CIDR) 로 좁힘. iac 가 같은 서브넷이라 ansible 작업 통과, 외부 ssh 차단
- keypair: `agent-fleet` 신규 생성. 기존 `IaC`, `engine-key` 와 분리

## Consequences
- 네트워크는 기존 자산 재사용 — 신규 network 생성 시 발생하는 라우팅/라우터 구성 부담 없음
- sg-agent 룰 수정은 in-place edit 불가, 룰 삭제 + 신규 룰 생성 절차. terraform 으로 sg 관리 시 `openstack_networking_secgroup_rule_v2` resource 로 표현
- naming 에 `<os>` 가 들어가서 향후 OS 다양화 (debian13, alma9 등) 시 fleet 단위 fan-out 가능. terraform `agent_workers` 변수에 OS 정보 포함
- floating IP 미할당 — iac 외부에서 fleet 멤버로 직접 ssh 불가. 운영자가 iac 거점에서만 접근
- c1 으로 시작 — agent 실측 결과 부족 시 flavor 갱신 (terraform 변수 갱신 + 재apply, image 동일 유지면 in-place resize 시도 가능)

## Alternatives
- 서브넷 `assessment-engine` 선택: agent 가 엔진 컴포넌트로 해석. 본 fleet 정체성과 불일치 (시뮬레이션 대상이지 엔진 일부 아님)
- 신규 서브넷 / 신규 network 생성: 기존 엔진과 통신 위해 라우터 / route 추가 필요. 운영 단순성 저하
- 신규 `sg-agent-fleet` sg 생성: quota 10/10 중 9 사용 — 여유 1 소모. sg-agent 가 이미 동일 용도로 존재해서 중복
- 신규 keypair 없이 `IaC` keypair 재사용: 충격 범위 확대 (iac + fleet 동시 노출), 회전 시 양쪽 영향
- flavor 더 큰 사양 (c2_m2_r40): agent 가 가벼운 outbound 클라이언트라 과투자. 필요 시 후속 결정으로 갱신
- naming 에 OS 미포함 (`agent-vm-NN`): OS 다양화 시 식별 불가
- floating IP 할당: outbound-only 모델에서 불필요. 비용/보안 노출 무익

## 후속 항목
- agent release contract 확정 후 `agent_workers` 변수에 `agent_version` 필드 또는 group_vars 에서 주입
- prod 환경 매트릭스는 staging 검증 통과 후 확정 — 동일 표준 적용 또는 다중 OS fan-out
