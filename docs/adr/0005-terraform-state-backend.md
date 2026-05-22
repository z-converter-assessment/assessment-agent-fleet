# 0005. Terraform state backend: local + cinder volume

- Status: Accepted
- Date: 2026-05-19

## Context
terraform state 저장 위치 결정 필요.

본 클라우드 정찰 결과:
- swift (object-store) 서비스 미가용 — keystone catalog 에 object-store endpoint 없음
- cinderv3 (block volume) 가용 — endpoint 정상
- 외부 S3 호환 endpoint 별도 인프라 없음
- 운영자 1인, iac VM 단일 작업 거점

## Decision
backend 종류: `local` (terraform 기본). 단 state 파일을 iac VM 의 로컬 디스크가 아니라 **iac 에 attach 한 cinder volume mount 경로**에 저장.

- volume 이름: `tfstate-agent-fleet` (단일 volume, 환경별 디렉토리 분리)
- volume 크기: 1 GB (state 파일 수십~수백 KB 규모. 여유)
- mount 경로: `/var/lib/terraform-state`
- 파일 위치: `/var/lib/terraform-state/<env>/terraform.tfstate`
- versions.tf 의 backend 블록: `backend "local" {}`
- environments/<env>/backend.hcl 에 `path = "/var/lib/terraform-state/<env>/terraform.tfstate"` 지정

## Consequences
- iac VM 자체가 죽어도 cinder volume detach -> 신규 iac VM 에 attach -> state 복구 가능. SPOF 완화
- 본 클라우드 안에서 해결 — 외부 의존 (GitHub, 외부 S3, sops 인프라) 없음
- cinder snapshot 으로 state 백업 트랙 통합 가능 — 별도 cron / 외부 백업 불필요
- backend `local` 은 lock 미지원 — 운영자 1인 가정. 추가 운영자 합류 시 backend 재선정 (postgres backend, 외부 S3 등) 필요
- volume mount 가 깨지면 terraform 명령이 실패 — 운영 절차 (`docs/operations/bootstrap.md` 또는 별도 ops doc) 에 mount 검증 단계 포함

## Alternatives
- swift backend: 본 클라우드 미가용. 가용해도 lock 지원이 native swift 에선 어려움 (lock container 별도 운영 필요)
- s3 호환 외부: 별도 인프라 (MinIO 등) 셋업 부담. 본 클라우드 안에서 해결되는 cinder 가 더 정합
- 순수 local (iac 디스크): iac VM SPOF. 별도 백업 cron 필요. cinder volume 대비 복구성 낮음
- git repo encrypted (sops/age): 분산성/감사성 최고. 단 lock 부재 + state 가 git history 에 누적되어 변경마다 commit 부담 + secret 이 (암호화돼도) repo 에
- postgres backend: db-vm 에 backend db 추가 가능하지만 운영 복잡, db-vm 의존성 증가 — 평가 엔진 db 와 책임 경계 흐려짐

## 후속 항목
- cinder snapshot 정책 (주기, 보존) 별도 결정 — `docs/operations/rotate.md` 또는 신규 backup ops doc
- 운영자 추가 합류 시 backend 재선정
