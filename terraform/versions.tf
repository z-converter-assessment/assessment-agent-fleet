terraform {
  required_version = ">= 1.6.0"

  # backend 종류 결정 후 추가. swift, s3 호환, local 중 택일.
  # backend "swift" {}

  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 2.1"
    }
  }
}
