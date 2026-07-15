# Imagen de la API (servicio "app" del docker-compose).
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# La API escucha en el 8000. No se publica al host: solo la ve el front por
# la red interna del compose.
EXPOSE 8000
CMD ["gunicorn", "--bind", ":8000", "--workers", "1", "--threads", "8", "main:app"]
