# UPES-ECS Security Hardening & Abuse Handling

Closes Risk **R9** (SIP abuse / DoS) and **R14** (prank / false alarms). LAN-only, but
"internal network" is not "trusted network" — campus Wi-Fi is shared.

---

## 1. Registration & anti-abuse

| Control | Setting |
|---|---|
| Anonymous SIP | **Disabled** (`allowguest=no`, no anonymous endpoint) |
| Guest / unknown devices | **Blocked** from registering |
| Unique credentials | One per account/device |
| Password strength | **≥ 12 chars, random**; banned trivial passwords |
| **fail2ban** | Enable the Asterisk jail — ban IPs after repeated failed registrations/auth |
| Registration rate-limit | Throttle repeated REGISTER from one IP/account |
| Registration source | LAN/campus Wi-Fi subnets only; **guest Wi-Fi excluded** |
| Failed-reg logging | On → feeds [Health Monitoring](10-Health-Monitoring-Checklist.md) as an Access/registration event |

---

## 2. Network / firewall

- SIP (5060) + RTP range bound to the **LAN interface only** — never the public internet.
- Firewall allows SIP/RTP only from **approved subnets** (student Wi-Fi, staff Wi-Fi, ERT/fixed LAN); deny the rest.
- **FreePBX admin GUI** restricted to the **management subnet** — never reachable from student Wi-Fi.
- Wi-Fi **client isolation**: off (or bypassed) only for the paths that need PBX access; keep everything else isolated.
- Consider a dedicated **voice VLAN** for ERT/fixed devices.

---

## 3. Asterisk hardening

- **Disable unused modules** (`modules.conf` `noload` for drivers/apps you don't use — e.g. other channel drivers, unused apps).
- Run Asterisk as the **`asterisk` user**, not root.
- Restrict **AMI/ARI** to localhost / the management subnet with strong credentials (needed later for dashboards/AI).
- Keep FreePBX + Asterisk **patched** (Module Admin updates on a schedule).
- Log to a protected location; don't world-read logs containing caller data.

---

## 4. Media confidentiality (planned — R7)

Plain UDP RTP is sniffable on shared Wi-Fi. **Future security enhancement:**
- **TLS** for SIP signaling + **SRTP** for media, at least on ERT/fixed devices (Linphone/MicroSIP support it).
- Certificate management on the PBX.
- Marked deferred in the [Risk Register](21-Risk-Register-and-Gaps.md#r7); revisit before wide student rollout.

---

## 5. Protecting the 111 queue from flooding

The emergency line must not be drownable by junk:

- **Per-account concurrent-call limits** for normal users (students/staff) so no one account can open many channels.
- Emergency calls (111) run in a **separate context/priority** so bulk traffic can't starve them.
- Monitor channel capacity; alert if normal traffic approaches emergency headroom.
- Capacity-test toward a realistic surge, not just 2–5 calls (ties to the surge posture).

---

## 6. Prank / false-alarm handling (R14)

111 must **always stay reachable** — never rate-limit real emergencies away. Handle abuse *after the fact*, by identity:

```text
1. Every call carries caller ID (Name - SAP ID) → the caller is known.
2. Repeated false/prank calls from a SAP ID are flagged ("cry wolf" tracking).
3. ERT Lead reviews; issue a warning per university policy.
4. Persistent abuse → suspend the SIP account (not the person's ability to be helped —
   fixed phones + escalation still cover genuine need), escalate to university discipline.
5. Log all of it; keep evidence (recording + incident log).
```

**Never** disable someone's ability to reach help as a first response — investigate, warn, then suspend the account for repeat abuse.

---

## 7. Account compromise / lost device

- Immediately **reset the SIP secret** and drop active registrations.
- Force re-provision; block the old credential; log the event.
- Preserve the account's history/logs (identity is never reused).

(Full lifecycle in [Device Provisioning](14-Device-Provisioning-Sheet.md).)

---

## 8. What gets logged (security)

Successful + failed registration · unknown-device attempts · Access Denied Events ·
paging attempts (allowed + denied) · conference joins · transfer/dispatch · voicemail
& recording access · config changes · account disable/revoke · fail2ban bans.

Review these in the [Health Dashboard](10-Health-Monitoring-Checklist.md) and the weekly drill report.

---

## 9. Live status/control API (`upes-api` :8090) — attack surface

The Console is backed by a **FastAPI** service (`systemd` unit `upes-api`, `Restart=always`)
that runs **inside the VM on port 8090** and queries Asterisk locally. It serves `GET /health`,
`GET /status`, and a privileged `POST /exec`. Because `/exec` can drive the PBX, it is a real
attack surface and is locked down accordingly:

- **Whitelist-only actions:** `/exec` accepts only `shift` / `callout` / `drill` / `reload`.
  Nothing else can run; there is no free-form command path.
- **Bind local / tunnel-only:** :8090 is **not** published to the LAN. The Console reaches it
  through a persistent **SSH tunnel** (`localhost:18090 → VM:8090`), so exposure rides on SSH
  (keys + fail2ban sshd jail), not an open HTTP port.
- **Restricted CORS:** cross-origin is denied, so a random browser page a user opens **cannot**
  cross-origin `POST` to `/exec`. The Console UI also requires a **confirm-before-run** click.
- Treat the API host as management-plane: keep it off student/guest Wi-Fi and audit `/exec`
  calls alongside config changes (§8).

---

## 10. Availability & recovery hardening (done)

Availability *is* a security property for an emergency line. The following are in place:

- **`systemd Restart=always`** on both **asterisk** and **`upes-api`** — auto-recovery if the
  process crashes, on top of boot autostart.
- **Boot autostart** of the VM and the Console (Windows Startup-folder launchers, **no admin
  required**) so the whole stack comes back after a host reboot.
- **Nightly backups** — `upes-ecs-backup.sh` + cron → `/var/backups/upes-ecs/` (per
  [SOP 11](11-Backup-Restore-Procedure.md)); restore has been test-verified.
- **Real all-campus paging PIN** provisioned (no placeholder/default).
- **SSH hardened for speed + surface:** `UseDNS`/GSSAPI off, `motd-news` disabled.

---

## 11. Secrets handling

`secrets/TEAM-CREDENTIALS.md` holds **real SIP logins** and **must never be web-served**. The
Console's static server and its in-app Markdown doc viewer both explicitly block the `secrets/`
path, and the file stays out of any publicly reachable location. SIP secrets, conference PINs,
and the paging PIN live in restricted include files, not in world-readable config or git.

---

## 12. Hardening checklist (before go-live)

- [ ] Anonymous SIP off · guest Wi-Fi blocked
- [x] fail2ban Asterisk **and** sshd jails active
- [ ] Unique ≥12-char secrets; no trivial passwords
- [ ] SIP/RTP firewalled to approved subnets; not public
- [ ] FreePBX GUI on management subnet only
- [ ] Unused Asterisk modules disabled
- [ ] AMI/ARI locked down
- [x] `upes-api` :8090 whitelist-only, tunnel-only bind, CORS restricted
- [x] `secrets/TEAM-CREDENTIALS.md` blocked from web/doc-viewer serving
- [x] asterisk + `upes-api` `Restart=always`; VM/Console boot autostart; nightly backups
- [x] Real all-campus paging PIN set (no default)
- [ ] FreePBX/Asterisk patched
- [ ] Per-account call limits set; 111 priority protected
- [ ] Prank/abuse SOP known to ERT Lead
- [ ] TLS/SRTP planned (deferred item tracked)
