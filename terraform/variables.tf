variable "openstack_cloud" {
  description = "clouds.yaml 안 cloud 이름. credential은 OS_CLIENT_CONFIG_FILE 또는 ~/.config/openstack/clouds.yaml 에서 로드."
  type        = string
}

variable "environment" {
  description = "환경 이름 (staging, prod 등)."
  type        = string
}

variable "keypair_name" {
  description = "OpenStack keypair 이름. fleet 멤버에 inject."
  type        = string
}

variable "network_name" {
  description = "fleet 멤버 가 join 할 OpenStack network 이름. data lookup 으로 ID 해석."
  type        = string
}

variable "subnet_name" {
  description = "network 안에서 fleet 멤버 port 가 부착될 subnet 이름. data lookup 으로 ID 해석."
  type        = string
}

variable "security_group_names" {
  description = "fleet 멤버 port 에 부착할 security group 이름 목록. data lookup 으로 ID 해석."
  type        = list(string)

  validation {
    condition     = length(var.security_group_names) > 0
    error_message = "security_group_names 가 비어있다."
  }
}

variable "agent_workers" {
  description = "fleet 멤버 매트릭스. docs/architecture/topology.md 의 단일 진실."
  type = map(object({
    image    = string
    flavor   = string
    role     = string
    metadata = optional(map(string), {})
  }))

  validation {
    condition     = length(var.agent_workers) > 0
    error_message = "agent_workers 매트릭스가 비어있다."
  }

  validation {
    condition = alltrue([
      for w in var.agent_workers : length(w.image) > 0 && length(w.flavor) > 0 && length(w.role) > 0
    ])
    error_message = "각 fleet 멤버 의 image, flavor, role 이 모두 정의되어야 한다."
  }
}
