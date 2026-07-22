#!/usr/bin/env bash
#
# install-carddav.sh -- install & start the UPES-ECS CardDAV directory (Radicale).
#
# Run this INSIDE the Asterisk VM as root. Stands up a LAN-only, read-only shared
# campus phonebook on 0.0.0.0:5232, generated from directory.json. Phones (Linphone,
# server = upes-ecs.local) subscribe once and auto-populate ERT/responder/staff
# contacts that dial sip:<ext>@upes-ecs.local -- so contacts survive laptop-IP changes.
#
# Idempotent: safe to re-run (won't clobber an existing directory password).
#
#   Env overrides:
#     CARDDAV_USER   read-only directory account (default: ertdir)
#     CARDDAV_PASS   its password (default: generated + recorded to secrets)
#     UPES_HOST      SIP host baked into contacts (default: upes-ecs.local)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CARDDAV_USER="${CARDDAV_USER:-ertdir}"
UPES_HOST="${UPES_HOST:-upes-ecs.local}"
SECRETS=/var/lib/upes-ecs/generated-secrets.txt
STORAGE=/var/lib/radicale/collections
COLL="$STORAGE/collection-root/upes/directory"

echo "==> Creating the 'radicale' service user"
id radicale >/dev/null 2>&1 || useradd --system --home /var/lib/radicale --shell /usr/sbin/nologin radicale

echo "==> Installing Radicale + password backend (pip)"
if ! pip3 install --quiet radicale passlib bcrypt; then
    echo "    WARNING: pip3 install failed (offline?). Continuing -- Radicale may already be present."
fi

echo "==> Installing vCard generator to /opt/upes-ecs/carddav/"
mkdir -p /opt/upes-ecs/carddav
cp "${SCRIPT_DIR}/gen_vcards.py" /opt/upes-ecs/carddav/gen_vcards.py
sed -i 's/\r$//' /opt/upes-ecs/carddav/gen_vcards.py
chmod 0755 /opt/upes-ecs/carddav/gen_vcards.py

echo "==> Ensuring a directory.json is present for the generator"
mkdir -p /opt/upes-ecs/family
if [ ! -f /opt/upes-ecs/family/directory.json ]; then
    for CAND in "${SCRIPT_DIR}/../../Console/directory.json" /mnt/upesdata/Console/directory.json; do
        [ -f "$CAND" ] && cp "$CAND" /opt/upes-ecs/family/directory.json && break
    done
fi

echo "==> Resolving the read-only directory password"
# Reuse an existing password on re-install; otherwise generate one and record it.
if [ -z "${CARDDAV_PASS:-}" ]; then
    EXISTING="$(grep -s "^CARDDAV_PASS=" "$SECRETS" | tail -1 | cut -d= -f2-)"
    if [ -n "$EXISTING" ]; then
        CARDDAV_PASS="$EXISTING"
    else
        CARDDAV_PASS="$(head -c 9 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 12)"
        mkdir -p "$(dirname "$SECRETS")"
        { echo "CARDDAV_USER=${CARDDAV_USER}"; echo "CARDDAV_PASS=${CARDDAV_PASS}"; } >> "$SECRETS"
        echo "    generated CardDAV password -> $SECRETS"
    fi
fi

echo "==> Writing /etc/radicale (config, rights, users)"
mkdir -p /etc/radicale
cp "${SCRIPT_DIR}/radicale.config" /etc/radicale/config
cp "${SCRIPT_DIR}/radicale.rights" /etc/radicale/rights
sed -i 's/\r$//' /etc/radicale/config /etc/radicale/rights

# Hash the password with bcrypt when the backend is available; else fall back to plain
# (dependency-free, acceptable for a closed-LAN read-only directory).
ENC=plain
HASH="$CARDDAV_PASS"
if python3 -c "from passlib.hash import bcrypt; bcrypt.hash('x')" >/dev/null 2>&1; then
    ENC=bcrypt
    HASH="$(python3 -c "from passlib.hash import bcrypt; print(bcrypt.hash('${CARDDAV_PASS}'))")"
fi
sed -i "s|__HTPASSWD_ENC__|${ENC}|" /etc/radicale/config
printf '%s:%s\n' "$CARDDAV_USER" "$HASH" > /etc/radicale/users
chmod 0640 /etc/radicale/users
echo "    auth: user='${CARDDAV_USER}' encryption='${ENC}'"

echo "==> Building the initial address book from directory.json"
mkdir -p "$COLL"
UPES_HOST="$UPES_HOST" python3 /opt/upes-ecs/carddav/gen_vcards.py --out "$COLL" --host "$UPES_HOST" || \
    echo "    (initial build skipped -- directory.json missing; the sync timer will retry)"
chown -R radicale:radicale /var/lib/radicale /etc/radicale/users

echo "==> Installing systemd units (server + 2-min sync timer)"
cp "${SCRIPT_DIR}/upes-carddav.service"      /etc/systemd/system/
cp "${SCRIPT_DIR}/upes-carddav-sync.service" /etc/systemd/system/
cp "${SCRIPT_DIR}/upes-carddav-sync.timer"   /etc/systemd/system/
sed -i 's/\r$//' /etc/systemd/system/upes-carddav*.service /etc/systemd/system/upes-carddav-sync.timer
# Bake the chosen SIP host into the sync unit so regenerated contacts keep the hostname.
sed -i "s|^Environment=UPES_HOST=.*|Environment=UPES_HOST=${UPES_HOST}|" /etc/systemd/system/upes-carddav-sync.service

systemctl daemon-reload
systemctl enable --now upes-carddav
systemctl enable --now upes-carddav-sync.timer

sleep 2
echo "==> Verifying (HTTP 207/401 both mean the server is up):"
code="$(curl -s -o /dev/null -w '%{http_code}' -u "${CARDDAV_USER}:${CARDDAV_PASS}" \
     -X PROPFIND -H 'Depth: 0' "http://127.0.0.1:5232/upes/directory/" || echo 000)"
echo "    PROPFIND /upes/directory/ -> HTTP ${code}"
[ "$code" = "207" ] && echo "    OK: directory reachable" || echo "    (check: journalctl -u upes-carddav -e)"
echo
echo "==> Done."
echo "    Phones: Linphone -> Contacts -> CardDAV"
echo "      URL : http://${UPES_HOST}:5232/upes/directory/"
echo "      User: ${CARDDAV_USER}    Pass: (see ${SECRETS})"
echo "    Manage: systemctl status upes-carddav | journalctl -u upes-carddav -f"
