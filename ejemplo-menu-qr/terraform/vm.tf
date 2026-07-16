# =============================================================================
#  vm.tf — La VM Linux (Compute Engine).
#
#  Crea:
#    1) Una cuenta de servicio propia para la VM (buena práctica: cada máquina
#       con su identidad, en vez de usar la cuenta por defecto del proyecto).
#    2) La VM en sí, con un script de arranque que instala Docker + docker
#       compose y descarga el agente (runner) de GitHub Actions.
#
#  La VM queda lista para que un self-hosted runner de GitHub corra ADENTRO:
#  GitHub ya no entra por SSH desde afuera, así que NO hace falta ninguna llave.
#  Solo queda un paso manual (una vez): registrar el runner con el token que da
#  GitHub. Ver el README.
# =============================================================================

# 1) Identidad de la VM (una cuenta para el "programa", no para una persona).
resource "google_service_account" "vm" {
  account_id   = "${var.service_name}-vm"
  display_name = "Cuenta de la VM del menú"
}

# 2) La VM.
resource "google_compute_instance" "vm" {
  name         = "${var.service_name}-vm"
  machine_type = var.machine_type
  zone         = var.zone

  # Disco de arranque: qué sistema operativo trae de fábrica.
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12" # Debian 12, liviano
    }
  }

  # Interfaz de red: la conectamos a la red "default" y le pegamos la IP fija.
  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_address.vm_ip.address
    }
  }

  # Script que corre UNA sola vez, cuando la VM se crea:
  #   - instala Docker y el plugin de docker compose
  # (El registro del runner queda como paso manual: necesita el token de GitHub.)
  metadata_startup_script = <<-EOT
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y docker.io curl tar
    systemctl enable --now docker

    # Plugin de docker compose (v2)
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
  EOT

  # La VM usa su propia cuenta de servicio.
  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  depends_on = [google_project_service.apis]
}
