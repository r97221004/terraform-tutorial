output "network" {
  description = "Everything the GKE chapter needs from the network."
  value = {
    network        = module.network.network_name
    subnet         = module.network.subnet_name
    pods_range     = module.network.pods_range_name
    services_range = module.network.services_range_name
  }
}
