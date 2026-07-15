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
# ---------------------------------------------------------------------------

# Los 7 valores NO secretos: Terraform los imprime al terminar el apply.
# Cada clave es el nombre EXACTO del secret que hay que crear en GitHub.
output "secrets_github" {
  description = "Valores (no sensibles) para pegar como secrets de GitHub"
  value = {
    GCP_PROJECT_ID = var.project_id
    GCP_ZONE       = var.zone
    VM_NAME        = google_compute_instance.vm.name
    DB_HOST        = google_sql_database_instance.db.public_ip_address
    DB_PORT        = "5432"
    DB_NAME        = google_sql_database.menu.name
    DB_USER        = var.db_user
  }
}

# Los 2 valores SECRETOS. Terraform NO los imprime (aparecen como <sensitive>).
# Se piden a propósito, uno por uno:
#   GCP_SA_KEY  ->  terraform output -raw clave_pipeline
#   DB_PASSWORD ->  terraform output -raw db_password
output "clave_pipeline" {
  description = "Secret GCP_SA_KEY. Extraela con: terraform output -raw clave_pipeline > key.json"
  value       = base64decode(google_service_account_key.cicd.private_key)
  sensitive   = true
}

output "db_password" {
  description = "Secret DB_PASSWORD. Verla con: terraform output -raw db_password"
  value       = var.db_password
  sensitive   = true
}
