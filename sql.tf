# ============================================================================
# Cloud SQL - PostgreSQL
# ============================================================================

resource "google_sql_database_instance" "postgres" {
  name             = "${var.project_nickname}-db-${var.environment}"
  database_version = "POSTGRES_15"
  region           = var.region
  
  deletion_protection = var.environment == "prod"
  
  settings {
    tier = "db-f1-micro"  # Tier pequeño para desarrollo
    
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
    
    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      binary_log_enabled = false
    }
    
    insights_config {
      query_insights_enabled = true
    }
  }
  
  depends_on = [
    google_project_service.apis,
    google_service_networking_connection.private_vpc_connection
  ]
}

resource "google_sql_database" "main" {
  name     = "waste_detection"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "app_user" {
  name     = "app_user"
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}