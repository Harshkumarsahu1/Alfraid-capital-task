output "server_name" {
  value       = google_compute_instance.server.name
  description = "Nomad server instance name"
}

output "server_internal_ip" {
  value       = google_compute_address.server_ip.address
  description = "Nomad server internal IP"
}

output "subnet_cidr" {
  value       = var.subnet_cidr
  description = "Subnet CIDR"
}
