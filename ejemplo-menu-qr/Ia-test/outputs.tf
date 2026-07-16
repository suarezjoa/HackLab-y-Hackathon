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
