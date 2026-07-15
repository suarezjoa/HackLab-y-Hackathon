"""
front — la web del menú. Corre como contenedor dentro de la VM (docker-compose).

Es SOLO la cara visible. No tiene base de datos: le pide todo a la API (el
servicio "app" del mismo compose) por HTTP. Como comparten la red interna del
compose, la dirección de la API es simplemente http://app:8000.
"""

import io
import os

import qrcode
import qrcode.image.svg
import requests
from flask import Flask, redirect, render_template, request, url_for

app = Flask(__name__)

# Dirección de la API. Por defecto apunta al servicio "app" del compose.
API_URL = os.environ.get("API_URL", "http://app:8000").rstrip("/")
TIMEOUT = 4


@app.route("/")
def menu_publico():
    try:
        platos = requests.get(f"{API_URL}/platos", timeout=TIMEOUT).json()
        platos = [p for p in platos if p.get("disponible")]
        return render_template("menu.html", platos=platos, error=None)
    except Exception:  # noqa: BLE001
        return render_template("menu.html", platos=[], error=API_URL)


@app.route("/agregar", methods=["POST"])
def agregar_menu():
    """Agrega un producto (nombre + precio) desde el menú y vuelve al menú.
    El dato viaja a la API, que lo guarda en Postgres."""
    requests.post(
        f"{API_URL}/platos",
        json={
            "nombre": request.form.get("nombre", ""),
            "precio": request.form.get("precio", 0),
        },
        timeout=TIMEOUT,
    )
    return redirect(url_for("menu_publico"))


@app.route("/qr")
def qr():
    """Muestra el código QR que apunta a esta misma web (para proyectar)."""
    url = request.host_url  # ej: http://localhost:8080/  o  http://<ip-de-la-vm>/
    img = qrcode.make(url, image_factory=qrcode.image.svg.SvgPathImage)
    buf = io.BytesIO()
    img.save(buf)
    svg = buf.getvalue().decode("utf-8")
    return render_template("qr.html", svg=svg, url=url)


@app.route("/admin")
def admin():
    try:
        platos = requests.get(f"{API_URL}/platos", timeout=TIMEOUT).json()
        return render_template("admin.html", platos=platos, error=None)
    except Exception:  # noqa: BLE001
        return render_template("admin.html", platos=[], error=API_URL)


@app.route("/admin/agregar", methods=["POST"])
def agregar():
    requests.post(
        f"{API_URL}/platos",
        json={
            "nombre": request.form.get("nombre", ""),
            "precio": request.form.get("precio", 0),
        },
        timeout=TIMEOUT,
    )
    return redirect(url_for("admin"))


@app.route("/admin/estado/<int:plato_id>", methods=["POST"])
def cambiar_estado(plato_id):
    requests.post(f"{API_URL}/platos/{plato_id}/estado", timeout=TIMEOUT)
    return redirect(url_for("admin"))


@app.route("/admin/borrar/<int:plato_id>", methods=["POST"])
def borrar(plato_id):
    requests.post(f"{API_URL}/platos/{plato_id}/borrar", timeout=TIMEOUT)
    return redirect(url_for("admin"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
