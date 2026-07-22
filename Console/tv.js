/* ==========================================================================
   UPES-ECS — Campus LED-TV wallboards, shared engine.
   One file drives both screens; the layout is chosen by <body data-screen>.
   Realtime: polls /api/status (Console proxy → in-VM API) every REFRESH ms,
   falls back to /status.json, and degrades gracefully (live→stale→down) so the
   board is NEVER blank on a glitch. Auto-reloads itself when assets are redeployed.
   ========================================================================== */
(() => {
  "use strict";
  const REFRESH_FULL = 5000;   // heavy /status (analytics/CDR/presence) — slow-changing
  const LIVE_GAP = 500;        // gap AFTER each /live completes — fast so a call-end clears within ~1s
  const TIMEOUT = 8000;        // per-request abort
  const STALE_AFTER = 13000;   // no fresh data for this long → amber "stale"
  const DOWN_AFTER = 26000;    // …this long → red "offline" + veil
  const LIVE_STALE_MS = 6000;  // server-stamped body age beyond which the call count is NOT live
  const SCREEN = document.body.dataset.screen || "ops";

  // GUARDRAIL: a 200 is not proof of freshness — the console serves a frozen last-good body
  // (X-Upes-Cache: stale) during a VM/tunnel blip, which would otherwise bump lastOkAt and keep the
  // Active-calls count showing as live. liveStale is read from that header (+ the skew-proof
  // X-Upes-Age-Ms from Serve.ps1 G3) and folded into conn() so the count hard-blanks to UNKNOWN.
  let liveStale = false;         // last /live or /status response could not be proven fresh
  let liveCacheHdr = "", liveAgeHdr = null;   // captured from the most recent /live|/status response
  let data = null, lastOkAt = 0, buildTok = null, dir = {}, region = null;
  const REGION_REFRESH = 180000;   // re-check the deployed language every 3 min

  // ---- tiny DOM helpers --------------------------------------------------
  const $ = (s, r = document) => r.querySelector(s);
  const setText = (s, t) => { const n = $(s); if (n && n.textContent !== String(t)) n.textContent = t; };
  function el(tag, cls, html) { const n = document.createElement(tag); if (cls) n.className = cls; if (html != null) n.innerHTML = html; return n; }
  const esc = (s) => String(s == null ? "" : s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));

  // ---- formatting --------------------------------------------------------
  const pad = (n) => String(n).padStart(2, "0");
  function fmtDur(s) { s = Math.max(0, s | 0); const h = s / 3600 | 0, m = (s % 3600) / 60 | 0, x = s % 60; return h ? `${h}:${pad(m)}:${pad(x)}` : `${m}:${pad(x)}`; }
  function ago(ms) { const s = Math.max(0, ms / 1000 | 0); if (s < 60) return s + "s"; const m = s / 60 | 0; if (m < 60) return m + "m"; const h = m / 60 | 0; return h < 48 ? h + "h" : (h / 24 | 0) + "d"; }
  function shortTime(t) { const m = /(\d{2}:\d{2}:\d{2})/.exec(t || ""); return m ? m[1] : (t || ""); }

  // ext → display name (from directory.json, generated from the source of truth)
  function label(ext) {
    ext = String(ext || "").trim();
    if (dir[ext]) return dir[ext].name;
    if (/^411\d$/.test(ext)) return "ERT Operator";
    if (ext === "4101") return "ERT Lead";
    if (ext === "4120") return "ERT Control";
    if (/^4[2-6]\d\d$/.test(ext)) return "Responder " + ext;
    return ext || "—";
  }
  const extOf = (iface) => (/(\d{3,})/.exec(iface || "") || [, ""])[1];

  // fill an element with name chips resolved from a list of extensions (capped + "+N more")
  function fillNames(sel, exts, cls) {
    const box = $(sel); if (!box) return;
    box.innerHTML = "";
    const list = exts || [], cap = 14;
    list.slice(0, cap).forEach(e => box.appendChild(el("span", cls, esc(label(e)))));
    if (list.length > cap) box.appendChild(el("span", "more", "+" + (list.length - cap) + " more"));
  }

  // call kind from destination + last app (mirrors the API's classifier)
  function callKind(dst, app) {
    dst = String(dst || ""); app = String(app || "").toLowerCase();
    if (dst === "111") return "emergency";
    if (dst === "199" || app.includes("drill")) return "drill";
    if (dst === "198" || app === "echo") return "echo";
    if (dst.slice(0, 3) === "900" || app.includes("confbridge")) return "bridge";
    if ((dst.length === 3 && dst[0] === "7") || app === "page") return "paging";
    return "other";
  }
  // pjsip endpoint/queue member state → semantic class
  function stateClass(st) {
    st = (st || "").toLowerCase();
    if (st === "not in use") return "ok";
    if (st === "in use" || st === "ringing") return "info";
    if (st === "busy") return "warn";
    if (st === "paused") return "warn";
    return "idle"; // unavailable / invalid / unknown
  }
  const stateWord = (st) => (st || "").toLowerCase() === "not in use" ? "READY" : (st || "—").toUpperCase();

  // ---- data layer --------------------------------------------------------
  async function fetchJSON(url) {
    const ac = new AbortController();
    const to = setTimeout(() => ac.abort(), TIMEOUT);
    try {
      const r = await fetch(url, { signal: ac.signal, cache: "no-store" });
      if (!r.ok) throw new Error(r.status);
      // GUARDRAIL: capture the console's freshness headers from the live/status endpoints only
      // (not /__build|/directory|/region). Same-origin, so custom headers are readable.
      if (url.indexOf("/api/live") >= 0 || url.indexOf("/api/status") >= 0) {
        try { liveCacheHdr = (r.headers.get("X-Upes-Cache") || "").toLowerCase(); } catch (_) { liveCacheHdr = ""; }
        try { const a = r.headers.get("X-Upes-Age-Ms"); liveAgeHdr = (a != null && a !== "") ? +a : null; } catch (_) { liveAgeHdr = null; }
      }
      return await r.json();
    } finally { clearTimeout(to); }
  }
  // Turn the captured headers into the liveStale verdict. stale header = console served a frozen
  // last-good body (works today); X-Upes-Age-Ms = skew-proof age (Serve.ps1 G3, after restart).
  function assessLiveFreshness() {
    liveStale = (liveCacheHdr === "stale") ||
      (liveAgeHdr != null && isFinite(liveAgeHdr) && liveAgeHdr > LIVE_STALE_MS);
  }
  // full snapshot: everything (analytics, CDR, presence, missed, shift, rollcall). Slow-changing.
  async function pollFull() {
    let d = null, viaApi = false;
    try { d = await fetchJSON("/api/status"); viaApi = true; }
    catch (_) { try { d = await fetchJSON("/status.json"); } catch (_) { } }
    if (d && d.state) {
      data = d; lastOkAt = Date.now();
      if (viaApi) assessLiveFreshness(); else liveStale = true;   // disk snapshot is never realtime
      render();
    }
  }
  // live snapshot: only the fast-changing call/queue fields, merged onto the last full snapshot so
  // an ended call clears within ~1-2s instead of waiting for the heavy full poll.
  const LIVE_FIELDS = ["asterisk", "activeCalls", "liveCalls", "queueAvailable", "queueMembers", "updated"];
  async function pollLive() {
    let d = null;
    try { d = await fetchJSON("/api/live"); } catch (_) { return; }
    if (!d) return;
    lastOkAt = Date.now();
    assessLiveFreshness();
    if (data) { LIVE_FIELDS.forEach(k => { if (k in d) data[k] = d[k]; }); }
    else { data = d; }
    render();
  }
  // self-rescheduling so requests never overlap on the slow PBX (wait LIVE_GAP after each completes).
  // anti-stampede: jitter the gap so boards don't poll /live in lockstep; gently back off on failure.
  let liveErr = 0;   // consecutive /live failures → progressive backoff (reset the instant one succeeds)
  async function liveLoop() {
    const before = lastOkAt;                 // pollLive only bumps lastOkAt on success
    try { await pollLive(); } catch (_) { }  // keep the loop alive no matter what
    liveErr = (lastOkAt === before) ? Math.min(liveErr + 1, 5) : 0;
    // base 700ms +/-30% jitter de-syncs boards; add up to ~3s while failing (stays < STALE_AFTER)
    const gap = (LIVE_GAP + liveErr * 600) * (0.7 + Math.random() * 0.6);
    setTimeout(liveLoop, gap);
  }
  function conn() {
    if (!lastOkAt) return "down";
    const age = Date.now() - lastOkAt;
    // GUARDRAIL: serve-stale returns HTTP 200 (bumps lastOkAt), so time-since-success alone would
    // wrongly read "live". If the console flagged the body as not-fresh, force at least "stale".
    if (liveStale) return age > DOWN_AFTER ? "down" : "stale";
    return age > DOWN_AFTER ? "down" : age > STALE_AFTER ? "stale" : "live";
  }

  // auto-reload when the Console redeploys the TV assets
  async function checkBuild() {
    // anti-stampede: stagger the post-deploy reload over ~3s so boards don't all reconnect in the same
    // instant (buildTok updates immediately, so a pending reload is never double-scheduled).
    try { const b = (await fetchJSON("/__build")).build; if (buildTok && b !== buildTok) setTimeout(() => location.reload(), Math.random() * 3000); buildTok = b; } catch (_) { }
  }
  async function loadDir() { try { dir = await fetchJSON("/directory.json") || {}; } catch (_) { } }

  // ---- region / language (written by Deploy-UPES; absent ⇒ English default) ----
  async function loadRegion() {
    try { const r = await fetchJSON("/region.json"); if (r && (r.language || r.languageName)) region = r; }
    catch (_) { /* absent / offline — English default */ }
    paintRegion();
  }
  function paintRegion() {
    const chip = $(".region"); if (!chip) return;
    const r = region || {};
    const code = String(r.language || "en").toLowerCase();
    const isEn = !code || code === "en";
    const native = r.native || r.languageName || (isEn ? "EN" : code.toUpperCase());
    setText(".region .lab", isEn ? "EN" : native);
    // english-fallback ⇒ pack not localised yet; softly flag that audio is still English.
    const fb = !isEn && r.prompts === "english-fallback";
    const note = $(".region .fb"); if (note) note.hidden = !fb;
    chip.title = "Deployed language: " + (r.languageName || (isEn ? "English" : native)) +
      (fb ? " — voice prompts still play in English (pack not localised yet)" : "");
  }

  // ---- shared chrome (clock + connection) --------------------------------
  function paintClock() {
    const now = new Date();
    const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
    const mons = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    setText(".clock .t", `${pad(now.getHours())}:${pad(now.getMinutes())}`);
    const sec = $(".clock .t .sec"); // optional seconds handled in markup if present
    setText(".clock .d", `${days[now.getDay()]} · ${now.getDate()} ${mons[now.getMonth()]} ${now.getFullYear()}`);
    paintConn();
  }
  function paintConn() {
    const c = conn(), dot = $(".conn .dot"), lab = $(".conn .lab");
    if (dot) dot.className = "dot " + c;
    if (lab) lab.textContent = c === "live" ? `live · ${ago(Date.now() - lastOkAt)} ago`
      : c === "stale" ? `stale · ${ago(Date.now() - lastOkAt)}` : "offline";
  }

  // ========================================================================
  // SCREEN 1 — PUBLIC SAFETY
  // ========================================================================
  function renderSafety() {
    const d = data, down = conn() === "down";
    const asteriskUp = d && d.asterisk === "active" && !down;

    // evacuation / roll-call takeover: active only for a RECENT roll-call that still has
    // unaccounted people. Recency is measured PBX-side (roll-call time vs the PBX's own
    // `updated` clock) — never the browser clock, which can be in a different timezone.
    const rc = d && d.rollcall;
    let rollcallRecent = false;
    if (rc && rc.called > 0 && rc.unaccounted > 0) {
      const rt = Date.parse(String(rc.time || "").replace(" ", "T"));
      const up = Date.parse(String(d.updated || "").replace(" ", "T"));
      // "active" = a roll-call started within the last 20 min (both times are PBX-side, so the
      // browser's timezone is irrelevant). Stale/abandoned test roll-calls age out to the hero.
      rollcallRecent = (isFinite(rt) && isFinite(up)) ? (up - rt) < 20 * 60 * 1000 : false;
    }
    // App-driven emergency (a live 111 call or an operator raising the campaign) also takes
    // over the board and shows the UPES Safe "I'm safe / need help" tally.
    const sf = d && d.safety;
    const appEmergency = !!(sf && sf.emergency && sf.emergency.active);
    const evacOn = rollcallRecent || appEmergency;

    document.body.classList.toggle("evac-on", evacOn);
    $(".evac").classList.toggle("show", evacOn);

    if (evacOn) {
      const critLabel = document.querySelectorAll(".evac .cbox .l")[2];
      const instruct = $(".evac .instruct");
      if (rollcallRecent) {
        // Roll-call (press-1) tally wins when one is running.
        setText(".evac .n.ok", rc.safe);
        setText(".evac .n.info", rc.responded);
        setText(".evac .n.crit", rc.unaccounted);
        fillNames("#ev-safe", rc.safeExts, "ok");
        fillNames("#ev-unacc", rc.unaccountedExts, "crit");
        if (critLabel) critLabel.textContent = "Unaccounted";
        if (instruct) instruct.innerHTML = "Answer your phone and <b>press 1</b> to mark yourself safe.";
      } else {
        // App-based tally (safe count + who tapped "need help").
        const safe = (sf.safeCount || 0), need = (sf.needHelpCount || 0);
        setText(".evac .n.ok", safe);
        setText(".evac .n.info", safe + need);
        setText(".evac .n.crit", need);
        fillNames("#ev-safe", [], "ok");
        fillNames("#ev-unacc", (sf.needHelp || []).map(h => h.sap), "crit");
        if (critLabel) critLabel.textContent = "Need help";
        if (instruct) instruct.innerHTML = "Open <b>UPES Safe</b> and tap <b>I'm safe</b> — or dial <b>111</b>.";
      }
      return;
    }

    // normal reassurance state
    const led = $(".statuscard .led"), lead = $(".statuscard .lead .txt"), note = $(".statuscard .note");
    if (asteriskUp) {
      led.className = "led ok"; lead.textContent = "Emergency line active";
      note.textContent = "Dial 111 from any campus phone — 24/7.";
    } else {
      led.className = "led crit"; lead.textContent = down ? "Status updating…" : "Line disruption";
      note.textContent = down ? "Reconnecting to the emergency system." : "If 111 does not connect, use a campus security phone.";
    }
    // responders ready — public board only reassures (shows the count when ≥1);
    // "0 ready" is an ops concern, not a public one, so it's hidden here (never alarm the lobby).
    const rcnt = $(".readycount");
    const q = d ? d.queueAvailable : null;
    if (asteriskUp && typeof q === "number" && q >= 1) {
      rcnt.style.display = "flex";           // display (not visibility) so it collapses when absent
      setText(".readycount b", q);
      setText(".readycount span", q === 1 ? "responder ready now" : "responders ready now");
      $(".readycount b").style.color = "var(--ok)";
    } else { rcnt.style.display = "none"; }
  }

  // ========================================================================
  // SCREEN 2 — OPERATIONS
  // ========================================================================
  const STATE_CLS = { READY: "s-ok", DEGRADED: "s-warn", CRITICAL: "s-crit", OFFLINE: "s-idle" };

  function kpi(v, label, cls, unit) {
    const k = el("div", "kpi " + (cls || ""));
    k.appendChild(el("div", "v " + (cls || ""), esc(v) + (unit ? `<span class="u">${esc(unit)}</span>` : "")));
    k.appendChild(el("div", "l", esc(label)));
    return k;
  }
  function rowsInto(sel, items, make, emptyMsg, cap = 8) {
    const box = $(sel); if (!box) return;
    box.innerHTML = "";
    if (!items || !items.length) { box.appendChild(el("div", "empty", esc(emptyMsg))); return; }
    const wrap = el("div", "rows");
    items.slice(0, cap).forEach(it => wrap.appendChild(make(it)));
    box.appendChild(wrap);
    const more = items.length - cap;
    const h = box.closest(".panel") && box.closest(".panel").querySelector(".count");
    if (h) h.textContent = items.length + (more > 0 ? "" : "");
  }

  function renderOps() {
    const d = data, c = conn();
    $(".veil").classList.toggle("show", c === "down");
    if (!d) return;

    // top bar
    setText("#host", d.hostname || "upes-ecs-pbx-01");
    const pill = $("#statepill");
    pill.className = "pill " + (STATE_CLS[d.state] || "s-idle");
    pill.querySelector(".txt").textContent = d.state || "—";
    setText("#ver", (d.version || "").replace(/Asterisk\s+([0-9.]+).*/, "Asterisk $1"));
    setText("#uptime", d.uptime ? "up " + d.uptime.replace(/,?\s*\d+ (minute|second).*/, "") : "");
    // registrar phones must use = the address Asterisk advertises (mediaAddress); host IP is only a fallback
    const reg = d.mediaAddress || d.serverIp;
    setText("#srvip", reg ? reg + ":5060" : "—");

    // KPI row
    const q = d.queueAvailable, min = d.minAgents || 1;
    const qcls = (q == null) ? "idle" : q <= 0 ? "crit" : (q <= min ? "warn" : "ok");
    const disk = d.diskPct, dcls = disk == null ? "idle" : disk >= 90 ? "crit" : disk >= 75 ? "warn" : "ok";
    const a = d.analytics || {}, em = a.emergency || {}, dr = a.drill || {};
    const kr = $("#kpis"); kr.innerHTML = "";
    kr.appendChild(kpi(q == null ? "—" : q, "ERT ready", qcls));
    kr.appendChild(kpi(d.registrations != null ? d.registrations : "—", "Endpoints online", "info"));
    // GUARDRAIL: the live 111 count is shown ONLY when the connection is proven live (conn() folds in
    // the serve-stale / X-Upes-Age-Ms freshness check). Otherwise hard-blank to UNKNOWN, never a frozen number.
    const callsFresh = conn() === "live";
    kr.appendChild(kpi(callsFresh ? (d.activeCalls || 0) : "—", "Active calls", callsFresh ? (d.activeCalls ? "info" : "") : "warn"));
    kr.appendChild(kpi(disk == null ? "—" : disk, "Disk", dcls, "%"));
    const fu = d.followups || { pending: 0, overdue: 0, queue: [] };
    kr.appendChild(kpi(fu.pending || 0, "Follow-ups due", fu.overdue ? "crit" : (fu.pending ? "warn" : "ok")));
    kr.appendChild(kpi(em.answeredPct == null ? "—" : em.answeredPct, "111 answered", em.answeredPct == null ? "idle" : em.answeredPct >= 95 ? "ok" : em.answeredPct >= 80 ? "warn" : "crit", "%"));
    kr.appendChild(kpi(em.avgWait == null ? "—" : em.avgWait, "Avg answer", "info", "s"));

    // ERT queue members
    rowsInto("#queue", d.queueMembers, (m) => {
      const ext = extOf(m.iface);
      const cls = stateClass(m.state);
      const r = el("div", "row");
      r.appendChild(el("span", "led " + cls));
      r.appendChild(el("span", "name", esc(label(ext)) + ` <span class="ext">${esc(ext)}</span>`));
      const right = el("div", "right"); right.appendChild(el("span", "tag " + cls, esc(stateWord(m.state)))); r.appendChild(right);
      return r;
    }, "No ERT positions in the queue", 8);

    // live calls
    rowsInto("#calls", d.liveCalls, (lc) => {
      const r = el("div", "row call");
      const from = label(lc.ext || lc.cid) || "caller";
      const to = lc.dialed || "—";
      const kind = callKind(lc.dialed, lc.app);
      const flow = el("div", "flow");
      flow.appendChild(el("span", "", esc(from)));
      flow.appendChild(el("span", "arrow", "→"));
      flow.appendChild(el("span", kind === "emergency" ? "" : "", esc(to)));
      r.appendChild(el("span", "led " + (kind === "emergency" ? "crit" : "info")));
      r.appendChild(flow);
      if (kind === "emergency") r.querySelector(".flow").appendChild(el("span", "tag crit", "111"));
      r.appendChild(el("span", "dur", fmtDur(lc.seconds)));
      return r;
    }, "No active calls", 6);

    // follow-ups due — missed 111 calls still awaiting a callback (view-only queue)
    rowsInto("#followups", fu.queue, (q) => {
      const r = el("div", "row");
      const urgent = q.overdue || q.status === "needshelp";
      r.appendChild(el("span", "led " + (urgent ? "crit" : "warn")));
      const who = (q.caller && q.caller !== "unknown") ? q.caller
        : (q.ext && q.ext !== "unknown" ? label(q.ext) : "Unknown caller");
      r.appendChild(el("span", "name", esc(who)));
      const right = el("div", "right");
      if (q.status === "needshelp") right.appendChild(el("span", "tag crit", "NEEDS HELP"));
      else if (q.status === "noanswer") right.appendChild(el("span", "tag warn", `NO ANSWER${q.attempts > 1 ? " ×" + q.attempts : ""}`));
      if (q.overdue) right.appendChild(el("span", "tag crit", "OVERDUE"));
      right.appendChild(el("span", "sub", ago(q.ageSec * 1000)));
      r.appendChild(right);
      return r;
    }, "✓ All callbacks done", 6);

    // recent calls (CDR)
    const cdr = (d.cdr || []).slice().reverse();
    rowsInto("#cdr", cdr, (c2) => {
      const kind = callKind(c2.dst, c2.app);
      const kc = kind === "emergency" ? "crit" : kind === "drill" ? "warn" : kind === "paging" ? "info" : "idle";
      const ok = (c2.disposition || "") === "ANSWERED";
      const r = el("div", "row");
      r.appendChild(el("span", "led " + (ok ? kc : "idle")));
      r.appendChild(el("span", "name", esc(label(c2.src)) + ` <span class="arrow">→</span> <span class="ext">${esc(c2.dst)}</span>`));
      const right = el("div", "right");
      right.appendChild(el("span", "tag " + kc, esc(kind)));
      right.appendChild(el("span", "sub", esc(shortTime(c2.time))));
      r.appendChild(right);
      return r;
    }, "No calls recorded yet", 8);

    // analytics
    renderAnalytics(a);

    // shift log
    const sl = (d.shiftLog || []).slice().reverse();
    rowsInto("#shift", sl, (s) => {
      const on = /on|start/i.test(s.action);
      const r = el("div", "row");
      r.appendChild(el("span", "led " + (on ? "ok" : "idle")));
      r.appendChild(el("span", "name", esc(label(s.ext))));
      const right = el("div", "right");
      right.appendChild(el("span", "tag " + (on ? "ok" : "idle"), esc((s.action || "").toUpperCase())));
      right.appendChild(el("span", "sub", esc(shortTime(s.time))));
      r.appendChild(right);
      return r;
    }, "No shift changes logged", 6);
  }

  function renderAnalytics(a) {
    const em = a.emergency || {}, dr = a.drill || {};
    setText("#mv-emans", em.answeredPct == null ? "—" : em.answeredPct + "%");
    setText("#mv-drill", dr.passPct == null ? "—" : dr.passPct + "%");
    setText("#mv-maxw", em.maxWait == null ? "—" : em.maxWait + "s");
    setText("#mv-total", a.total || 0);

    // 14-day volume — vertical columns (last = today, highlighted)
    const days = a.days || {}; const dv = Object.keys(days).sort().map(k => days[k]);
    const cols = $("#cols");
    if (cols) {
      cols.innerHTML = "";
      const dmax = Math.max(1, ...dv);
      dv.forEach((v, i) => {
        const c = el("div", "c" + (i === dv.length - 1 ? " today" : ""));
        c.style.height = Math.max(2, Math.round((v / dmax) * 100)) + "%";
        c.title = v; cols.appendChild(c);
      });
    }
    // calls by type — horizontal labeled bars (only non-zero kinds)
    const bk = a.byKind || {}; const order = ["emergency", "drill", "paging", "bridge", "echo", "other"];
    const bmax = Math.max(1, ...order.map(k => bk[k] || 0));
    const hb = $("#hbars");
    if (hb) {
      hb.innerHTML = "";
      const rows = order.filter(k => bk[k]);
      if (!rows.length) { hb.appendChild(el("div", "empty", "no calls yet")); }
      else rows.forEach(k => {
        const row = el("div", "hb");
        row.appendChild(el("span", "lab", esc(k)));
        const track = el("div", "track");
        const fill = el("div", "fill " + k);
        fill.style.width = Math.max(4, Math.round((bk[k] / bmax) * 100)) + "%";
        track.appendChild(fill); row.appendChild(track);
        row.appendChild(el("span", "n", esc(bk[k])));
        hb.appendChild(row);
      });
    }
  }

  // ---- fit the canvas to the viewport, filling it (no dead margins), no scroll/clip ----
  // The canvas is a fixed 1080 tall; its WIDTH follows the window's aspect ratio (clamped to a
  // sane landscape range), so the fluid 12-col grid reflows to fill the whole width instead of
  // letterboxing a strict 16:9 box inside a wider window. Uniform scale => no distortion.
  function fitStage() {
    const s = $(".screen"); if (!s) return;
    const vw = window.innerWidth, vh = window.innerHeight, H = 1080;
    const aspect = Math.max(1.3, Math.min(vw / vh, 2.4));   // clamp: 4:3 .. 21:9-ish
    const W = Math.round(H * aspect);
    s.style.width = W + "px"; s.style.height = H + "px";
    const sc = Math.min(vw / W, vh / H);                    // contain (uniform); W~viewport so it fills
    const x = (vw - W * sc) / 2, y = (vh - H * sc) / 2;
    s.style.transform = `translate(${Math.round(x)}px, ${Math.round(y)}px) scale(${sc})`;
  }

  // ---- main loop ---------------------------------------------------------
  function render() { paintClock(); (SCREEN === "safety" ? renderSafety : renderOps)(); }

  // kiosk niceties: click/keys request fullscreen; block context menu
  document.addEventListener("contextmenu", e => e.preventDefault());
  const goFull = () => { const de = document.documentElement; if (!document.fullscreenElement && de.requestFullscreen) de.requestFullscreen().catch(() => { }); };
  document.addEventListener("keydown", e => { if (e.key === "f" || e.key === "F") goFull(); });
  document.addEventListener("click", goFull);

  fitStage(); window.addEventListener("resize", fitStage);
  loadDir(); loadRegion(); pollFull(); liveLoop(); checkBuild();
  // anti-stampede: jittered self-rescheduling timers so many boards don't fire heavy polls on the same tick
  const jittered = (fn, base) => { const t = () => setTimeout(() => { try { fn(); } finally { t(); } }, base * (0.85 + Math.random() * 0.3)); t(); };
  jittered(pollFull, REFRESH_FULL);   // heavy /status — +/-15% jitter de-syncs boards
  setInterval(paintClock, 1000);      // clock stays on an exact 1s tick (no jitter)
  jittered(checkBuild, 5000);         // build check — +/-15% jitter de-syncs boards
  setInterval(loadDir, 300000);
  setInterval(loadRegion, REGION_REFRESH);
})();
