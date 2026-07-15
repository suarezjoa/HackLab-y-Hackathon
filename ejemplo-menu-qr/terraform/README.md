# 🏗️ Terraform — Levantar una VM + Postgres, y borrarlas

Este directorio arma con **Infraestructura como Código** dos servicios de GCP:

- una **VM** Linux (Compute Engine), y
- una instancia **Postgres** (Cloud SQL).

La gracia de Terraform: lo describimos en archivos de texto, y con **un comando**
se crea todo… y con otro se borra todo. Vamos a verlo con el ciclo clásico:
**plan → apply → destroy**.

---

## Los archivos (uno por tema)

| Archivo | Qué define |
|---|---|
| `versions.tf` | Versión de Terraform y del proveedor de Google |
| `variables.tf` | Los datos que cambian (proyecto, región, contraseña…) |
| `apis.tf` | Enciende las APIs de GCP (Compute y Cloud SQL) |
| `network.tf` | La IP fija de la VM + las reglas de firewall |
| `vm.tf` | La VM (con Docker + el agente de GitHub) y su cuenta de servicio |
| `database.tf` | La instancia Postgres, la base y el usuario |
| `outputs.tf` | Los datos que imprime al terminar (IPs, comando SSH) |

> Terraform lee **todos** los `.tf` de la carpeta como un solo programa. Separarlos
> es solo para que se entienda mejor; el resultado es el mismo.

---

## Antes de empezar (una sola vez)

```bash
# 1) Completar tus datos
cp terraform.tfvars.example terraform.tfvars   # editá project_id y db_password

# 2) Loguearte para que Terraform pueda crear recursos en tu cuenta
gcloud auth application-default login

# 3) Descargar el proveedor de Google
terraform init
```

---

## Paso 1 — `plan`: la vista previa (no crea nada)

```bash
terraform plan
```

Terraform te muestra **qué va a hacer, sin hacerlo todavía**. Cada recurso a
crear aparece con un `+` verde. Vas a ver, entre otros, la VM:

```text
  # google_compute_instance.vm will be created
  + resource "google_compute_instance" "vm" {
      + machine_type = "e2-small"
      + name         = "menu-food-truck-vm"
      + zone         = "southamerica-east1-a"
      ...
    }

  # google_sql_database_instance.db will be created
  + resource "google_sql_database_instance" "db" {
      + database_version = "POSTGRES_15"
      + name             = "menu-food-truck-db"
      ...
    }

Plan: 9 to add, 0 to change, 0 to destroy.
```

👉 El mensaje clave es la última línea: **"Plan: 9 to add"**. Todavía no existe nada.
(El número exacto puede variar un poco según la versión del proveedor.)

---

## Paso 2 — `apply`: crearlo de verdad

```bash
terraform apply
```

Muestra el mismo plan y pide confirmación. Escribís `yes` y Terraform crea todo.
Al terminar imprime los **outputs**:

```text
Apply complete! Resources: 9 added, 0 changed, 0 destroyed.

Outputs:

ip_de_la_vm   = "34.xx.xx.xx"
ip_de_la_base = "35.xx.xx.xx"
comando_ssh   = "gcloud compute ssh menu-food-truck-vm --zone ..."
```

Podés verificar en la consola de GCP que la VM y la base **están ahí**. O entrar
a la VM con el `comando_ssh` que te dio.

---

## Paso 3 — `destroy`: borrar todo

```bash
terraform destroy
```

Muestra todo lo que va a borrar (cada recurso con un `-` rojo) y pide `yes`.
Al confirmar, la VM y la base **desaparecen**.

```text
Plan: 0 to add, 0 to change, 9 to destroy.
...
Destroy complete! Resources: 9 destroyed.
```

> 💡 Esta es la idea fuerza de la clase: **lo levanto y lo borro con un comando**.
> Nada de hacer 40 clics en la consola, ni de olvidarse algo prendido gastando plata.

---

## Resumen del ciclo

```text
  terraform plan     ->  ¿qué va a pasar?   (no toca nada)
  terraform apply    ->  hacelo             (crea la VM + Postgres)
  terraform destroy  ->  borralo            (no queda nada)
```
