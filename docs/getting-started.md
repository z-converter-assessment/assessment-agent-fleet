# Getting Started

본 repo를 처음 다루는 사람이 큰 그림을 잡기 위한 진행 순서. 키워드 중심으로 단계만 나열.
세부 절차는 진행 시점에 docs/ 안 추가 문서로 분기.

## 0. 작업 환경 진입
- RDP / WindowApp -> Windows Server 2022 점프호스트
- 점프호스트에서 인프라 VM 생성 + ssh 셋업: `docs/operations/infra-vm-create.md`
- ssh -> 인프라 VM (Ubuntu 또는 Debian)
- 인프라 VM toolchain 설치: `docs/operations/bootstrap.md`
- 미흡 시 `docs/preflight.md` 참조

## 1. credential 확인
- clouds.yaml 또는 application credential
- env: OS_AUTH_URL, OS_PROJECT_NAME, OS_REGION_NAME 등
- `openstack token issue` 응답 확인
- `openstack server list` 응답 확인

## 2. repo 준비
- git clone
- gh CLI 인증 (release artifact fetch 용)
- 작업 branch 결정

## 3. Terraform — VM provisioning
- providers.tf: openstack provider 선언
- variables.tf: VM 매트릭스 (이름, image, flavor, 역할)
- terraform init -> plan -> apply
- outputs.tf: 워커 VM IP / hostname 노출

## 4. Ansible inventory 생성
- terraform output -> inventory 변환
- group_vars / host_vars 구조 결정

## 5. Ansible — agent 배포
- agent C11 바이너리: GitHub Release fetch + sha256 검증
- 설치 경로: /usr/local/bin/assessment-agent
- env 파일: /etc/assessment-agent.env (template + Vault)
- systemd unit enable -> start

## 6. 헬스 검증
- agent systemd active 상태 확인
- agent -> engine broker 도달 검증

## 7. 운영 루틴
- agent 버전 갱신
- env / secret 회전
- 인시던트 대응 (journalctl, 재시작)
