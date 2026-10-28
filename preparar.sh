#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if [ "$(uname -s)" != Darwin ] || [ "$(uname -m)" != arm64 ]; then
  echo "Ejecuta este asistente desde Terminal de macOS en tu Mac con Apple Silicon."
  exit 1
fi
docker info >/dev/null
docker compose version
if [ ! -f .env ]; then
  sed -e "s/^LOCAL_UID=.*/LOCAL_UID=$(id -u)/" \
      -e "s/^LOCAL_GID=.*/LOCAL_GID=$(id -g)/" .env.example > .env
else
  echo "Se conserva tu .env existente; comprueba LOCAL_UID=$(id -u) y LOCAL_GID=$(id -g)."
fi
docker compose --profile spark config -q
docker compose build jupyter
echo "Imagen preparada. Arranca con:"
echo "docker compose --profile spark up -d --wait --wait-timeout 300"
