#!/usr/bin/env python3
"""
UPES-ECS Safety & Location API -- ingest + family/safety service for the mobile app.

Runs INSIDE the Asterisk VM alongside upes_api.py, but serves a DIFFERENT audience:
where upes_api.py is a read-only operator console feed on loopback, THIS service is
reached by student/parent phones on the campus LAN, so it binds 0.0.0.0:8091 and
authenticates every request with HTTP Basic.

Credentials are the SAME as the SIP account: username = SAP ID, password = the pinned
SIP secret from pjsip_accounts.conf. That file is the single source of truth (see
deploy/qemu/Add-UpesUser.ps1); we parse it read-only, so there is exactly ONE password
per user and it can never drift from what the softphone uses.

What it does:
  * POST /loc      -- a phone reports its live GPS position (stored + appended to a trail)
  * POST /safe     -- a student self-declares "I'm safe" / "I need help" during an emergency
  * GET  /me       -- a phone reads back its own state + whether an emergency is active
  * GET  /emergency-- is a campus emergency active right now?
  * POST /emergency-- (operator only) raise/clear the campus "mark yourself safe" campaign
  * GET  /family   -- a PARENT sees each linked child: online, last location, on-campus, safe?
  * GET  /map      -- (operator only) everyone's latest position for the Console map

Everything is defensive: a missing file / unreadable account map degrades to empty state,
never a 500. State that must survive a restart is appended to NDJSON under /var/lib/upes-ecs.
"""

import hmac
import json
import math
import os
import re
import subprocess
import threading
import time
from datetime import datetime, timezone

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials

# --------------------------------------------------------------------------- #
# Paths / config
# --------------------------------------------------------------------------- #

ACCOUNTS_CONF = os.environ.get("UPES_ACCOUNTS_CONF", "/etc/asterisk/pjsip_accounts.conf")

# Base dirs are env-overridable so the service can run outside the VM (dev/tests) and
# so an operator can relocate state. Defaults match the production layout.
FAMILY_DIR = os.environ.get("UPES_FAMILY_DIR", "/opt/upes-ecs/family")
FAMILIES_CSV = os.path.join(FAMILY_DIR, "families.csv")     # parent_sap,child_sap  (one per line)
CAMPUS_JSON = os.path.join(FAMILY_DIR, "campus.json")       # {"lat":..,"lon":..,"radiusM":..}
DIRECTORY_JSON = os.path.join(FAMILY_DIR, "directory.json") # {sap: {name, kind}}  (copy of Console/directory.json)

STATE_DIR = os.environ.get("UPES_STATE_DIR", "/var/lib/upes-ecs")
LOC_DIR = os.path.join(STATE_DIR, "location")
LOC_TRAIL = os.path.join(LOC_DIR, "trail.ndjson")           # append-only breadcrumb history
SAFETY_DIR = os.path.join(STATE_DIR, "safety")
SAFE_LOG = os.path.join(SAFETY_DIR, "declared.ndjson")      # append-only "I'm safe / need help"
NEEDHELP_ALERTS = os.path.join(SAFETY_DIR, "needhelp-pending.log")  # Console-visible urgent list
EMERGENCY_FLAG = os.path.join(SAFETY_DIR, "emergency.json") # {"active":bool,"since":iso,"reason":..,"by":..}

# Per-user voice language: the app writes it here and the Asterisk dialplan reads it at
# call time via astdb DB(lang/<ext>). Repo source of truth is provisioning/user-languages.csv;
# this is the live copy the API upserts (header: ext,lang). Lives beside family/ runtime config.
USER_LANG_CSV = os.environ.get("UPES_USER_LANG_CSV", os.path.join(FAMILY_DIR, "user-languages.csv"))
# i18n/languages.json validates the language code. Resolved robustly at call time (see
# _languages_path); env override for odd layouts. If it can't be found we accept ^[a-z]{2,3}$.
LANGUAGES_JSON = os.environ.get("UPES_LANGUAGES_JSON", "")
# Campus default voice language: env wins, else the catalog "default", else English.
DEFAULT_LANG = os.environ.get("UPES_DEFAULT_LANG", "")

# ERT / control positions that may drive the emergency campaign + see the map.
OPERATOR_EXTS = {"4101", "4110", "4111", "4112", "4113", "4120"}
OPERATOR_PREFIXES = ("41", "42", "43", "44", "45", "46")   # responders/dispatch too

# A phone that pinged within this window is "app-active" (independent of SIP registration).
APP_ACTIVE_SEC = 150
# A safe declaration older than this is considered stale once a fresh emergency starts.
SAFE_FRESH_SEC = 3600
# Default campus geofence -- UPES Bidholi / Energy Acres (Dehradun). Override via campus.json.
CAMPUS_DEFAULT = {"lat": 30.4159443, "lon": 77.9668329, "radiusM": 800}

app = FastAPI(title="upes-safety-api", version="1.0")
security = HTTPBasic()

# --------------------------------------------------------------------------- #
# Small helpers (defensive: never raise)
# --------------------------------------------------------------------------- #

def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S%z")


def ensure_dirs():
    for d in (FAMILY_DIR, LOC_DIR, SAFETY_DIR):
        try:
            os.makedirs(d, exist_ok=True)
        except Exception:
            pass


def append_ndjson(path, obj):
    try:
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(obj, separators=(",", ":")) + "\n")
    except Exception:
        pass


def read_lines(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read().splitlines()
    except Exception:
        return []


def read_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except Exception:
        return default


def haversine_m(lat1, lon1, lat2, lon2):
    """Great-circle distance in metres, 0 on bad input."""
    try:
        r = 6371000.0
        p1, p2 = math.radians(lat1), math.radians(lat2)
        dphi = math.radians(lat2 - lat1)
        dlmb = math.radians(lon2 - lon1)
        a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
        return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    except Exception:
        return 0.0


# --------------------------------------------------------------------------- #
# Account map (auth) -- parsed from pjsip_accounts.conf, cached by mtime
# --------------------------------------------------------------------------- #

_accounts = {"mtime": 0, "map": {}}
_accounts_lock = threading.Lock()

_USER_RE = re.compile(r'^\s*username\s*=\s*(\S+)\s*$')
_PASS_RE = re.compile(r'^\s*password\s*=\s*(\S+)\s*$')


def account_map():
    """username -> password, parsed from the SIP source of truth. Re-reads on change."""
    try:
        mtime = os.path.getmtime(ACCOUNTS_CONF)
    except Exception:
        return {}
    with _accounts_lock:
        if mtime == _accounts["mtime"] and _accounts["map"]:
            return _accounts["map"]
        m, cur_user = {}, None
        for ln in read_lines(ACCOUNTS_CONF):
            um = _USER_RE.match(ln)
            if um:
                cur_user = um.group(1)
                continue
            pm = _PASS_RE.match(ln)
            if pm and cur_user:
                m[cur_user] = pm.group(1)
                cur_user = None
        _accounts["mtime"] = mtime
        _accounts["map"] = m
        return m


def authenticate(creds: HTTPBasicCredentials = Depends(security)) -> str:
    """Validate Basic creds against the SIP secret; return the SAP ID (username)."""
    users = account_map()
    want = users.get(creds.username or "")
    ok = bool(want) and hmac.compare_digest(want, creds.password or "")
    if not ok:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return creds.username


def is_operator(sap: str) -> bool:
    return sap in OPERATOR_EXTS or (len(sap) == 4 and sap.startswith(OPERATOR_PREFIXES))


def require_operator(sap: str):
    if not is_operator(sap):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="operator only")


# --------------------------------------------------------------------------- #
# Live in-memory state (latest position + latest safe declaration per SAP)
# --------------------------------------------------------------------------- #

_latest_loc = {}    # sap -> {lat,lon,acc,battery,ts(epoch),iso}
_latest_safe = {}   # sap -> {status,note,ts(epoch),iso}
_state_lock = threading.Lock()


def _load_persisted_state():
    """Rebuild in-memory latest-loc / latest-safe from the NDJSON trails on startup."""
    for ln in read_lines(LOC_TRAIL):
        try:
            o = json.loads(ln)
            _latest_loc[o["sap"]] = o
        except Exception:
            continue
    for ln in read_lines(SAFE_LOG):
        try:
            o = json.loads(ln)
            _latest_safe[o["sap"]] = o
        except Exception:
            continue


# --------------------------------------------------------------------------- #
# Emergency flag + campus geofence + directory
# --------------------------------------------------------------------------- #

def emergency_state():
    """Active if the operator flag is set OR a live 111 call is in progress."""
    flag = read_json(EMERGENCY_FLAG, {})
    active = bool(flag.get("active"))
    reason = flag.get("reason", "")
    since = flag.get("since", "")
    if not active and _live_111():
        active, reason, since = True, "live 111 call", now_iso()
    return {"active": active, "since": since, "reason": reason}


def set_emergency(active, reason, by):
    write = {"active": bool(active), "since": now_iso() if active else "",
             "reason": reason or "", "by": by}
    try:
        with open(EMERGENCY_FLAG, "w", encoding="utf-8") as fh:
            json.dump(write, fh)
    except Exception:
        pass
    return write


def _live_111():
    """True if any active channel is dialing/handling 111 (defensive, 0.5s cache)."""
    try:
        out = subprocess.run(
            ["asterisk", "-rx", "core show channels concise"],
            capture_output=True, text=True, timeout=4,
        ).stdout
        for ln in out.splitlines():
            f = ln.split("!")
            if len(f) > 2 and f[2] == "111":
                return True
    except Exception:
        pass
    return False


_online_cache = {"ts": 0, "set": set()}


def online_saps():
    """SAP IDs with a live SIP registration (pjsip contacts). Cached ~5s."""
    now = time.time()
    if now - _online_cache["ts"] < 5:
        return _online_cache["set"]
    saps = set()
    try:
        out = subprocess.run(
            ["asterisk", "-rx", "pjsip show contacts"],
            capture_output=True, text=True, timeout=6,
        ).stdout
        for ln in out.splitlines():
            m = re.search(r'([0-9]{3,9})/sip:', ln)
            if m:
                saps.add(m.group(1))
    except Exception:
        pass
    _online_cache["ts"] = now
    _online_cache["set"] = saps
    return saps


def campus():
    c = read_json(CAMPUS_JSON, {})
    return {
        "lat": c.get("lat", CAMPUS_DEFAULT["lat"]),
        "lon": c.get("lon", CAMPUS_DEFAULT["lon"]),
        "radiusM": c.get("radiusM", CAMPUS_DEFAULT["radiusM"]),
    }


_dir_cache = {"mtime": 0, "map": {}}


def directory():
    try:
        mtime = os.path.getmtime(DIRECTORY_JSON)
    except Exception:
        return _dir_cache["map"]
    if mtime != _dir_cache["mtime"]:
        _dir_cache["map"] = read_json(DIRECTORY_JSON, {})
        _dir_cache["mtime"] = mtime
    return _dir_cache["map"]


def name_of(sap):
    d = directory().get(sap)
    return d.get("name") if isinstance(d, dict) and d.get("name") else sap


# --------------------------------------------------------------------------- #
# Family map (parent_sap -> [child_sap, ...]) from families.csv
# --------------------------------------------------------------------------- #

_fam_cache = {"mtime": 0, "map": {}}


def family_map():
    try:
        mtime = os.path.getmtime(FAMILIES_CSV)
    except Exception:
        return {}
    if mtime == _fam_cache["mtime"] and _fam_cache["map"]:
        return _fam_cache["map"]
    m = {}
    for ln in read_lines(FAMILIES_CSV):
        ln = ln.strip()
        if not ln or ln.startswith("#") or ln.lower().startswith("parent"):
            continue
        parts = [p.strip() for p in ln.split(",")]
        if len(parts) < 2 or not parts[0] or not parts[1]:
            continue
        m.setdefault(parts[0], [])
        if parts[1] not in m[parts[0]]:
            m[parts[0]].append(parts[1])
    _fam_cache["mtime"] = mtime
    _fam_cache["map"] = m
    return m


# --------------------------------------------------------------------------- #
# Per-user voice language (ext -> lang code) -- app writes it, dialplan reads astdb
# --------------------------------------------------------------------------- #

_SAP_DIGITS_RE = re.compile(r'^\d{3,}$')
_LANG_FALLBACK_RE = re.compile(r'^[a-z]{2,3}$')

# languages.json catalog (code set + default), cached by mtime; codes=None => file absent.
_lang_catalog_cache = {"mtime": 0, "codes": None, "default": ""}
# runtime ext->lang store parsed from USER_LANG_CSV, cached by mtime.
_lang_cache = {"mtime": 0, "map": {}}


def _languages_path():
    """Best-effort locate i18n/languages.json. Env override wins; else probe the repo
    layout relative to this file and the production install root. None if not found."""
    if LANGUAGES_JSON:
        return LANGUAGES_JSON if os.path.isfile(LANGUAGES_JSON) else None
    here = os.path.dirname(os.path.abspath(__file__))
    for cand in (
        os.path.join(here, "..", "i18n", "languages.json"),   # repo checkout (api/ -> ../i18n)
        os.path.join(here, "i18n", "languages.json"),
        "/opt/upes-ecs/i18n/languages.json",                  # VM, if i18n was shipped
        os.path.join(FAMILY_DIR, "languages.json"),
    ):
        if os.path.isfile(cand):
            return cand
    return None


def language_catalog():
    """(codes, default). codes is a set of known 2-3 letter codes, or None if the
    catalog file can't be found (caller then falls back to a regex + English default)."""
    path = _languages_path()
    if not path:
        return None, (DEFAULT_LANG or "en")
    try:
        mtime = os.path.getmtime(path)
    except Exception:
        return None, (DEFAULT_LANG or "en")
    if mtime != _lang_catalog_cache["mtime"] or _lang_catalog_cache["codes"] is None:
        data = read_json(path, {})
        codes = {l.get("code") for l in data.get("languages", []) if isinstance(l, dict) and l.get("code")}
        _lang_catalog_cache["codes"] = codes or None
        _lang_catalog_cache["default"] = DEFAULT_LANG or data.get("default", "en")
        _lang_catalog_cache["mtime"] = mtime
    return _lang_catalog_cache["codes"], (_lang_catalog_cache["default"] or "en")


def default_lang():
    return language_catalog()[1]


def valid_lang(code):
    """Known code per languages.json; if the catalog is missing, accept ^[a-z]{2,3}$."""
    if not code:
        return False
    codes, _ = language_catalog()
    if codes is None:
        return bool(_LANG_FALLBACK_RE.match(code))
    return code in codes


def lang_map():
    """ext -> lang from the runtime CSV (header ext,lang). Re-reads on change."""
    try:
        mtime = os.path.getmtime(USER_LANG_CSV)
    except Exception:
        return {}
    if mtime == _lang_cache["mtime"] and _lang_cache["map"]:
        return _lang_cache["map"]
    m = {}
    for ln in read_lines(USER_LANG_CSV):
        ln = ln.strip()
        if not ln or ln.startswith("#") or ln.lower().startswith("ext"):
            continue
        parts = [p.strip() for p in ln.split(",")]
        if len(parts) < 2 or not parts[0] or not parts[1]:
            continue
        m[parts[0]] = parts[1]
    _lang_cache["mtime"] = mtime
    _lang_cache["map"] = m
    return m


def lang_of(sap):
    """Current preferred language for a user: runtime CSV wins, then a 'lang' field on
    the directory entry (if present), else '' (caller applies the campus default)."""
    v = lang_map().get(sap)
    if v:
        return v
    d = directory().get(sap)
    if isinstance(d, dict) and d.get("lang"):
        return d.get("lang")
    return ""


def set_lang(sap, code):
    """Upsert ext->lang into the runtime CSV (full rewrite, header preserved). Returns
    True on a durable write. Defensive: any failure returns False, never raises."""
    m = dict(lang_map())
    m[sap] = code
    try:
        d = os.path.dirname(USER_LANG_CSV) or "."
        os.makedirs(d, exist_ok=True)
        tmp = USER_LANG_CSV + ".tmp"
        with open(tmp, "w", encoding="utf-8") as fh:
            fh.write("ext,lang\n")
            for k in sorted(m):
                fh.write("%s,%s\n" % (k, m[k]))
        os.replace(tmp, USER_LANG_CSV)
        _lang_cache["mtime"] = 0   # force reload on next read
        return True
    except Exception:
        return False


def apply_lang_live(sap, code):
    """Push the language into Asterisk's astdb so DB(lang/<ext>) is live for the NEXT
    call without a reload. Returns True if asterisk accepted it, False if unreachable."""
    try:
        r = subprocess.run(
            ["asterisk", "-rx", "database put lang %s %s" % (sap, code)],
            capture_output=True, text=True, timeout=4,
        )
        out = ((r.stdout or "") + (r.stderr or "")).lower()
        return ("success" in out) or (r.returncode == 0 and "unable" not in out)
    except Exception:
        return False


# --------------------------------------------------------------------------- #
# Status assembly for a single person
# --------------------------------------------------------------------------- #

def child_status(sap, emergency_since_epoch=None):
    now = time.time()
    online = online_saps()
    camp = campus()

    with _state_lock:
        loc = _latest_loc.get(sap)
        safe = _latest_safe.get(sap)

    loc_out, oncampus = None, None
    if loc:
        age = int(now - loc.get("ts", 0))
        dist = haversine_m(camp["lat"], camp["lon"], loc.get("lat", 0), loc.get("lon", 0))
        oncampus = dist <= camp["radiusM"]
        loc_out = {
            "lat": loc.get("lat"), "lon": loc.get("lon"),
            "acc": loc.get("acc"), "ageSec": age,
            "distM": round(dist), "battery": loc.get("battery"),
        }

    # Safe state is only meaningful if declared AFTER the emergency began (or recently).
    safe_status, safe_age = "unknown", None
    if safe:
        s_age = int(now - safe.get("ts", 0))
        fresh_cut = emergency_since_epoch if emergency_since_epoch else (now - SAFE_FRESH_SEC)
        if safe.get("ts", 0) >= fresh_cut:
            safe_status = safe.get("status", "unknown")
            safe_age = s_age

    return {
        "sap": sap,
        "name": name_of(sap),
        "registered": sap in online,
        "appActive": bool(loc and (now - loc.get("ts", 0)) <= APP_ACTIVE_SEC),
        "location": loc_out,
        "onCampus": oncampus,
        "safe": safe_status,           # safe | needshelp | unknown
        "safeAgeSec": safe_age,
    }


def _emergency_since_epoch():
    e = emergency_state()
    if not e["active"]:
        return None
    try:
        return datetime.strptime(e["since"][:19], "%Y-%m-%dT%H:%M:%S").replace(
            tzinfo=timezone.utc).timestamp()
    except Exception:
        return None


# --------------------------------------------------------------------------- #
# Routes
# --------------------------------------------------------------------------- #

@app.get("/health")
def health():
    return {"ok": True, "service": "upes-safety-api", "users": len(account_map())}


@app.post("/loc")
async def post_loc(request: Request, sap: str = Depends(authenticate)):
    """A phone reports its position. Returns whether an emergency is active so the app
    can speed up its ping cadence and surface the 'I'm safe' prompt."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    try:
        lat = float(body.get("lat"))
        lon = float(body.get("lon"))
    except Exception:
        raise HTTPException(status_code=422, detail="lat/lon required (numeric)")
    rec = {
        "sap": sap, "lat": lat, "lon": lon,
        "acc": body.get("acc"), "battery": body.get("battery"),
        "ts": time.time(), "iso": now_iso(),
    }
    with _state_lock:
        _latest_loc[sap] = rec
    append_ndjson(LOC_TRAIL, rec)
    return {"ok": True, "emergency": emergency_state()}


@app.post("/safe")
async def post_safe(request: Request, sap: str = Depends(authenticate)):
    """A student self-declares 'safe' or 'needshelp'. 'needshelp' also lands on the
    Console's urgent list so the ERT sees it immediately."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    st = body.get("status")
    if st not in ("safe", "needshelp"):
        raise HTTPException(status_code=422, detail="status must be 'safe' or 'needshelp'")
    note = str(body.get("note", ""))[:200]
    rec = {"sap": sap, "name": name_of(sap), "status": st, "note": note,
           "ts": time.time(), "iso": now_iso()}
    with _state_lock:
        _latest_safe[sap] = rec
    append_ndjson(SAFE_LOG, rec)
    if st == "needshelp":
        try:
            with open(NEEDHELP_ALERTS, "a", encoding="utf-8") as fh:
                fh.write("%s|%s|%s|%s\n" % (rec["iso"], sap, rec["name"], note))
        except Exception:
            pass
    return {"ok": True, "recorded": st}


@app.get("/me")
def get_me(sap: str = Depends(authenticate)):
    return {
        "sap": sap, "name": name_of(sap),
        "isParent": sap in family_map(),
        "isOperator": is_operator(sap),
        "lang": lang_of(sap),
        "emergency": emergency_state(),
        "status": child_status(sap, _emergency_since_epoch()),
    }


@app.get("/lang")
def get_lang(sap: str = "", caller: str = Depends(authenticate)):
    """Read a user's preferred voice language. Defaults to the caller; querying another
    user's setting is operator-only (mirrors /map). Returns the campus default too."""
    target = (sap or caller).strip()
    if target != caller and not is_operator(caller):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="operator only")
    return {"ext": target, "lang": lang_of(target), "default": default_lang()}


@app.post("/lang")
async def post_lang(request: Request, caller: str = Depends(authenticate)):
    """Set a user's preferred voice language. Persists to the runtime CSV AND pushes it
    live into astdb (DB(lang/<ext>)) so the next 111 call is answered in that language.
    Persistence and live-apply are independent: 'applied' reports the astdb push only."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    target = str(body.get("sap", "") or "").strip()
    code = str(body.get("lang", "") or "").strip().lower()
    if not _SAP_DIGITS_RE.match(target):
        raise HTTPException(status_code=422, detail="sap must be digits (>=3)")
    if not valid_lang(code):
        raise HTTPException(status_code=422, detail="unknown language code")
    # A user may set their own language; operators may set anyone's.
    if target != caller and not is_operator(caller):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="operator only")
    persisted = set_lang(target, code)
    applied = apply_lang_live(target, code)
    return {"ok": persisted, "ext": target, "lang": code,
            "default": default_lang(), "applied": applied}


@app.get("/emergency")
def get_emergency(sap: str = Depends(authenticate)):
    return emergency_state()


@app.post("/emergency")
async def post_emergency(request: Request, sap: str = Depends(authenticate)):
    """Operator raises/clears the campus 'mark yourself safe' campaign."""
    require_operator(sap)
    try:
        body = await request.json()
    except Exception:
        body = {}
    active = bool(body.get("active", True))
    reason = str(body.get("reason", ""))[:120]
    return {"ok": True, "emergency": set_emergency(active, reason, sap)}


@app.get("/family")
def get_family(sap: str = Depends(authenticate)):
    """A parent sees the live status of each linked child."""
    children = family_map().get(sap, [])
    since = _emergency_since_epoch()
    return {
        "parent": {"sap": sap, "name": name_of(sap)},
        "emergency": emergency_state(),
        "children": [child_status(c, since) for c in children],
    }


@app.get("/map")
def get_map(sap: str = Depends(authenticate)):
    """Operator view: latest position + status of everyone who has ever reported."""
    require_operator(sap)
    since = _emergency_since_epoch()
    with _state_lock:
        saps = list(_latest_loc.keys())
    people = [child_status(s, since) for s in saps]
    return {"campus": campus(), "emergency": emergency_state(), "people": people}


# --------------------------------------------------------------------------- #

@app.on_event("startup")
def _startup():
    ensure_dirs()
    _load_persisted_state()


if __name__ == "__main__":
    import uvicorn  # imported lazily so the app can be imported (tests/tools) without uvicorn
    ensure_dirs()
    _load_persisted_state()
    # Bind all interfaces: campus phones reach this directly over Wi-Fi. Every route
    # except /health requires HTTP Basic (SIP secret), so this is safe on the LAN.
    uvicorn.run(app, host="0.0.0.0", port=8091)
