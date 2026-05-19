output "hostname" {
  value = openstack_compute_instance_v2.this.name
}

output "address" {
  value = openstack_networking_port_v2.this.all_fixed_ips[0]
}

output "role" {
  value = var.role
}
