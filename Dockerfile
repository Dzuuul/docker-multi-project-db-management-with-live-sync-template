# Menggunakan versi terbaru yang stabil (bisa diganti ke versi spesifik seperti 16-alpine)
FROM postgres:latest

# Set label untuk identitas image
LABEL maintainer="Fikri Maulana"
LABEL version="1.0"
LABEL description="Reusable Postgres Image with init scripts"

# Postgres menggunakan port 5432 secara default
EXPOSE 5432
