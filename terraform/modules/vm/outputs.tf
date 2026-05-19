output "hostname" {
  value = openstack_compute_instance_v2.this.name
}

output "address" {
  value = openstack_compute_instance_v2.this.access_ip_v4
}

output "role" {
  value = var.role
}
