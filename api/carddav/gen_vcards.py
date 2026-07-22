#!/usr/bin/env python3
"""
gen_vcards.py -- turn the UPES-ECS directory into a CardDAV address book.

Reads the Console directory (ext -> {name, kind}) and writes one vCard per
"reachable position" into a Radicale filesystem collection. Phones subscribed to
the CardDAV book then show ERT / responder / staff positions by NAME and dial them
via sip:<ext>@<hostname>, so contacts survive laptop-IP changes exactly like the
SIP account does.

WHO IS INCLUDED (decided with the operator): ERT + responders + staff. Student SAP
IDs are deliberately EXCLUDED so we never broadcast personal student directories to
every handset. Change INCLUDE_KINDS below to re-scope.

This writes Radicale's on-disk storage format directly (a collection dir with a
.Radicale.props marker + one .vcf per contact). That is offline-friendly (no HTTP
round-trips) and lets a systemd timer regenerate the book whenever directory.json
changes. Idempotent: safe to run every couple of minutes.

Usage:
  gen_vcards.py [--directory PATH] [--out COLLECTION_DIR] [--host HOSTNAME] [--owner USER]
Defaults match install-carddav.sh.
"""
import argparse
import json
import os
import sys

# Directory "kind" -> (included?, friendly group label for ORG/TITLE).
KIND_LABELS = {
    "ert-lead":  "ERT Lead",
    "ert":       "ERT Operator",
    "control":   "ERT Control Room",
    "responder": "Responder",
    "staff":     "Staff",
    # excluded on purpose:
    "student":   None,
    "other":     None,
}
INCLUDE_KINDS = {k for k, v in KIND_LABELS.items() if v is not None}


def vcard(ext, name, kind, host):
    """Build one vCard 3.0 with a SIP address Linphone can dial."""
    label = KIND_LABELS.get(kind) or "UPES-ECS"
    sip = "sip:%s@%s" % (ext, host)
    # \N is a hard line-ending in vCard; keep values single-line and CRLF-joined.
    lines = [
        "BEGIN:VCARD",
        "VERSION:3.0",
        "UID:upes-%s" % ext,
        "FN:%s" % name,
        "N:%s;;;;" % name,
        "ORG:UPES-ECS;%s" % label,
        "TITLE:%s" % label,
        # SIP address: IMPP is the standard field Linphone reads for a dialable SIP URI.
        "IMPP;TYPE=sip:%s" % sip,
        # Fallbacks some clients prefer:
        "X-SIP;TYPE=sip:%s" % sip,
        "TEL;TYPE=WORK,VOICE:%s" % ext,
        "CATEGORIES:%s" % label,
        "END:VCARD",
    ]
    return "\r\n".join(lines) + "\r\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--directory", default="/opt/upes-ecs/family/directory.json")
    ap.add_argument("--out", default="/var/lib/radicale/collections/collection-root/upes/directory")
    ap.add_argument("--host", default=os.environ.get("UPES_HOST", "upes-ecs.local"))
    ap.add_argument("--owner", default="radicale")
    args = ap.parse_args()

    try:
        with open(args.directory, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        sys.stderr.write("gen_vcards: cannot read %s: %s\n" % (args.directory, e))
        return 1

    os.makedirs(args.out, exist_ok=True)
    # Mark the dir as a Radicale address-book collection (idempotent).
    props = os.path.join(args.out, ".Radicale.props")
    if not os.path.exists(props):
        with open(props, "w", encoding="utf-8") as f:
            json.dump({"tag": "VADDRESSBOOK", "D:displayname": "UPES Campus Directory"}, f)

    keep = set()
    written = 0
    for ext, info in sorted(data.items()):
        if not isinstance(info, dict):
            continue
        kind = info.get("kind", "")
        if kind not in INCLUDE_KINDS:
            continue
        name = info.get("name") or ext
        fname = "upes-%s.vcf" % ext
        keep.add(fname)
        path = os.path.join(args.out, fname)
        body = vcard(ext, name, kind, args.host)
        # Only rewrite when changed, so CardDAV ETags/sync tokens stay stable.
        try:
            with open(path, "r", encoding="utf-8") as f:
                if f.read() == body:
                    written += 1
                    continue
        except Exception:
            pass
        with open(path, "w", encoding="utf-8") as f:
            f.write(body)
        written += 1

    # Remove vCards for positions no longer in the directory (e.g. a removed user).
    for existing in os.listdir(args.out):
        if existing.startswith("upes-") and existing.endswith(".vcf") and existing not in keep:
            try:
                os.remove(os.path.join(args.out, existing))
            except Exception:
                pass

    # Hand the whole tree to the radicale service user so the server can read/serve it.
    try:
        import pwd  # Unix-only; harmless to skip on non-Linux (build/test hosts).
        uid = pwd.getpwnam(args.owner).pw_uid
        gid = pwd.getpwnam(args.owner).pw_gid
        for root, dirs, files in os.walk(os.path.dirname(os.path.dirname(args.out))):
            os.chown(root, uid, gid)
            for fn in files:
                os.chown(os.path.join(root, fn), uid, gid)
    except (KeyError, PermissionError, OSError, ImportError):
        pass  # owner may not exist yet at first build; the installer chowns afterwards.

    sys.stdout.write("gen_vcards: wrote %d contact(s) to %s (host=%s)\n" % (written, args.out, args.host))
    return 0


if __name__ == "__main__":
    sys.exit(main())
