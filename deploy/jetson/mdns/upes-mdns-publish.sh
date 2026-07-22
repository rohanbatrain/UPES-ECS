#!/usr/bin/env bash
#
# upes-mdns-publish.sh -- publish the UPES-ECS mDNS name (default upes-ecs.local)
# as an A record pointing at THIS node's current interface IP, via Avahi.
#
# It runs in the FOREGROUND (exec avahi-publish) so systemd's upes-mdns.service can
# supervise it (Restart=always). keepalived starts this service only on the MASTER,
# so at most one node ever publishes the name -> no split-brain / duplicate answers.
#
# The IP is (re)computed on every start, so a DHCP lease change is picked up the next
# time the service (re)starts. HOST/IFACE come from the EnvironmentFile that
# enable-mdns-failover.sh writes (/etc/default/upes-mdns).
#
set -euo pipefail

# Pull HOST/IFACE from the EnvironmentFile too, so the script also works if run by
# hand (systemd already injects these via EnvironmentFile=).
if [ -r /etc/default/upes-mdns ]; then
  # shellcheck source=/dev/null
  . /etc/default/upes-mdns
fi

HOST="${UPES_MDNS_HOST:-upes-ecs.local}"
IFACE="${UPES_MDNS_IFACE:-eth0}"

# This node's current global IPv4 on the voice NIC (first one wins). Re-read live so
# DHCP address changes are honoured on each (re)start.
IP="$(ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null \
        | awk '{print $4}' | cut -d/ -f1 | head -n1)"

if [ -z "$IP" ]; then
  echo "upes-mdns-publish: no global IPv4 on '$IFACE' -- cannot publish '$HOST'" >&2
  logger -t upes-mdns "no global IPv4 on ${IFACE}; not publishing ${HOST}" 2>/dev/null || true
  exit 1
fi

logger -t upes-mdns "publishing ${HOST} -> ${IP} on ${IFACE}" 2>/dev/null || true

# avahi-publish -a <fqdn> <address> registers the A record and stays in the
# foreground; when it is killed (service stop) Avahi withdraws the record.
exec avahi-publish -a "$HOST" "$IP"
