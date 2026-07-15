# Imagen de la web (servicio "front" del docker-compose).
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# La web escucha en el 8080 dentro del contenedor; el compose lo publica al 80.
ENV PORT=8080
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 main:app
