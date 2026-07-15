# =============================================================================
#  outputs.tf — Datos útiles que Terraform imprime al terminar el `apply`.
#
#  Los outputs son la "salida" del programa: los valores que uno quiere ver o
#  usar después (IPs, nombres, etc.), sin tener que buscarlos en la consola.
# =============================================================================

output "ip_de_la_vm" {
  description = "IP pública fija de la VM (para entrar por SSH o abrir la web)"
  value       = google_compute_address.vm_ip.address
}

output "ip_de_la_base" {
  description = "IP pública de la base Postgres (Cloud SQL)"
  value       = google_sql_database_instance.db.public_ip_address
}

output "comando_ssh" {
  description = "Comando listo para entrar a la VM"
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --zone ${var.zone} --project ${var.project_id}"
}

# ---------------------------------------------------------------------------
#  Secrets de GitHub — LISTOS PARA COPIAR Y PEGAR
#
#  Ya NO hay llave de GCP: el runner vive adentro de la VM. Los únicos secrets
#  son los datos de conexión a la base.
# ---------------------------------------------------------------------------

# Los valores NO secretos: Terraform los imprime al terminar el apply.
# Cada clave es el nombre EXACTO del secret que hay que crear en GitHub.
output "secrets_github" {
  description = "Valores (no sensibles) para pegar como secrets de GitHub"
  value = {
    DB_HOST = google_sql_database_instance.db.public_ip_address
    DB_PORT = "5432"
    DB_NAME = google_sql_database.menu.name
    DB_USER = var.db_user
  }
}

# El único valor SECRETO. Terraform NO lo imprime (aparece como <sensitive>).
#   DB_PASSWORD ->  terraform output -raw db_password
output "db_password" {
  description = "Secret DB_PASSWORD. Verla con: terraform output -raw db_password"
  value       = var.db_password
  sensitive   = true
}
