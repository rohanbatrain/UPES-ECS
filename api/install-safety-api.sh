#!/usr/bin/env bash
#
# install-safety-api.sh -- install & start the UPES-ECS Safety & Location API.
#
# Run this INSIDE the Asterisk VM as root. Installs the app to /opt/upes-ecs/api,
# seeds the family/ config dir, installs the systemd unit, starts the service on
# 0.0.0.0:8091 (campus phones reach it directly), and verifies /health.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Python dependencies (fastapi, uvicorn[standard])"
if ! pip3 install --quiet fastapi 'uvicorn[standard]'; then
    echo "WARNING: pip3 install failed. Continuing -- deps may already be present."
fi

echo "==> Installing app to /opt/upes-ecs/api/safety_api.py"
mkdir -p /opt/upes-ecs/api
cp "${SCRIPT_DIR}/safety_api.py" /opt/upes-ecs/api/safety_api.py
chmod 0644 /opt/upes-ecs/api/safety_api.py

echo "==> Seeding /opt/upes-ecs/family (families.csv, campus.json, directory.json)"
mkdir -p /opt/upes-ecs/family
# Only copy if absent -- never clobber live family/campus data on re-install.
for f in families.csv campus.json; do
    SRC="${SCRIPT_DIR}/../provisioning/family/${f}"
    DST="/opt/upes-ecs/family/${f}"
    if [ -f "$SRC" ] && [ ! -f "$DST" ]; then cp "$SRC" "$DST"; echo "    seeded ${f}"; fi
done
# Names for the app come from the Console directory (safe to refresh every install).
if [ -f "${SCRIPT_DIR}/../Console/directory.json" ]; then
    cp "${SCRIPT_DIR}/../Console/directory.json" /opt/upes-ecs/family/directory.json
fi
# Per-user voice language store the app upserts (ext,lang). Seed from the repo source
# of truth only if absent -- never clobber live language choices on re-install.
if [ -f "${SCRIPT_DIR}/../provisioning/user-languages.csv" ] && [ ! -f /opt/upes-ecs/family/user-languages.csv ]; then
    cp "${SCRIPT_DIR}/../provisioning/user-languages.csv" /opt/upes-ecs/family/user-languages.csv
    echo "    seeded user-languages.csv"
fi

mkdir -p /var/lib/upes-ecs/location /var/lib/upes-ecs/safety

echo "==> Installing systemd unit to /etc/systemd/system/upes-safety-api.service"
cp "${SCRIPT_DIR}/safety-api.service" /etc/systemd/system/upes-safety-api.service

echo "==> Reloading systemd and enabling/starting the service"
systemctl daemon-reload
systemctl enable --now upes-safety-api

sleep 2
echo "==> Verifying /health:"
curl -s http://127.0.0.1:8091/health || echo "(health check failed -- journalctl -u upes-safety-api -e)"
echo
echo "==> Done. Manage with: systemctl status upes-safety-api | journalctl -u upes-safety-api -f"
