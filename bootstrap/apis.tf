resource "google_project_service" "bootstrap_apis" {
  for_each = toset([
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com"
  ])

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}