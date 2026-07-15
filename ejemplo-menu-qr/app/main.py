"""
app — la API del menú. Corre como contenedor dentro de la VM (docker-compose).

Su única tarea: leer y escribir los platos en la base de datos Postgres, que
NO está en la VM sino en Google Cloud SQL. Devuelve todo en JSON. El front le
pega a esta API por la red interna del compose (http://app:8000).

Los datos de conexión a la base llegan por variables de entorno:
    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASS
"""

import os

import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request

app = Flask(__name__)


def conectar():
    """Abre una conexión a Postgres (Cloud SQL) con los datos del entorno."""
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=os.environ.get("DB_PORT", "5432"),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASS"],
        connect_timeout=5,
    )


def preparar_base():
    """Crea la tabla si no existe y carga platos de ejemplo la primera vez."""
    with conectar() as conn, conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS platos (
                id SERIAL PRIMARY KEY,
                nombre TEXT NOT NULL,
                precio INTEGER NOT NULL DEFAULT 0,
                disponible BOOLEAN NOT NULL DEFAULT TRUE
            )
            """
        )
        cur.execute("SELECT COUNT(*) FROM platos")
        if cur.fetchone()[0] == 0:
            cur.executemany(
                "INSERT INTO platos (nombre, precio) VALUES (%s, %s)",
                [
                    ("Hamburguesa clásica", 4500),
                    ("Papas con cheddar", 3000),
                    ("Limonada de menta", 1800),
                ],
            )
        conn.commit()


@app.route("/salud")
def salud():
    """Chequeo simple para saber si la API está viva y llega a la base."""
    try:
        with conectar() as conn, conn.cursor() as cur:
            cur.execute("SELECT 1")
        return jsonify(estado="ok", base="conectada")
    except Exception as e:  # noqa: BLE001
        return jsonify(estado="error", detalle=str(e)), 500


@app.route("/platos", methods=["GET"])
def listar():
    with conectar() as conn, conn.cursor(
        cursor_factory=psycopg2.extras.RealDictCursor
    ) as cur:
        cur.execute("SELECT id, nombre, precio, disponible FROM platos ORDER BY nombre")
        return jsonify(cur.fetchall())


@app.route("/platos", methods=["POST"])
def crear():
    datos = request.get_json(force=True, silent=True) or {}
    nombre = (datos.get("nombre") or "").strip()
    precio = int(datos.get("precio") or 0)
    if not nombre:
        return jsonify(error="falta el nombre"), 400
    with conectar() as conn, conn.cursor() as cur:
        cur.execute(
            "INSERT INTO platos (nombre, precio) VALUES (%s, %s) RETURNING id",
            (nombre, precio),
        )
        nuevo_id = cur.fetchone()[0]
        conn.commit()
    return jsonify(id=nuevo_id), 201


@app.route("/platos/<int:plato_id>/estado", methods=["POST"])
def cambiar_estado(plato_id):
    with conectar() as conn, conn.cursor() as cur:
        cur.execute(
            "UPDATE platos SET disponible = NOT disponible WHERE id = %s", (plato_id,)
        )
        conn.commit()
    return jsonify(ok=True)


@app.route("/platos/<int:plato_id>/borrar", methods=["POST"])
def borrar(plato_id):
    with conectar() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM platos WHERE id = %s", (plato_id,))
        conn.commit()
    return jsonify(ok=True)


# Preparamos la base al arrancar (si la conexión falla, la API igual levanta
# y /salud devuelve el error; útil para diagnosticar en clase).
try:
    preparar_base()
except Exception as e:  # noqa: BLE001
    print(f"[aviso] no pude preparar la base todavía: {e}")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
