# ============================================================================
# Terraform - Sistema Distribuido de Detección y Clasificación de Desechos
# Infraestructura en Google Cloud Platform (GCP)
# ============================================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

# ============================================================================
# Provider Configuration
# ============================================================================

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# ============================================================================
# Habilitar APIs necesarias
# ============================================================================

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "sqladmin.googleapis.com",
    "storage.googleapis.com",
    "servicenetworking.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "aiplatform.googleapis.com"
  ])
  
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}