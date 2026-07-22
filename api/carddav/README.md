# UPES-ECS CardDAV directory (shared campus phonebook)

A LAN-only, **read-only** CardDAV server ([Radicale](https://radicale.org/)) that publishes the
ERT / responder / staff directory to every phone. Responders dial **by name**, and every
contact carries `sip:<ext>@upes-ecs.local`, so contacts survive laptop-IP changes exactly like
the SIP account does. Runs **inside the Asterisk VM** on `:5232`.

## What's in the book

Generated from `Console/directory.json` by `gen_vcards.py`. Included **kinds**: `ert-lead`,
`ert`, `control`, `responder`, `staff`. **Students are excluded by design** — we never broadcast
personal student directories to every handset; students still register and dial as normal. To
re-scope, edit `INCLUDE_KINDS` in `gen_vcards.py`.

The book is regenerated **on-disk** (not over HTTP) by a systemd timer every 2 minutes, so adding
a user with `Add-UpesUser.ps1` shows up on every phone within a couple of minutes with no manual
CardDAV step. `Add-UpesUser.ps1` also pushes `directory.json` and kicks the sync immediately.

## Install (inside the VM)

Fresh builds install it automatically (`setup-in-vm.sh` → `install-carddav.sh`). For an existing
VM, run it by hand as root:

```bash
sudo UPES_HOST=upes-ecs.local bash /path/to/api/carddav/install-carddav.sh
```

This installs Radicale, creates the `radicale` service user, writes `/etc/radicale/{config,rights,users}`,
generates a read-only directory password (recorded to `/var/lib/upes-ecs/generated-secrets.txt`),
builds the initial book, and enables `upes-carddav.service` + `upes-carddav-sync.timer`.

## Provision phones (Linphone)

Auto-provisioning: the Linphone template
(`provisioning/linphone/linphone-provisioning-template.xml`) includes a `friends_list_0` CardDAV
section pointing at `http://upes-ecs.local:5232/upes/directory/`. Fill `__CARDDAV_USER__` /
`__CARDDAV_PASS__` from the generated secrets at provisioning time.

Manual (if a phone's Linphone build ignores the provisioned friends-list — the keys are
version-sensitive): **Contacts → CardDAV / Add address book**

| Field    | Value                                          |
|----------|------------------------------------------------|
| URL      | `http://upes-ecs.local:5232/upes/directory/`   |
| Username | `ertdir` (default; see generated-secrets.txt)  |
| Password | *(see `/var/lib/upes-ecs/generated-secrets.txt`)* |

## Verify

```bash
# 207 = served, 401 = up but auth-challenged (both healthy). PROPFIND needs Depth.
curl -s -o /dev/null -w '%{http_code}\n' -u ertdir:<pass> \
  -X PROPFIND -H 'Depth: 0' http://127.0.0.1:5232/upes/directory/

curl -s -u ertdir:<pass> http://127.0.0.1:5232/upes/directory/upes-4101.vcf   # one contact
systemctl status upes-carddav upes-carddav-sync.timer
ls /var/lib/radicale/collections/collection-root/upes/directory/*.vcf | wc -l  # contact count
```

`upes-ecs-healthcheck.sh` also checks the server and the contact count.

## Notes

- **Linux only.** Radicale's atomic cache write assumes POSIX `rename`; running the server on
  Windows throws a `FileNotFoundError` on PROPFIND. That is fine — the server always runs in the
  Ubuntu VM. (The `gen_vcards.py` generator is cross-platform and testable anywhere.)
- **Plain HTTP** on a closed LAN appliance. Auth is `bcrypt` when the backend is available, else
  `plain` (see `htpasswd_encryption` in `/etc/radicale/config`). For TLS, put a reverse proxy in
  front and change the provisioned URL to `https://`.
- **Read-only over HTTP.** No phone can mutate the emergency directory; the book only changes when
  `directory.json` changes and the timer regenerates it.
- Backups: `upes-ecs-backup.sh` includes `/var/lib/radicale` and `/etc/radicale`.

## Files

| File                          | Purpose                                             |
|-------------------------------|-----------------------------------------------------|
| `gen_vcards.py`               | directory.json → vCards in the Radicale collection  |
| `radicale.config`             | Radicale server config (→ `/etc/radicale/config`)   |
| `radicale.rights`             | read-only rights (→ `/etc/radicale/rights`)         |
| `upes-carddav.service`        | the Radicale server (systemd)                       |
| `upes-carddav-sync.service`   | one-shot vCard regenerate                           |
| `upes-carddav-sync.timer`     | fire the regenerate every 2 min                     |
| `install-carddav.sh`          | install/wire everything, idempotent                 |
