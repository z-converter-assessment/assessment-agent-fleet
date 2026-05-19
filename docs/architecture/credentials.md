# Credentials

OpenStack API 접근 credential 흐름.

## 종류
- clouds.yaml — `~/.config/openstack/clouds.yaml` 또는 env `OS_CLIENT_CONFIG_FILE`
- application credential — Horizon에서 발급. 만료 / 회수 가능
- env 직접 지정 — `OS_AUTH_URL`, `OS_USERNAME`, `OS_PROJECT_NAME` 등

본 repo는 application credential 권장. 사용자 비밀번호 노출 방지.

## 적용 위치
- 인프라 VM의 작업 사용자 home에 clouds.yaml 또는 application credential 파일
- 파일 권한 0600
- shell rc에서 env 지정 또는 `--os-cloud <name>` 옵션

## 검증
- `openstack token issue` — token 발급
- `openstack server list` — project 단위 server 조회
- `openstack network list` — network 권한

## 회수
- Horizon에서 application credential delete
- 또는 clouds.yaml 파일 삭제

## 의존
- terraform/providers.tf — OpenStack provider가 본 credential 사용
- ansible에서 openstack.cloud collection 모듈도 동일 credential 사용
