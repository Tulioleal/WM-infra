# 🏗️ Waste Detection Infrastructure

Infraestructura como código (IaC) con **OpenTofu/Terraform** para el sistema distribuido de detección de desechos. Provisiona todos los recursos en **Google Cloud Platform** que consumen los repositorios de [Inference API](#) y [Training Job](#).

## Recursos provisionados

```
┌─────────────────────────────────────────────────────────────┐
│                        GCP Project                          │
│                                                             │
│  ┌─── VPC ────────────────────────────────────────────┐     │
│  │                                                    │     │
│  │  ┌──────────────┐    ┌──────────────────────────┐  │     │
│  │  │  Cloud SQL   │    │  GKE Cluster             │  │     │
│  │  │  PostgreSQL  │◄───│  ├─ system-pool (CPU)    │  │     │
│  │  │  (privado)   │    │  ├─ inference-pool (CPU) │  │     │
│  │  └──────────────┘    │  └─ [training via Job]   │  │     │
│  │                      └──────────────────────────┘  │     │
│  │                                                    │     │
│  │  Cloud NAT ──► Internet                            │     │
│  └────────────────────────────────────────────────────┘     │
│                                                             │
│  ┌──────────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  GCS: Modelos    │  │  GCS: Images │  │  Artifact    │  │
│  │  (versionado)    │  │  (lifecycle) │  │  Registry    │  │
│  └──────────────────┘  └──────────────┘  └──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Estructura del proyecto

```
├── main.tf                    # Providers, APIs habilitadas
├── backend.tf                 # Backend remoto en GCS
├── variables.tf               # Definición de variables
├── terraform.tfvars.example   # Ejemplo de valores (sin secretos)
├── vpc.tf                     # VPC, subnet, Cloud NAT, firewall, Private Service Connection
├── gke.tf                     # Cluster GKE + node pools (system, inference)
├── sql.tf                     # Cloud SQL PostgreSQL (privado)
├── gcs.tf                     # Buckets para modelos e imágenes
├── artifact.tf                # Artifact Registry para imágenes Docker
├── iam.tf                     # Service accounts, Workload Identity, roles
├── k8s.tf                     # Recursos de Kubernetes (namespace, ConfigMap, Secret, SA)
├── outputs.tf                 # Outputs del módulo
│
├── bootstrap/                 # Configuración inicial (ejecutar una sola vez)
│   ├── main.tf                # Provider
│   ├── variables.tf           # Variables del bootstrap
│   ├── terraform.tfvars       # Valores (sin secretos)
│   ├── state.tf               # Bucket GCS para Terraform state
│   ├── apis.tf                # APIs base (IAM, STS, Resource Manager)
│   ├── service_accounts.tf    # SAs para CI/CD (ci-infra, ci-app)
│   ├── wif.tf                 # Workload Identity Federation (GitHub Actions)
│   └── output.tf              # Outputs
│
└── scripts/
    └── upload_model.sh        # Script para subir modelo inicial a GCS
```

## Componentes principales

### Red (vpc.tf)

VPC custom con una subnet y dos rangos secundarios para pods y services de GKE. Incluye Cloud NAT para salida a internet desde nodos privados y Private Service Connection para que Cloud SQL sea accesible solo por IP privada.

### GKE (gke.tf)

Cluster zonal con Workload Identity habilitado y dos node pools:

| Pool | Máquina | Preemptible | Autoscaling | Propósito |
|------|---------|-------------|-------------|-----------|
| `system-pool` | `e2-small` | No | 1–3 | DNS, kube-system, componentes |
| `inference-pool` | `e2-standard-4` | Sí | 1–10 | Pods de la Inference API |

El inference pool usa **taints** (`workload=inference:NoSchedule`) para que solo los pods con el toleration correspondiente se programen ahí.

### Base de datos (sql.tf)

Cloud SQL PostgreSQL 15 con IP privada, backups automáticos y Query Insights habilitado. Tier `db-f1-micro` para desarrollo.

### Almacenamiento (gcs.tf)

| Bucket | Uso | Políticas |
|--------|-----|-----------|
| Modelos | Pesos `.pt` y metadata de cada versión | Versionado habilitado, retiene últimas 5 versiones |
| Imágenes | Imágenes de inferencia + anotaciones YOLO | Lifecycle: eliminación automática tras 120 días |

### IAM (iam.tf)

Dos service accounts con principio de mínimo privilegio:

- **App SA**: usado por los pods vía Workload Identity. Tiene `storage.objectAdmin` sobre los buckets de modelos e imágenes.
- **GKE Nodes SA**: reemplaza la SA default de Compute Engine. Solo tiene permisos de lectura de Artifact Registry, escritura de logs y métricas.

### Recursos de Kubernetes (k8s.tf)

Terraform crea los recursos base que los repos de aplicación consumen:

- **Namespace** para aislar la carga de trabajo
- **ConfigMap** `infra-config` con nombres de buckets GCS
- **Secret** `db-credentials` con la connection string de PostgreSQL
- **ServiceAccount** de Kubernetes anotado para Workload Identity

---

## Bootstrap

La carpeta `bootstrap/` contiene la configuración inicial que se ejecuta **una sola vez** antes del resto de la infraestructura. Crea los pre-requisitos que el root module necesita para funcionar.

### Qué provisiona

```
bootstrap/
├── Bucket GCS para Terraform remote state (versionado)
├── Workload Identity Federation (pool + OIDC provider para GitHub Actions)
├── Service Account: ci-infra (para el pipeline de este repo)
├── Service Account: ci-app (para pipelines de inference-api, frontend, training)
└── APIs base: IAM, STS, Resource Manager
```

### Service Accounts de CI/CD

| SA | Repos | Roles |
|----|-------|-------|
| `ci-infra` | WM-infra | `editor`, `container.admin`, `projectIamAdmin`, `serviceUsageAdmin`, `serviceAccountAdmin`, `networksAdmin` |
| `ci-app` | WM-inference-api, WM-frontend, WM-training | `artifactregistry.writer`, `container.developer`, `container.clusterViewer`, `storage.objectAdmin` |

### Workload Identity Federation

Un solo pool con un provider OIDC de GitHub Actions. Cada repo se autentica con el token OIDC que GitHub genera automáticamente — no se usan llaves JSON de service account. La condición de atributo restringe el acceso al owner del repositorio configurado.

### Variables del bootstrap

| Variable | Descripción |
|----------|-------------|
| `project_id` | ID del proyecto en GCP |
| `region` | Región de GCP |
| `bucket_name` | Nombre del bucket para Terraform state |
| `github_owner` | Usuario u organización de GitHub |
| `github_app_repos` | Lista de repos que usan la SA `ci-app` |

### Ejecución

```bash
cd bootstrap/
terraform init
terraform apply
```

> Después de crear el bucket de state, la infraestructura principal puede inicializarse con `terraform init` usando el backend remoto.

---

## Script: upload_model.sh

Script utilitario para subir manualmente un modelo pre-entrenado a GCS (útil para el primer despliegue antes de que exista un training job).

```bash
# Subir como "latest"
./scripts/upload_model.sh ./best.pt

# Subir como versión específica (también actualiza latest)
./scripts/upload_model.sh ./best.pt v1_inicial
```

Sube el archivo `.pt` y un `metadata.json` al bucket de modelos, y luego copia a `models/latest/` para que la Inference API lo cargue automáticamente.

## Variables

| Variable | Descripción | Default |
|----------|-------------|---------|
| `project_id` | ID del proyecto en GCP | *requerido* |
| `region` | Región de GCP | `us-central1` |
| `zone` | Zona de GCP | `us-central1-a` |
| `environment` | Entorno (`dev`, `staging`, `prod`) | `dev` |
| `project_nickname` | Nombre corto para nombrar recursos | *requerido* |
| `db_password` | Contraseña de PostgreSQL | *requerido, sensible* |

## Uso

### Requisitos previos

- Terraform/OpenTofu >= 1.0
- `gcloud` autenticado con permisos de Owner o Editor

### Primer despliegue

```bash
# 1. Bootstrap (una sola vez)
cd bootstrap/
terraform init && terraform apply
cd ..

# 2. Infraestructura principal
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con tus valores

terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars

# 3. (Opcional) Subir modelo inicial
./scripts/upload_model.sh ./best.pt v1_inicial
```

### Conectarse al cluster

```bash
gcloud container clusters get-credentials <CLUSTER_NAME> --zone <ZONE> --project <PROJECT_ID>
```

## Outputs

| Output | Descripción |
|--------|-------------|
| `cluster_name` | Nombre del cluster GKE |
| `cluster_endpoint` | Endpoint del cluster (sensible) |
| `models_bucket` | Nombre del bucket de modelos |
| `images_bucket` | Nombre del bucket de imágenes |
| `database_connection` | Nombre de conexión de Cloud SQL |
| `database_private_ip` | IP privada de Cloud SQL |
| `artifact_registry` | URL del Artifact Registry |
| `service_account_email` | Email de la SA de la aplicación |

## Seguridad

- Cloud SQL solo accesible por IP privada dentro de la VPC (sin IP pública)
- Workload Identity (GKE) en lugar de llaves JSON para los pods
- Workload Identity Federation (GitHub Actions) en lugar de llaves JSON para CI/CD
- Service account de nodos GKE con roles mínimos (no usa la SA default de Compute)
- SAs de CI/CD separadas: `ci-infra` (permisos amplios) vs `ci-app` (solo deploy + registry)
- Secretos de DB inyectados como Kubernetes Secrets, no hardcodeados en manifests de aplicación
- `db_password` marcada como `sensitive` en Terraform

> **Nota**: Asegurate de que `terraform.tfvars` y cualquier archivo con secretos estén en `.gitignore`.

## Stack

- **OpenTofu/Terraform** ~> 1.0 con providers `google` y `google-beta` ~> 5.0
- **Google Cloud Platform**: VPC, GKE, Cloud SQL, GCS, Artifact Registry, Cloud NAT, IAM
- **Kubernetes provider**: para crear namespace, ConfigMap, Secret y ServiceAccount desde Terraform