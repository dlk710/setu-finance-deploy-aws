#!/usr/bin/env bash
#
# Setu Finance - EC2 first-boot bootstrap (Amazon Linux 2023, arm64/t4g).
# Standalone deploy repo: clones the APP repo (source) and this DEPLOY repo (infra).
# Same script for both environments; set DEPLOY_ENV below.
# Paste into the instance "User data" field at launch.
#
set -euxo pipefail

# ===== EDIT THESE =====
DEPLOY_ENV="dev"                        # "dev" now; "prod" on the prod box later
APP_REPO_URL="https://github.com/dlk710/setu-finance.git"
APP_REPO_BRANCH="main"
DEPLOY_REPO_URL="https://github.com/dlk710/setu-finance-deploy-aws.git"
DEPLOY_REPO_BRANCH="main"
BUCKET="setu-finance-backups"
SITE_ADDRESS="dev.finance.example.com"  # match the env (dev.* now, finance.* for prod)
# ======================

APP_DIR="/opt/setu/app"
DEPLOY_DIR="/opt/setu/deploy"
BIN_DIR="/opt/setu/bin"

# --- Docker + compose plugin (arm64) ---
dnf update -y
dnf install -y docker git
systemctl enable --now docker
usermod -aG docker ec2-user || true
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
curl -SL "https://github.com/docker/buildx/releases/download/v0.34.1/buildx-v0.34.1.linux-arm64" \
  -o /usr/local/lib/docker/cli-plugins/docker-buildx
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx
# (awscli v2 ships preinstalled on Amazon Linux 2023.)

# --- Get app source + deploy assets ---
mkdir -p /opt/setu "${BIN_DIR}"
git clone --depth 1 --branch "${APP_REPO_BRANCH}"    "${APP_REPO_URL}"    "${APP_DIR}"
git clone --depth 1 --branch "${DEPLOY_REPO_BRANCH}" "${DEPLOY_REPO_URL}" "${DEPLOY_DIR}"
cd "${APP_DIR}"

# --- Place deploy files alongside the app source (Docker build context) ---
cp "${DEPLOY_DIR}/Dockerfile"   ./Dockerfile
cp "${DEPLOY_DIR}/compose.yml"  ./compose.yml
cp "${DEPLOY_DIR}/Caddyfile"    ./Caddyfile
cp "${DEPLOY_DIR}/deploy.sh"    ./deploy.sh
chmod +x ./deploy.sh

# --- Build the env file from the matching template, generate real secrets ---
cp "${DEPLOY_DIR}/.env.${DEPLOY_ENV}.example" "./.env.${DEPLOY_ENV}"
SESSION_SECRET="$(openssl rand -hex 32)"
DB_PASS="$(openssl rand -hex 16)"
sed -i "s|^SITE_ADDRESS=.*|SITE_ADDRESS=${SITE_ADDRESS}|"                 "./.env.${DEPLOY_ENV}"
sed -i "s|^AUTH_SESSION_SECRET=.*|AUTH_SESSION_SECRET=${SESSION_SECRET}|" "./.env.${DEPLOY_ENV}"
sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=${DB_PASS}|"                        "./.env.${DEPLOY_ENV}"
chmod 600 "./.env.${DEPLOY_ENV}"
# NOTE: afterward, edit this file to set PORTAL_PASSWORD and SMTP creds.

# --- Deploy the chosen environment ---
./deploy.sh "${DEPLOY_ENV}"

# --- Backups every 2 hours for all environments ---
cp "${DEPLOY_DIR}/bin/backup-to-s3.sh" "${BIN_DIR}/backup-to-s3.sh"
cp "${DEPLOY_DIR}/bin/restore.sh"      "${BIN_DIR}/restore.sh"
sed -i "s|^BUCKET=.*|BUCKET=\"${BUCKET}\"|" "${BIN_DIR}/backup-to-s3.sh"
sed -i "s|^BUCKET=.*|BUCKET=\"${BUCKET}\"|" "${BIN_DIR}/restore.sh"
chmod 700 "${BIN_DIR}"/*.sh
( crontab -l 2>/dev/null; \
  echo "0 */2 * * * ${BIN_DIR}/backup-to-s3.sh ${DEPLOY_ENV} >> /var/log/setu-backup.log 2>&1" ) \
  | crontab -

echo "Setu ${DEPLOY_ENV} bootstrap complete: https://${SITE_ADDRESS}"
