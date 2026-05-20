# 0003. OpenStack credential 방식: application credential

- Status: Accepted
- Date: 2026-05-19

## Context
OpenStack API 호출 (terraform openstack provider, ansible openstack.cloud collection, openstack CLI 검증) 에 인증 credential 필요. 가능한 후보:
- 사용자 비번 기반 (OS_USERNAME / OS_PASSWORD) — clouds.yaml 또는 env
- application credential (Keystone v3)
- federated SSO (SAML, OIDC) — 본 클라우드 미지원

## Decision
application credential 채택. `~/.config/openstack/clouds.yaml` 에 `auth_type: v3applicationcredential` 로 배치, 권한 0600.

발급 시 `Unrestricted=false` 고정 (이 AC 로 추가 AC 발급 차단).
cloud entry name 은 Horizon 기본값 `openstack` 사용 — terraform provider 와 ansible openstack.cloud 가 같은 이름으로 참조.

## Consequences
- 사용자 비번이 디스크 / git history / VM 어디에도 남지 않음
- Horizon 에서 개별 발급/회수 가능. 사용자 비번 회수와 분리되어 충격 범위 축소
- 만료 시점 도래 시 작업 중단 — 회전 절차 (`docs/operations/rotate.md`) 정상 동작 전제
- 모든 도구가 동일 clouds.yaml 참조 — credential 추적 단순화

## Alternatives
- 사용자 비번 clouds.yaml: 비번 평문 디스크 노출, 회수 시 사용자 권한 전체 차단으로 충격 큼
- env 직접 export: shell history 와 process env 노출 리스크, rc 파일 관리 부담
- federated SSO: 클라우드 측 미지원

## 운영 관찰 (참고)
- 현재 클라우드의 keystone endpoint 가 HTTP (`http://...:5000`) 로 노출. application credential secret 이 평문 전송됨. 사설망 내부 통신이라 작업 진행에는 차단 없으나, HTTPS 전환은 클라우드 운영자 측 별도 트랙으로 짚어둘 사항
