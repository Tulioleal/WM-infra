# ============================================================================
# Workload Identity Federation - Pool + Provider
# ============================================================================
# Un solo pool y provider para todos los repos de GitHub.
# Cada repo se autentica vía OIDC tokens que GitHub genera automáticamente.

# wif.tf

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Pool de identidad para pipelines de GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "GitHub OIDC Provider"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  attribute_condition = "assertion.repository_owner == '${var.github_owner}'"
}

# Bindings: qué repo puede usar qué SA
# Infra repo → ci-infra SA
resource "google_service_account_iam_member" "wif_infra" {
  service_account_id = google_service_account.ci_infra.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/WM-infra"
}

# App repos → ci-app SA
resource "google_service_account_iam_member" "wif_app" {
  for_each = toset(var.github_app_repos)

  service_account_id = google_service_account.ci_app.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_owner}/${each.value}"
}