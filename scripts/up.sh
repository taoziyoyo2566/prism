#!/usr/bin/env bash
set -euo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

sudo "$REPO_DIR/scripts/prep.sh"
cd "$REPO_DIR"
docker compose up -d
