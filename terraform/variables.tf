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
  description = <<-EOT
    fleet 멤버 매트릭스. docs/architecture/topology.md 의 단일 진실.

    각 host 필드:
      - image            OpenStack image 명 (예: debian12_x64_uefi_3G)
      - flavor           OpenStack flavor 명 (예: c1_m1_r30)
      - role             agent 메타데이터에 박힐 역할 라벨 (예: agent-host)
      - service_category ansible 의 서비스 role 분기 (web / db / cache / mq / container / monitor / app / none)
      - ssh_user         cloud-init 기본 사용자명 (debian / ubuntu / cloud-user / almalinux / rocky 등)
      - noise_profile    ansible 의 noise role 분기 (cpu_light / cpu_heavy / mem_heavy / io_heavy / mixed / idle / agent_restart_demo / offline_once)
      - metadata         OpenStack instance metadata override (선택)
  EOT
  type = map(object({
    image            = string
    flavor           = string
    role             = string
    service_category = optional(string, "none")
    ssh_user         = string
    noise_profile    = optional(string, "idle")
    metadata         = optional(map(string), {})
  }))

  validation {
    condition     = length(var.agent_workers) > 0
    error_message = "agent_workers 매트릭스가 비어있다."
  }

  validation {
    condition = alltrue([
      for w in var.agent_workers : length(w.image) > 0 && length(w.flavor) > 0 && length(w.role) > 0 && length(w.ssh_user) > 0
    ])
    error_message = "각 fleet 멤버 의 image, flavor, role, ssh_user 가 모두 정의되어야 한다."
  }

  validation {
    condition = alltrue([
      for w in var.agent_workers : contains(["web", "db", "cache", "mq", "container", "monitor", "app", "none"], w.service_category)
    ])
    error_message = "service_category 는 web / db / cache / mq / container / monitor / app / none 중 하나."
  }

  validation {
    condition = alltrue([
      for w in var.agent_workers : contains(["cpu_light", "cpu_heavy", "mem_heavy", "io_heavy", "mixed", "idle", "agent_restart_demo", "offline_once"], w.noise_profile)
    ])
    error_message = "noise_profile 은 cpu_light / cpu_heavy / mem_heavy / io_heavy / mixed / idle / agent_restart_demo / offline_once 중 하나."
  }
}
