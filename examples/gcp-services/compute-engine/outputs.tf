output "external_ip" {
  description = "The VM's ephemeral external IP."
  value       = google_compute_instance.web.network_interface[0].access_config[0].nat_ip
}

output "internal_ip" {
  description = "The VM's internal IP, from the default network's us-central1 subnet."
  value       = google_compute_instance.web.network_interface[0].network_ip
}

output "url" {
  description = "Where nginx answers, once the startup script has run."
  value       = "http://${google_compute_instance.web.network_interface[0].access_config[0].nat_ip}"
}

output "ssh_command" {
  description = "SSH into the VM through IAP."
  value       = "gcloud compute ssh ${google_compute_instance.web.name} --zone=${var.zone} --tunnel-through-iap"
}
