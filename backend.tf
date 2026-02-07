// backend.tf
terraform {
  backend "gcs" {
    bucket  = "waste-detection-tfstate"
    prefix  = "terraform/state"
  }
}