# 🍔 Menú QR del food truck — VM con docker-compose + Cloud SQL

Ejemplo completo que **une las dos clases**:

- **Terraform** crea *toda* la infraestructura en la nube.
- **GitHub Actions** (el pipeline) construye las imágenes y actualiza la VM.

> **El problema que resolvemos**
> Un food truck quiere un menú digital: los clientes escanean un QR y ven el
> menú del día en el celular. El dueño edita platos y precios, y hay que montar
> todo en la nube.

---

## La arquitectura

Casi todo vive en **una sola VM**, con `docker-compose` levantando dos
contenedores. La **única** pieza gestionada aparte es la base de datos, en
**Google Cloud SQL**.

```
   [ Celular ]
       │ escanea QR  (http://IP-de-la-VM)
       ▼
 ┌──────────────────────────────────────────────┐        ┌────────────────────┐
 │  VM (Compute Engine)                           │  SQL   │  Cloud SQL          │
 │  ┌───────────┐        ┌───────────┐           │ ─────► │  Postgres           │
 │  │  front    │ ─HTTP─►│    app    │           │        │  (la base)          │
 │  │  (web:80) │        │ (API:8000)│           │        └────────────────────┘
 │  └───────────┘        └───────────┘           │
 │            docker-compose                      │
 └──────────────────────────────────────────────┘
```

- **front** y **app** se hablan por la red interna del compose (`http://app:8000`).
- Solo el **front** se publica al mundo (puerto 80).
- **app** es el único que sale a **Cloud SQL**.

| Pieza | Dónde vive | Qué hace |
|---|---|---|
| **front** | contenedor en la VM | La web que ve el cliente |
| **app** | contenedor en la VM | La API que lee/escribe el menú |
| **Cloud SQL (Postgres)** | servicio gestionado de GCP | Guarda los platos |

---

## Qué hay en cada carpeta

```
<raíz-del-repo>/
├── .github/workflows/
│   └── deploy.yml            → el pipeline (se corre con un botón en Actions)
└── ejemplo-menu-qr/
    ├── docker-compose.yml    → define front + app (corre en la VM)
    ├── front/                → la web (Python + Flask)
    │   └── main.py · templates/ · requirements.txt · Dockerfile
    ├── app/                  → la API (Flask + Postgres)
    │   └── main.py · requirements.txt · Dockerfile
    └── terraform/            → la infraestructura (VM + Postgres), un archivo por tema
        └── versions.tf · variables.tf · apis.tf · network.tf
            vm.tf · database.tf · outputs.tf · README.md
```

> El `deploy.yml` vive en `.github/workflows/` de la **raíz del repo** (GitHub
> solo ejecuta workflows desde ahí, no desde subcarpetas).

---

## Cómo funciona el reparto de tareas

- **Terraform** crea la VM (con Docker + docker compose ya instalados) y la base
  Postgres en Cloud SQL. Nada más: no escribe configuración adentro de la VM.
- **El pipeline** (a mano, desde Actions) arma el `.env` con los datos de la base
  a partir de los **secrets de GitHub**, copia el código a la VM y corre
  `docker compose up -d --build` para construir y levantar todo.

---

## Probarlo local primero (sin tocar GCP)

Antes de subir nada a la nube, podés levantar todo en tu compu con
`docker-compose.local.yml`. Ese archivo **construye las imágenes en el momento**
y usa un **Postgres en contenedor** en lugar de Cloud SQL:

```bash
cd ejemplo-menu-qr
docker compose -f docker-compose.local.yml up --build
```

Abrí **http://localhost:8080** (y `/admin` para editar el menú). La página
**`/qr`** muestra el código QR que apunta a la web: proyectalo y los chicos lo
escanean con el celu. Para frenar y borrar todo (incluida la base local):

```bash
docker compose -f docker-compose.local.yml down -v
```

Es la misma app y el mismo `front`/`app` que van a producción: lo único que
cambia es de dónde sale la base. Ideal para ensayar la demo sin gastar en GCP.

---

## ¿Cómo sé que REALMENTE guardó en la base?

Buena pregunta: la web podría estar mostrándote cualquier cosa. Para estar
seguros, le preguntamos **directamente a Postgres**, salteando la app.

> Nota: los comandos van en **una sola línea**. Si copiás de un tutorial de
> Linux/Mac verás un `\` al final de cada línea (continuación de bash); en
> **PowerShell** eso falla. Dejalos en una línea y listo.

**1) Mirar la tabla con los propios ojos** (con el compose local corriendo):

```bash
docker compose -f docker-compose.local.yml exec db psql -U menu -d menu -c "SELECT * FROM platos;"
```

Vas a ver una fila por cada plato, incluido el que acabás de agregar desde la web.
Este comando **no pasa por la app**: entra a la base y lee la tabla. Si el plato
está acá, está guardado de verdad.

**2) La prueba de fuego — que sobreviva a un reinicio:**

```bash
# agregá un plato desde la web, y después reiniciá:
docker compose -f docker-compose.local.yml restart
# volvé a consultar: el plato sigue ahí, porque está en el volumen, no en la RAM
docker compose -f docker-compose.local.yml exec db psql -U menu -d menu -c "SELECT nombre, precio FROM platos;"
```

Si los datos se perdieran al reiniciar, era que vivían "en el aire". Como
persisten, confirmás que están escritos en la base.

**3) En la nube (Cloud SQL)** es la misma idea, con `gcloud`:

```bash
gcloud sql connect menu-food-truck-db --user=menu --database=menu
# ya adentro del prompt de Postgres:
SELECT * FROM platos;
```

> 💡 Truco para la clase: agregá un plato con un nombre gracioso desde el celular
> de un alumno y mostrá cómo aparece en el `SELECT` en la pantalla. Ahí se entiende
> que el dato viajó celular → front → app → base.

---

## Cómo correrlo en la nube

> Necesitás: cuenta de GCP con facturación activa, y `gcloud`, `terraform` y
> `docker` instalados. Además un repo en GitHub.

### Paso 1 — Terraform crea la infra (VM + Postgres)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # completá project_id y db_password
gcloud auth application-default login

terraform init
terraform plan      # muestra QUÉ va a crear (todavía no crea nada)
terraform apply     # lo crea de verdad
```

Al terminar imprime `ip_de_la_vm`, `ip_de_la_base` y `comando_ssh`.
(Detalle del ciclo plan/apply/destroy en [`terraform/README.md`](terraform/README.md).)

### Paso 2 — Sacar la llave del pipeline

La cuenta de servicio del pipeline, sus permisos y su llave **ya los creó
Terraform** (archivo `cicd.tf`). Solo tenés que extraer la llave:

```bash
terraform output -raw clave_pipeline > key.json
```

Ese `key.json` es el valor del secret `GCP_SA_KEY` (paso siguiente).

> ⚠️ `key.json` es una contraseña: no la subas al repo y borrala al terminar.

### Paso 3 — Cargar TODOS los secrets en GitHub

Terraform te deja los valores listos. Los 7 no-secretos se imprimen al terminar
el `apply` (o corré `terraform output secrets_github`). Los 2 secretos se piden
aparte:

```bash
terraform output secrets_github        # los 7 valores para copiar y pegar
terraform output -raw clave_pipeline    # GCP_SA_KEY
terraform output -raw db_password       # DB_PASSWORD
```

En **Settings → Secrets and variables → Actions → New repository secret**, creá:

| Secret | Valor |
|---|---|
| `GCP_SA_KEY` | Todo el contenido de `key.json` |
| `GCP_PROJECT_ID` | Tu Project ID (ej: `ryn-gym`) |
| `GCP_ZONE` | `southamerica-east1-a` |
| `VM_NAME` | `menu-food-truck-vm` |
| `DB_HOST` | La `ip_de_la_base` que imprimió Terraform |
| `DB_PORT` | `5432` |
| `DB_NAME` | `menu` |
| `DB_USER` | `menu` |
| `DB_PASSWORD` | La misma que pusiste en `terraform.tfvars` |

El pipeline no tiene NADA sensible escrito: todo sale de estos secrets.

### Paso 4 — Desplegar desde el botón

En la pestaña **Actions** → workflow **"Desplegar en la VM"** → botón
**"Run workflow"**. El pipeline se loguea en GCP, arma el `.env` con los secrets,
copia el proyecto a la VM y corre `docker compose up -d --build`.

### Paso 5 — El momento "ohhh"

1. Abrí `http://<ip_de_la_vm>` (o `http://<ip_de_la_vm>/qr` y escaneá el código).
2. Aparece el menú del día (viene de Postgres, vía la API).
3. Entrá a `/admin` o tocá **➕ Agregar producto**, y cargá un plato.
4. Refrescá: el cambio ya está, y quedó guardado en Cloud SQL.

Todo corre en una VM, con la base afuera en Cloud SQL, y el deploy se dispara
con un botón desde GitHub.

---

## Diagnóstico rápido (si algo no anda)

- La web carga pero dice "no pude conectar con la API" → mirá el estado de los
  contenedores en la VM: `sudo docker compose -f /opt/menu/docker-compose.yml ps`.
- ¿La API llega a la base? Desde la VM: `curl http://localhost` (front) y revisá
  los logs: `sudo docker compose -f /opt/menu/docker-compose.yml logs app`.
- La app expone `/salud` (a través de la API) para verificar la conexión a Cloud SQL.

---

## El punto pedagógico

| Concepto de las clases | En este ejemplo |
|---|---|
| Terraform levanta **infraestructura** | `terraform/` crea la VM, Cloud SQL, la red y los permisos |
| Contenedores empaquetan **la app** | `front/Dockerfile` y `app/Dockerfile` |
| **docker-compose** orquesta varios contenedores | `docker-compose.yml` levanta front + app juntos |
| Pipelines **llevan** el código a producción | `.github/workflows/deploy.yml` (botón en Actions) |

---

## Cerrar el círculo (no gastar de más)

```bash
cd terraform
terraform destroy
```
