variable "project_id" {
  type        = string
  description = "GCP project ID where the state bucket will be created."
}

variable "region" {
  type        = string
  description = "GCS bucket location/region. Example: us-central1"
}

variable "bucket_name" {
  type        = string
  description = "Name of the GCS bucket to store Terraform state."
}

variable "github_owner" {
  type        = string
  description = "GitHub username or organization that owns the repos."
}