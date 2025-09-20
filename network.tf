resource "google_compute_network" "vpc" {
  name                    = "${local.name_prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${local.name_prefix}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
}

# Internal allowlist for Nomad cluster communication
resource "google_compute_firewall" "allow-internal" {
  name    = "${local.name_prefix}-allow-internal"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.subnet_cidr]
}

# Allow SSH from IAP only (no public IPs needed)
resource "google_compute_firewall" "allow-ssh-iap" {
  name    = "${local.name_prefix}-allow-ssh-iap"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Optional: Allow HTTP access to app internally (we'll use SSH tunnel/IAP)
resource "google_compute_firewall" "allow-http-internal" {
  name    = "${local.name_prefix}-allow-http-internal"
  network = google_compute_network.vpc.name

  direction     = "INGRESS"
  source_ranges = [var.subnet_cidr]

  allow {
    protocol = "tcp"
    ports    = ["8080", "4646", "4647", "4648"]
  }
}
