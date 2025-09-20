# Reserve a static internal IP for the Nomad server so clients can join reliably
resource "google_compute_address" "server_ip" {
  name         = "${local.name_prefix}-server-ip"
  address_type = "INTERNAL"
  purpose      = "GCE_ENDPOINT"
  subnetwork   = google_compute_subnetwork.subnet.id
  region       = var.region
}

## Image: use Ubuntu LTS family
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2004-lts"
  project = "ubuntu-os-cloud"
}

# Nomad server instance (single)
resource "google_compute_instance" "server" {
  name         = "${local.name_prefix}-server-0"
  machine_type = var.server_machine_type
  zone         = var.zone
  tags         = ["nomad", "server"]
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.name
    network_ip = google_compute_address.server_ip.address
    # No access_config => no external IP
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/server-startup.sh", {
    server_ip = google_compute_address.server_ip.address
    region    = var.region
  })

  service_account {
    email  = google_service_account.nomad_sa.email
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/monitoring.read"
    ]
  }
}

# Instance template for clients
resource "google_compute_instance_template" "client_tmpl" {
  name_prefix  = "${local.name_prefix}-client-"
  machine_type = var.client_machine_type
  tags         = ["nomad", "client"]
  labels       = var.labels

  disk {
    auto_delete  = true
    boot         = true
    source_image = data.google_compute_image.ubuntu.self_link
    disk_size_gb = 10
    disk_type    = "pd-standard"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    # no access_config -> no public IP
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/scripts/client-startup.sh", {
    server_ip = google_compute_address.server_ip.address
    region    = var.region
  })

  scheduling {
    preemptible       = var.client_preemptible
    automatic_restart = false
  }

  service_account {
    email  = google_service_account.nomad_sa.email
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/monitoring.read"
    ]
  }
}

# Managed Instance Group for clients
resource "google_compute_region_instance_group_manager" "clients" {
  name               = "${local.name_prefix}-clients"
  base_instance_name = "${local.name_prefix}-client"
  region             = var.region
  target_size        = var.client_count

  version {
    instance_template = google_compute_instance_template.client_tmpl.id
  }

  update_policy {
    minimal_action    = "REPLACE"
    type              = "OPPORTUNISTIC"
  }

  named_port {
    name = "http"
    port = 8080
  }
}
