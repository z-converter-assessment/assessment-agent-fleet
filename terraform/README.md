# terraform

OpenStack 환경의 워커 VM provisioning. `agent_workers` 변수로 VM 매트릭스 정의.

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

## 결정 필요
- state backend 종류 (swift, s3 호환, local)
- network 모듈 추가 시점 (기존 network join 시 불필요)
- security group 모듈 추가 시점
- floating IP 정책

세부 설계는 docs/architecture/ 참조.
