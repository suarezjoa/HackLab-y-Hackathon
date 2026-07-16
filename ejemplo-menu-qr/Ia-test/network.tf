# =============================================================================
#  network.tf — La red: una IP pública FIJA para la VM y las reglas de firewall.
# =============================================================================

# IP pública FIJA (reservada) para la VM.
# Sin esto, GCP le da una IP efímera que puede cambiar al reiniciar. Con una IP
# reservada, siempre entramos por la misma dirección.
resource "google_compute_address" "vm_ip" {
  name   = "${var.service_name}-ip"
  region = var.region

  # No la creamos hasta que la API de Compute esté encendida.
  depends_on = [google_project_service.apis]
}

# Firewall: por defecto GCP bloquea casi todo. Acá abrimos los puertos pedidos:
#   - 22 (SSH)  -> para entrar a la VM por consola
#   - 80 (HTTP) -> para ver la web desde el navegador
resource "google_compute_firewall" "web" {
  name    = "${var.service_name}-permitir-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "80"]
  }

  # 0.0.0.0/0 = "desde cualquier lado". Cómodo para el ejemplo; en un caso real
  # conviene restringir a IPs conocidas.
  source_ranges = ["0.0.0.0/0"]

  depends_on = [google_project_service.apis]
}
