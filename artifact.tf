# ============================================================================
# Artifact Registry para imágenes Docker
# ============================================================================

resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = "${var.project_nickname}-${var.environment}"
  format        = "DOCKER"
  
  depends_on = [google_project_service.apis]
}