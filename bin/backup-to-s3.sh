#!/usr/bin/env bash
#
# Setu Finance - 2-hourly Postgres backup to S3 (Standard storage).
# Retention is handled by the S3 lifecycle rule (expire after 30 days).
#
set -euo pipefail

BUCKET="setu-finance-backups"      # <-- your S3 bucket name (no s3:// prefix)
ENV_LABEL="${1:-prod}"             # backups/<env>/...  (prod by default)
PREFIX="backups/${ENV_LABEL}"
CONTAINER="setu-postgres"
DB_NAME="setu_portal"
DB_USER="setu"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
FILE="setu_portal-${TS}.sql.gz"
TMP="/tmp/${FILE}"

docker exec "${CONTAINER}" pg_dump -U "${DB_USER}" "${DB_NAME}" | gzip -9 > "${TMP}"
aws s3 cp "${TMP}" "s3://${BUCKET}/${PREFIX}/${FILE}" --only-show-errors
rm -f "${TMP}"
echo "$(date -u +%FT%TZ) backup uploaded: s3://${BUCKET}/${PREFIX}/${FILE}"
