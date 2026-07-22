# Stable hostname (`upes-ecs.local`) — set the SIP server once, never re-point phones

## The problem this solves

QEMU forwards SIP/RTP on **the laptop's LAN IP**. That IP changes every time you move to a
new router or a phone hotspot (OTG). `Set-UpesLanIp.ps1` already rebinds Asterisk's
*advertised* media address on the server side — but every phone still had the raw IP typed
into its Linphone profile, so someone had to re-point every handset by hand after each move.

## The fix — mDNS

`Publish-UpesHostname.ps1` runs on the laptop and answers multicast-DNS (RFC 6762) queries
for **`upes-ecs.local`** with the laptop's *current* LAN IP — the same IP `Set-UpesLanIp.ps1`
computes, so the name and Asterisk's advertised address always agree. Phones provisioned with
`server = upes-ecs.local` re-resolve on their next REGISTER (every 120 s) and follow the
laptop automatically. **Set the server once; never touch it again.**

Why mDNS and not a DNS hostname (`pbx.upes.lan`): on an arbitrary router or a phone hotspot
you do **not** control DHCP, so you cannot hand out a DNS server. mDNS is link-local multicast
— it needs nothing on the network and works fully offline. It is the only mechanism that is
genuinely *set-once* for the field/van case.

## How it runs

- `start-vm.ps1` launches it hidden on boot (right after the `Set-UpesLanIp` rebind), so it is
  covered by the existing autostart — no extra setup.
- It recomputes the IP live and re-announces on change, so a **mid-session network switch needs
  nothing** — not even a rebind click.
- `stop-vm.ps1` stops it (no PBX → no reason to advertise the name).
- Log: `%USERPROFILE%\qemu\seed\mdns.log`.

Manual controls:

```powershell
# run the responder in the foreground (Ctrl-C to stop)
powershell -File "%USERPROFILE%\qemu\Publish-UpesHostname.ps1"

# fire a single announcement (e.g. to nudge phones after a fast move)
powershell -File "%USERPROFILE%\qemu\Publish-UpesHostname.ps1" -Once

# publish a different name
powershell -File "%USERPROFILE%\qemu\Publish-UpesHostname.ps1" -Name pbx.local
```

## Provision phones with the hostname

In the Linphone remote-provisioning template
(`provisioning/linphone/linphone-provisioning-template.xml`), `__DOMAIN__` now defaults to
`upes-ecs.local`. Contacts pushed by the CardDAV directory also dial `sip:<ext>@upes-ecs.local`,
so both the account and the phonebook survive IP changes.

## Verify

On the laptop:

```powershell
Resolve-DnsName upes-ecs.local -Type A     # -> the current LAN IP
```

On a phone / another PC on the same Wi-Fi: `ping upes-ecs.local` should reach the laptop.

## Caveats / fixed devices

- **Linphone (Android/desktop) resolves `.local`** — that is the provisioned answer point,
  student, and staff fleet, so those are all set-once.
- Some **fixed SIP devices** (certain gate phones / corridor speakers) cannot resolve mDNS.
  Leave those on a raw IP, or put them on a controlled campus router that has a real DNS entry
  for the PBX. This is the documented exception — the field/van phones are the ones this fixes.
- Windows already runs its own mDNS responder; ours coexists with it via `SO_REUSEADDR` on
  UDP 5353 (unprivileged — no admin needed).
- If `Resolve-DnsName upes-ecs.local` fails: confirm the VM is running (the responder starts
  with it), check `seed\mdns.log`, and make sure the phone and laptop are on the **same LAN
  segment** (mDNS does not cross subnets/VLANs or client-isolation "AP isolation" Wi-Fi).
