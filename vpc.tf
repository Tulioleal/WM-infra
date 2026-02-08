# ============================================================================
# VPC Network
# ============================================================================

resource "google_compute_network" "vpc" {
  name                    = "${var.project_nickname}-vpc-${var.environment}"
  auto_create_subnetworks = false
  
  depends_on = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_nickname}-subnet-${var.environment}"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
  
  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = "10.1.0.0/16"
  }
  
  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = "10.2.0.0/20"
  }
}

# ============================================================================
# Cloud NAT para acceso a internet desde nodos privados
# ============================================================================

resource "google_compute_router" "router" {
  name    = "${var.project_nickname}-router-${var.environment}"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.project_nickname}-nat-${var.environment}"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

# ============================================================================
# Private Service Connection para Cloud SQL
# ============================================================================

resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.project_nickname}-private-ip-${var.environment}"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id

  depends_on = [google_project_service.apis]
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  update_on_creation_fail = true

  lifecycle {
    prevent_destroy = false
  }

  timeouts {
    update = "20m"
    delete = "20m"
  }

  depends_on = [google_project_service.apis]
}

# ============================================================================
# Firewall - Comunicación del Control Plane a los Nodos
# ============================================================================

resource "google_compute_firewall" "gke_master_to_nodes" {
  name    = "${var.project_nickname}-gke-master-to-nodes-${var.environment}"
  network = google_compute_network.vpc.name

  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }

  # Rangos del control plane de GKE público (Google Front End + health checks)
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
    "209.85.152.0/22",
    "209.85.204.0/22",
    "35.184.76.126/32"    # Control plane de tu cluster
  ]

  target_tags = ["gke-waste-detection-cluster-dev-12e86875-node"]

  description = "Permite comunicación del control plane GKE a los nodos"
}