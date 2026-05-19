variable "openstack_cloud" {
  description = "clouds.yaml 안 cloud 이름. credential은 OS_CLIENT_CONFIG_FILE 또는 ~/.config/openstack/clouds.yaml 에서 로드."
  type        = string
}

variable "environment" {
  description = "환경 이름 (staging, prod 등)."
  type        = string
}

variable "keypair_name" {
  description = "OpenStack keypair 이름. 워커 VM에 inject."
  type        = string
}

variable "network_id" {
  description = "워커 VM이 join할 network UUID 또는 이름."
  type        = string
}

variable "agent_workers" {
  description = "워커 VM 매트릭스. docs/architecture/topology.md 의 단일 진실."
  type = map(object({
    image    = string
    flavor   = string
    role     = string
    metadata = optional(map(string), {})
  }))
}
