# ============================================================================
# Variables
# ============================================================================

variable "project_id" {
  description = "ID del proyecto en GCP"
  type        = string
}

variable "region" {
  description = "Región principal de GCP"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "Zona principal de GCP"
  type        = string
  default     = "us-central1-a"
}

variable "environment" {
  description = "Entorno (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_nickname" {
  description = "Apodo del proyecto para recursos"
  type        = string
}

variable "db_password" {
  description = "Contraseña para la base de datos PostgreSQL"
  type        = string
  sensitive   = true
}