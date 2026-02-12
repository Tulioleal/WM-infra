# ============================================================================
# Google Cloud Storage (GCS) Buckets
# ============================================================================

resource "google_storage_bucket" "models" {
  name          = "${var.project_id}-${var.project_nickname}-models-${var.environment}"
  location      = var.region
  force_destroy = var.environment != "prod"
  
  uniform_bucket_level_access = true
  
  versioning {
    enabled = true
  }
  
  lifecycle_rule {
    condition {
      num_newer_versions = 5
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_storage_bucket" "inference_images" {
  name          = "${var.project_id}-${var.project_nickname}-images-${var.environment}"
  location      = var.region
  force_destroy = var.environment != "prod"
  
  uniform_bucket_level_access = true
  
  lifecycle_rule {
    condition {
      age = 120  # Eliminar imágenes después de 30 días
    }
    action {
      type = "Delete"
    }
  }
}