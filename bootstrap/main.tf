# ============================================================================
# Bootstrap - State Bucket + Workload Identity Federation para GitHub Actions
# ============================================================================
#
# Este bootstrap crea:
#   1. Bucket de GCS para el state de Tofu
#   2. Workload Identity Pool + Provider para GitHub Actions
#   3. Service Accounts por pipeline con permisos específicos
#   4. Bindings de WIF para cada repo de GitHub
#
# Correr desde tu laptop:
#   tofu init
#   tofu apply
#
# ============================================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ============================================================================
# 1. State Bucket
# ============================================================================

resource "google_storage_bucket" "tfstate" {
  name                        = var.bucket_name
  location                    = var.region
  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
}

# ============================================================================
# 2. Workload Identity Federation - Pool + Provider
# ============================================================================
# Un solo pool y provider para todos los repos de GitHub.
# Cada repo se autentica vía OIDC tokens que GitHub genera automáticamente.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Pool de identidad para pipelines de GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  # GitHub emite tokens OIDC para cada workflow run
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  # Mapeo de atributos del token de GitHub a atributos de Google
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Solo permitir tokens de repos de tu cuenta
  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"
}

# ============================================================================
# 3. Service Accounts por Pipeline
# ============================================================================

# --- Infra SA: permisos amplios para gestionar toda la infraestructura ---
resource "google_service_account" "ci_infra" {
  account_id   = "ci-infra"
  display_name = "CI/CD - Infra Pipeline"
  description  = "SA para el pipeline de infraestructura (tofu apply)"
}

# La SA de infra necesita poder gestionar todos los recursos del proyecto
resource "google_project_iam_member" "ci_infra_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.ci_infra.email}"
}

# Permisos adicionales que "editor" no incluye
resource "google_project_iam_member" "ci_infra_iam_admin" {
  project = var.project_id
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = "serviceAccount:${google_service_account.ci_infra.email}"
}

resource "google_project_iam_member" "ci_infra_k8s_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.ci_infra.email}"
}

resource "google_project_iam_member" "ci_infra_service_usage" {
  project = var.project_id
  role    = "roles/serviceusage.serviceUsageAdmin"
  member  = "serviceAccount:${google_service_account.ci_infra.email}"
}

# --- App SA: permisos para build, push y deploy de aplicaciones ---
resource "google_service_account" "ci_app" {
  account_id   = "ci-app"
  display_name = "CI/CD - App Pipelines"
  description  = "SA compartida para pipelines de inference-api, frontend y training"
}

# Push imágenes al Artifact Registry
resource "google_project_iam_member" "ci_app_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.ci_app.email}"
}

# Desplegar en GKE (kubectl apply)
resource "google_project_iam_member" "ci_app_k8s_developer" {
  project = var.project_id
  role    = "roles/container.developer"
  member  = "serviceAccount:${google_service_account.ci_app.email}"
}

# Acceso a GKE para obtener credenciales del cluster
resource "google_project_iam_member" "ci_app_k8s_viewer" {
  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${google_service_account.ci_app.email}"
}

# ============================================================================
# 4. Workload Identity Bindings - Conectar repos con SAs
# ============================================================================

# --- WM-infra → ci-infra SA ---
resource "google_service_account_iam_member" "wif_infra" {
  service_account_id = google_service_account.ci_infra.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/WM-infra"
}

# --- WM-inference-api → ci-app SA ---
resource "google_service_account_iam_member" "wif_inference_api" {
  service_account_id = google_service_account.ci_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/WM-inference-api"
}

# --- WM-frontend → ci-app SA ---
resource "google_service_account_iam_member" "wif_frontend" {
  service_account_id = google_service_account.ci_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/WM-frontend"
}

# --- WM-training → ci-app SA ---
resource "google_service_account_iam_member" "wif_training" {
  service_account_id = google_service_account.ci_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/WM-training"
}