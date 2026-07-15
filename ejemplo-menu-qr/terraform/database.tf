# =============================================================================
#  database.tf — La base de datos Postgres (Cloud SQL).
#
#  Crea tres cosas:
#    1) La INSTANCIA: el "servidor" de Postgres gestionado por Google.
#    2) La BASE de datos "menu" dentro de esa instancia.
#    3) El USUARIO con el que la app se conecta.
# =============================================================================

# 1) La instancia de Postgres.
resource "google_sql_database_instance" "db" {
  name             = "${var.service_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = var.db_tier # tamaño de la máquina de la base

    ip_configuration {
      ipv4_enabled = true # le damos IP pública para conectarnos

      # Firewall de la base: SOLO dejamos entrar a la IP fija de nuestra VM.
      authorized_networks {
        name  = "vm"
        value = google_compute_address.vm_ip.address
      }
    }
  }

  # Para la clase lo dejamos en false, así `destroy` puede borrarla sin trabas.
  # En producción se pone true para evitar borrados accidentales.
  deletion_protection = false

  depends_on = [google_project_service.apis]
}

# 2) La base de datos dentro de la instancia.
resource "google_sql_database" "menu" {
  name     = "menu"
  instance = google_sql_database_instance.db.name
}

# 3) El usuario que usa la app para conectarse.
resource "google_sql_user" "app" {
  name     = var.db_user
  instance = google_sql_database_instance.db.name
  password = var.db_password
}
