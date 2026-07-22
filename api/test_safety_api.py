"""End-to-end tests for safety_api.py.

Runs the real FastAPI app against a temp environment (fake accounts file + family
links + campus geofence), exercising every route and the family/safety logic.
No Asterisk needed -- the `asterisk -rx` calls degrade to empty (defensive), so
SIP-registration is simply reported False here.

Run:  python api/test_safety_api.py     (needs: pip install fastapi httpx)
Exit code is non-zero if any check fails, so it doubles as a CI gate.
"""
import base64
import importlib.util
import json
import os
import sys
import tempfile

_API_DIR = os.path.dirname(os.path.abspath(__file__))

TMP = tempfile.mkdtemp(prefix="upes-safety-test-")
FAM = os.path.join(TMP, "family")
STATE = os.path.join(TMP, "state")
os.makedirs(FAM, exist_ok=True)
os.makedirs(STATE, exist_ok=True)

ACCOUNTS = os.path.join(TMP, "pjsip_accounts.conf")
with open(ACCOUNTS, "w", encoding="utf-8") as f:
    f.write("""
[500120597](auth-tpl)
username=500120597
password=childsecret01
[40009001](auth-tpl)
username=40009001
password=parentsecret9
[4110](auth-tpl)
username=4110
password=operatorsecret
""")
with open(os.path.join(FAM, "families.csv"), "w", encoding="utf-8") as f:
    f.write("parent_sap,child_sap\n40009001,500120597\n")
with open(os.path.join(FAM, "campus.json"), "w", encoding="utf-8") as f:
    json.dump({"lat": 30.4166, "lon": 77.9666, "radiusM": 900}, f)
with open(os.path.join(FAM, "directory.json"), "w", encoding="utf-8") as f:
    json.dump({"500120597": {"name": "Rohan Batra", "kind": "student"}}, f)

os.environ["UPES_ACCOUNTS_CONF"] = ACCOUNTS
os.environ["UPES_FAMILY_DIR"] = FAM
os.environ["UPES_STATE_DIR"] = STATE

# Import safety_api.py by path so this test runs from any working directory.
_spec = importlib.util.spec_from_file_location(
    "safety_api", os.path.join(_API_DIR, "safety_api.py"))
safety = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(safety)
from fastapi.testclient import TestClient  # noqa: E402


def auth(user, pw):
    return {"Authorization": "Basic " + base64.b64encode(f"{user}:{pw}".encode()).decode()}


CHILD = auth("500120597", "childsecret01")
PARENT = auth("40009001", "parentsecret9")
OPER = auth("4110", "operatorsecret")
BAD = auth("500120597", "wrongpw")

passed = failed = 0


def check(name, cond):
    global passed, failed
    if cond:
        passed += 1
        print(f"  PASS  {name}")
    else:
        failed += 1
        print(f"  FAIL  {name}")


with TestClient(safety.app) as c:
    r = c.get("/health")
    check("health ok", r.status_code == 200 and r.json()["ok"] is True)
    check("health counts 3 users", r.json()["users"] == 3)

    check("no-auth 401 on /me", c.get("/me").status_code == 401)
    check("bad-pw 401 on /me", c.get("/me", headers=BAD).status_code == 401)
    check("good-auth 200 on /me", c.get("/me", headers=CHILD).status_code == 200)

    r = c.post("/loc", headers=CHILD, json={"lat": 30.4166, "lon": 77.9666, "acc": 8})
    check("loc accepted", r.status_code == 200 and r.json()["ok"])
    check("no emergency yet", r.json()["emergency"]["active"] is False)
    check("loc rejects non-numeric", c.post("/loc", headers=CHILD, json={"lat": "x"}).status_code == 422)

    r = c.get("/family", headers=PARENT)
    check("family 200", r.status_code == 200)
    kids = r.json()["children"]
    check("family has 1 child", len(kids) == 1)
    check("child name resolved", kids[0]["name"] == "Rohan Batra")
    check("child on campus", kids[0]["onCampus"] is True)
    check("child safe unknown pre-declare", kids[0]["safe"] == "unknown")
    check("child appActive after ping", kids[0]["appActive"] is True)
    check("child /family empty (not a parent)", len(c.get("/family", headers=CHILD).json()["children"]) == 0)

    r = c.post("/emergency", headers=OPER, json={"active": True, "reason": "drill"})
    check("operator can raise emergency", r.status_code == 200 and r.json()["emergency"]["active"])
    check("child forbidden from raising emergency", c.post("/emergency", headers=CHILD, json={"active": True}).status_code == 403)
    check("emergency now active", c.get("/emergency", headers=CHILD).json()["active"] is True)

    check("safe rejects bad status", c.post("/safe", headers=CHILD, json={"status": "maybe"}).status_code == 422)
    r = c.post("/safe", headers=CHILD, json={"status": "safe"})
    check("safe recorded", r.status_code == 200 and r.json()["recorded"] == "safe")
    check("parent sees child SAFE", c.get("/family", headers=PARENT).json()["children"][0]["safe"] == "safe")

    c.post("/safe", headers=CHILD, json={"status": "needshelp", "note": "stuck in Block B"})
    check("parent sees child NEEDSHELP", c.get("/family", headers=PARENT).json()["children"][0]["safe"] == "needshelp")
    alert = os.path.join(STATE, "safety", "needhelp-pending.log")
    check("needhelp alert file written", os.path.exists(alert) and "stuck in Block B" in open(alert).read())

    r = c.get("/map", headers=OPER)
    check("map operator 200", r.status_code == 200)
    check("map lists the child", any(p["sap"] == "500120597" for p in r.json()["people"]))
    check("child cannot see map", c.get("/map", headers=CHILD).status_code == 403)

    c.post("/loc", headers=CHILD, json={"lat": 28.6139, "lon": 77.2090})  # far away
    check("child now OFF campus", c.get("/family", headers=PARENT).json()["children"][0]["onCampus"] is False)

    safety._latest_loc.clear()
    safety._latest_safe.clear()
    safety._load_persisted_state()
    check("loc persisted across reload", "500120597" in safety._latest_loc)
    check("safe persisted across reload", safety._latest_safe.get("500120597", {}).get("status") == "needshelp")

    # --- per-user voice language (/lang) ------------------------------------ #
    # Stub the `asterisk -rx "database put lang ..."` call so tests need no PBX.
    class _FakeProc:
        returncode = 0
        stdout = "Updated database successfully.\n"
        stderr = ""

    _apply_calls = []
    _real_run = safety.subprocess.run

    def _fake_run(cmd, *a, **k):
        # Only intercept the astdb write; anything else keeps degrading to empty.
        if isinstance(cmd, list) and len(cmd) >= 3 and cmd[2].startswith("database put lang"):
            _apply_calls.append(cmd[2])
            return _FakeProc()
        return _real_run(cmd, *a, **k)

    safety.subprocess.run = _fake_run
    try:
        # GET default: no language set yet -> empty lang, campus default present.
        r = c.get("/lang", headers=CHILD)
        check("lang GET default 200", r.status_code == 200)
        check("lang GET unset is empty", r.json()["lang"] == "")
        check("lang GET reports campus default", r.json()["default"] == safety.default_lang())
        check("lang GET echoes ext", r.json()["ext"] == "500120597")

        # POST valid: child sets own language; persists + applies to (stubbed) astdb.
        r = c.post("/lang", headers=CHILD, json={"sap": "500120597", "lang": "hi"})
        check("lang POST valid 200", r.status_code == 200 and r.json()["ok"] is True)
        check("lang POST applied to astdb", r.json()["applied"] is True)
        check("lang POST wrote astdb key", any("500120597 hi" in x for x in _apply_calls))

        # POST rejects a non-digit SAP.
        check("lang POST bad sap 422",
              c.post("/lang", headers=CHILD, json={"sap": "abc", "lang": "hi"}).status_code == 422)
        # POST rejects a code that isn't in languages.json.
        check("lang POST unknown lang 422",
              c.post("/lang", headers=CHILD, json={"sap": "500120597", "lang": "zz"}).status_code == 422)

        # GET-after-POST round-trip reflects the new value (from the runtime CSV).
        check("lang GET after POST is hi", c.get("/lang", headers=CHILD).json()["lang"] == "hi")
        # /me now surfaces the language without breaking its shape.
        me = c.get("/me", headers=CHILD).json()
        check("me still has sap/name", me["sap"] == "500120597" and me["name"] == "Rohan Batra")
        check("me now carries lang", me.get("lang") == "hi")

        # A non-operator cannot change someone else's language.
        check("lang POST cross-user 403",
              c.post("/lang", headers=CHILD, json={"sap": "500000002", "lang": "hi"}).status_code == 403)
        # An operator can.
        r = c.post("/lang", headers=OPER, json={"sap": "500000002", "lang": "te"})
        check("operator sets other user's lang", r.status_code == 200 and r.json()["ok"] is True)
        check("operator reads other user's lang",
              c.get("/lang", headers=OPER, params={"sap": "500000002"}).json()["lang"] == "te")

        # Runtime CSV really was written (durable across process restart).
        csv_path = os.path.join(FAM, "user-languages.csv")
        check("lang CSV persisted", os.path.exists(csv_path) and "500120597,hi" in open(csv_path).read())
    finally:
        safety.subprocess.run = _real_run

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
