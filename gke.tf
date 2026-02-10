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
  
  initial_node_count = 2
  
  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }
  
  node_config {
    preemptible  = true  # Usar máquinas preemptibles para reducir costos
    service_account = google_service_account.gke_nodes.email
    machine_type = "e2-standard-4"  # 4 vCPU, 16 GB RAM
    disk_size_gb = 50
    disk_type    = "pd-standard"
    
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

# ============================================================================
# Node Pool para Entrenamiento (GPU - Opcional)
# ============================================================================

resource "google_container_node_pool" "training_pool" {
  name       = "training-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  initial_node_count = 0  # Escala desde 0
  
  autoscaling {
    min_node_count = 0
    max_node_count = 2
  }
  
  node_config {
    preemptible  = false // esto deberia ser true para reducir costos, pero las GPU preemptibles pueden ser inestables para entrenamiento, para efectos practicos lo dejamos en false
    service_account = google_service_account.gke_nodes.email
    // cambiar a n1-standard-4 y tesla t4 para entrenamiento pero hay poca disponibilidad, por eso usamos e2-standard-4s
    machine_type = "g2-standard-4"  # 4 vCPU, 15 GB RAM
    disk_size_gb = 100
    disk_type    = "pd-ssd"
    
    # GPU Tesla T4 para entrenamiento
    guest_accelerator {
      type  = "nvidia-l4"
      count = 1
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }
    
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    labels = {
      workload = "training"
      env      = var.environment
    }
    
    taint {
      key    = "workload"
      value  = "training"
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