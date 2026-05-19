# commit 규칙

## type prefix (5개 중 정확한 분류)
- `feat` — 새 기능 추가 (기존 기능 확장 X)
- `fix` — 버그 수정
- `chore` — 설정·패키지·문서·메타 변경
- `refactor` — 동작 동일, 구조 변경
- `test` — 테스트 코드만

## scope (선택)
영향 영역. 예: `feat(terraform):`, `chore(docs):`, `chore(ansible):`

## 설명
- subject 와 body 모두 한글
- subject 70자 이내 요약
- body 는 변경 이유와 영향, 영향 범위 명시

## 금지
- LLM 메타데이터 (Co-Authored-By, "Generated with ..." 등)
- 이모지
- 빈 섹션 (의미 없는 헤더)

## 예시

```
chore(docs): 프로젝트 문서 골격 추가

repo 진입과 운영에 필요한 핵심 문서 구조 셋업.
- docs/architecture/: 토폴로지, credential, agent release, env contract
- docs/operations/: bootstrap, deploy, upgrade, rotate, runbook
```

```
feat(terraform): openstack vm provisioning 골격 추가

OpenStack provider 기반의 워커 VM provisioning 골격.
state backend 와 network 모듈은 결정 후 추가.
```
