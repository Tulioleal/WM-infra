# ============================================================================
# Service Accounts por Pipeline
# ============================================================================

# --- Infra SA: permisos amplios para gestionar toda la infraestructura ---
resource "google_service_account" "ci_infra" {
  account_id   = "ci-infra"
  display_name = "CI/CD - Infra Pipeline"
  description  = "SA para el pipeline de infraestructura (tofu apply)"
}

resource "google_project_iam_member" "ci_infra_roles" {
  for_each = toset([
    "roles/editor",
    "roles/resourcemanager.projectIamAdmin",
    "roles/container.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/servicenetworking.networksAdmin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ci_infra.email}"
}

# --- CI App ---
resource "google_service_account" "ci_app" {
  account_id   = "ci-app"
  display_name = "CI/CD - App Pipelines"
  description  = "SA compartida para pipelines de inference-api, frontend y training"
}

resource "google_project_iam_member" "ci_app_roles" {
  for_each = toset([
    "roles/artifactregistry.writer",
    "roles/container.developer",
    "roles/container.clusterViewer",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/storage.objectAdmin"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.ci_app.email}"
}