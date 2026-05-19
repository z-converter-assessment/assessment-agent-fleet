# Preflight

작업 시작 전 확인할 사항. 모든 항목 통과 후 진행.

## 점프호스트 접속
- 맥북에서 WindowApp으로 RDP 접속 가능
- Windows Server 2022 데스크탑 도달
- 점프호스트에서 OpenStack Horizon 접속 가능 (브라우저)

## 인프라 VM 접속
- 점프호스트에서 인프라 VM으로 ssh 세션 연결 가능
- OS: Ubuntu 또는 Debian 안정 버전
- 디스크 여유 (terraform state, ansible cache 용)

## 인프라 VM toolchain
- terraform (>= 1.6)
- ansible-core (>= 2.16)
- ansible-lint
- python3 + openstacksdk
- git, gh CLI
- openssh-client
- jq (terraform output -> ansible inventory 변환)

처음 셋업이라면 `docs/operations/bootstrap.md`.

## OpenStack credential
- clouds.yaml 또는 application credential 파일 존재
- env 변수 또는 --os-cloud 옵션 지정 가능
- `openstack token issue` 정상 응답
- `openstack server list` 정상 응답
- 프로젝트, 도메인, region 명확

## SSH key
- fleet 멤버 접근용 ssh key pair 준비
- OpenStack keypair 등록 여부 확인

## repo
- 본 repo clone 권한 확인 (gh auth status)
- 작업 branch 결정

## 작업 대상
- 환경 (staging / prod) 명확
- 변경할 .tfvars 또는 group_vars 사전 식별
- 변경 범위 (신규 배포, 버전 갱신, secret 회전, VM 추가) 명확
- prod 변경 시 작업 시간대와 영향 범위 합의

## 외부 의존
- agent repo의 release tag 결정
- agent 바이너리 sha256 확보
- engine 측 broker, endpoint 정보 확보 (필요 시)

## state, secret
- Terraform state backend 접근 가능 (있다면)
- Ansible Vault password 핸들링 방식 확인 (있다면)
