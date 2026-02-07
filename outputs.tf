# ============================================================================
# Outputs
# ============================================================================

output "cluster_name" {
  description = "Nombre del cluster GKE"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint del cluster GKE"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "models_bucket" {
  description = "Nombre del bucket para modelos"
  value       = google_storage_bucket.models.name
}

output "datasets_bucket" {
  description = "Nombre del bucket para datasets"
  value       = google_storage_bucket.datasets.name
}

output "images_bucket" {
  description = "Nombre del bucket para imágenes"
  value       = google_storage_bucket.inference_images.name
}

output "database_connection" {
  description = "Nombre de conexión de Cloud SQL"
  value       = google_sql_database_instance.postgres.connection_name
}

output "database_private_ip" {
  description = "IP privada de Cloud SQL"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "artifact_registry" {
  description = "URL del Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.repository_id}"
}

output "service_account_email" {
  description = "Email del Service Account de la aplicación"
  value       = google_service_account.app_sa.email
}
