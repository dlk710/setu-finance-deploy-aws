#!/usr/bin/env bash
#
# Setu Finance - deploy a given environment.
#   ./deploy.sh dev     # uses .env.dev,  project setu-dev
#   ./deploy.sh prod    # uses .env.prod, project setu-prod
#
set -euo pipefail

ENV_NAME="${1:-}"
case "${ENV_NAME}" in
  dev|prod) ;;
  *) echo "usage: $0 <dev|prod>"; exit 1 ;;
esac

cd "$(dirname "$0")"

if [ ! -f ".env.${ENV_NAME}" ]; then
  echo "Missing .env.${ENV_NAME} (copy from .env.${ENV_NAME}.example and fill it in)." >&2
  exit 1
fi

# The active .env is what compose reads for both variable substitution and the
# api container's env_file. We just point it at the chosen environment.
cp ".env.${ENV_NAME}" .env
chmod 600 .env

export COMPOSE_PROJECT_NAME="setu-${ENV_NAME}"
docker compose -f compose.yml up -d --build

echo "Deployed '${ENV_NAME}' (project ${COMPOSE_PROJECT_NAME})."
echo "Site: $(grep -E '^SITE_ADDRESS=' .env | cut -d= -f2-)"
