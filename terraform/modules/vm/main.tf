resource "openstack_networking_port_v2" "this" {
  name           = "${var.name}-port"
  network_id     = var.network_id
  admin_state_up = true

  security_group_ids = var.security_group_ids

  fixed_ip {
    subnet_id = var.subnet_id
  }
}

resource "openstack_compute_instance_v2" "this" {
  name        = var.name
  image_name  = var.image
  flavor_name = var.flavor
  key_pair    = var.keypair

  network {
    port = openstack_networking_port_v2.this.id
  }

  metadata = merge(
    {
      environment = var.environment
      role        = var.role
    },
    var.metadata,
  )
}
