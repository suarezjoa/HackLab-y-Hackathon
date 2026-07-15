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
ejemplo-menu-qr/
├── docker-compose.yml        → define front + app (corre en la VM)
├── front/                    → la web (Python + Flask)
│   ├── main.py · templates/ · requirements.txt · Dockerfile
├── app/                      → la API (Flask + Postgres)
│   ├── main.py · requirements.txt · Dockerfile
├── terraform/                → TODA la infraestructura
│   ├── main.tf               → VM + Cloud SQL + registro + red + permisos
│   ├── variables.tf · outputs.tf · terraform.tfvars.example
└── .github/workflows/
    └── deploy.yml             → construye imágenes y actualiza la VM
```

---

## Cómo funciona el reparto de tareas

- **Terraform** crea la VM y, en su arranque, deja instalado Docker + compose y
  escribe un archivo `.env` en `/opt/menu/` con los datos de conexión a Cloud
  SQL. Es decir: **la VM ya sabe hablarle a la base** apenas se crea.
- **El pipeline** solo se ocupa de las imágenes: las construye, las publica y en
  la VM hace `docker compose pull && up -d`. **No maneja secretos de la base.**

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

### Paso 1 — Terraform crea toda la infra

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # completá project_id y db_password
gcloud auth application-default login

terraform init
terraform plan      # muestra QUÉ va a crear (todavía no crea nada)
terraform apply     # lo crea de verdad
```

Al terminar imprime:

- `url_de_la_web` → `http://<ip>` (la que va en el QR).
- `ip_de_la_vm` → para entrar por SSH.
- `ip_de_la_base` → la IP de Postgres (ya quedó en el `.env` de la VM).
- `ruta_del_repo` y `email_cuenta_pipeline`.

### Paso 2 — Darle la llave al pipeline

```bash
gcloud iam service-accounts keys create key.json --iam-account=<email_cuenta_pipeline>
```

En GitHub: **Settings → Secrets and variables → Actions → New repository secret**
- Nombre: `GCP_SA_KEY`
- Valor: todo el contenido de `key.json`

> ⚠️ `key.json` es una contraseña: no la subas al repo y borrala al terminar.

### Paso 3 — Ajustar el pipeline y hacer push

En `.github/workflows/deploy.yml`, revisá que `PROJECT_ID`, `REGION`, `ZONE`,
`REPO` y `VM` coincidan con tu Terraform. Después:

```bash
git add .
git commit -m "Primer deploy del menú"
git push
```

En la pestaña **Actions** vas a ver el pipeline: construye el front y la app,
los sube al registro, copia el compose a la VM y levanta todo.

### Paso 4 — El momento "ohhh"

1. Abrí la `url_de_la_web` (o entrá a `<url_de_la_web>/qr` y escaneá el código).
2. Aparece el menú del día (viene de Postgres, vía la API).
3. Entrá a `<url_de_la_web>/admin`, cambiá un precio o agregá un plato.
4. Refrescá el menú: el cambio ya está.

Todo corre en una VM, con la base afuera en Cloud SQL, y cada cambio de código
se publica solo con un `git push`.

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
| Terraform levanta **infraestructura** | `terraform/` crea la VM, Cloud SQL, el registro, la red y los permisos |
| Contenedores empaquetan **la app** | `front/Dockerfile` y `app/Dockerfile` |
| **docker-compose** orquesta varios contenedores | `docker-compose.yml` levanta front + app juntos |
| Pipelines **llevan** el código a producción | `.github/workflows/deploy.yml` |

---

## Cerrar el círculo (no gastar de más)

```bash
cd terraform
terraform destroy
```
