#!/usr/bin/env bash
#
# Setu Finance - restore Postgres from an S3 backup.
#
#   ./restore.sh                 restore the most recent backup
#   ./restore.sh <filename>      restore a specific backup
#   ./restore.sh --list          list available backups and exit
#   ./restore.sh -y [file]       skip the confirmation prompt
#
set -euo pipefail

BUCKET="setu-finance-backups"
ENV_LABEL="${ENV_LABEL:-prod}"     # which env's backups: prod (default) or dev
PREFIX="backups/${ENV_LABEL}"
PG_CONTAINER="setu-postgres"
API_CONTAINER="setu-api"
DB_NAME="setu_portal"
DB_USER="setu"

ASSUME_YES="false"
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --list)
      aws s3 ls "s3://${BUCKET}/${PREFIX}/" | sort
      exit 0 ;;
    -y|--yes) ASSUME_YES="true" ;;
    *) TARGET="$arg" ;;
  esac
done

# Resolve which object to restore.
if [ -z "${TARGET}" ]; then
  TARGET="$(aws s3 ls "s3://${BUCKET}/${PREFIX}/" | sort | tail -1 | awk '{print $4}')"
  if [ -z "${TARGET}" ]; then
    echo "No backups found in s3://${BUCKET}/${PREFIX}/" >&2
    exit 1
  fi
fi

echo "About to restore: s3://${BUCKET}/${PREFIX}/${TARGET}"
echo "This REPLACES the current '${DB_NAME}' database."
if [ "${ASSUME_YES}" != "true" ]; then
  read -r -p "Type 'yes' to continue: " reply
  [ "${reply}" = "yes" ] || { echo "Aborted."; exit 1; }
fi

# Stop the API so nothing writes mid-restore (ignore if not running).
docker stop "${API_CONTAINER}" >/dev/null 2>&1 || true

# Recreate an empty database (connect via the 'postgres' maintenance DB).
docker exec -i "${PG_CONTAINER}" psql -U "${DB_USER}" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS ${DB_NAME} WITH (FORCE);" \
  -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"

# Stream the dump straight from S3 into psql.
aws s3 cp "s3://${BUCKET}/${PREFIX}/${TARGET}" - \
  | gunzip \
  | docker exec -i "${PG_CONTAINER}" psql -U "${DB_USER}" -d "${DB_NAME}" -v ON_ERROR_STOP=1

# Bring the API back.
docker start "${API_CONTAINER}" >/dev/null 2>&1 || true

echo "Restore complete from ${TARGET}"
