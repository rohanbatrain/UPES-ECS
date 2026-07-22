# UPES-ECS — Master Runbook ("how to do everything")

A LAN-only campus emergency + internal calling system on Asterisk. In an emergency, **dial 111.**
This is the single index: pick a deployment, wire the network, add people, go multilingual, operate.

---

## 0. Two ways to run it — pick one

| Target | When | Effort | HA |
|---|---|---|---|
| **A. One Windows PC** (QEMU VM) | pilot, demo, a single van/room | one double-click | no |
| **B. Two Jetson Nano** (native ARM) + Juniper | real campus, always-on | ~1 hr per node | **yes (active/standby)** |

Both run the *same* Asterisk config, dialplan, accounts, prompts, API, and dashboards.

---

## A · Single Windows PC (simplest)

Copy the repo onto the PC, then:
```powershell
powershell -ExecutionPolicy Bypass -File .\Install-UpesEcs.ps1
```
Installs prereqs + firewall, builds/boots the PBX VM, autostarts it, starts the Console on `:8080`.
Full detail: [README.md](README.md#set-up-on-a-new-windows-pc-one-command). Region/language picker: double-click **`Deploy-UPES.cmd`**.

---

## B · Two Jetson Nano — High Availability (production)

A Jetson Nano is ARM64 Linux, so Asterisk runs **natively** (no QEMU → fast), and two boards form an
active/standby cluster. If one board dies, the other keeps 111 answering.

> **Recommended: the simple "two servers on the LAN" path (no VIP, no Juniper VRRP config).**
> The two boxes just watch each other over the LAN; whoever is alive owns the name **`upes-ecs.local`**;
> phones follow the name. One command per box:
> ```bash
> cd deploy/jetson/mdns
> sudo ./setup-node.sh --role primary   --self <BOX-A-IP> --peer <BOX-B-IP> --iface eth0   # on box A
> sudo ./setup-node.sh --role secondary --self <BOX-B-IP> --peer <BOX-A-IP> --iface eth0   # on box B
> ```
> Full runbook: [deploy/jetson/mdns/README-MDNS.md](deploy/jetson/mdns/README-MDNS.md) · trimmed switch guide:
> [deploy/jetson/mdns/NETWORK-JUNIPER-MDNS.md](deploy/jetson/mdns/NETWORK-JUNIPER-MDNS.md).
> Point phones at `upes-ecs.local` with a short (~60 s) SIP registration; failover recovers 111 in seconds.

The **VIP variant** below (a floating Virtual IP phones register to) is the alternative if some devices
can't resolve `.local` mDNS — it needs an L2-contiguous voice VLAN and a little more switch config.

**Steps (full runbook: [deploy/jetson/README.md](deploy/jetson/README.md)):**
1. Flash both Jetsons with Ubuntu (JetPack). Put both on the **voice VLAN**, static IPs, plus a VIP in the same subnet.
2. Exchange SSH keys (for config sync). Copy the repo to each board.
3. Install (from `deploy/jetson/`):
   ```bash
   # node 1 — MASTER
   sudo ./install-jetson.sh --role primary   --vip <VIP> --peer <node2-ip> --iface eth0
   # node 2 — BACKUP
   sudo ./install-jetson.sh --role secondary  --vip <VIP> --peer <node1-ip> --iface eth0
   ```
4. Verify: VIP is up on the master (`ip -4 addr show eth0`), dial 111, Console at `http://<VIP>:8080`.
5. Point phones at the **VIP** with a **short SIP registration (~60 s)** so failover recovers in seconds.
6. **Test failover:** `sudo systemctl stop asterisk` on the master (or power it off) → VIP moves → dial 111 → still works.

Config/accounts/prompts sync primary→secondary automatically (rsync timer), so adding a user on the
primary propagates. Limitation: registrations re-establish on failover (that's why the short expiry);
zero-touch failover (shared DB) is documented as an upgrade.

---

## 2 · Network with your Juniper gear — the "100%" checklist

Full Junos `set` config: [deploy/jetson/NETWORK-JUNIPER.md](deploy/jetson/NETWORK-JUNIPER.md). The essentials:

- [ ] **One voice VLAN** spanning both switches (trunked uplinks) so it's L2-contiguous across both Jetsons — this is what lets the VIP move on failover.
- [ ] **Both Jetsons + the VIP** in that one voice subnet (Jetsons static; VIP excluded from DHCP).
- [ ] **DHCP** for phones on the voice VLAN; phones register to the **VIP**.
- [ ] **QoS end-to-end:** RTP = **DSCP EF** (strict-priority queue), SIP = CS3/AF31; classify at the access edge, honor on trunks/router. Voice never drops under load.
- [ ] **No AP client-isolation** on the voice SSID (the #1 gotcha for Wi-Fi softphones); same subnet as the Jetsons.
- [ ] **PoE** budget covers IP desk phones.
- [ ] **Firewall:** permit `5060/udp` + `10000–10019/udp` within the voice VLAN, block from the internet, **SIP ALG off**. LAN-only by design.
- [ ] Gratuitous ARP allowed (Junos default) · failover tested.

> keepalived provides the *application* VIP at L2 — you do **not** need Juniper VRRP for it. Juniper VRRP is separate (gateway redundancy, optional).

---

## 3 · Add a person

SAP ID = extension = username. One idempotent command (never changes an existing password):
```powershell
powershell -File deploy\qemu\Add-UpesUser.ps1 -SapId 500000005 -Name "Student Example Five"
```
On the Jetson cluster, run it on the **primary**; the sync propagates to the backup.
Rules + credentials: [deploy/qemu/ADD-USER-RUNBOOK.md](deploy/qemu/ADD-USER-RUNBOOK.md) · [secrets/TEAM-CREDENTIALS.md](secrets/TEAM-CREDENTIALS.md).

---

## 4 · Regional languages (voice prompts **and** dashboard UI)

Everything localizes to the deployed region: the ~41 voice prompts AND the dashboard UI (~679 strings).
The system speaks **44 languages** (all Piper natural voices); Indian ones with real voices: hi, te, ml, ur, ne.

**Status:** English shipped · **Hindi live** on the pilot (voice + UI) · te/ml/ur/ne audio + UI = AI first-pass, staged.

### The translator pipeline (who + what to give)
- **Who:** one **native speaker per language**, ideally with first-aid/emergency familiarity — these are CPR/evacuation instructions, so accuracy > fluency.
- **Give them two files** (they *correct the AI draft*, they don't start from scratch):
  1. Voice: `i18n/translations/<code>.csv` (41 rows, English + draft) + the rules in [i18n/TRANSLATION-GUIDE.md](i18n/TRANSLATION-GUIDE.md).
  2. UI: `Console/ui-lang/<code>.json` (~679 short strings).
- **Rules they follow:** keep the DTMF digit on "press 1", keep `*22`/`111`/`UPES`/`SIP` verbatim, don't add/drop first-aid steps, stay within the length target.

### Generate + deploy a language
```powershell
# after the CSV is filled + the Piper voice is downloaded (URL in i18n/languages.json):
powershell -File scripts\gen-lang-prompts.win.ps1 -Lang <code>     # regenerates the audio pack
```
Then `Deploy-UPES` → pick the language (Windows), or the Jetson sync picks it up. The dashboard flips
to that language automatically (from `region.json`). Details: [DEPLOY-REGIONAL.md](DEPLOY-REGIONAL.md).

---

## 5 · The dashboards

- **Operations Console** — `http://<host-or-VIP>:8080` — control room: wallboard, follow-ups (missed-111 callbacks), roll-call, mass callout, directory, region.
- **Two LED-TV wallboards** — `…/tv-safety.html` (public "DIAL 111") + `…/tv-ops.html` (NOC). Launch kiosk: `Console\Show-TV.ps1 -Both`.
- Both are **realtime**, **auto-refresh**, and now **localize** to the deployed language (nav, labels, everything) while live data stays as data.

---

## 6 · Day-2 operations

- **Moved networks (Windows):** `Set-UpesLanIp.ps1` (or the Console "Rebind"). Jetson: fixed VIP, no rebind.
- **Missed-111 follow-ups:** Console → Follow-ups → log the callback (safe/needs-help/no-answer/escalated).
- **Backups:** nightly cron on the PBX (`upes-ecs-backup.sh`).
- **Revert a language to English:** re-run the deploy picking English (backup of English prompts is kept on the box).

---

## 7 · Go-live checklist

- [ ] Deploy chosen (Windows pilot **or** 2× Jetson HA). VIP up; dial 111 answers; 199 drill works.
- [ ] Juniper: voice VLAN spans both nodes · QoS EF for RTP · no client isolation · failover tested.
- [ ] Users added (SAP ID = ext); credentials delivered securely.
- [ ] Language chosen; **native expert has verified** the voice CSV + UI JSON (AI draft is not go-live quality on its own for a life-safety line).
- [ ] Dashboards on the TVs; Console reachable by the control room.
- [ ] Backups running; a second answer point on shift (no single point of failure in staffing).
