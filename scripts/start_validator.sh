#!/usr/bin/env bash
set -euo pipefail

PUBLIC_IP=${PUBLIC_IP:-""}
if [[ -z "$PUBLIC_IP" ]]; then
  echo "PUBLIC_IP must be set (e.g., export PUBLIC_IP=54.193.165.179)" >&2
  exit 1
fi

if [[ ! -f config/config.json ]]; then
  echo "Missing config/config.json. Ensure the repo was cloned correctly." >&2
  exit 1
fi

echo "[+] Ensuring data directory exists..."
mkdir -p data

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed. Run scripts/install_docker.sh first." >&2
  exit 1
fi

echo "[+] Starting avalanchego via docker compose..."
PUBLIC_IP=$PUBLIC_IP docker compose up -d --remove-orphans

echo "[+] Tail logs with: docker compose logs -f --tail=200"
