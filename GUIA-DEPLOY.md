# 🚀 Guía para conectar el deploy automático

> Guía paso a paso para explicar en el hackaton cómo dejamos el deploy
> automático de la app (menú QR) usando un **agente de GitHub** que vive
> dentro de la VM.

---

## 🧠 La idea en una frase

En vez de que GitHub entre "desde afuera" a la VM por SSH cada vez que queremos
desplegar, **metemos un agente de GitHub adentro de la VM**. Ese agente escucha
a GitHub y, cada vez que alguien hace `git push`, **baja el código ahí mismo,
lo construye con Docker y lo levanta**. Todo automático.

```
ANTES:  push → runner en la nube → SSH a la VM → deploy
AHORA:  push → agente que vive EN la VM → git pull + docker compose → deploy
```

### ¿Qué es un "self-hosted runner"?

Un **runner** es el "trabajador" que ejecuta los pasos de un workflow de GitHub
Actions. Por defecto GitHub te presta uno en la nube (`ubuntu-latest`). Un
**self-hosted runner** es un runner que corremos **nosotros**, en **nuestra
propia máquina** (en este caso, la VM). Es literalmente un programita que se
queda escuchando: "¿hay algo para hacer? ¿hay algo para hacer?" y cuando GitHub
le manda un trabajo, lo ejecuta localmente.

**Ventaja para nosotros:** el runner ya está DENTRO de la VM, así que no
necesita ni `gcloud`, ni SSH, ni copiar archivos por la red. Baja el repo y
corre `docker compose` en el mismo lugar donde vive la app.

---

## 📦 Qué necesitamos tener antes de empezar

- ✅ La infraestructura ya creada con Terraform (`terraform apply` hecho).
- ✅ La VM andando en GCP (`menu-food-truck-vm`).
- ✅ El repositorio en GitHub: `suarezjoa/HackLab-y-Hackathon`.
- ✅ El workflow `.github/workflows/deploy.yml` ya escrito (lo vemos abajo).

### Datos que vamos a usar (todos reales, de nuestro Terraform)

| Dato | Valor |
|---|---|
| Proyecto de GCP | `ryn-gym` |
| Zona | `southamerica-east1-a` |
| Nombre de la VM | `menu-food-truck-vm` |
| IP pública de la VM (la web) | `34.39.130.139` |
| IP de la base (Postgres) | `34.39.199.46` |

---

## 📄 El workflow que hace la magia

Este archivo ya está en `.github/workflows/deploy.yml`. Es la "receta" que el
agente ejecuta con cada push:

```yaml
name: Deploy automatico en la VM

on:
  push:
    branches: [ main ]        # cada push a main despliega solo

jobs:
  deploy:
    runs-on: self-hosted      # corre en el agente que vive EN la VM
    steps:
      - name: Bajar el código en la VM
        uses: actions/checkout@v4

      - name: Generar el .env (valores a la vista, sin secrets)
        run: |
          cat > ejemplo-menu-qr/.env <<'EOF'
          DB_HOST=34.39.199.46
          DB_PORT=5432
          DB_NAME=menu
          DB_USER=menu
          DB_PASS=seguro1234
          EOF

      - name: Construir y levantar
        run: |
          cd ejemplo-menu-qr
          docker compose up -d --build
```

**Cómo leerlo (para explicar):**
- `on: push` → "arrancá cuando alguien haga push a la rama `main`".
- `runs-on: self-hosted` → "esto lo corre NUESTRO agente, no un runner de la nube".
- `actions/checkout` → baja el código del repo dentro de la VM.
- El paso del `.env` → escribe el archivo con los datos de la base. Van **a la
  vista** (sin secrets) para que sea rápido y todos entiendan de dónde sale cada
  valor. ⚠️ Esto es válido para un hackaton con infra descartable; en algo
  productivo, esto iría en GitHub Secrets.
- `docker compose up -d --build` → construye las imágenes y levanta los
  contenedores (`app` + `front`).

---

## ✅ Los pasos, uno por uno

### Paso 1 — Subir el workflow a GitHub

El pipeline todavía está solo en nuestra máquina. Lo subimos:

```bash
git add .github/workflows/deploy.yml
git commit -m "CI: deploy automatico con self-hosted runner"
git push origin main
```

> 💡 **Para explicar:** al hacer este push, GitHub va a intentar correr el
> workflow, pero el job va a quedar **en cola** ("Waiting for a runner") porque
> todavía no existe el agente. Es totalmente normal. Lo creamos en el Paso 3 y
> el trabajo arranca solo.

---

### Paso 2 — Entrar a la VM y prepararla

Nos conectamos a la VM:

```bash
gcloud compute ssh menu-food-truck-vm --zone southamerica-east1-a --project ryn-gym
```

Ya adentro de la VM, instalamos `git` y damos permiso de Docker al usuario:

```bash
sudo apt-get update && sudo apt-get install -y git
sudo usermod -aG docker $USER
exit
```

> 💡 **Para explicar:**
> - El script de arranque de la VM solo instaló Docker y `curl`. Nos faltaba
>   `git`, que es lo que el agente usa para bajar el repo.
> - `usermod -aG docker $USER` sirve para poder usar `docker` **sin `sudo`**.
> - Hacemos `exit` (y volvemos a entrar) porque el permiso de Docker recién
>   toma efecto en una sesión nueva.

Volvemos a entrar:

```bash
gcloud compute ssh menu-food-truck-vm --zone southamerica-east1-a --project ryn-gym
```

---

### Paso 3 — Registrar el agente en GitHub

En el navegador vamos a:

**`https://github.com/suarezjoa/HackLab-y-Hackathon/settings/actions/runners/new`**

Elegimos **Linux / X64**. GitHub nos muestra unos comandos **con un token**.
Los copiamos y los pegamos en la VM. Se ven parecido a esto (⚠️ usar SIEMPRE los
que muestra GitHub, porque el token es único y cambia):

```bash
mkdir actions-runner && cd actions-runner
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/vX.X.X/actions-runner-linux-x64-X.X.X.tar.gz
tar xzf ./actions-runner-linux-x64.tar.gz
./config.sh --url https://github.com/suarezjoa/HackLab-y-Hackathon --token <EL_TOKEN_QUE_DA_GITHUB>
```

Cuando el `config.sh` haga preguntas (nombre del runner, labels, carpeta de
trabajo), le damos **Enter** a todo para dejar los valores por defecto.

> 💡 **Para explicar:** el `token` es como una "invitación" temporal para que
> esta VM se registre como agente de NUESTRO repo. GitHub lo genera solo y dura
> poco, por eso no se escribe en ningún archivo.

---

### Paso 4 — Que el agente arranque solo (como servicio)

Instalamos el agente como servicio para que quede prendido siempre, aunque se
reinicie la VM:

```bash
sudo ./svc.sh install
sudo ./svc.sh start
```

Verificamos en:

**`https://github.com/suarezjoa/HackLab-y-Hackathon/settings/actions/runners`**

que el agente aparezca en **verde (Idle)**.

> 💡 **Para explicar:** "Idle" quiere decir "despierto y esperando trabajo".
> Apenas aparece en verde, el job que quedó en cola en el Paso 1 **arranca
> solo** y hace el primer deploy.

---

### Paso 5 — Probar el deploy automático 🎤

Desde nuestra máquina, hacemos cualquier cambio en el código (por ejemplo, un
texto del `front`) y lo subimos:

```bash
git commit -am "test deploy"
git push
```

Y ahora, la demo:

1. Abrimos la pestaña **Actions** del repo y mostramos cómo el trabajo corre en
   **nuestro self-hosted runner** (no en la nube de GitHub).
2. Cuando termina, abrimos la web en:

   **`http://34.39.130.139`**

   ...y mostramos el cambio ya desplegado. 🎉

---

## 🔁 Resumen del flujo (para la lámina final)

```
1. git push  ──────────────►  GitHub
                                 │
2. GitHub avisa al agente  ──────┘
                                 ▼
3. El agente (dentro de la VM):
     • baja el repo (checkout)
     • escribe el .env
     • docker compose up -d --build
                                 ▼
4. App actualizada en  http://34.39.130.139
```

**En criollo:** hacés `git push` y, sin tocar nada más, la web se actualiza sola.

---

## 🆘 Si algo falla

- **El job queda en cola para siempre** → el agente no está en verde. Revisar
  Paso 3 y 4 (que `svc.sh start` haya corrido bien).
- **Error de permisos con Docker** → faltó `usermod -aG docker $USER` o no
  volviste a entrar a la VM (Paso 2).
- **`git: command not found`** → faltó instalar git en el Paso 2.
- **La web no carga** → revisar que el contenedor `front` esté arriba en la VM:
  `docker compose ps` dentro de `~/actions-runner/_work/.../ejemplo-menu-qr`.
