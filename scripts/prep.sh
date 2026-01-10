#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
ENV_FILE="$REPO_DIR/.env"
PRISM_USER="photoprism"
RUN_USER="${SUDO_USER:-}"
ENV_CREATED="false"
ADMIN_PASSWORD=""

if [[ ${EUID} -ne 0 ]]; then
  echo "Please run as root (e.g. sudo $0)." >&2
  exit 1
fi

random_password() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20
}

if ! id "$PRISM_USER" >/dev/null 2>&1; then
  useradd -r -s /bin/false -M "$PRISM_USER"
else
  PRISM_SHELL=$(getent passwd "$PRISM_USER" | cut -d: -f7)
  if [[ "$PRISM_SHELL" != "/bin/false" ]]; then
    echo "Warning: user $PRISM_USER has login shell ($PRISM_SHELL). Consider setting to /bin/false." >&2
  fi
fi

PRISM_UID=$(id -u "$PRISM_USER")
PRISM_GID=$(id -g "$PRISM_USER")

if [[ ! -f "$ENV_FILE" ]]; then
  ADMIN_PASSWORD=$(random_password)
  DB_PASSWORD=$(random_password)
  ROOT_PASSWORD=$(random_password)

  cat >"$ENV_FILE" <<EOF
PHOTOPRISM_ADMIN_PASSWORD=${ADMIN_PASSWORD}
PHOTOPRISM_DATABASE_PASSWORD=${DB_PASSWORD}
MARIADB_PASSWORD=${DB_PASSWORD}
MARIADB_DATABASE=photoprism
MARIADB_USER=photoprism
MARIADB_ROOT_PASSWORD=${ROOT_PASSWORD}

PHOTOPRISM_UID=${PRISM_UID}
PHOTOPRISM_GID=${PRISM_GID}

HOST_STORAGE_PATH=/opt/photoprism/storage
HOST_ORIGINALS_PATH=/opt/photoprism/originals
HOST_DB_PATH=/opt/photoprism/database

PHOTOPRISM_WORKERS=1
PHOTOPRISM_ORIGINALS_LIMIT=500
# PHOTOPRISM_DISABLE_TENSORFLOW=true
EOF
  ENV_CREATED="true"
fi

# Load variables from .env (supports simple KEY=VALUE lines).
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

require_var() {
  local name=$1
  local value=${!name-}
  if [[ -z "$value" ]]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
}

require_var HOST_STORAGE_PATH
require_var HOST_ORIGINALS_PATH
require_var HOST_DB_PATH
require_var PHOTOPRISM_DATABASE_PASSWORD
require_var MARIADB_PASSWORD
require_var MARIADB_DATABASE
require_var MARIADB_USER
require_var MARIADB_ROOT_PASSWORD

if [[ "$PHOTOPRISM_DATABASE_PASSWORD" != "$MARIADB_PASSWORD" ]]; then
  echo "PHOTOPRISM_DATABASE_PASSWORD must equal MARIADB_PASSWORD." >&2
  exit 1
fi

TARGET_UID=${PHOTOPRISM_UID:-$PRISM_UID}
TARGET_GID=${PHOTOPRISM_GID:-$PRISM_GID}

mkdir -p "$HOST_ORIGINALS_PATH" "$HOST_STORAGE_PATH" "$HOST_DB_PATH"
chown -R "${TARGET_UID}:${TARGET_GID}" \
  "$HOST_ORIGINALS_PATH" "$HOST_STORAGE_PATH" "$HOST_DB_PATH"

if getent group docker >/dev/null 2>&1; then
  if [[ -n "$RUN_USER" && "$RUN_USER" != "root" && "$RUN_USER" != "$PRISM_USER" ]]; then
    usermod -aG docker "$RUN_USER"
  fi
else
  echo "Warning: docker group not found; ensure $PRISM_USER can access Docker."
fi

if [[ -n "$RUN_USER" && "$RUN_USER" != "root" ]]; then
  chown -R "${RUN_USER}:${RUN_USER}" "$REPO_DIR"
fi

echo "OK: user and directories are ready."
if [[ "$ENV_CREATED" == "true" ]]; then
  echo "Admin login password: ${ADMIN_PASSWORD}"
else
  echo "Admin login password is set in .env."
fi
