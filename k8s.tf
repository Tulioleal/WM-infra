# ============================================================================
# Kubernetes Resources - Valores que dependen de la infraestructura
# ============================================================================

# Namespace
resource "kubernetes_namespace_v1" "waste_detection" {
  metadata {
    name = var.project_nickname
  }
}

# ConfigMap con valores de infraestructura
resource "kubernetes_config_map_v1" "infra_config" {
  metadata {
    name      = "infra-config"
    namespace = kubernetes_namespace_v1.waste_detection.metadata[0].name
  }

  data = {
    GCS_MODELS_BUCKET = google_storage_bucket.models.name
    GCS_IMAGES_BUCKET = google_storage_bucket.inference_images.name
  }
}

# Secret con credenciales de la base de datos
resource "kubernetes_secret_v1" "db_credentials" {
  metadata {
    name      = "db-credentials"
    namespace = kubernetes_namespace_v1.waste_detection.metadata[0].name
  }

  data = {
    DATABASE_URL = "postgresql://app_user:${var.db_password}@${google_sql_database_instance.postgres.private_ip_address}:5432/${var.project_nickname}"
  }
}