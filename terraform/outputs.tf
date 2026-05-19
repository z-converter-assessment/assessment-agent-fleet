output "agent_workers" {
  description = "Ansible inventory 입력용 워커 VM 정보."
  value = {
    for name, m in module.vm : name => {
      hostname = m.hostname
      address  = m.address
      role     = m.role
    }
  }
}
