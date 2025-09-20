# Service account for Nomad instances (server and clients)
resource "google_service_account" "nomad_sa" {
  account_id   = "${local.name_prefix}-sa"
  display_name = "Nomad Instances Service Account"
}

# Grant minimal roles for logging/monitoring
resource "google_project_iam_member" "logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.nomad_sa.email}"
}

resource "google_project_iam_member" "metrics" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.nomad_sa.email}"
}

resource "google_project_iam_member" "monitoring-viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.nomad_sa.email}"
}
