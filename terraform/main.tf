module "vm" {
  for_each = var.agent_workers

  source = "./modules/vm"

  name        = each.key
  image       = each.value.image
  flavor      = each.value.flavor
  role        = each.value.role
  keypair     = var.keypair_name
  network_id  = var.network_id
  environment = var.environment
  metadata    = each.value.metadata
}
