# =============================================================================
#  database.tf — La base de datos Postgres (Cloud SQL) con IP pública fija.
#
#  Crea:
#    1) La INSTANCIA: el "servidor" de Postgres gestionado por Google.
#    2) El USUARIO con el que la app se conecta.
#
#  Nota sobre la "IP fija": Cloud SQL no usa una IP reservada como la VM. Al
#  habilitar la IP pública (ipv4_enabled), Google le asigna una IP que se
#  mantiene estable durante toda la vida de la instancia: no cambia sola.
# =============================================================================

# 1) La instancia de Postgres.
resource "google_sql_database_instance" "db" {
  name             = "${var.service_name}-db"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = var.db_tier # tamaño de la máquina de la base

    ip_configuration {
      ipv4_enabled = true # le damos IP pública (fija) para conectarnos

      # Quién puede conectarse a la base por IP pública.
      # 0.0.0.0/0 = "desde cualquier lado". Cómodo para el ejemplo; en un caso
      # real conviene restringir a IPs conocidas (ej: la IP de la VM).
      authorized_networks {
        name  = "todos"
        value = "0.0.0.0/0"
      }
    }
  }

  # Para la clase lo dejamos en false, así `destroy` puede borrarla sin trabas.
  # En producción se pone true para evitar borrados accidentales.
  deletion_protection = false

  depends_on = [google_project_service.apis]
}

# 2) El usuario que usa la app para conectarse.
resource "google_sql_user" "app" {
  name     = var.db_user
  instance = google_sql_database_instance.db.name
  password = var.db_password
}
