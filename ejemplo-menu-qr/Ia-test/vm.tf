# =============================================================================
#  vm.tf — La VM Linux (Compute Engine) con Ubuntu.
#
#  Crea una VM con:
#    - Ubuntu 22.04 LTS como sistema operativo.
#    - 1 vCPU y 1 GB de RAM (machine_type = custom-1-1024).
#    - La IP pública FIJA que reservamos en network.tf.
# =============================================================================

resource "google_compute_instance" "vm" {
  name         = "${var.service_name}-vm"
  machine_type = var.machine_type
  zone         = var.zone

  # Disco de arranque: qué sistema operativo trae de fábrica.
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts" # Ubuntu 22.04 LTS
    }
  }

  # Interfaz de red: la conectamos a la red "default" y le pegamos la IP fija.
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.vm_ip.address # IP pública fija
    }
  }

  depends_on = [google_project_service.apis]
}
