# ============================================================================
# Google Kubernetes Engine (GKE) Cluster
# ============================================================================

resource "google_container_cluster" "primary" {
  name     = "${var.project_nickname}-cluster-${var.environment}"
  location = var.zone

  deletion_protection = false
  
  # Usamos un pool de nodos separado
  remove_default_node_pool = true
  initial_node_count       = 1
  
  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }
  
  # Configuración de workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
  
  # Logging y monitoring
  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }
  
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = true
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = "2025-01-01T06:00:00Z"  # 3 AM hora Argentina (UTC-3)
      end_time   = "2025-01-01T10:00:00Z"  # 7 AM hora Argentina
      recurrence = "FREQ=WEEKLY;BYDAY=TU,TH,SA,SU"
    }
}
  
  depends_on = [google_project_service.apis, google_container_cluster.primary]
}

# ============================================================================
# Node Pool para la API de Inferencia (CPU)
# ============================================================================

resource "google_container_node_pool" "inference_pool" {
  name       = "inference-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  
  initial_node_count = 1
  
  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }
  
  node_config {
    spot         = true  # Ideal para modelos rápidos de procesar
    service_account = google_service_account.gke_nodes.email
    machine_type = "e2-standard-2" # 2 vCPU y 8GB es balanceado y más barato
    disk_size_gb = 50
    disk_type    = "pd-balanced" #meojr velocidad de inicio del nodo
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    labels = {
      workload = "inference"
      env      = var.environment
    }
    
    taint {
      key    = "workload"
      value  = "inference"
      effect = "NO_SCHEDULE"
    }
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}

resource "google_container_node_pool" "system_pool" {
  name       = "system-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name

  initial_node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    preemptible  = false # No queremos que los nodos del sistema sean preemptibles
    machine_type = "e2-small"  # Barato, solo para DNS y sistema
    disk_size_gb = 20
    service_account = google_service_account.gke_nodes.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      workload = "system"
      env      = var.environment
    }

    # Sin taints — cualquier pod puede correr acá

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }
}