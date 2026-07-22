#!/usr/bin/env bash
#
# install-upes-api.sh -- install & start the UPES-ECS local status API.
#
# Run this INSIDE the Asterisk VM as root. It installs the Python deps,
# drops the app into /opt/upes-ecs/api, installs the systemd unit, starts
# the service, and verifies /health.
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing Python dependencies (fastapi, uvicorn[standard])"
# The VM has internet via NAT. If pip fails (offline / mirror down), warn
# loudly but continue -- the deps may already be present system-wide.
if ! pip3 install --quiet fastapi 'uvicorn[standard]'; then
    echo "WARNING: pip3 install failed. Continuing anyway --"
    echo "         fastapi/uvicorn may already be installed. If the service"
    echo "         fails to start, install them manually and retry."
fi

echo "==> Installing app to /opt/upes-ecs/api/upes_api.py"
mkdir -p /opt/upes-ecs/api
cp "${SCRIPT_DIR}/upes_api.py" /opt/upes-ecs/api/upes_api.py
chmod 0644 /opt/upes-ecs/api/upes_api.py

echo "==> Installing systemd unit to /etc/systemd/system/upes-api.service"
cp "${SCRIPT_DIR}/upes-api.service" /etc/systemd/system/upes-api.service

echo "==> Reloading systemd and enabling/starting the service"
systemctl daemon-reload
systemctl enable --now upes-api

echo "==> Waiting for the service to come up..."
sleep 2

echo "==> Verifying /health:"
curl -s http://127.0.0.1:8090/health || echo "(health check failed -- check: journalctl -u upes-api -e)"
echo
echo "==> Done. Manage with: systemctl status upes-api  |  journalctl -u upes-api -f"
