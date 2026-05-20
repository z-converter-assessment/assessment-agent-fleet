# terraform

OpenStack 환경의 fleet 멤버 VM provisioning. `agent_workers` 변수로 VM 매트릭스 정의.

## 구조
- `versions.tf` — terraform 버전, openstack provider 버전
- `providers.tf` — openstack provider (clouds.yaml 안 cloud 이름으로 인증)
- `variables.tf` — 입력 변수 선언
- `outputs.tf` — Ansible inventory 입력용 출력
- `main.tf` — `modules/vm` 호출
- `modules/vm/` — VM 단위 module
- `environments/<env>/terraform.tfvars.example` — 환경별 변수 example
- `environments/<env>/backend.hcl.example` — state backend example

## 사용 흐름
1. `terraform.tfvars.example` 을 `terraform.tfvars` 로 복사 후 값 채움 (.gitignore가 차단)
2. `backend.hcl.example` 도 동일하게 복사 후 채움
3. `terraform init -backend-config=environments/<env>/backend.hcl`
4. `terraform plan -var-file=environments/<env>/terraform.tfvars`
5. `terraform apply -var-file=environments/<env>/terraform.tfvars`
6. `terraform output -json` 결과를 Ansible inventory로 변환

## 확정 결정 (ADR 참조)
- topology: ADR 0004 — fleet 멤버 매트릭스, 네트워크, sg, keypair, naming
- state backend: ADR 0005 — local + cinder volume mount

## 잔여 결정
- prod 환경 매트릭스 (staging 검증 통과 후)
- network / security-group 의 terraform module 화 시점 (현재는 기존 자산 재사용)

세부 설계는 docs/architecture/ 참조.
