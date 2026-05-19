# 인프라 VM 생성 (점프호스트에서)

점프호스트 (Windows Server 2022) 에서 OpenStack 리눅스 VM 을 생성하고
ssh 접속까지 셋업하는 절차. 이후 VM 안에서 `docs/operations/bootstrap.md` 진행.

## 전제
- 점프호스트 RDP 접속 완료
- Windows Terminal 또는 PowerShell 7 가용
- OpenStack Horizon (브라우저) 접근 가능
- OpenStack project / 권한 확인 완료

## 1. SSH key 생성 (점프호스트)

```powershell
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\agent-fleet -C "agent-fleet"
```

`agent-fleet.pub` 내용을 복사해둔다.

## 2. OpenStack keypair 등록

Horizon -> Compute -> Key Pairs -> Import Public Key.
- Key Pair Name: `agent-fleet`
- Public Key: 1번 의 `agent-fleet.pub` 내용

## 3. security group 생성

Horizon -> Network -> Security Groups -> Create Security Group.
- 이름: `infra-vm`
- 생성 후 Manage Rules 로 추가
  - SSH (TCP/22) ingress, 출발지: 점프호스트 외부 IP `/32` (또는 사내 CIDR)

## 4. 인프라 VM 생성

Horizon -> Compute -> Instances -> Launch Instance.
- Instance Name: `agent-fleet-infra`
- Source: Ubuntu 24.04 또는 Debian 12 image
- Flavor: vCPU 2 / RAM 4GB / disk 20GB 이상 권장
- Networks: 워커 VM 도 join 할 network (기존 또는 신규)
- Security Groups: `default` + `infra-vm`
- Key Pair: `agent-fleet`

## 5. floating IP 할당 (외부 도달 필요 시)

Horizon -> Network -> Floating IPs -> Allocate IP To Project -> Associate.

## 6. ssh 접속 검증 (점프호스트)

```powershell
ssh -i $env:USERPROFILE\.ssh\agent-fleet <user>@<vm-ip>
```

- Ubuntu image: 사용자명 `ubuntu`
- Debian image: 사용자명 `debian`

## 7. 다음 단계

인프라 VM 안에서
- `docs/operations/bootstrap.md` — toolchain 설치
- `docs/preflight.md` — OpenStack credential, ssh key, repo clone
- `docs/operations/deploy.md` — 워커 VM provisioning + 배포

claude code 를 인프라 VM 안에서 쓰려면 npm 또는 native installer 로 별도 설치.

## 보강 항목 (결정 후 갱신)
- VM image, flavor 표준 (docs/decisions-pending.md)
- network 구조 (기존 join 또는 신규)
- security group rule 매트릭스
