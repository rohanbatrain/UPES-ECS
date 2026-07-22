#!/usr/bin/env python3
"""
UPES-ECS Emergency PBX -- local HTTP status/control API.

Runs INSIDE the Asterisk VM (Ubuntu 22.04) and talks to Asterisk over the
local `asterisk -rx` CLI socket via subprocess. There is deliberately NO SSH:
the whole point of this service is to replace slow per-request SSH polling with
a fast local HTTP API that the Emergency Console can hit cross-origin.

Served by uvicorn on 0.0.0.0:8090. The systemd unit runs this as root, so
`asterisk -rx` works without sudo -- we never shell out to sudo here.

Every subprocess/file/parse operation is wrapped defensively so that /status
NEVER hangs (all subprocess calls have timeouts) and NEVER 500s (all failures
degrade to empty lists / default values).
"""

import csv
import json
import os
import re
import socket
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

# --------------------------------------------------------------------------- #
# Constants / paths
# --------------------------------------------------------------------------- #

MIN_AGENTS = 1
QUEUE_NAME = "ert_emergency_queue"

ALERTS_MISSED_PENDING = "/var/lib/upes-ecs/alerts/missed-pending.log"
INCIDENTS_MISSED_NDJSON = "/var/lib/upes-ecs/incidents/missed-emergency.ndjson"
FOLLOWUPS_NDJSON = "/var/lib/upes-ecs/incidents/followups.ndjson"
CALLBACK_TARGET_SEC = 300   # 5-minute callback SLA; a still-open follow-up older than this is OVERDUE
CDR_MASTER_CSV = "/var/log/asterisk/cdr-csv/Master.csv"
RECORDINGS_DIR = "/var/spool/asterisk/monitor/upes-ecs/"
SHIFT_LOG = "/var/lib/upes-ecs/shift/shift.log"

# Safety / mobile-app state (written by safety_api.py; read here so the Console --
# which only talks to THIS api -- can show who's safe / needs help during an emergency).
SAFETY_DIR = "/var/lib/upes-ecs/safety"
EMERGENCY_FLAG = os.path.join(SAFETY_DIR, "emergency.json")
NEEDHELP_LOG = os.path.join(SAFETY_DIR, "needhelp-pending.log")
SAFE_DECLARED = os.path.join(SAFETY_DIR, "declared.ndjson")
LOCATION_TRAIL = "/var/lib/upes-ecs/location/trail.ndjson"
FAMILY_DIR = "/opt/upes-ecs/family"
CAMPUS_JSON = os.path.join(FAMILY_DIR, "campus.json")
SAFETY_DIRECTORY = os.path.join(FAMILY_DIR, "directory.json")
CAMPUS_DEFAULT = {"lat": 30.4159443, "lon": 77.9668329, "radiusM": 800}

UPES_OPT = "/opt/upes-ecs"

# ANSI escape / colour codes emitted by the Asterisk CLI.
ANSI_RE = re.compile(r'\x1b\[[0-9;]*m')

app = FastAPI(title="upes-api", version="1.0")

# Permissive CORS so the Console can call us from any origin.
app.add_middleware(
    CORSMiddleware,
    # The Console reaches this API server-side via Serve.ps1's proxy (same-origin to the
    # browser), so we do NOT need wildcard CORS. Restricting it blocks a malicious web page
    # in the operator's browser from cross-origin POSTing to /exec (mass callout / reload).
    allow_origins=["http://localhost:8080", "http://127.0.0.1:8080"],
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=False,
)


# --------------------------------------------------------------------------- #
# Low-level helpers (all defensive: never raise)
# --------------------------------------------------------------------------- #

def ax(cmd):
    """Run `asterisk -rx <cmd>` locally and return stdout (str).

    Returns "" on any failure (timeout, missing binary, non-zero exit) so
    callers can parse the result without worrying about exceptions.
    """
    try:
        return subprocess.run(
            ["asterisk", "-rx", cmd],
            capture_output=True, text=True, timeout=8,
        ).stdout
    except Exception:
        return ""


def strip_ansi(s):
    """Remove ANSI colour codes from a string."""
    return ANSI_RE.sub('', s or '')


def sh(args, timeout=8):
    """Run an arbitrary command (list of args, no shell) -> stdout str or ""."""
    try:
        return subprocess.run(
            args, capture_output=True, text=True, timeout=timeout,
        ).stdout
    except Exception:
        return ""


def read_lines(path):
    """Read a text file into a list of lines (no trailing newlines).

    Returns [] if the file is missing or unreadable.
    """
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    except Exception:
        return []


def first_line(text):
    """First non-empty line of a block of text, else ""."""
    for line in (text or "").splitlines():
        if line.strip():
            return line.strip()
    return ""


# --------------------------------------------------------------------------- #
# Individual status collectors -- each guarded, each returns a safe default
# --------------------------------------------------------------------------- #

def get_asterisk_active():
    """Return 'active' if asterisk unit is active, else the raw is-active value."""
    out = sh(["systemctl", "is-active", "asterisk"]).strip()
    return "active" if out == "active" else (out or "inactive")


def get_version():
    return first_line(ax("core show version"))


def get_uptime():
    line = first_line(ax("core show uptime"))
    return line.replace("System uptime: ", "").strip()


def get_queue_raw():
    """Cached-per-request raw queue output (fetched by caller)."""
    return ax("queue show %s" % QUEUE_NAME)


def count_available(queue_raw):
    """Number of 'Not in use' members in the queue output."""
    try:
        return sum(1 for ln in queue_raw.splitlines() if "Not in use" in ln)
    except Exception:
        return 0


def get_media_address():
    """The LAN IP Asterisk advertises to phones (external_media_address).

    This is the address a handset must register to — the *authoritative* registrar
    IP, which may differ from the host's default-route IP when the laptop is on more
    than one network (e.g. a separate internet NIC). '' if unset/unparseable.
    """
    out = ax("pjsip show transport transport-udp")
    for ln in out.splitlines():
        if "external_media_address" in ln:
            val = ln.split(":", 1)[-1].strip() if ":" in ln else ""
            return val
    return ""


def get_registrations():
    """Count contacts whose URI is sip:<digit...> in pjsip show contacts."""
    out = ax("pjsip show contacts")
    try:
        return sum(1 for ln in out.splitlines() if re.search(r'sip:[0-9]', ln))
    except Exception:
        return 0


def get_disk_pct():
    """Disk use% of / from `df -P /` (digits only), 0 on failure."""
    out = sh(["df", "-P", "/"])
    try:
        lines = out.splitlines()
        if len(lines) >= 2:
            # Use% is the 5th column of the data row.
            m = re.search(r'(\d+)%', lines[1])
            if m:
                return int(m.group(1))
    except Exception:
        pass
    return 0


def get_missed_pending():
    """Number of lines in the missed-pending alert log (0 if missing)."""
    if not os.path.exists(ALERTS_MISSED_PENDING):
        return 0
    return len(read_lines(ALERTS_MISSED_PENDING))


def get_active_calls():
    """Parse 'N active call(s)' out of core show channels."""
    out = ax("core show channels")
    try:
        m = re.search(r'(\d+) active call', out)
        if m:
            return int(m.group(1))
    except Exception:
        pass
    return 0


def _dur_to_secs(s):
    """'HH:MM:SS' (or 'MM:SS') -> int seconds, 0 on failure."""
    try:
        secs = 0
        for part in str(s).split(":"):
            secs = secs * 60 + int(part)
        return secs
    except Exception:
        return 0


# Extension embedded in a channel name, e.g. PJSIP/4110-0000000a -> 4110.
_CHAN_EXT_RE = re.compile(r'/(\d+)-')


def get_live_calls():
    """Active channel legs from `core show channels concise`.

    Each leg: {ext, cid, dialed, state, app, bridge, seconds}. Two legs sharing a
    non-empty `bridge` id are talking to each other (the Console pairs them into a
    caller -> responder edge); an unbridged leg dialing 111 is a caller still in
    the queue. Asterisk 18 concise layout is
    Name!Ctx!Exten!Prio!State!App!Data!CallerID!Acct!Peer!Ama!Duration!BridgeId!UniqueId
    Parsed defensively (short/oddly-shaped lines are skipped); returns [] on failure.
    """
    out = ax("core show channels concise")
    legs = []
    for raw in (out or "").splitlines():
        line = strip_ansi(raw).strip()
        if "!" not in line:
            continue  # skips the "N active channels" trailer
        f = line.split("!")
        if len(f) < 5:
            continue
        name = f[0]
        m = _CHAN_EXT_RE.search(name)
        legs.append({
            "ext": m.group(1) if m else "",
            "cid": f[7] if len(f) > 7 else "",
            "dialed": f[2] if len(f) > 2 else "",
            "state": f[4] if len(f) > 4 else "",
            "app": f[5] if len(f) > 5 else "",
            # BridgeId is second-to-last (UniqueId is last) on Asterisk 12+ concise.
            "bridge": f[-2] if len(f) >= 14 else "",
            "seconds": _dur_to_secs(f[11]) if len(f) > 11 else 0,
        })
    return legs


def get_queue_members(queue_raw):
    """List of {name, iface, state} for each PJSIP member in the queue."""
    members = []
    state_re = re.compile(
        r'\((Not in use|Unavailable|In use|Paused|Invalid|Ringing|Busy)\)'
    )
    iface_re = re.compile(r'(PJSIP/\S+)')
    for raw in (queue_raw or "").splitlines():
        if "PJSIP/" not in raw:
            continue
        line = strip_ansi(raw)
        iface_m = iface_re.search(line)
        state_m = state_re.search(line)
        iface = iface_m.group(1) if iface_m else ""
        state = state_m.group(1) if state_m else ""
        # Name is the text before " (" (member label as shown by Asterisk).
        name = line.split(" (")[0].strip() if " (" in line else line.strip()
        members.append({"name": name, "iface": iface, "state": state})
    return members


def get_registered_users():
    """List of {ext, ip} parsed from pjsip show contacts."""
    users = []
    out = ax("pjsip show contacts")
    pat = re.compile(r'([0-9]{8,9})/sip:[0-9]+@([0-9.]+)')
    for ln in out.splitlines():
        if "sip:" not in ln:
            continue
        m = pat.search(ln)
        if m:
            users.append({"ext": m.group(1), "ip": m.group(2)})
    return users


def get_presence():
    """List of {ext, state} parsed from pjsip show endpoints."""
    presence = []
    out = ax("pjsip show endpoints")
    pat = re.compile(
        r'Endpoint:\s+(\S+?)(?:/\S+)?\s+'
        r'(Not in use|Unavailable|In use|Busy|Ringing|Unknown|Invalid)'
    )
    for ln in out.splitlines():
        m = pat.search(ln)
        if m:
            presence.append({"ext": m.group(1), "state": m.group(2)})
    return presence


def get_missed_recent():
    """Last 6 records from the missed-emergency NDJSON file."""
    out = []
    lines = read_lines(INCIDENTS_MISSED_NDJSON)
    for ln in lines[-6:]:
        ln = ln.strip()
        if not ln:
            continue
        try:
            obj = json.loads(ln)
        except Exception:
            continue
        out.append({
            "incident_id": obj.get("incident_id", ""),
            "caller": obj.get("caller_extension", ""),
            "time": obj.get("datetime", ""),
            "severity": obj.get("severity", ""),
        })
    return out


def _parse_incident_dt(s):
    """'2026-07-07T11:37:43+0000' -> aware datetime, or None."""
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%S%z")
    except Exception:
        try:
            return datetime.strptime(str(s)[:19], "%Y-%m-%dT%H:%M:%S")
        except Exception:
            return None


def _followups_map():
    """incident_id -> {latest followup record, 'attempts': N} from followups.ndjson."""
    latest, attempts = {}, {}
    for ln in read_lines(FOLLOWUPS_NDJSON):
        ln = ln.strip()
        if not ln:
            continue
        try:
            o = json.loads(ln)
        except Exception:
            continue
        iid = o.get("incident_id")
        if not iid:
            continue
        latest[iid] = o
        attempts[iid] = attempts.get(iid, 0) + 1
    for iid in latest:
        latest[iid]["attempts"] = attempts.get(iid, 1)
    return latest


def get_followup_state():
    """Derive the missed-emergency callback queue from the incident log + followups.

    Each missed 111 call needs a human callback. An incident is OPEN until a followup
    with outcome safe/escalated closes it; noanswer/needshelp keep it open (logging an
    attempt). Open items older than CALLBACK_TARGET_SEC are OVERDUE. Returns the open
    queue (oldest first), counts, and the recently-closed list for the audit trail.
    """
    fmap = _followups_map()
    byid = {}
    for ln in read_lines(INCIDENTS_MISSED_NDJSON):
        ln = ln.strip()
        if not ln:
            continue
        try:
            o = json.loads(ln)
        except Exception:
            continue
        iid = o.get("incident_id")
        if iid:
            byid[iid] = o   # last record wins if an id repeats

    now = datetime.now().astimezone()
    queue, closed = [], []
    overdue = 0
    for iid, o in byid.items():
        fu = fmap.get(iid)
        dt = _parse_incident_dt(o.get("datetime", ""))
        age = int((now - dt).total_seconds()) if dt else 0
        caller = o.get("caller_name") or o.get("caller_extension") or "unknown"
        if fu and fu.get("outcome") in ("safe", "escalated"):
            closed.append({
                "incident_id": iid, "caller": caller,
                "ext": o.get("caller_extension", ""),
                "outcome": fu.get("outcome", ""), "operator": fu.get("operator", ""),
                "time": fu.get("datetime", ""), "note": fu.get("note", ""),
            })
        else:
            is_overdue = age > CALLBACK_TARGET_SEC
            if is_overdue:
                overdue += 1
            queue.append({
                "incident_id": iid, "caller": caller,
                "ext": o.get("caller_extension", ""),
                "time": o.get("datetime", ""), "ageSec": age,
                "status": (fu.get("outcome") if fu else "new"),   # new | noanswer | needshelp
                "attempts": (fu.get("attempts", 0) if fu else 0),
                "lastNote": (fu.get("note", "") if fu else ""),
                "voicemail": o.get("voicemail", ""),
                "overdue": is_overdue,
            })
    queue.sort(key=lambda q: q["ageSec"], reverse=True)      # oldest / most overdue first
    closed.sort(key=lambda c: c["time"], reverse=True)
    return {
        "pending": len(queue), "overdue": overdue, "targetSec": CALLBACK_TARGET_SEC,
        "queue": queue[:20], "recentClosed": closed[:8],
    }


# CDR-CSV standard column indices.
CDR_SRC = 1
CDR_DST = 2
CDR_DCONTEXT = 3
CDR_LASTAPP = 7
CDR_START = 9
CDR_ANSWER = 10
CDR_DURATION = 12
CDR_DISPOSITION = 14
CDR_UNIQUEID = 16


def read_cdr_rows():
    """Parse Master.csv with the csv module -> list of field-lists.

    Rows with fewer than 17 fields are skipped. Returns [] on any failure.
    """
    rows = []
    try:
        with open(CDR_MASTER_CSV, "r", encoding="utf-8", errors="replace",
                  newline="") as fh:
            for fields in csv.reader(fh):
                if len(fields) < 17:
                    continue
                rows.append(fields)
    except Exception:
        return []
    # Bound memory + aggregation cost as the CDR grows unbounded (analytics scans all rows).
    return rows[-5000:]


def get_cdr(rows):
    """Map the last 40 CDR rows into the Console's expected shape."""
    out = []
    for f in rows[-40:]:
        try:
            dur = int(f[CDR_DURATION])
        except Exception:
            dur = 0
        out.append({
            "time": f[CDR_START],
            "src": f[CDR_SRC],
            "dst": f[CDR_DST],
            "context": f[CDR_DCONTEXT],
            "app": f[CDR_LASTAPP],
            "dur": dur,
            "disposition": f[CDR_DISPOSITION],
            "uniqueid": f[CDR_UNIQUEID],
        })
    return out


def get_recordings():
    """Newest 12 recordings in the monitor dir, parsed from filename."""
    out = []
    pat = re.compile(r'^(.*?)_([0-9]+)_([0-9]{8}-[0-9]{6})\.wav$')
    try:
        entries = []
        for name in os.listdir(RECORDINGS_DIR):
            if not name.endswith(".wav"):
                continue
            full = os.path.join(RECORDINGS_DIR, name)
            try:
                mtime = os.path.getmtime(full)
            except Exception:
                mtime = 0
            entries.append((mtime, name))
        # Newest first.
        entries.sort(key=lambda e: e[0], reverse=True)
        for _mtime, name in entries[:12]:
            m = pat.match(name)
            if m:
                incident, caller, tstamp = m.group(1), m.group(2), m.group(3)
            else:
                incident, caller, tstamp = "", "", ""
            out.append({
                "file": name,
                "incident": incident,
                "caller": caller,
                "time": tstamp,
            })
    except Exception:
        return []
    return out


def _classify_kind(dst, app):
    """Classify a call into a coarse 'kind' from destination + last app."""
    dst = dst or ""
    app_l = (app or "").lower()
    if dst == "111":
        return "emergency"
    if dst == "199" or "drill" in app_l:
        return "drill"
    if dst == "198" or app_l == "echo":
        return "echo"
    if dst[:3] == "900" or "confbridge" in app_l:
        return "bridge"
    if (len(dst) == 3 and dst[:1] == "7") or app_l == "page":
        return "paging"
    return "other"


def get_analytics(rows):
    """Aggregate the FULL Master.csv into the analytics block."""
    kinds = {"emergency": 0, "drill": 0, "echo": 0,
             "bridge": 0, "paging": 0, "other": 0}
    hours = [0] * 24
    day_counts = {}
    caller_counts = {}

    emerg_total = emerg_answered = 0
    drill_total = drill_answered = 0

    waits = []  # seconds, emergency answered calls with parseable timestamps

    total = 0
    for f in rows:
        total += 1
        dst = f[CDR_DST]
        app = f[CDR_LASTAPP]
        disposition = f[CDR_DISPOSITION]
        start = f[CDR_START]
        answer = f[CDR_ANSWER]
        src = f[CDR_SRC]

        kind = _classify_kind(dst, app)
        kinds[kind] = kinds.get(kind, 0) + 1

        # Hour-of-day + day bucketing from the start timestamp.
        start_dt = None
        try:
            start_dt = datetime.strptime(start, "%Y-%m-%d %H:%M:%S")
        except Exception:
            start_dt = None
        if start_dt is not None:
            hours[start_dt.hour] += 1
            day_key = start_dt.strftime("%Y-%m-%d")
            day_counts[day_key] = day_counts.get(day_key, 0) + 1

        # Top callers.
        if src:
            caller_counts[src] = caller_counts.get(src, 0) + 1

        answered = disposition == "ANSWERED"

        if kind == "emergency":
            emerg_total += 1
            if answered:
                emerg_answered += 1
                # Wait = answer - start (seconds) when both parse.
                try:
                    ans_dt = datetime.strptime(answer, "%Y-%m-%d %H:%M:%S")
                    if start_dt is not None:
                        delta = (ans_dt - start_dt).total_seconds()
                        if delta >= 0:
                            waits.append(delta)
                except Exception:
                    pass
        elif kind == "drill":
            drill_total += 1
            if answered:
                drill_answered += 1

    # Days: last 14 calendar days ending today, always present (0-filled).
    days = {}
    today = datetime.now().date()
    for i in range(13, -1, -1):
        d = (today - timedelta(days=i)).strftime("%Y-%m-%d")
        days[d] = day_counts.get(d, 0)

    # Top 8 callers by count.
    top_callers = sorted(
        caller_counts.items(), key=lambda kv: kv[1], reverse=True
    )[:8]
    top_callers = [[src, cnt] for src, cnt in top_callers]

    def pct(numer, denom):
        if not denom:
            return None
        return round(numer / denom * 100)

    avg_wait = round(sum(waits) / len(waits), 1) if waits else 0
    max_wait = int(max(waits)) if waits else 0

    emergency = {
        "total": emerg_total,
        "answered": emerg_answered,
        "answeredPct": pct(emerg_answered, emerg_total),
        "avgWait": avg_wait,
        "maxWait": max_wait,
    }
    drill = {
        "total": drill_total,
        "answered": drill_answered,
        "passPct": pct(drill_answered, drill_total),
    }

    return {
        "total": total,
        "byKind": kinds,
        "hours": hours,
        "days": days,
        "topCallers": top_callers,
        "emergency": emergency,
        "drill": drill,
    }


def get_shift_log():
    """Last 12 pipe-delimited entries from the shift log."""
    out = []
    for ln in read_lines(SHIFT_LOG)[-12:]:
        ln = ln.strip()
        if not ln:
            continue
        parts = ln.split("|")
        if len(parts) < 3:
            continue
        out.append({
            "time": parts[0],
            "ext": parts[1],
            "action": parts[2],
        })
    return out


ROLLCALL_DIR = "/var/lib/upes-ecs/rollcall"


def get_rollcall():
    """Summarise the most recent roll-call run so the Console can show it live.

    <runid>.roster = one extension per line (everyone called);
    <runid>.csv    = ext,response,time  (response '1' = pressed-1-safe).
    Returns None if no run exists yet.
    """
    try:
        rosters = [os.path.join(ROLLCALL_DIR, f) for f in os.listdir(ROLLCALL_DIR)
                   if f.endswith(".roster")]
    except Exception:
        return None
    if not rosters:
        return None
    try:
        latest = max(rosters, key=os.path.getmtime)
        runid = os.path.basename(latest)[:-len(".roster")]
        called = [x.strip() for x in open(latest).read().splitlines() if x.strip()]
        safe, responded, ts = [], [], None
        csvf = latest[:-len(".roster")] + ".csv"
        if os.path.exists(csvf):
            for ln in open(csvf).read().splitlines():
                p = ln.split(",")
                if len(p) >= 2 and p[0].strip():
                    ext = p[0].strip()
                    responded.append(ext)
                    if p[1].strip() == "1":
                        safe.append(ext)
                    if len(p) >= 3 and p[2].strip():
                        ts = p[2].strip()
        unaccounted = [e for e in called if e not in responded]
        m = re.match(r"(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})", runid)
        when = ("%s-%s-%s %s:%s:%s" % m.groups()) if m else runid
        return {
            "runid": runid, "time": ts or when,
            "called": len(called), "safe": len(safe),
            "responded": len(responded), "unaccounted": len(unaccounted),
            "safeExts": safe, "unaccountedExts": unaccounted,
        }
    except Exception:
        return None


def get_safety(live_calls):
    """Mobile-app safety snapshot for the Console: emergency flag + who has declared
    safe / needs help since the emergency began. Derived from the files safety_api.py
    writes; fully defensive (missing files -> inactive/empty).

    `live_calls` is the already-computed liveCalls list, so an in-progress 111 call
    activates the emergency banner even before an operator flips the flag.
    """
    flag = {}
    try:
        with open(EMERGENCY_FLAG, "r", encoding="utf-8") as fh:
            flag = json.load(fh)
    except Exception:
        flag = {}
    active = bool(flag.get("active"))
    reason = flag.get("reason", "")
    since = flag.get("since", "")
    if not active:
        for c in (live_calls or []):
            if c.get("dialed") == "111":
                active, reason, since = True, "live 111 call", ""
                break

    since_epoch = None
    if since:
        try:
            since_epoch = datetime.strptime(since[:19], "%Y-%m-%dT%H:%M:%S").timestamp()
        except Exception:
            since_epoch = None

    # Latest declaration per SAP from declared.ndjson.
    latest = {}
    for ln in read_lines(SAFE_DECLARED):
        ln = ln.strip()
        if not ln:
            continue
        try:
            o = json.loads(ln)
        except Exception:
            continue
        if o.get("sap"):
            latest[o["sap"]] = o
    safe_count = need_count = 0
    for o in latest.values():
        if since_epoch and o.get("ts", 0) < since_epoch:
            continue   # stale declaration from before this emergency
        if o.get("status") == "safe":
            safe_count += 1
        elif o.get("status") == "needshelp":
            need_count += 1

    # Pending "need help" list (pipe log: iso|sap|name|note), newest first.
    need_help = []
    for ln in read_lines(NEEDHELP_LOG)[-30:]:
        parts = ln.split("|")
        if len(parts) >= 3:
            need_help.append({
                "time": parts[0], "sap": parts[1], "name": parts[2],
                "note": parts[3] if len(parts) > 3 else "",
            })
    need_help.reverse()

    return {
        "emergency": {"active": active, "since": since, "reason": reason},
        "safeCount": safe_count,
        "needHelpCount": len(need_help),
        "needHelp": need_help[:20],
    }


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #

@app.get("/health")
def health():
    return {"ok": True, "service": "upes-api"}


# --------------------------------------------------------------------------- #
# /status response cache  (REVERSIBLE: delete this block + the 3 "CACHE" lines
# inside status() to restore the original uncached behaviour.)
#
# The Console and every TV wallboard poll /status every 4-5s. Each call fans out
# to ~10 `asterisk -rx` subprocesses plus a full CDR/analytics parse -- expensive
# on the emulated PBX. A short TTL lets all concurrent pollers share ONE
# computation instead of each re-running the whole fan-out. TTL is kept below the
# poll interval so the boards stay effectively live. No lock (matches the other
# caches here); a rare double-miss just recomputes once -- harmless.
# --------------------------------------------------------------------------- #
_status_cache = {"ts": 0.0, "data": None}
STATUS_TTL = 2.5   # seconds

# --------------------------------------------------------------------------- #
# /live response cache  (REVERSIBLE: delete this block + the 3 "CACHE" lines
# inside live() to restore the original uncached behaviour.)
#
# /live is the hottest path: every TV wallboard polls it ~every 1.3s and each
# call fans out to ~4 `asterisk -rx` subprocesses on the single-vCPU emulated
# PBX. A sub-poll-interval TTL lets all concurrent pollers share ONE computation
# instead of each re-running the fan-out, while boards stay effectively live. No
# lock (matches the other caches here); a rare double-miss just recomputes once.
# --------------------------------------------------------------------------- #
_live_cache = {"ts": 0.0, "data": None}
LIVE_TTL = 0.4   # seconds  (tight so a natural call-end clears fast; hangup action busts it to 0)


def _gather(tasks):
    """Run a dict of {name: zero-arg callable} concurrently and return {name: result}.

    Every collector here is already individually defensive (returns a safe empty
    value instead of raising), so this only trades ~17 SEQUENTIAL `asterisk -rx`
    subprocess spawns for concurrent ones -- cutting a /status cache-miss from
    ~sum(collector times) down to ~max(collector times) on the emulated PBX.
    A collector that somehow still raises yields None (same defensive contract).
    REVERSIBLE: delete this helper and restore the sequential body in status().
    """
    results = {}
    with ThreadPoolExecutor(max_workers=max(1, len(tasks))) as ex:
        futures = {name: ex.submit(fn) for name, fn in tasks.items()}
        for name, fut in futures.items():
            try:
                results[name] = fut.result()
            except Exception:
                results[name] = None
    return results


@app.get("/status")
def status():
    """Full point-in-time snapshot consumed by the Emergency Console.

    Nothing in here is allowed to raise: each collector is individually
    defensive, so a partial failure yields empty/default values rather than
    a 500 or a hang.
    """
    _now = time.time()                                                    # CACHE
    if _status_cache["data"] is not None and _now - _status_cache["ts"] < STATUS_TTL:  # CACHE
        return _status_cache["data"]                                      # CACHE
    updated = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    hostname = socket.gethostname()

    # Fan the independent, subprocess/IO-bound collectors out concurrently. Each
    # is defensive, so order doesn't matter and nothing here can raise. queue_raw,
    # cdr_rows and live_calls are gathered ONCE and reused by the derived fields
    # below (count_available/queue_members, cdr/analytics, safety) exactly as before.
    g = _gather({
        "asterisk_state": get_asterisk_active,
        "queue_raw": get_queue_raw,
        "disk_pct": get_disk_pct,
        "followups": get_followup_state,
        "cdr_rows": read_cdr_rows,
        "live_calls": get_live_calls,
        "version": get_version,
        "uptime": get_uptime,
        "media_address": get_media_address,
        "registrations": get_registrations,
        "active_calls": get_active_calls,
        "registered_users": get_registered_users,
        "presence": get_presence,
        "missed_recent": get_missed_recent,
        "recordings": get_recordings,
        "shift_log": get_shift_log,
        "rollcall": get_rollcall,
    })

    asterisk_state = g["asterisk_state"]
    queue_raw = g["queue_raw"]
    cdr_rows = g["cdr_rows"]
    live_calls = g["live_calls"]
    followups = g["followups"] or {}
    disk_pct = g["disk_pct"] or 0   # never None: keeps the >= comparisons (and never-500 contract) safe

    queue_available = count_available(queue_raw)
    missed_pending = followups.get("pending", 0)   # OPEN callbacks (derived), not the append-only log length

    # Derive the top-level health state.
    if asterisk_state != "active":
        state = "OFFLINE"
    elif queue_available < MIN_AGENTS or disk_pct >= 90:
        state = "CRITICAL"
    elif disk_pct >= 75 or missed_pending > 0:
        state = "DEGRADED"
    else:
        state = "READY"

    thin_cover = state == "READY" and queue_available < (MIN_AGENTS + 1)

    result = {
        "updated": updated,
        "state": state,
        "hostname": hostname,
        "asterisk": asterisk_state,
        "version": g["version"],
        "uptime": g["uptime"],
        "queueAvailable": queue_available,
        "minAgents": MIN_AGENTS,
        "thinCover": thin_cover,
        "mediaAddress": g["media_address"],
        "registrations": g["registrations"],
        "diskPct": disk_pct,
        "missedPending": missed_pending,
        "followups": followups,
        "activeCalls": g["active_calls"],
        "liveCalls": live_calls,
        "safety": get_safety(live_calls),
        "queueMembers": get_queue_members(queue_raw),
        "registeredUsers": g["registered_users"],
        "presence": g["presence"],
        "missedRecent": g["missed_recent"],
        "cdr": get_cdr(cdr_rows),
        "recordings": g["recordings"],
        "analytics": get_analytics(cdr_rows),
        "shiftLog": g["shift_log"],
        "rollcall": g["rollcall"],
    }

    _status_cache["ts"] = time.time()   # CACHE
    _status_cache["data"] = result      # CACHE
    return result


def _campus():
    try:
        with open(CAMPUS_JSON, "r", encoding="utf-8") as fh:
            c = json.load(fh)
        return {"lat": c.get("lat", CAMPUS_DEFAULT["lat"]),
                "lon": c.get("lon", CAMPUS_DEFAULT["lon"]),
                "radiusM": c.get("radiusM", CAMPUS_DEFAULT["radiusM"])}
    except Exception:
        return dict(CAMPUS_DEFAULT)


def _haversine_m(lat1, lon1, lat2, lon2):
    try:
        import math
        r = 6371000.0
        p1, p2 = math.radians(lat1), math.radians(lat2)
        dp = math.radians(lat2 - lat1)
        dl = math.radians(lon2 - lon1)
        a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
        return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    except Exception:
        return 0.0


@app.get("/map")
def live_map():
    """Latest reported position of every phone (for the Console live map). Reads the
    location trail safety_api.py appends; fully defensive. On/off-campus is a geofence
    check against campus.json."""
    camp = _campus()
    names = {}
    try:
        with open(SAFETY_DIRECTORY, "r", encoding="utf-8") as fh:
            names = json.load(fh)
    except Exception:
        names = {}

    latest = {}
    for ln in read_lines(LOCATION_TRAIL)[-5000:]:
        ln = ln.strip()
        if not ln:
            continue
        try:
            o = json.loads(ln)
        except Exception:
            continue
        if o.get("sap"):
            latest[o["sap"]] = o   # last line for a sap wins

    now = datetime.now().timestamp()
    people = []
    for sap, o in latest.items():
        lat, lon = o.get("lat"), o.get("lon")
        if lat is None or lon is None:
            continue
        dist = _haversine_m(camp["lat"], camp["lon"], lat, lon)
        age = int(now - o.get("ts", 0)) if o.get("ts") else None
        nm = names.get(sap, {})
        people.append({
            "sap": sap,
            "name": nm.get("name") if isinstance(nm, dict) else sap,
            "lat": lat, "lon": lon,
            "distM": round(dist),
            "onCampus": dist <= camp["radiusM"],
            "ageSec": age,
            "appActive": age is not None and age <= 150,
            "battery": o.get("battery"),
        })
    people.sort(key=lambda p: (p["onCampus"] is False, p["ageSec"] if p["ageSec"] is not None else 1e9))
    return {"campus": camp, "people": people, "updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S")}


@app.get("/live")
def live():
    """Lightweight, high-frequency snapshot of only the FAST-changing state.

    The Console/TV boards poll this every ~1s so an ended call clears almost
    immediately, without the cost of the full /status (which parses the whole CDR
    + analytics on every call). Just the channel/queue reads -- a few `asterisk -rx`
    calls, no file/CDR/analytics work.
    """
    _now = time.time()                                                    # CACHE
    if _live_cache["data"] is not None and _now - _live_cache["ts"] < LIVE_TTL:  # CACHE
        return _live_cache["data"]                                        # CACHE
    queue_raw = get_queue_raw()
    result = {
        "updated": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "asterisk": get_asterisk_active(),
        "activeCalls": get_active_calls(),
        "liveCalls": get_live_calls(),
        "queueAvailable": count_available(queue_raw),
        "queueMembers": get_queue_members(queue_raw),
    }
    _live_cache["ts"] = time.time()   # CACHE
    _live_cache["data"] = result      # CACHE
    return result


# --------------------------------------------------------------------------- #
# /exec -- strictly whitelisted control actions
# --------------------------------------------------------------------------- #

DIGITS_RE = re.compile(r'^[0-9]+$')


def _sanitize(value, allowed_re):
    """Return value if it fully matches allowed_re, else ''."""
    if value is None:
        return ""
    value = str(value)
    return value if allowed_re.match(value) else ""


@app.post("/exec")
async def do_exec(request: Request):
    """Execute one of a strict whitelist of control actions.

    All arguments are validated/sanitized with regex before use. We never
    build a shell string -- commands are passed as explicit arg lists with
    shell=False so user input can never be interpreted by a shell.
    """
    def reject():
        return {"ok": False, "command": "", "output": "rejected"}

    try:
        body = await request.json()
    except Exception:
        return reject()

    if not isinstance(body, dict):
        return reject()

    action = body.get("action")
    args = body.get("args") or {}
    if not isinstance(args, dict):
        args = {}

    # ---- shift ---------------------------------------------------------- #
    if action == "shift":
        mode = args.get("mode", "on")
        if mode not in ("on", "off"):
            mode = "on"
        ext = str(args.get("ext", ""))
        if not DIGITS_RE.match(ext):
            return reject()
        cmd = [os.path.join(UPES_OPT, "ert-shift.sh"), mode, ext]
        out = sh(cmd, timeout=15)
        return {"ok": True, "command": " ".join(cmd), "output": out}

    # ---- callout -------------------------------------------------------- #
    if action == "callout":
        group = _sanitize(args.get("group"), re.compile(r'^[a-z0-9]+$'))
        sound = _sanitize(args.get("sound"), re.compile(r'^(custom/)?[A-Za-z0-9_-]+$'))
        mode = args.get("mode", "notify")
        if mode not in ("notify", "rollcall"):
            return reject()
        if not group or not sound:
            return reject()
        group_csv = os.path.join(UPES_OPT, "groups", "%s.csv" % group)
        cmd = [os.path.join(UPES_OPT, "mass_callout.sh"), group_csv, sound, mode]
        out = sh(cmd, timeout=15)
        return {"ok": True, "command": " ".join(cmd), "output": out}

    # ---- drill ---------------------------------------------------------- #
    if action == "drill":
        ext = str(args.get("ext", ""))
        if not DIGITS_RE.match(ext):
            return reject()
        cli = "originate PJSIP/%s extension 199@ctx_student" % ext
        out = ax(cli)
        return {"ok": True, "command": 'asterisk -rx "%s"' % cli, "output": out}

    # ---- followup ------------------------------------------------------- #
    if action == "followup":
        iid = _sanitize(args.get("incident_id"), re.compile(r'^[A-Za-z0-9-]{1,40}$'))
        ext = _sanitize(args.get("ext"), re.compile(r'^[0-9]{1,12}$'))
        outcome = args.get("outcome")
        if outcome not in ("safe", "escalated", "noanswer", "needshelp"):
            return reject()
        if not iid or not ext:
            return reject()
        note = _sanitize(args.get("note", ""), re.compile(r'^[\w .,:@/()\-]{0,200}$'))
        cmd = [os.path.join(UPES_OPT, "followup.sh"), iid, ext, outcome, note]
        out = sh(cmd, timeout=15)
        return {"ok": True, "command": " ".join(cmd[:4]), "output": out}

    # ---- emergency (raise/clear the mobile-app "mark yourself safe" campaign) ---- #
    if action == "emergency":
        active = bool(args.get("active", True))
        reason = _sanitize(args.get("reason", ""), re.compile(r'^[\w .,:@/()\-]{0,120}$'))
        rec = {
            "active": active,
            "since": datetime.now().astimezone().strftime("%Y-%m-%dT%H:%M:%S%z") if active else "",
            "reason": reason,
            "by": "console",
        }
        try:
            os.makedirs(SAFETY_DIR, exist_ok=True)
            with open(EMERGENCY_FLAG, "w", encoding="utf-8") as fh:
                json.dump(rec, fh)
            out = "emergency %s" % ("RAISED" if active else "cleared")
        except Exception as e:
            return {"ok": False, "command": "emergency", "output": "write failed: %s" % e}
        return {"ok": True, "command": "emergency %s" % active, "output": out}

    # ---- reload --------------------------------------------------------- #
    if action == "reload":
        ax("dialplan reload")
        return {
            "ok": True,
            "command": 'asterisk -rx "dialplan reload"',
            "output": "reloaded",
        }

    # ---- hangup (clear a stuck/zombie leg, or ALL live channels) -------- #
    # DESTRUCTIVE. scope="all" hangs up EVERY active channel -- this drops any
    # LIVE 111 emergency call too, so the Console gates it behind a hard confirm.
    # scope="PJSIP/<name>" hangs up just that one leg (used to reap a known zombie).
    # ax() runs asterisk -rx with shell=False and scope is regex-validated, so the
    # channel name can never be interpreted by a shell.
    if action == "hangup":
        scope = str(args.get("scope", ""))
        if scope == "all":
            cli = "channel request hangup all"
        elif re.match(r'^PJSIP/[A-Za-z0-9._/-]{1,80}$', scope):
            cli = "channel request hangup %s" % scope
        else:
            return reject()
        before = get_active_calls()
        out = (ax(cli) or "").strip()
        # IMMEDIATE board update: bust the live+status caches so the very NEXT poll recomputes
        # from Asterisk instead of returning the pre-hangup count for up to a TTL. Dict mutation,
        # so no 'global' needed. This is what makes a hangup show on the Console instantly.
        _live_cache["ts"] = 0.0
        _status_cache["ts"] = 0.0
        after = get_active_calls()
        head = (out + "\n") if out else ""
        return {
            "ok": True,
            "command": 'asterisk -rx "%s"' % cli,
            "output": "%shung up %s -- active calls %d -> %d" % (head, scope, before, after),
        }

    # Anything else is rejected.
    return reject()


if __name__ == "__main__":
    # Bind loopback only: the host reaches this via the SSH tunnel (VM-side 127.0.0.1:8090),
    # so nothing on the campus LAN can hit the API/exec directly. Serve.ps1 is the only caller.
    uvicorn.run(app, host="127.0.0.1", port=8090)
