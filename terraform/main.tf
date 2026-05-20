data "openstack_networking_network_v2" "fleet" {
  name = var.network_name
}

data "openstack_networking_subnet_v2" "fleet" {
  name       = var.subnet_name
  network_id = data.openstack_networking_network_v2.fleet.id
}

data "openstack_networking_secgroup_v2" "fleet" {
  for_each = toset(var.security_group_names)

  name = each.value
}

module "vm" {
  for_each = var.agent_workers

  source = "./modules/vm"

  name               = each.key
  image              = each.value.image
  flavor             = each.value.flavor
  role               = each.value.role
  keypair            = var.keypair_name
  network_id         = data.openstack_networking_network_v2.fleet.id
  subnet_id          = data.openstack_networking_subnet_v2.fleet.id
  security_group_ids = [for sg in data.openstack_networking_secgroup_v2.fleet : sg.id]
  environment        = var.environment
  metadata           = each.value.metadata
}
