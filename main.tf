locals {
  name_prefix = "nomad"
}

# Enable OS Login across the project for secure SSH via IAP
resource "google_compute_project_metadata" "default" {
  metadata = {
    enable-oslogin = "TRUE"
  }
}
