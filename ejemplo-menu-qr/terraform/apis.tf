# =============================================================================
#  apis.tf — Encender los servicios de GCP que vamos a usar.
#
#  En GCP, antes de poder crear recursos de un servicio, hay que "habilitar"
#  su API en el proyecto (como activar una función en una app). Acá encendemos
#  las dos que necesita este ejemplo:
#    - Compute Engine  -> para la VM
#    - Cloud SQL Admin -> para la base Postgres
#
#  `for_each` recorre la lista y crea un recurso por cada API, sin repetir código.
# =============================================================================

resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",  # Compute Engine (la VM)
    "sqladmin.googleapis.com", # Cloud SQL (la base Postgres)
  ])

  service = each.value

  # Si hacemos `destroy`, NO apagamos la API (podría estar en uso por otras cosas).
  disable_on_destroy = false
}
