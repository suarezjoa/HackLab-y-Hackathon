# =============================================================================
#  versions.tf — Qué versiones usamos y contra qué nube trabajamos.
#
#  Este archivo es el "encabezado" del proyecto Terraform:
#    - Qué versión mínima de Terraform requiere.
#    - Qué proveedor (provider) vamos a usar y su versión. Un proveedor es el
#      "plugin" que sabe hablar con una nube concreta; acá, Google Cloud.
#    - La configuración del proveedor: contra qué proyecto y región trabajamos.
# =============================================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

# Toda la infraestructura se crea en ESTE proyecto y ESTA región de GCP.
provider "google" {
  project = var.project_id
  region  = var.region
}
