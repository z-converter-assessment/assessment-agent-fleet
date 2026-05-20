terraform {
  required_version = ">= 1.6.0"

  # backend "local" + state 파일 경로를 cinder volume mount 위치로 지정.
  # 결정 history: docs/adr/0005-terraform-state-backend.md
  # 실제 path 는 환경별 backend.hcl 로 주입.
  backend "local" {}

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.4"
    }
  }
}
