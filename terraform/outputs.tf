output "agent_workers" {
  description = "Ansible inventory 입력용 워커 VM 정보."
  value = {
    for name, m in module.vm : name => {
      hostname         = m.hostname
      address          = m.address
      role             = m.role
      service_category = var.agent_workers[name].service_category
      ssh_user         = var.agent_workers[name].ssh_user
      noise_profile    = var.agent_workers[name].noise_profile
    }
  }
}
