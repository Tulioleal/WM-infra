# ============================================================================
# Service Account para la aplicación
# ============================================================================

resource "google_service_account" "app_sa" {
  account_id   = "${var.project_nickname}-app-${var.environment}"
  display_name = "Waste Detection Application Service Account"
}

# Permisos para GCS
resource "google_storage_bucket_iam_member" "models_access" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_storage_bucket_iam_member" "datasets_access" {
  bucket = google_storage_bucket.datasets.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_storage_bucket_iam_member" "images_access" {
  bucket = google_storage_bucket.inference_images.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app_sa.email}"
}

resource "google_storage_bucket_iam_member" "models_bucket_reader" {
  bucket = google_storage_bucket.models.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.app_sa.email}"
}

# Workload Identity binding
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.app_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.project_nickname}/${var.project_nickname}-app-sa]"
}

# 1. Crear la SA custom
resource "google_service_account" "gke_nodes" {
  account_id   = "gke-nodes-${var.environment}"
  display_name = "GKE Nodes SA - ${var.environment}"
  project      = var.project_id
}

# 2. Asignar los roles mínimos
locals {
  gke_node_roles = [
    "roles/container.defaultNodeServiceAccount",
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset(local.gke_node_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}