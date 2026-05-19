resource "openstack_compute_instance_v2" "this" {
  name        = var.name
  image_name  = var.image
  flavor_name = var.flavor
  key_pair    = var.keypair

  network {
    uuid = var.network_id
  }

  metadata = merge(
    {
      environment = var.environment
      role        = var.role
    },
    var.metadata,
  )
}
