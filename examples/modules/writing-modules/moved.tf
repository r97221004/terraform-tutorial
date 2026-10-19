# Only needed if this configuration takes over the state of the Networking
# chapter, whose resources were at the root. With fresh state these are no-ops.

moved {
  from = google_compute_network.vpc
  to   = module.network.google_compute_network.vpc
}
moved {
  from = google_compute_subnetwork.gke
  to   = module.network.google_compute_subnetwork.gke
}
moved {
  from = google_compute_router.nat
  to   = module.network.google_compute_router.nat[0]
}
moved {
  from = google_compute_router_nat.nat
  to   = module.network.google_compute_router_nat.nat[0]
}
moved {
  from = google_compute_firewall.allow_internal
  to   = module.network.google_compute_firewall.allow_internal
}
moved {
  from = google_compute_firewall.allow_iap_ssh
  to   = module.network.google_compute_firewall.allow_iap_ssh[0]
}
