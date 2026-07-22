/* ============================================================================
   UPES-ECS Operations Console — app.js
   A tiny vanilla-JS framework built around a FEATURE REGISTRY.
   Adding a feature = push one module object {id,title,subtitle,icon,group,render,...}
   No build step, no framework, no CDN. Everything runs on the LAN.
   ========================================================================== */
(function () {
"use strict";

/* ---------------------------------------------------------------------------
   1. STATIC DATA  (confirmed roster + system reference — no fabricated data)
   ------------------------------------------------------------------------- */

// Confirmed roster — source: ../Notes/Confirmed Details.md
const ROSTER = [
  { id: "500120597", name: "Rohan Batra" },
  { id: "500000002", name: "Student Example Two" },
  { id: "500000003", name: "Student Example Three" },
  { id: "500000004", name: "Student Example Four" },
  { id: "40000001",  name: "Staff Member One" },
  { id: "40000002",  name: "Staff Member Two" },
  { id: "40000003",  name: "Staff Member Three" },
];
const nameFor = (id) => {
  const hit = ROSTER.find((r) => r.id === String(id || "").trim());
  return hit ? hit.name : null;
};

// System reference (ported from the original console; matches the SOP numbering plan)
const REF = {
  services: [
    ["111", "Campus Emergency Hotline (human-first) — primary number", "live"],
    ["102", "Emergency guidance line — offline panic-coach (fallback + test dial)", "live"],
    ["101", "Conversational AI assistant (online, future)", "later"],
    ["199", "Drill / Test line (no real dispatch)", "live"],
    ["198", "Echo / audio test", "live"],
    ["196", "Internal AI test", "later"],
    ["*45 / *46", "ERT queue Pause / Resume", "live"],
  ],
  positions: [
    ["4101", "ERT Lead / Incident Commander", "ctx_ert_lead", "escalation target"],
    ["4110–4113", "ERT Operator positions (+reserve)", "ctx_ert", "in 111 queue"],
    ["4120", "ERT Control Room", "ctx_control_room", "in 111 queue"],
    ["4200 · 4201–4202", "Medical — dispatch + seats", "ctx_responder", "dispatch target"],
    ["4300 · 4302–4303", "Security — dispatch + seats", "ctx_responder", "dispatch target"],
    ["4301", "Security Lead", "ctx_responder_lead", "dispatch target"],
    ["4400 · 4401–4402", "Warden — dispatch + seats", "ctx_responder", "dispatch target"],
    ["4500 · 4501–4502", "Operations — dispatch + seats", "ctx_responder", "dispatch target"],
    ["4600 · 4601–4602", "IT / Network — dispatch + seats", "ctx_responder", "dispatch target"],
    ["4700+", "IP speakers / gate phones", "ctx_fixed_device", "fixed"],
  ],
  paging: [
    ["700", "All-Campus Broadcast", "PIN-restricted"],
    ["701", "Academic Blocks", ""],
    ["702", "Hostels", ""],
    ["703", "Security Gates", ""],
    ["704", "Medical / ERT", ""],
    ["705", "Admin / Operations", ""],
  ],
  conf: [
    ["9000", "Main Incident Command (recorded)"],
    ["9001", "Security Coordination"],
    ["9002", "Medical Coordination"],
    ["9003", "Warden / Hostel"],
    ["9004", "Operations / Admin"],
  ],
  contexts: [
    ["ctx_student", "Students — call 111, 199, other students"],
    ["ctx_staff", "Staff / faculty — + staff calling"],
    ["ctx_ert", "ERT Operator positions — answer 111 queue, dispatch"],
    ["ctx_ert_lead", "ERT Lead — + paging, escalation, 9000"],
    ["ctx_responder", "Medical / Security / Warden / Ops / IT — dispatch targets"],
    ["ctx_responder_lead", "Department lead (Security 4301) — responder base + elevation seam"],
    ["ctx_control_room", "Control room / emergency admin"],
    ["ctx_fixed_device", "Speakers, gate phones"],
    ["ctx_admin", "UPES-ECS / IT admin"],
  ],
  huntGroups: [
    ["4200", "Medical", "First aid, ambulance liaison, clinic"],
    ["4300", "Security", "Gates, patrol, CCTV, access control"],
    ["4400", "Warden", "Hostels, student welfare, headcount"],
    ["4500", "Operations", "Facilities, power, transport, logistics"],
    ["4600", "IT / Network", "PBX, network, devices, provisioning"],
  ],
  sop: [
    ["01", "Numbering Plan"], ["02", "ERT SOP"], ["03", "Drill & Test SOP"],
    ["04", "Role Matrix"], ["10", "Health Monitoring"], ["11", "Backup / Restore"],
    ["12", "Incident Logging Schema"], ["17", "Pilot Test Plan"], ["18", "Go-Live Checklist"],
    ["21", "Risk Register"], ["25", "Quick-Cards"], ["28", "Voice Prompts"], ["30", "Roles & Shifts"],
  ],
  blueprint: [
    ["00", "Blueprint README"], ["01", "Bare-Minimum Checklist"], ["02", "System Architecture"],
    ["03", "Call Flows"], ["04", "Network & Deployment"], ["05", "Bill of Materials"],
    ["06", "Numbering & Data Map"], ["07", "Deployment Runbook"],
  ],
};

// Standard emergency announcement set (message TYPES, not campus-specific data).
// The recording filename is a naming convention — the operator confirms the actual prompt (see SOP 28).
const MESSAGES = [
  { id: "evacuate",   label: "Evacuate — leave the building now", prompt: "custom/upes-evacuate" },
  { id: "shelter",    label: "Shelter in place / lockdown",       prompt: "custom/upes-shelter" },
  { id: "allclear",   label: "All clear — resume normal activity", prompt: "custom/upes-allclear" },
  { id: "assemble",   label: "Proceed to assembly point",         prompt: "custom/upes-assemble" },
  { id: "rollcall",   label: "Roll-call — press 1 if you are safe", prompt: "custom/upes-rollcall" },
  { id: "test",       label: "This is a test — no action required", prompt: "custom/upes-test" },
];

const CALLOUT_GROUPS = [
  { id: "all",        label: "All registered clients", zone: "700" },
  { id: "hostels",    label: "Hostels",                zone: "702" },
  { id: "academic",   label: "Academic blocks",        zone: "701" },
  { id: "ert",        label: "ERT team",               zone: "704" },
  { id: "responders", label: "Department responders",  zone: "705" },
  { id: "roster",     label: "Confirmed roster (pilot group)", zone: "700" },
];

const QUEUE = "ert_emergency_queue";

/* ---------------------------------------------------------------------------
   2. ICON SET  (inline SVG, stroke = currentColor — no icon font / CDN)
   ------------------------------------------------------------------------- */
const I = (p) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${p}</svg>`;
const ICONS = {
  dashboard: I('<rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/>'),
  register:  I('<circle cx="9" cy="8" r="3.2"/><path d="M3.5 20a5.5 5.5 0 0 1 11 0"/><path d="M18 8v6M15 11h6"/>'),
  callout:   I('<path d="M3 11v2a1 1 0 0 0 1 1h2l4 4V6L6 10H4a1 1 0 0 0-1 1Z"/><path d="M15 8a5 5 0 0 1 0 8M17.5 5.5a8 8 0 0 1 0 13"/>'),
  rollcall:  I('<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M8 8h5M8 12h5M8 16h3"/><path d="m15.5 15.5 1.2 1.2 2.3-2.6"/>'),
  announce:  I('<path d="M4 9v6h4l7 4V5L8 9H4Z"/><path d="M18 9v6"/><path d="M21 7v10"/>'),
  directory: I('<path d="M6 4h12a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z"/><path d="M4 8h2M4 12h2M4 16h2"/><circle cx="12" cy="10" r="2"/><path d="M9 16a3 3 0 0 1 6 0"/>'),
  hunt:      I('<path d="M15.5 13.5c-1 1-1 1-2 .5a10 10 0 0 1-4.5-4.5c-.5-1-.5-1 .5-2 .6-.6.7-1 .3-1.7L8.3 3.7C7.9 3 7.4 2.9 6.7 3.2 4 4.3 3.4 6.9 5.4 11a18 18 0 0 0 7.6 7.6c4.1 2 6.7 1.4 7.8-1.3.3-.7.2-1.2-.5-1.6l-1.9-1.2c-.7-.4-1.1-.3-1.7.3Z"/>'),
  numbering: I('<path d="M9 4 7 20M17 4l-2 16M5 9h15M4 15h15"/>'),
  ert:       I('<path d="M12 3l7 3v5c0 4.5-3 7.5-7 9-4-1.5-7-4.5-7-9V6l7-3Z"/><path d="M9.5 12l1.8 1.8 3.2-3.6"/>'),
  network:   I('<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.7 2.5 15.3 0 18M12 3c-2.5 2.7-2.5 15.3 0 18"/>'),
  ops:       I('<circle cx="12" cy="12" r="3"/><path d="M19 12a7 7 0 0 0-.1-1l2-1.5-2-3.4-2.3 1a7 7 0 0 0-1.7-1l-.3-2.5H9.4l-.3 2.5a7 7 0 0 0-1.7 1l-2.3-1-2 3.4L5 11a7 7 0 0 0 0 2l-2 1.5 2 3.4 2.3-1a7 7 0 0 0 1.7 1l.3 2.5h4.2l.3-2.5a7 7 0 0 0 1.7-1l2.3 1 2-3.4-2-1.5c.1-.3.1-.7.1-1Z"/>'),
  docs:      I('<path d="M6 3h9l4 4v14a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1Z"/><path d="M14 3v5h5M8 13h8M8 17h5"/>'),
  copy:      I('<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h8"/>'),
  sun:       I('<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4 12H2M22 12h-2M5 5 3.5 3.5M20.5 20.5 19 19M19 5l1.5-1.5M3.5 20.5 5 19"/>'),
  moon:      I('<path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5Z"/>'),
  search:    I('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>'),
  inbox:     I('<path d="M4 13h4l1.5 3h5L16 13h4"/><path d="M4 13 6 5h12l2 8v5a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-5Z"/>'),
  phone:     I('<path d="M6 3l2 5-2 1.5a12 12 0 0 0 6.5 6.5L14 14l5 2v3a1 1 0 0 1-1 1C10 20 4 14 4 6a1 1 0 0 1 1-1Z"/>'),
  timeline:  I('<path d="M6 3v18"/><circle cx="6" cy="7" r="2"/><circle cx="6" cy="15" r="2"/><path d="M10 7h9M10 15h9M10 11h6"/>'),
  records:   I('<rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18"/><path d="m10 13 4 2.5-4 2.5Z"/>'),
  presence:  I('<circle cx="8.5" cy="8" r="3"/><path d="M3 20a5.5 5.5 0 0 1 11 0"/><circle cx="17" cy="9" r="2.3"/><path d="M15 20a4.5 4.5 0 0 1 6.5-4"/>'),
  chart:     I('<path d="M4 4v16h16"/><rect x="7" y="11" width="3" height="6" rx="1"/><rect x="12" y="7" width="3" height="10" rx="1"/><rect x="17" y="13" width="3" height="4" rx="1"/>'),
  map:       I('<path d="M9 4 3 6v14l6-2 6 2 6-2V4l-6 2-6-2Z"/><path d="M9 4v14M15 6v14"/>'),
  livemap:   I('<path d="M12 21.5c3.7-4 6-7 6-10a6 6 0 0 0-12 0c0 3 2.3 6 6 10Z"/><circle cx="12" cy="11" r="2.2"/><path d="M4.5 15.5c-1 .8-1.5 1.6-1.5 2.5 0 2 4 3.5 9 3.5s9-1.5 9-3.5c0-.9-.5-1.7-1.5-2.5" opacity=".5"/>'),
};

/* ---------------------------------------------------------------------------
   3. HELPERS
   ------------------------------------------------------------------------- */
const $  = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
const esc = (s) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) =>
  ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const initials = (n) => n.split(/\s+/).filter(Boolean).slice(0, 2).map((w) => w[0]).join("").toUpperCase();

function code(text, label) {
  return `<div class="codeblock${label ? " has-label" : ""}">${label ? `<span class="label">${esc(label)}</span>` : ""}` +
    `<button class="copy" type="button" aria-label="Copy to clipboard">${ICONS.copy}<span>Copy</span></button>` +
    `<pre>${esc(text)}</pre></div>`;
}
function pill(text, kind, dot) {
  return `<span class="pill ${kind || "neutral"}${dot ? " dot" : ""}">${esc(text)}</span>`;
}
function empty(icon, title, sub) {
  return `<div class="empty"><span class="em-ic">${ICONS[icon] || ICONS.inbox}</span>` +
    `<div class="em-t">${esc(title)}</div>${sub ? `<div class="em-p">${esc(sub)}</div>` : ""}</div>`;
}
function pbxNote(text) {
  return `<div class="pbxnote">${pill("Run on the PBX", "warn")}<span>${text}</span></div>`;
}

/* ---- Execute (confirm → run on the PBX) --------------------------------- */
function execButton(label) {
  return `<button class="btn danger exec-btn" type="button">${ICONS.phone}<span>${esc(label || "Execute")}</span></button>`;
}
async function apiExec(action, args, endpoint) {
  // Default endpoint is the VM whitelist /api/exec ({action,args}). A custom endpoint
  // (e.g. host-side "api/rebind") gets the bare args object as its body.
  const res = await fetch(endpoint || "api/exec", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify(endpoint ? (args || {}) : { action, args }),
  });
  if (!res.ok) throw new Error("HTTP " + res.status);
  return res.json();
}
// Confirmation modal: shows WHAT will happen + the exact command, requires a second
// click to actually run it (prevents accidental broadcasts), then shows live output.
function confirmExec({ title, what, command, action, args, endpoint, onDone, poll }) {
  const wrap = document.createElement("div");
  wrap.className = "modal-back";
  wrap.innerHTML =
    `<div class="modal" role="dialog" aria-modal="true" aria-label="${esc(title)}">
       <div class="modal-h">${ICONS.callout}<h3>${esc(title)}</h3></div>
       <div class="callout warn"><span class="ct">Confirm before it runs</span>${what}</div>
       <div class="section-label">Exact command (runs on the PBX)</div>
       ${code(command)}
       <div class="modal-out" id="exec-out" hidden></div>
       <div class="modal-actions">
         <button class="btn" data-act="cancel" type="button">Cancel</button>
         <button class="btn danger" data-act="go" type="button">${ICONS.phone}<span>Execute now</span></button>
       </div>
     </div>`;
  document.body.appendChild(wrap);
  const close = () => wrap.remove();
  const onEsc = (e) => { if (e.key === "Escape") { close(); document.removeEventListener("keydown", onEsc); } };
  document.addEventListener("keydown", onEsc);
  wrap.addEventListener("click", (e) => { if (e.target === wrap) close(); });
  wrap.querySelector('[data-act="cancel"]').addEventListener("click", close);
  const go = wrap.querySelector('[data-act="go"]');
  go.addEventListener("click", async () => {
    if (go.dataset.ran === "ok") return;   // already succeeded — never re-fire
    go.disabled = true; go.querySelector("span").textContent = "Running…";
    const out = wrap.querySelector("#exec-out"); out.hidden = false;
    const setOut = (label, kind, text) =>
      out.innerHTML = `<div class="section-label">${label}${kind ? " " + pill(kind[0], kind[1]) : ""}</div>` +
        `<pre class="md-pre">${esc(text)}</pre>`;
    // After it has RUN, the Execute button must not fire the action again. On success we
    // REMOVE it (leaving only Close); on failure/error we relabel it "Retry".
    const finish = (ok) => {
      if (ok) {
        go.dataset.ran = "ok";
        go.remove();
        const c = wrap.querySelector('[data-act="cancel"]'); if (c) c.remove();
      } else {
        go.disabled = false; go.querySelector("span").textContent = "Retry";
      }
      if (!wrap.querySelector('[data-act="close"]')) {
        const b = document.createElement("button");
        b.className = "btn"; b.textContent = "Close"; b.setAttribute("data-act", "close");
        b.addEventListener("click", close);
        wrap.querySelector(".modal-actions").appendChild(b);
      }
    };
    setOut("Result", null, poll ? "starting on the PBX…" : "running on the PBX…");
    try {
      let r = await apiExec(action, args, endpoint);
      // poll mode: the action runs detached (e.g. the slow rebind). The POST returns
      // running:true immediately; we GET the same endpoint until it reports done.
      if (poll && endpoint) {
        let tries = 0;
        while (r && r.running && tries < 60) {   // ~3s × 60 ≈ 3 min cap
          setOut("Result", ["running", "warn"], r.output || "working on the PBX…");
          if (r.serverIp) App.serverIp = r.serverIp;
          if (typeof onDone === "function") { try { onDone(r); } catch (_) {} }
          await new Promise((res) => setTimeout(res, 3000));
          try { const g = await fetch(endpoint, { cache: "no-store" }); if (g.ok) r = await g.json(); } catch (_) {}
          tries++;
        }
      }
      const okRun = r.ok !== false;
      setOut("Result", okRun ? ["done", "ok"] : ["rejected", "crit"], r.output || "(no output)");
      if (okRun && typeof onDone === "function") { try { onDone(r); } catch (_) {} }
      finish(okRun);
    } catch (e) {
      out.innerHTML = `<div class="section-label">Result ${pill("error", "crit")}</div>` +
        `<pre class="md-pre">${esc(e.message)}\n\nThe exec backend needs Serve.ps1 running (restart it if you just updated).</pre>`;
      finish(false);
    }
  });
}

// Live IVR voice-language switch (Region & language view). Delegated so it survives the
// view's periodic repaints. Confirms, POSTs {language} to the host-side api/ivrlang endpoint,
// then reloads region.json (the endpoint rewrites it) so the chip + view reflect the change.
document.addEventListener("click", (e) => {
  const b = e.target.closest(".ivr-switch-btn");
  if (!b || b.disabled) return;
  const lang = b.dataset.lang;
  const name = lang === "hi" ? "Hindi" : "English";
  confirmExec({
    title: "Switch IVR voice language",
    what: `Change the live emergency-IVR voice prompts to <b>${name}</b>. ` +
          `This swaps the prompt set on the running PBX and takes effect on the <b>next</b> call — no redeploy, no reboot.`,
    command: `powershell -File deploy\\qemu\\Set-UpesIvrLanguage.ps1 -Language ${lang}`,
    endpoint: "api/ivrlang",
    args: { language: lang },
    onDone: () => { try { loadRegion(); } catch (_) {} },
  });
});

// Copy-to-clipboard delegation (works without HTTPS via a textarea fallback)
document.addEventListener("click", (e) => {
  const btn = e.target.closest(".copy");
  if (!btn) return;
  const pre = btn.parentElement.querySelector("pre");
  const text = pre ? pre.textContent : "";
  const done = () => {
    const span = btn.querySelector("span");
    const prev = span.textContent;
    span.textContent = "Copied"; btn.classList.add("done");
    setTimeout(() => { span.textContent = prev; btn.classList.remove("done"); }, 1300);
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(done).catch(fallback);
  } else { fallback(); }
  function fallback() {
    const ta = document.createElement("textarea");
    ta.value = text; ta.style.position = "fixed"; ta.style.opacity = "0";
    document.body.appendChild(ta); ta.select();
    try { document.execCommand("copy"); done(); } catch (_) {}
    document.body.removeChild(ta);
  }
});

/* ---------------------------------------------------------------------------
   3b. MINIMAL MARKDOWN RENDERER  (no CDN — powers the in-app doc viewer)
   ------------------------------------------------------------------------- */
function mdInline(s) {
  s = esc(s);
  s = s.replace(/`([^`]+)`/g, (m, c) => `<code>${c}</code>`);
  s = s.replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>");
  s = s.replace(/(^|[^*])\*(?!\s)([^*]+?)\*(?!\*)/g, "$1<em>$2</em>");
  s = s.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (m, t, u) => {
    if (/^https?:/i.test(u)) return `<a href="${u}" target="_blank" rel="noopener">${t}</a>`;
    if (/\.md(#|$)/i.test(u)) return `<a href="#doc:${u.replace(/^(\.\.\/)+/, "").replace(/#.*$/, "")}">${t}</a>`;
    if (!/^(https?:|#|\/|\.{0,2}\/)/i.test(u)) return esc(t);   // block javascript:/data: etc.
    return `<a href="${u}">${t}</a>`;
  });
  return s;
}
function renderMarkdown(md) {
  const lines = String(md).replace(/\r\n/g, "\n").split("\n");
  const out = []; let i = 0;
  while (i < lines.length) {
    const ln = lines[i];
    if (/^```/.test(ln)) {
      const buf = []; i++;
      while (i < lines.length && !/^```/.test(lines[i])) { buf.push(esc(lines[i])); i++; }
      i++; out.push(`<pre class="md-pre"><code>${buf.join("\n")}</code></pre>`); continue;
    }
    if (/^\s*\|.*\|\s*$/.test(ln) && i + 1 < lines.length && /^\s*\|[\s:|-]+\|\s*$/.test(lines[i + 1])) {
      const head = ln.trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim());
      i += 2; const rows = [];
      while (i < lines.length && /^\s*\|.*\|\s*$/.test(lines[i])) {
        rows.push(lines[i].trim().replace(/^\||\|$/g, "").split("|").map((c) => c.trim())); i++;
      }
      out.push(`<div class="table-wrap"><table><thead><tr>${head.map((h) => `<th>${mdInline(h)}</th>`).join("")}</tr></thead><tbody>${rows.map((r) => `<tr>${r.map((c) => `<td>${mdInline(c)}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`);
      continue;
    }
    const h = ln.match(/^(#{1,6})\s+(.*)$/);
    if (h) { out.push(`<h${h[1].length}>${mdInline(h[2])}</h${h[1].length}>`); i++; continue; }
    if (/^\s*([-*_])\1\1+\s*$/.test(ln)) { out.push("<hr>"); i++; continue; }
    if (/^\s*>/.test(ln)) {
      const buf = [];
      while (i < lines.length && /^\s*>/.test(lines[i])) { buf.push(lines[i].replace(/^\s*>\s?/, "")); i++; }
      out.push(`<blockquote>${renderMarkdown(buf.join("\n"))}</blockquote>`); continue;
    }
    if (/^\s*([-*+]|\d+\.)\s+/.test(ln)) {
      const ol = /^\s*\d+\.\s+/.test(ln); const items = [];
      while (i < lines.length && /^\s*([-*+]|\d+\.)\s+/.test(lines[i])) { items.push(lines[i].replace(/^\s*([-*+]|\d+\.)\s+/, "")); i++; }
      out.push(`<${ol ? "ol" : "ul"}>${items.map((it) => `<li>${mdInline(it)}</li>`).join("")}</${ol ? "ol" : "ul"}>`); continue;
    }
    if (/^\s*$/.test(ln)) { i++; continue; }
    const buf = [];
    while (i < lines.length && !/^\s*$/.test(lines[i]) && !/^```/.test(lines[i]) && !/^#{1,6}\s/.test(lines[i]) &&
           !/^\s*\|.*\|\s*$/.test(lines[i]) && !/^\s*>/.test(lines[i]) && !/^\s*([-*+]|\d+\.)\s+/.test(lines[i])) {
      buf.push(lines[i]); i++;
    }
    out.push(`<p>${mdInline(buf.join(" "))}</p>`);
  }
  return out.join("\n");
}

/* ---------------------------------------------------------------------------
   4. APP STATE + FEATURE REGISTRY
   ------------------------------------------------------------------------- */
const App = {
  status: null,          // last successfully parsed status.json
  statusError: false,    // true when the fetch/parse failed
  // --- live-freshness guardrail (emergency safety) ------------------------------------------
  // The Active-calls count must be PROVABLY realtime or shown as UNKNOWN — never a confident
  // stale number. A 200 is NOT proof: the console serves a frozen last-good body (X-Upes-Cache:
  // stale) during a VM/tunnel blip. liveStale is set from that header (works today) and from the
  // server-stamped X-Upes-Age-Ms (Serve.ps1 G3, skew-proof — doesn't trust the emulated VM clock).
  liveStale: false,      // true when the last live/status response could not be proven fresh
  liveAgeMs: null,       // server-stamped age of that response (ms), or null if unknown
  LIVE_STALE_MS: 6000,   // age beyond which the call count is treated as not-live
  everLoaded: false,     // have we ever received a status?
  buildTag: null,        // Console asset build stamp — reload the page when it changes
  // Neutral default = the host you loaded the Console from (correct on any box). The proxy
  // overrides it with the real LAN IP: Serve.ps1 (Windows) or serve-console.py (bare metal).
  serverIp: (typeof location !== "undefined" && location.hostname) ? location.hostname : "",
  bareMetal: false,      // env-specific: true on native/bare-metal (no QEMU VM). Hides VM-lifecycle UI.
  region: null,          // active deployed region (region.json) — null ⇒ English default
  _langs: null,          // supported-language catalogue (languages.json), lazy-loaded
  features: [],          // the registry
  current: null,         // active feature module
  GROUP_ORDER: ["Operations", "Insights", "Emergency tools", "Administration", "Directory & comms", "Reference"],
};

/**
 * Register a feature module. Shape:
 *   { id, title, subtitle, icon, group, render() -> htmlString,
 *     mount?(rootEl), live?(rootEl, status|null) }
 * `render` returns markup for the view. `mount` wires up any interactivity.
 * `live` is called on every status poll while the feature is active.
 */
function register(feature) { App.features.push(feature); }

/* ---------------------------------------------------------------------------
   5. FEATURE MODULES
   ------------------------------------------------------------------------- */

/* ---- 5.1  Dashboard / Wallboard ---------------------------------------- */
register({
  id: "dashboard", group: "Operations", icon: "dashboard",
  title: "Wallboard", subtitle: "Live control-room view of the emergency PBX",
  render() {
    return `
      <div id="dash-banner">${bannerSkeleton()}</div>
      <div class="section-label">Live status <span class="hint" id="dash-age">connecting…</span></div>
      <div class="tiles" id="dash-tiles">${tileSkeletons(6)}</div>
      <div class="grid grid-2" style="margin-top:var(--sp-6)">
        <div>
          <div class="section-label">ERT queue members</div>
          <div class="table-wrap" id="dash-queue">${empty("phone", "Waiting for status…", "")}</div>
        </div>
        <div>
          <div class="section-label">Recent missed emergencies</div>
          <div id="dash-missed">${empty("inbox", "Waiting for status…", "")}</div>
        </div>
      </div>
      <div class="section-label">Registered clients</div>
      <div class="table-wrap" id="dash-users">${empty("register", "Waiting for status…", "")}</div>`;
  },
  live(root, s) {
    // ---- state banner ----
    const stateInfo = {
      READY:    ["s-ok", "READY", "All answer points staffed. 111 is being answered."],
      DEGRADED: ["s-warn", "DEGRADED", "Reduced capacity — check queue members and pending items."],
      CRITICAL: ["s-crit", "CRITICAL", "Not ready to answer 111 — register ERT answer points / check the VM."],
      OFFLINE:  ["s-crit", "OFFLINE", "The PBX is unreachable. Verify the VM is running and on this network."],
    };
    const banner = $("#dash-banner", root);
    if (App.statusError || !s) {
      const off = stateInfo.OFFLINE;
      banner.innerHTML = bannerHtml(off, "No status.json — run Update-Status.ps1 on the host", null);
    } else {
      const info = (stateInfo[s.state] || ["s-neutral", s.state || "UNKNOWN", "State not reported."]).slice();
      if (s.state === "READY" && s.thinCover) {
        info[2] = "Ready to answer 111 — one answer point on shift (no backup). Add a second for redundancy.";
      }
      banner.innerHTML = bannerHtml(info, null, s.updated);
    }

    // ---- age line ----
    const age = $("#dash-age", root);
    if (App.statusError || !s) { age.textContent = "offline — showing last-known layout"; }
    else { age.innerHTML = `updated ${esc(s.updated || "—")}`; }

    // ---- tiles ----
    const val = (v, unit) => v == null ? "—" : `${esc(v)}${unit ? ` <span class="unit">${unit}</span>` : ""}`;
    let tiles;
    if (App.statusError || !s) {
      tiles = [
        tile("Asterisk", "offline", "crit", "PBX unreachable"),
        tile("ERT queue", "—", "crit", "available agents"),
        tile("Active calls", "—", "info", "in progress"),
        tile("Registered", "—", "info", "clients online"),
        tile("Storage", "—", "info", "disk used"),
        tile("Missed pending", "—", "warn", "awaiting follow-up"),
      ].join("");
    } else {
      const q = s.queueAvailable;
      const disk = s.diskPct;
      const missed = s.missedPending;
      tiles = [
        tile("Asterisk", s.asterisk === "active" ? "active" : (s.asterisk || "—"),
             s.asterisk === "active" ? "ok" : "crit", "PBX service"),
        tile("ERT queue", val(q),
             q == null ? "info" : (q >= ((s.minAgents || 1) + 1) ? "ok" : (q >= (s.minAgents || 1) ? "warn" : "crit")),
             s.thinCover ? "on shift · no backup" : "available to answer 111"),
        // GUARDRAIL: never show a confident stale 111 count. When freshness can't be proven, hard-blank
        // to UNKNOWN so an operator can't mis-read a frozen number as live.
        App.liveStale
          ? tile("Active calls", "—", "crit",
                 App.liveAgeMs != null ? ("not live · last seen " + Math.round(App.liveAgeMs / 1000) + "s ago") : "not live · link down")
          : tile("Active calls", val(s.activeCalls != null ? s.activeCalls : (Array.isArray(s.queueMembers) ? undefined : null)),
                 "info", "in progress", s.activeCalls == null),
        tile("Registered", val(s.registrations), "info", "clients online"),
        tile("Storage", disk == null ? "—" : disk + '<span class="unit">%</span>',
             disk == null ? "info" : (disk >= 90 ? "crit" : (disk >= 75 ? "warn" : "ok")), "recordings disk"),
        tile("Missed pending", val(missed), (missed > 0 ? "warn" : "ok"), "awaiting follow-up"),
      ].join("");
    }
    $("#dash-tiles", root).innerHTML = tiles;

    // ---- queue members table ----
    const qEl = $("#dash-queue", root);
    const members = s && Array.isArray(s.queueMembers) ? s.queueMembers : null;
    if (!members) {
      qEl.innerHTML = empty("phone", "No queue-member data", "Status.json has no queueMembers[] yet.");
    } else if (members.length === 0) {
      qEl.innerHTML = empty("phone", "No members in the ERT queue", "Register and add ERT answer points.");
    } else {
      qEl.innerHTML = `<table><thead><tr><th>Position</th><th>Interface</th><th>State</th></tr></thead><tbody>` +
        members.map((m) => `<tr><td class="name">${esc(m.name || "—")}</td>` +
          `<td><code>${esc(m.iface || "—")}</code></td><td>${memberState(m.state)}</td></tr>`).join("") +
        `</tbody></table>`;
    }

    // ---- missed emergencies ----
    const mEl = $("#dash-missed", root);
    const missedList = s && Array.isArray(s.missedRecent) ? s.missedRecent : null;
    if (!missedList) {
      mEl.innerHTML = `<div class="panel">${empty("inbox", "No missed-emergency data", "Status.json has no missedRecent[] yet.")}</div>`;
    } else if (missedList.length === 0) {
      mEl.innerHTML = `<div class="panel">${empty("inbox", "No recent missed emergencies", "Every 111 call has been answered.")}</div>`;
    } else {
      mEl.innerHTML = `<div class="table-wrap"><table><thead><tr><th>Incident</th><th>Caller</th><th>Time</th><th>Severity</th></tr></thead><tbody>` +
        missedList.map((m) => {
          const caller = m.caller || "—";
          const named = nameFor(caller);
          return `<tr><td><code>${esc(m.incident_id || "—")}</code></td>` +
            `<td class="name">${esc(caller)}${named ? ` <span class="muted">· ${esc(named)}</span>` : ""}</td>` +
            `<td>${esc(m.time || "—")}</td><td>${severityPill(m.severity)}</td></tr>`;
        }).join("") + `</tbody></table></div>`;
    }

    // ---- registered users ----
    const uEl = $("#dash-users", root);
    const users = s && Array.isArray(s.registeredUsers) ? s.registeredUsers : null;
    if (!users) {
      uEl.innerHTML = empty("register", "No per-client registration data",
        "Status.json has no registeredUsers[] — the Registered tile above still shows the count.");
    } else if (users.length === 0) {
      uEl.innerHTML = empty("register", "No clients registered", "No phones are currently registered to the PBX.");
    } else {
      uEl.innerHTML = `<table><thead><tr><th>Extension</th><th>Name</th><th>IP address</th></tr></thead><tbody>` +
        users.map((u) => {
          const nm = nameFor(u.ext);
          return `<tr><td><span class="num">${esc(u.ext)}</span></td>` +
            `<td>${nm ? `<span class="name">${esc(nm)}</span>` : `<span class="muted">not in roster</span>`}</td>` +
            `<td><code>${esc(u.ip || "—")}</code></td></tr>`;
        }).join("") + `</tbody></table>`;
    }
  },
});

/* ---- 5.1b  Follow-ups (missed-emergency callbacks) --------------------- */
// Every missed 111 call must get a human callback (5-min target). This is where the control
// room CHASES them: pick an open item, log the outcome. safe/escalated close it; noanswer/
// needshelp keep it open for another attempt. Every action is an audit record on the PBX.
const FU_OUTCOMES = {
  safe:      ["Reached - safe",  "ok",   "Contacted them and they are OK. Closes the follow-up."],
  needshelp: ["Needs help",      "crit", "Contacted them and they need help - stays open until escalated."],
  noanswer:  ["No answer",       "warn", "Could not reach them - logs an attempt and keeps it open to retry."],
  escalated: ["Escalated",       "warn", "Handed to ERT / authorities. Closes the follow-up."],
};
function fuAgo(sec) { sec = Math.max(0, sec | 0); if (sec < 60) return sec + "s"; const m = sec / 60 | 0; if (m < 60) return m + "m"; const h = m / 60 | 0; return h < 48 ? h + "h" : (h / 24 | 0) + "d"; }
function fuWhen(iso) { return String(iso || "").replace("T", " ").replace(/(\+\d{4}|Z)$/, "").slice(0, 16) || "-"; }
function fuOperator() { const el = document.getElementById("fu-operator"); let v = el ? el.value.trim() : ""; if (!v) v = localStorage.getItem("upes.operator") || ""; return v.replace(/\D/g, ""); }
function fuBadge(q) {
  let b = (q.status === "needshelp") ? pill("needs help", "crit")
    : (q.status === "noanswer") ? pill("no answer" + (q.attempts > 1 ? " x" + q.attempts : ""), "warn")
    : pill("new", "neutral");
  if (q.overdue) b = pill("overdue", "crit") + b;
  return b;
}
function fuModal(item, outcome) {
  const op = fuOperator();
  if (!op) { const i = document.getElementById("fu-operator"); if (i) { i.focus(); i.classList.add("bad"); } return; }
  const oc = FU_OUTCOMES[outcome]; if (!oc) return;
  const who = nameFor(item.ext) || (item.caller !== "unknown" ? item.caller : "Unknown caller");
  const wrap = document.createElement("div");
  wrap.className = "modal-back";
  wrap.innerHTML =
    `<div class="modal" role="dialog" aria-modal="true" aria-label="Log callback">
       <div class="modal-h">${ICONS.phone}<h3>Log callback</h3></div>
       <div class="callout ${oc[1]}"><span class="ct">${esc(who)} &middot; ${esc(item.incident_id)}</span>
         Outcome: <strong>${esc(oc[0])}</strong> &mdash; ${esc(oc[2])}</div>
       <div class="section-label">Note (optional)</div>
       <textarea id="fu-note" class="fu-note" rows="2" maxlength="200" placeholder="e.g. spoke to student, minor cut, first-aid advised"></textarea>
       <div class="modal-out" id="fu-out" hidden></div>
       <div class="modal-actions">
         <button class="btn" data-act="cancel" type="button">Cancel</button>
         <button class="btn danger" data-act="go" type="button">${ICONS.phone}<span>Record callback</span></button>
       </div>
     </div>`;
  document.body.appendChild(wrap);
  const close = () => wrap.remove();
  const onEsc = (e) => { if (e.key === "Escape") { close(); document.removeEventListener("keydown", onEsc); } };
  document.addEventListener("keydown", onEsc);
  wrap.addEventListener("click", (e) => { if (e.target === wrap) close(); });
  wrap.querySelector('[data-act="cancel"]').addEventListener("click", close);
  const go = wrap.querySelector('[data-act="go"]');
  go.addEventListener("click", async () => {
    if (go.dataset.ran === "ok") return;
    const note = (wrap.querySelector("#fu-note").value || "").replace(/["\\\r\n]/g, " ").trim().slice(0, 200);
    localStorage.setItem("upes.operator", op);
    go.disabled = true; go.querySelector("span").textContent = "Recording...";
    const out = wrap.querySelector("#fu-out"); out.hidden = false;
    out.innerHTML = `<pre class="md-pre">recording on the PBX...</pre>`;
    try {
      const r = await apiExec("followup", { incident_id: item.incident_id, ext: op, outcome, note });
      const ok = r.ok !== false;
      out.innerHTML = `<div class="section-label">Result ${pill(ok ? "done" : "rejected", ok ? "ok" : "crit")}</div>` +
        `<pre class="md-pre">${esc(r.output || "(no output)")}</pre>`;
      if (ok) { go.dataset.ran = "ok"; go.remove(); const c = wrap.querySelector('[data-act="cancel"]'); if (c) c.textContent = "Close"; poll(); setTimeout(close, 600); }
      else { go.disabled = false; go.querySelector("span").textContent = "Retry"; }
    } catch (e) {
      out.innerHTML = `<div class="section-label">Result ${pill("error", "crit")}</div>` +
        `<pre class="md-pre">${esc(e.message)}\n\nThe exec backend needs Serve.ps1 running.</pre>`;
      go.disabled = false; go.querySelector("span").textContent = "Retry";
    }
  });
}
register({
  id: "followups", group: "Operations", icon: "inbox",
  title: "Follow-ups", subtitle: "Chase every missed 111 call - callback within 5 minutes",
  render() {
    return `
      <div class="fu-oprow">
        <label class="section-label" for="fu-operator" style="margin:0">Your operator ext</label>
        <input id="fu-operator" class="fu-operator" inputmode="numeric" placeholder="e.g. 4101" />
        <span class="hint">recorded on each callback for accountability</span>
      </div>
      <div class="tiles" id="fu-tiles">${tileSkeletons(3)}</div>
      <div class="section-label">Open callbacks <span class="hint" id="fu-count"></span></div>
      <div id="fu-queue">${empty("inbox", "Waiting for status...", "")}</div>
      <div class="section-label" style="margin-top:var(--sp-6)">Recently closed</div>
      <div id="fu-closed">${empty("inbox", "-", "")}</div>`;
  },
  mount(root) {
    const inp = $("#fu-operator", root);
    if (inp) {
      inp.value = localStorage.getItem("upes.operator") || "";
      inp.addEventListener("input", () => { inp.classList.remove("bad"); localStorage.setItem("upes.operator", inp.value.replace(/\D/g, "")); });
    }
    $("#fu-queue", root).addEventListener("click", (e) => {
      const b = e.target.closest("button[data-out]"); if (!b) return;
      const row = b.closest("[data-iid]"); if (!row) return;
      const item = App._fuIndex && App._fuIndex[row.dataset.iid];
      if (item) fuModal(item, b.dataset.out);
    });
  },
  live(root, s) {
    const fu = s && s.followups ? s.followups : null;
    const tEl = $("#fu-tiles", root), qEl = $("#fu-queue", root), cEl = $("#fu-closed", root), cnt = $("#fu-count", root);
    if (!fu) {
      tEl.innerHTML = [tile("Follow-ups due", "-", "warn", "awaiting callback"), tile("Overdue", "-", "crit", "past target"), tile("Target", "5", "info", "minute callback")].join("");
      qEl.innerHTML = `<div class="panel">${empty("inbox", App.statusError ? "PBX offline" : "No follow-up data", "")}</div>`;
      return;
    }
    tEl.innerHTML = [
      tile("Follow-ups due", fu.pending, fu.pending ? "warn" : "ok", "awaiting callback"),
      tile("Overdue", fu.overdue, fu.overdue ? "crit" : "ok", "past 5-min target"),
      tile("Target", Math.round((fu.targetSec || 300) / 60), "info", "minute callback"),
    ].join("");
    cnt.textContent = fu.pending ? `${fu.pending} open${fu.overdue ? ` · ${fu.overdue} overdue` : ""}` : "";
    App._fuIndex = {};
    const q = Array.isArray(fu.queue) ? fu.queue : [];
    if (!q.length) {
      qEl.innerHTML = `<div class="panel">${empty("inbox", "All callbacks done", "Every missed 111 call has been followed up.")}</div>`;
    } else {
      qEl.innerHTML = q.map((item) => {
        App._fuIndex[item.incident_id] = item;
        const who = nameFor(item.ext) || (item.caller !== "unknown" ? item.caller : "Unknown caller");
        const vm = item.voicemail === "available" ? pill("voicemail", "info") : "";
        const meta = `<code>${esc(item.incident_id)}</code> &middot; ${esc(fuAgo(item.ageSec))} ago` +
          (item.attempts ? ` &middot; ${item.attempts} attempt${item.attempts > 1 ? "s" : ""}` : "") +
          (item.lastNote ? ` &middot; "${esc(item.lastNote)}"` : "");
        const urgent = item.overdue || item.status === "needshelp";
        return `<div class="fu-item ${item.overdue ? "overdue" : ""}" data-iid="${esc(item.incident_id)}">
          <div class="fu-top">
            <div class="fu-who"><span class="fu-led ${urgent ? "crit" : ""}"></span>
              <span>${esc(who)}</span> <span class="num">${esc(item.ext)}</span></div>
            <div class="fu-badges">${vm}${fuBadge(item)}</div>
          </div>
          <div class="fu-meta">${meta}</div>
          <div class="fu-btns">
            <button class="btn" data-out="safe" type="button">Reached - safe</button>
            <button class="btn" data-out="needshelp" type="button">Needs help</button>
            <button class="btn" data-out="noanswer" type="button">No answer</button>
            <button class="btn" data-out="escalated" type="button">Escalated</button>
          </div>
        </div>`;
      }).join("");
    }
    const cl = Array.isArray(fu.recentClosed) ? fu.recentClosed : [];
    cEl.innerHTML = cl.length
      ? `<div class="table-wrap"><table><thead><tr><th>Caller</th><th>Incident</th><th>Outcome</th><th>By</th><th>When</th></tr></thead><tbody>` +
        cl.map((c) => `<tr><td>${esc(nameFor(c.ext) || c.caller)}</td><td><code>${esc(c.incident_id)}</code></td>` +
          `<td>${pill(esc(c.outcome), c.outcome === "safe" ? "ok" : "warn")}</td><td>${esc(nameFor(c.operator) || c.operator)}</td>` +
          `<td class="muted">${esc(fuWhen(c.time))}</td></tr>`).join("") + `</tbody></table></div>`
      : `<div class="panel">${empty("inbox", "No callbacks logged yet", "")}</div>`;
  },
});

/* ---- 5.1a2  Department Map (LIVE campus responder topology) ------------ */
// The department model the live map draws. Extensions are POSITIONS (dispatch +
// answer seats; Security also a Lead) — matches the Numbering Plan / SOP 30.
const DEPTS = [
  { key: "ert",      name: "ERT — answers 111", nodes: [
      { ext: "4101", label: "Lead" },   { ext: "4120", label: "Control" },
      { ext: "4110", label: "Op 1" },   { ext: "4111", label: "Op 2" },
      { ext: "4112", label: "Op 3" },   { ext: "4113", label: "Reserve" } ] },
  { key: "medical",  name: "Medical", nodes: [
      { ext: "4200", label: "Dispatch" }, { ext: "4201", label: "Resp 1" }, { ext: "4202", label: "Resp 2" } ] },
  { key: "security", name: "Security", nodes: [
      { ext: "4300", label: "Dispatch" }, { ext: "4301", label: "Lead" }, { ext: "4302", label: "Resp 1" }, { ext: "4303", label: "Resp 2" } ] },
  { key: "warden",   name: "Warden / Hostel", nodes: [
      { ext: "4400", label: "Dispatch" }, { ext: "4401", label: "Resp 1" }, { ext: "4402", label: "Resp 2" } ] },
  { key: "ops",      name: "Operations", nodes: [
      { ext: "4500", label: "Dispatch" }, { ext: "4501", label: "Resp 1" }, { ext: "4502", label: "Resp 2" } ] },
  { key: "it",       name: "IT / Network", nodes: [
      { ext: "4600", label: "Dispatch" }, { ext: "4601", label: "Resp 1" }, { ext: "4602", label: "Resp 2" } ] },
];

// Compute the SVG geometry (positions of every node + card). Pure — no DOM.
function dmBuild() {
  const W = 960, H = 644;
  const caller = { x: 18, y: 286, w: 152, h: 68 };
  const ert    = { x: 208, y: 150, w: 252, h: 236 };
  const geo = { W, H, caller, ert, nodes: {}, boxes: {} };
  // ERT chips: 2 columns × 3 rows inside the hub card.
  const ePadX = 14, eTop = ert.y + 44, chipH = 46, gY = 10, gX = 12;
  const eChipW = (ert.w - 2 * ePadX - gX) / 2;
  DEPTS[0].nodes.forEach((n, i) => {
    const col = i % 2, row = Math.floor(i / 2);
    const x = ert.x + ePadX + col * (eChipW + gX), y = eTop + row * (chipH + gY);
    geo.nodes[n.ext] = { x, y, w: eChipW, h: chipH, cx: x + eChipW / 2, cy: y + chipH / 2, label: n.label, dept: "ert" };
  });
  // Department cards stacked down the right side.
  const dx = 504, dw = 438, dh = 104, dgap = 12, y0 = 40;
  DEPTS.slice(1).forEach((d, i) => {
    const y = y0 + i * (dh + dgap);
    geo.boxes[d.key] = { x: dx, y, w: dw, h: dh, ax: dx, ay: y + dh / 2, name: d.name };
    const n = d.nodes.length, padX = 14, top = y + 42, ch = 46, cw = (dw - 2 * padX - (n - 1) * 10) / n;
    d.nodes.forEach((node, j) => {
      const nx = dx + padX + j * (cw + 10);
      geo.nodes[node.ext] = { x: nx, y: top, w: cw, h: ch, cx: nx + cw / 2, cy: top + ch / 2, label: node.label, dept: d.key };
    });
  });
  return geo;
}
function dmChipSvg(ext, nd) {
  return `<g class="dm-node is-off" id="dm-nd-${ext}" data-ext="${ext}">` +
    `<rect x="${nd.x}" y="${nd.y}" width="${nd.w}" height="${nd.h}" rx="7"/>` +
    `<text class="dm-ext" x="${nd.cx}" y="${nd.y + nd.h / 2 - 1}">${ext}</text>` +
    `<text class="dm-lbl" x="${nd.cx}" y="${nd.y + nd.h / 2 + 13}">${esc(nd.label)}</text></g>`;
}
function dmSvg(geo) {
  const c = geo.caller, e = geo.ert, p = [];
  p.push(`<svg class="arch-svg dm-svg" viewBox="0 0 ${geo.W} ${geo.H}" role="img" aria-label="Live department map">`);
  p.push(`<g id="dm-edges"></g>`);            // drawn first → sits under the nodes
  p.push(`<g class="dm-caller is-idle" id="dm-caller"><rect x="${c.x}" y="${c.y}" width="${c.w}" height="${c.h}" rx="11"/>` +
    `<text class="dm-ext" x="${c.x + c.w / 2}" y="${c.y + 27}">Campus caller</text>` +
    `<text class="dm-lbl" id="dm-caller-sub" x="${c.x + c.w / 2}" y="${c.y + 46}">dials 111</text></g>`);
  p.push(`<g class="dm-hub"><rect class="dm-card" x="${e.x}" y="${e.y}" width="${e.w}" height="${e.h}" rx="12"/>` +
    `<text class="dm-title" x="${e.x + 14}" y="${e.y + 25}">ERT — answers 111</text></g>`);
  DEPTS[0].nodes.forEach((n) => p.push(dmChipSvg(n.ext, geo.nodes[n.ext])));
  DEPTS.slice(1).forEach((d) => {
    const b = geo.boxes[d.key];
    p.push(`<g class="dm-dept"><rect class="dm-card" x="${b.x}" y="${b.y}" width="${b.w}" height="${b.h}" rx="12"/>` +
      `<text class="dm-title" x="${b.x + 14}" y="${b.y + 25}">${esc(b.name)}</text></g>`);
    d.nodes.forEach((n) => p.push(dmChipSvg(n.ext, geo.nodes[n.ext])));
  });
  p.push(`</svg>`);
  return p.join("");
}
function dmEdgeSvg(x1, y1, x2, y2, kind) {
  const mx = (x1 + x2) / 2, d = `M ${x1} ${y1} C ${mx} ${y1}, ${mx} ${y2}, ${x2} ${y2}`;
  return `<path class="dm-edge is-${kind}" d="${d}"/><path class="dm-flow is-${kind}" d="${d}"/>`;
}
function dmState(st) {
  const s = String(st || "").toLowerCase();
  if (/in use|busy/.test(s)) return "oncall";
  if (/ring/.test(s)) return "ringing";
  if (/not in use|idle|available|ready/.test(s)) return "ready";
  return "off";   // Unavailable / Invalid / Unknown / unreported
}
const DM_RANK = { coach: 1, ringing: 2, oncall: 3 };
const dmHotter = (a, b) => (DM_RANK[b] || 0) > (DM_RANK[a] || 0) ? b : (a || b);
function dmDur(n) { n = parseInt(n, 10) || 0; const m = Math.floor(n / 60), s = n % 60; return `${m}:${String(s).padStart(2, "0")}`; }
function dmRow(callerExt, toLabel, status, secs) {
  const meta = { oncall: ["on call", "ok"], ringing: ["ringing", "warn"], coaching: ["with coach", "info"] }[status] || [status, "neutral"];
  const nm = nameFor(callerExt);
  return `<tr><td><span class="num">${esc(callerExt)}</span>${nm ? ` <span class="muted">· ${esc(nm)}</span>` : ""}</td>` +
    `<td>${esc(toLabel)}</td><td>${pill(meta[0], meta[1], true)}</td><td>${esc(dmDur(secs))}</td></tr>`;
}
register({
  id: "deptmap", group: "Operations", icon: "map",
  title: "Department Map", subtitle: "Live campus responder map — who is calling, who is receiving, in real time",
  _geo: null,
  render() {
    this._geo = dmBuild();
    return `
      ${toolIntro("Live department map", "A caller dials 111; the ERT queue answers and dispatches; each department position lights up as it rings and connects — updated live from the PBX. Green = on shift · amber pulse = ringing · red = on a call · grey = off / unreachable.")}
      <div class="dm-toolbar">
        <span class="dm-legend"><span class="dm-key ready"></span>on shift</span>
        <span class="dm-legend"><span class="dm-key ringing"></span>ringing</span>
        <span class="dm-legend"><span class="dm-key oncall"></span>on a call</span>
        <span class="dm-legend"><span class="dm-key off"></span>off / down</span>
        <span class="dm-live-chip" id="dm-livechip">—</span>
      </div>
      ${dmSvg(this._geo)}
      <div class="section-label">Live calls <span class="hint" id="dm-age">connecting…</span></div>
      <div id="dm-live">${empty("phone", "Waiting for status…", "")}</div>`;
  },
  live(root, s) {
    const geo = this._geo; if (!geo) return;
    // 1) presence of every position (queueMembers refine ERT state if presence missing)
    const pres = {};
    if (s && Array.isArray(s.presence)) s.presence.forEach((p) => { pres[p.ext] = p.state; });
    if (s && Array.isArray(s.queueMembers)) s.queueMembers.forEach((m) => {
      const x = String(m.iface || "").split("/")[1]; if (x && pres[x] == null) pres[x] = m.state;
    });
    // 2) colour every node from presence
    Object.keys(geo.nodes).forEach((ext) => {
      const g = document.getElementById("dm-nd-" + ext);
      if (g) g.setAttribute("class", "dm-node is-" + dmState(pres[ext]));
    });
    // 3) derive edges + a human-readable call list from liveCalls[]
    const legs = s && Array.isArray(s.liveCalls) ? s.liveCalls : [];
    const isCaller = (e) => /^(5\d{8}|4\d{7}|1001)$/.test(String(e || ""));
    const isResp   = (e) => /^4(1\d\d|[2-6]\d\d)$/.test(String(e || ""));
    const isErt    = (e) => /^4(1\d\d|120)$/.test(String(e || ""));
    let callerKind = null;                 // hottest state of the caller→ERT edge
    const deptEdge = {};                   // dept key → hottest ERT→dept edge state
    const rows = [];
    const byBridge = {};
    legs.forEach((l) => { if (l.bridge) (byBridge[l.bridge] = byBridge[l.bridge] || []).push(l); });
    const paired = new Set();
    Object.keys(byBridge).forEach((bid) => {
      const grp = byBridge[bid];
      const cLeg = grp.find((l) => isCaller(l.ext)) || grp.find((l) => isCaller(l.cid));
      const rLeg = grp.find((l) => isResp(l.ext));
      if (!cLeg || !rLeg) return;
      paired.add(cLeg); paired.add(rLeg);
      callerKind = dmHotter(callerKind, "oncall");
      const rExt = rLeg.ext, secs = Math.max(rLeg.seconds || 0, cLeg.seconds || 0);
      const callerExt = cLeg.ext || cLeg.cid || "caller";
      if (!isErt(rExt)) { const k = geo.nodes[rExt] ? geo.nodes[rExt].dept : null; if (k) deptEdge[k] = dmHotter(deptEdge[k], "oncall"); }
      rows.push({ html: dmRow(callerExt, roleFor(rExt)[0] + " (" + rExt + ")", "oncall", secs) });
    });
    // unbridged caller legs → in the ERT queue, or with the offline coach
    legs.forEach((l) => {
      if (paired.has(l)) return;
      const callerExt = l.ext || l.cid;
      if (!isCaller(callerExt)) return;
      const dialed = String(l.dialed || ""), app = String(l.app || "").toLowerCase();
      const coach = ["s", "menu", "fastpath", "leave"].indexOf(dialed) >= 0 || /playback|background/.test(app) || /helpline|coach/.test(String(l.state || ""));
      callerKind = dmHotter(callerKind, coach ? "coach" : "ringing");
      rows.push({ html: dmRow(callerExt, coach ? "Offline coach" : "ERT queue (111)", coach ? "coaching" : "ringing", l.seconds) });
    });
    // presence-only: light ERT→dept for a department that is ringing / on a call but had no bridge leg
    Object.keys(geo.boxes).forEach((key) => {
      if (deptEdge[key]) return;
      const dept = DEPTS.find((d) => d.key === key);
      let hot = null;
      dept.nodes.forEach((n) => { const st = dmState(pres[n.ext]); if (st === "ringing" || st === "oncall") hot = dmHotter(hot, st === "oncall" ? "oncall" : "ringing"); });
      if (hot) deptEdge[key] = hot;
    });
    // 4) paint the edges (under the nodes)
    const edges = [];
    const cA = [geo.caller.x + geo.caller.w, geo.caller.y + geo.caller.h / 2];
    if (callerKind) edges.push(dmEdgeSvg(cA[0], cA[1], geo.ert.x, geo.ert.y + geo.ert.h / 2, callerKind));
    Object.keys(deptEdge).forEach((key) => {
      const b = geo.boxes[key];
      edges.push(dmEdgeSvg(geo.ert.x + geo.ert.w, geo.ert.y + geo.ert.h / 2, b.ax, b.ay, deptEdge[key]));
    });
    const eg = document.getElementById("dm-edges"); if (eg) eg.innerHTML = edges.join("");
    // 5) caller node + live counter
    const active = (s && s.activeCalls != null) ? s.activeCalls : rows.length;
    const callerG = document.getElementById("dm-caller");
    if (callerG) callerG.setAttribute("class", "dm-caller " + (callerKind ? "is-hot" : "is-idle"));
    const sub = document.getElementById("dm-caller-sub");
    if (sub) sub.textContent = callerKind ? (rows.length + " calling") : "dials 111";
    const chip = $("#dm-livechip", root);
    if (chip) {
      // GUARDRAIL: don't assert a live-call count the console can't prove is fresh.
      chip.textContent = (App.statusError || !s) ? "PBX offline"
        : App.liveStale ? "reconnecting…"
        : (active > 0 ? active + " live call" + (active === 1 ? "" : "s") : "no active calls");
      chip.className = "dm-live-chip" + (!App.statusError && s && !App.liveStale && active > 0 ? " hot" : "");
    }
    const age = $("#dm-age", root); if (age) age.textContent = (App.statusError || !s) ? "offline — last-known layout"
      : App.liveStale ? ("not live · last seen " + (App.liveAgeMs != null ? Math.round(App.liveAgeMs / 1000) + "s ago" : "link down"))
      : ("updated " + esc(s.updated || "—"));
    const box = $("#dm-live", root);
    if (box) {
      box.innerHTML = rows.length
        ? `<div class="table-wrap"><table><thead><tr><th>Caller</th><th>Receiving</th><th>Status</th><th>Elapsed</th></tr></thead><tbody>${rows.map((r) => r.html).join("")}</tbody></table></div>`
        : empty("phone", (App.statusError || !s) ? "PBX offline" : "No active calls", "The map shows current staffing; a call edge appears here the moment a 111 call connects.");
    }
  },
});

/* ---- 5.1b  shared classifiers for timeline / records / presence -------- */
// Role/label for an extension, from the numbering plan (no fabricated data).
const DEPT_NAME = { "42": "Medical", "43": "Security", "44": "Warden", "45": "Operations", "46": "IT / Network" };
function roleFor(ext) {
  const e = String(ext || "").trim();
  if (e === "4101") return ["ERT Lead", "crit"];
  if (/^411\d$/.test(e)) return ["ERT Operator", "warn"];
  if (e === "4120") return ["ERT Control Room", "warn"];
  if (e === "4301") return ["Security Lead", "warn"];
  if (/^4[2-6]\d\d$/.test(e)) {                       // department dispatch + answer seats
    const d = DEPT_NAME[e.slice(0, 2)];
    return [d + (e.slice(2) === "00" ? " Dispatch" : " Responder"), "info"];
  }
  if (/^4[7-9]\d\d$/.test(e)) return ["Fixed device / speaker", "neutral"];
  if (/^5\d{8}$/.test(e)) return ["Student", "neutral"];
  if (/^4\d{7}$/.test(e)) return ["Staff / faculty", "neutral"];
  if (e === "1001") return ["Legacy test client", "neutral"];
  return ["Client", "neutral"];
}
// Any staffed responder POSITION (ERT desks + all department dispatch/seats/lead).
const isResponderExt = (e) => /^4(1\d\d|[2-6]\d\d)$/.test(String(e || "").trim());
// Classify a CDR row into a timeline event kind.
function kindOf(row) {
  const d = String(row.dst || "").trim();
  const app = String(row.app || "").toLowerCase();
  const ctx = String(row.context || "").toLowerCase();
  if (d === "111") return { key: "emergency", label: "Emergency (111)", kind: "crit", icon: "phone" };
  if (d.indexOf("*77") === 0 || ctx.indexOf("sos") >= 0) return { key: "sos", label: "Silent SOS", kind: "crit", icon: "ert" };
  if (d === "199" || app.indexOf("drill") >= 0 || String(row.uniqueid).indexOf("DRILL") >= 0) return { key: "drill", label: "Drill / test", kind: "warn", icon: "ert" };
  if (/^900\d$/.test(d) || app.indexOf("confbridge") >= 0) return { key: "bridge", label: "Incident bridge", kind: "info", icon: "announce" };
  if (d === "198" || app === "echo") return { key: "echo", label: "Echo test", kind: "neutral", icon: "network" };
  if (/^7\d\d$/.test(d) || app === "page") return { key: "page", label: "Paging / announce", kind: "warn", icon: "announce" };
  if (isResponderExt(d)) return { key: "responder", label: "Responder call", kind: "info", icon: "hunt" };
  return { key: "call", label: "Call", kind: "neutral", icon: "phone" };
}
function dispoPill(d) {
  const s = String(d || "").toUpperCase();
  if (s === "ANSWERED") return pill("Answered", "ok");
  if (s === "NO ANSWER") return pill("No answer", "warn");
  if (s === "BUSY") return pill("Busy", "warn");
  if (s === "FAILED" || s === "CONGESTION") return pill(d || "Failed", "crit");
  return pill(d || "—", "neutral");
}
const dur = (n) => { n = parseInt(n, 10) || 0; const m = Math.floor(n / 60), s = n % 60; return m ? `${m}m ${s}s` : `${s}s`; };
const endpt = (e) => { const n = nameFor(e); return `<span class="num">${esc(e)}</span>${n ? ` <span class="muted">· ${esc(n)}</span>` : ""}`; };
// "20260704-193056" -> "2026-07-04 19:30:56"
function fmtRecTime(t) {
  const m = String(t || "").match(/^(\d{4})(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)$/);
  return m ? `${m[1]}-${m[2]}-${m[3]} ${m[4]}:${m[5]}:${m[6]}` : (t || "—");
}

/* ---- 5.1c  Incident Timeline (live, from CDR) -------------------------- */
const TL_FILTERS = [
  ["all", "All"], ["emergency", "Emergencies"], ["sos", "SOS"],
  ["drill", "Drills"], ["bridge", "Bridges"], ["page", "Paging"],
];
register({
  id: "timeline", group: "Operations", icon: "timeline",
  title: "Incident Timeline", subtitle: "Live stream of emergency, drill and bridge events",
  _filter: "all",
  render() {
    return `
      ${toolIntro("Live activity", "Every call the PBX handled, newest first — built from the call-detail log. Emergencies, drills, silent SOS and incident bridges are highlighted. Auto-refreshes with the wallboard.")}
      <div class="filterbar" id="tl-filters">
        ${TL_FILTERS.map((f) => `<button class="chip" type="button" data-f="${f[0]}"${f[0] === this._filter ? ' aria-pressed="true"' : ""}>${esc(f[1])}</button>`).join("")}
      </div>
      <div id="tl-list">${empty("timeline", "Waiting for status…", "")}</div>`;
  },
  mount(root) {
    const self = this;
    $("#tl-filters", root).addEventListener("click", (e) => {
      const b = e.target.closest(".chip"); if (!b) return;
      self._filter = b.dataset.f;
      $$("#tl-filters .chip", root).forEach((c) => c.setAttribute("aria-pressed", c.dataset.f === self._filter ? "true" : "false"));
      self._renderList(root, App.statusError ? null : App.status);
    });
  },
  live(root, s) { this._renderList(root, s); },
  _renderList(root, s) {
    const box = $("#tl-list", root); if (!box) return;
    const rows = s && Array.isArray(s.cdr) ? s.cdr.slice() : null;
    if (!rows) { box.innerHTML = empty("timeline", "No call-detail data", "status.json has no cdr[] yet — run Update-Status.ps1."); return; }
    const events = rows.map((r) => ({ r, k: kindOf(r) })).reverse()
      .filter((e) => this._filter === "all" ? true : e.k.key === this._filter);
    if (!events.length) { box.innerHTML = empty("timeline", "No matching events", "Nothing recorded for this filter yet."); return; }
    box.innerHTML = `<div class="timeline">` + events.map(({ r, k }) => `
      <div class="tl-item is-${k.kind}">
        <div class="tl-dot">${ICONS[k.icon] || ICONS.phone}</div>
        <div class="tl-body">
          <div class="tl-head">${pill(k.label, k.kind)} ${dispoPill(r.disposition)}
            <span class="tl-time">${esc(r.time || "—")}</span></div>
          <div class="tl-meta">${r.src ? `from ${endpt(r.src)} ` : ""}→ to ${endpt(r.dst)}
            <span class="muted">· ${esc(r.app || "")}${r.dur ? " · " + dur(r.dur) : ""}</span></div>
        </div>
      </div>`).join("") + `</div>`;
  },
});

/* ---- 5.1d  Presence & Shifts (live) ------------------------------------ */
register({
  id: "presence", group: "Operations", icon: "presence",
  title: "Presence & Shifts", subtitle: "Who is on each responder position right now",
  render() {
    return `
      ${toolIntro("Live presence", "Registration + queue state of every defined endpoint. Responder positions show who is on shift and reachable; clients show who is online. Auto-refreshes.")}
      <div class="section-label">Responder positions</div>
      <div class="table-wrap" id="pres-pos">${empty("presence", "Waiting for status…", "")}</div>
      <div class="section-label">Registered clients</div>
      <div class="table-wrap" id="pres-cli">${empty("register", "Waiting for status…", "")}</div>
      <div class="section-label">Recent shift changes <span class="hint">dial *22 to go on shift · *23 to go off</span></div>
      <div id="pres-shift">${empty("timeline", "Waiting for status…", "")}</div>`;
  },
  live(root, s) {
    // ---- shift log (who logged on/off, newest first) ----
    const shEl = $("#pres-shift", root);
    const sh = s && Array.isArray(s.shiftLog) ? s.shiftLog.slice().reverse() : null;
    if (shEl) {
      if (!sh) {
        shEl.innerHTML = `<div class="panel">${empty("timeline", "No shift log yet", "status.json has no shiftLog[] — dial *22/*23 to record a shift change.")}</div>`;
      } else if (!sh.length) {
        shEl.innerHTML = `<div class="panel">${empty("timeline", "No shift changes recorded", "Responders dial *22 to go on shift, *23 to go off.")}</div>`;
      } else {
        shEl.innerHTML = `<div class="table-wrap"><table><thead><tr><th>When</th><th>Who</th><th>Change</th></tr></thead><tbody>` +
          sh.map((e) => {
            const nm = nameFor(e.ext);
            const on = String(e.action || "").toUpperCase() === "ON";
            return `<tr><td>${esc(e.time || "—")}</td>` +
              `<td><span class="num">${esc(e.ext)}</span>${nm ? ` <span class="muted">· ${esc(nm)}</span>` : ""}</td>` +
              `<td>${on ? pill("ON shift", "ok", true) : pill("OFF shift", "neutral", true)}</td></tr>`;
          }).join("") + `</tbody></table></div>`;
      }
    }
    const pres = s && Array.isArray(s.presence) ? s.presence : null;
    const reg = s && Array.isArray(s.registeredUsers) ? s.registeredUsers : [];
    const qm = s && Array.isArray(s.queueMembers) ? s.queueMembers : [];
    const regMap = {}; reg.forEach((u) => regMap[u.ext] = u.ip || "");
    const inQueue = {}; qm.forEach((m) => { const x = String(m.iface || "").split("/")[1]; if (x) inQueue[x] = m.state; });

    const posEl = $("#pres-pos", root), cliEl = $("#pres-cli", root);
    if (!pres) {
      posEl.innerHTML = empty("presence", "No presence data", "status.json has no presence[] yet — run Update-Status.ps1.");
      cliEl.innerHTML = empty("register", "No presence data", "");
      return;
    }
    const positions = pres.filter((p) => isResponderExt(p.ext) || p.ext === "4120");
    const clients = pres.filter((p) => /^\d{8,9}$/.test(p.ext) || p.ext === "1001");

    const onShift = (p) => {
      const st = String(p.state || "").toLowerCase();
      const reachable = !/unavailable|invalid|unknown/.test(st);
      return reachable || regMap[p.ext] != null;
    };
    if (!positions.length) {
      posEl.innerHTML = empty("presence", "No responder positions defined", "");
    } else {
      posEl.innerHTML = `<table><thead><tr><th>Position</th><th>Role</th><th>On shift</th><th>Queue</th><th>State</th></tr></thead><tbody>` +
        positions.map((p) => {
          const role = roleFor(p.ext);
          const shift = onShift(p);
          return `<tr><td><span class="num">${esc(p.ext)}</span></td>` +
            `<td>${pill(role[0], role[1])}</td>` +
            `<td>${shift ? pill("On shift", "ok", true) : pill("Off / down", "crit", true)}</td>` +
            `<td>${inQueue[p.ext] ? pill("in 111 queue", "ok") : `<span class="muted">—</span>`}</td>` +
            `<td>${memberState(p.state)}</td></tr>`;
        }).join("") + `</tbody></table>`;
    }
    if (!clients.length) {
      cliEl.innerHTML = empty("register", "No clients present", "");
    } else {
      cliEl.innerHTML = `<table><thead><tr><th>Extension</th><th>Name</th><th>Registered</th><th>IP</th><th>State</th></tr></thead><tbody>` +
        clients.map((p) => {
          const nm = nameFor(p.ext);
          const registered = regMap[p.ext] != null;
          return `<tr><td><span class="num">${esc(p.ext)}</span></td>` +
            `<td>${nm ? `<span class="name">${esc(nm)}</span>` : `<span class="muted">not in roster</span>`}</td>` +
            `<td>${registered ? pill("online", "ok", true) : pill("offline", "neutral", true)}</td>` +
            `<td><code>${esc(regMap[p.ext] || "—")}</code></td>` +
            `<td>${memberState(p.state)}</td></tr>`;
        }).join("") + `</tbody></table>`;
    }
  },
});

/* ---- 5.1e  Call Records + recording playback --------------------------- */
register({
  id: "records", group: "Operations", icon: "records",
  title: "Call Records", subtitle: "Call-detail log and playback of recorded incidents",
  render() {
    return `
      ${toolIntro("Call detail + recordings", "The recent call-detail log, and in-browser playback of whole-call recordings. Recordings are synced from the PBX by Pull-Recordings.ps1 (run on the host).")}
      <div class="section-label">Recorded incidents</div>
      <div id="rec-list">${empty("records", "Waiting for status…", "")}</div>
      <div class="section-label">Call-detail log <span class="hint">most recent first</span></div>
      <div class="table-wrap" id="cdr-table">${empty("inbox", "Waiting for status…", "")}</div>`;
  },
  live(root, s) {
    // recordings
    const rEl = $("#rec-list", root);
    const recs = s && Array.isArray(s.recordings) ? s.recordings : null;
    // Only rebuild the grid when the recording set actually changes. The 4s poll
    // would otherwise recreate every <audio> element, pausing whatever is playing
    // and resetting its position. Skipping the re-render leaves the player alone.
    const recSig = recs ? recs.map((r) => `${r.file}|${r.time}`).join(",") : "__none__";
    if (rEl.dataset.recSig === recSig) {
      // recordings unchanged — leave the DOM (and any in-progress playback) intact
    } else if (!recs) {
      rEl.dataset.recSig = recSig;
      rEl.innerHTML = `<div class="panel">${empty("records", "No recording data", "status.json has no recordings[] yet.")}</div>`;
    } else if (!recs.length) {
      rEl.dataset.recSig = recSig;
      rEl.innerHTML = `<div class="panel">${empty("records", "No recordings yet", "Recorded incidents will appear here.")}</div>`;
    } else {
      rEl.dataset.recSig = recSig;
      rEl.innerHTML = `<div class="rec-grid">` + recs.map((r) => {
        const nm = nameFor(r.caller);
        return `<div class="rec-card">
          <div class="rec-top"><span class="pill info">${esc(r.incident || "incident")}</span>
            <span class="rec-time">${esc(fmtRecTime(r.time))}</span></div>
          <div class="rec-who">caller ${endpt(r.caller)}</div>
          <audio controls preload="metadata" src="recordings/${encodeURIComponent(r.file)}"></audio>
          <div class="rec-file"><code>${esc(r.file)}</code></div>
        </div>`;
      }).join("") + `</div>` +
        pbxNote("If a player shows an error, run <code>Pull-Recordings.ps1</code> on the host to sync the audio files into the Console.");
    }
    // cdr table
    const tEl = $("#cdr-table", root);
    const rows = s && Array.isArray(s.cdr) ? s.cdr.slice().reverse() : null;
    if (!rows) {
      tEl.innerHTML = empty("inbox", "No call-detail data", "status.json has no cdr[] yet.");
    } else if (!rows.length) {
      tEl.innerHTML = empty("inbox", "No calls recorded", "");
    } else {
      tEl.innerHTML = `<table><thead><tr><th>Time</th><th>From</th><th>To</th><th>App</th><th>Result</th><th>Length</th></tr></thead><tbody>` +
        rows.map((r) => `<tr><td>${esc(r.time || "—")}</td><td>${r.src ? endpt(r.src) : `<span class="muted">—</span>`}</td>` +
          `<td>${endpt(r.dst)}</td><td><span class="muted">${esc(r.app || "—")}</span></td>` +
          `<td>${dispoPill(r.disposition)}</td><td>${esc(dur(r.dur))}</td></tr>`).join("") + `</tbody></table>`;
    }
  },
});

/* ---- 5.1f  Insights / CDR analytics (live) ----------------------------- */
const KIND_META = {
  emergency: ["Emergency (111)", "crit"], drill: ["Drill (199)", "warn"],
  bridge: ["Incident bridge", "info"], paging: ["Paging", "warn"],
  echo: ["Echo test", "neutral"], other: ["Other calls", "neutral"],
};
// horizontal bar list: items = [{label, value, kind, note?}]
function hbars(items) {
  const max = Math.max(1, ...items.map((i) => i.value));
  return `<div class="bars">` + items.map((i) => `
    <div class="bar-row">
      <div class="bar-label">${i.label}</div>
      <div class="bar-track"><div class="bar-fill is-${i.kind || "info"}" style="width:${Math.round((i.value / max) * 100)}%"></div></div>
      <div class="bar-val">${esc(i.value)}${i.note ? ` <span class="muted">${esc(i.note)}</span>` : ""}</div>
    </div>`).join("") + `</div>`;
}
// vertical histogram: items = [{label, value, tip}], showEvery labels
function vbars(items, showEvery) {
  const max = Math.max(1, ...items.map((i) => i.value));
  return `<div class="histo">` + items.map((i, ix) => `
    <div class="hb" title="${esc(i.tip || (i.label + ": " + i.value))}">
      <div class="hb-bar" style="height:${i.value ? Math.max(6, Math.round((i.value / max) * 100)) : 2}%"></div>
      <div class="hb-x">${(showEvery ? (ix % showEvery === 0) : true) ? esc(i.label) : ""}</div>
    </div>`).join("") + `</div>`;
}
register({
  id: "insights", group: "Insights", icon: "chart",
  title: "Insights", subtitle: "Emergency KPIs, call volume and drill pass-rate",
  render() {
    return `
      ${toolIntro("Reporting", "Aggregated over the full call-detail log on the PBX. Answer-time on 111 is the key emergency KPI; drill pass-rate turns 199 drills into a measurable program. Auto-refreshes.")}
      <div class="tiles" id="an-kpi">${tileSkeletons(4)}</div>
      <div class="grid grid-2" style="margin-top:var(--sp-6)">
        <div><div class="section-label">Calls by type</div><div class="panel" id="an-kind">${empty("chart", "Waiting for status…", "")}</div></div>
        <div><div class="section-label">Top callers</div><div class="panel" id="an-callers">${empty("chart", "Waiting for status…", "")}</div></div>
      </div>
      <div class="section-label">Activity by hour of day</div>
      <div class="panel" id="an-hours">${empty("chart", "Waiting for status…", "")}</div>
      <div class="section-label">Calls per day <span class="hint">last 14 days</span></div>
      <div class="panel" id="an-days">${empty("chart", "Waiting for status…", "")}</div>`;
  },
  live(root, s) {
    const a = s && s.analytics ? s.analytics : null;
    const kpiEl = $("#an-kpi", root);
    if (!a) {
      kpiEl.innerHTML = [
        tile("Emergency answered", "—", "info", "of 111 calls"),
        tile("Avg answer time", "—", "info", "to pick up 111"),
        tile("Drill pass-rate", "—", "info", "199 answered"),
        tile("Total calls", "—", "info", "in the log"),
      ].join("");
      ["#an-kind", "#an-callers", "#an-hours", "#an-days"].forEach((sel) => {
        const el = $(sel, root); if (el) el.innerHTML = empty("chart", "No analytics data", "status.json has no analytics{} yet — run Update-Status.ps1.");
      });
      return;
    }
    const em = a.emergency || {}, dr = a.drill || {};
    const pct = (v) => v == null ? "—" : `${v}<span class="unit">%</span>`;
    kpiEl.innerHTML = [
      tile("Emergency answered", pct(em.answeredPct),
        em.answeredPct == null ? "info" : (em.answeredPct >= 95 ? "ok" : (em.answeredPct >= 80 ? "warn" : "crit")),
        `${em.answered || 0} of ${em.total || 0} calls to 111`),
      tile("Avg answer time", em.avgWait == null ? "—" : `${em.avgWait}<span class="unit">s</span>`,
        em.avgWait == null ? "info" : (em.avgWait <= 10 ? "ok" : (em.avgWait <= 20 ? "warn" : "crit")),
        em.maxWait == null ? "to pick up 111" : `max ${em.maxWait}s`),
      tile("Drill pass-rate", pct(dr.passPct),
        dr.passPct == null ? "info" : (dr.passPct >= 90 ? "ok" : (dr.passPct >= 70 ? "warn" : "crit")),
        `${dr.answered || 0} of ${dr.total || 0} drills answered`),
      tile("Total calls", a.total != null ? a.total : "—", "info", "in the call-detail log"),
    ].join("");

    // calls by type
    const kindEl = $("#an-kind", root);
    const bk = a.byKind || {};
    const kindItems = Object.keys(KIND_META).filter((k) => bk[k]).map((k) =>
      ({ label: pill(KIND_META[k][0], KIND_META[k][1]), value: bk[k] || 0, kind: KIND_META[k][1] }));
    kindEl.innerHTML = kindItems.length ? hbars(kindItems) : empty("chart", "No calls yet", "");

    // top callers
    const callersEl = $("#an-callers", root);
    const tc = Array.isArray(a.topCallers) ? a.topCallers : [];
    const callerItems = tc.map((row) => {
      const ext = row[0], n = row[1], nm = nameFor(ext);
      return { label: `<span class="num">${esc(ext)}</span>${nm ? ` <span class="muted">· ${esc(nm)}</span>` : ""}`, value: n, kind: "info" };
    });
    callersEl.innerHTML = callerItems.length ? hbars(callerItems) : empty("chart", "No callers yet", "");

    // hours histogram (0..23)
    const hoursEl = $("#an-hours", root);
    const hrs = Array.isArray(a.hours) ? a.hours : [];
    if (hrs.length === 24) {
      hoursEl.innerHTML = vbars(hrs.map((v, h) => ({ label: String(h).padStart(2, "0"), value: v, tip: `${String(h).padStart(2, "0")}:00 — ${v} call${v === 1 ? "" : "s"}` })), 3);
    } else { hoursEl.innerHTML = empty("chart", "No hourly data", ""); }

    // days
    const daysEl = $("#an-days", root);
    const days = a.days || {};
    const dkeys = Object.keys(days);
    if (dkeys.length) {
      daysEl.innerHTML = vbars(dkeys.map((d) => ({ label: d.slice(8), value: days[d], tip: `${d} — ${days[d]} calls` })), 1);
    } else { daysEl.innerHTML = empty("chart", "No daily data", ""); }
  },
});

/* ---- 5.1g  Emergency Call Flow (reference) ----------------------------- */
register({
  id: "callflow", group: "Reference", icon: "phone",
  title: "Emergency Call Flow", subtitle: "What happens when someone dials 111 — the disaster-ready path",
  render() {
    const flow = [
      ["crit", "phone", "111 answered instantly", "Call is recorded and given an incident ID <em>before</em> it rings anyone — nothing is ever lost. Calm prompt: “stay on the line, help is being reached. If someone needs first-aid now, press 1 any time.”"],
      ["info", "hunt", "Rings the ERT queue — humans first", "All available on-shift responders ring for 20s. Answered → a trained person handles it. This is always the priority path."],
      ["warn", "ert", "Press 1 any time → first-aid now", "A caller who knows it’s dire jumps straight to guidance without waiting the queue out — while the system keeps trying to reach a responder underneath."],
      ["crit", "announce", "No human in 20s → two things at once", "① A <strong>background alert</strong> rings the ERT Lead + backup (they press 1 to join the queue). ② The <strong>offline panic-coach</strong> starts immediately and logs a Missed Incident so a human calls back."],
      ["info", "ert", "Coach: first-aid + keep reaching a human", "Situations 1–7 (CPR · bleeding · choking · fire · lockdown · recovery · trapped). <strong>9</strong> = retry a responder (re-queue &amp; bridge whoever is now free). <strong>8</strong> = leave a message."],
      ["neutral", "inbox", "Voicemail → Missed Emergency Incident", "Never a dead end. Logged critical, callback within 5 minutes, never auto-closed."],
    ];
    const steps = `<div class="timeline">` + flow.map(([kind, icon, title, body]) => `
      <div class="tl-item is-${kind}">
        <div class="tl-dot">${ICONS[icon] || ICONS.phone}</div>
        <div class="tl-body"><div class="tl-head">${pill(title, kind)}</div>
          <div class="tl-meta">${body}</div></div>
      </div>`).join("") + `</div>`;
    const layer = (num, name, status, sk, desc) => `<tr>` +
      `<td><span class="num">${num}</span></td><td class="name">${esc(name)}</td>` +
      `<td>${pill(status, sk)}</td><td>${desc}</td></tr>`;
    return `
      <div class="callout"><span class="ct">One number</span> The campus learns exactly one number — <strong>111</strong>.
        <code>101</code> (online AI) and <code>102</code> (offline coach) are internal routes the system uses
        <strong>automatically</strong>; a caller is <strong>never</strong> told to hang up and dial them. Grounded in
        emergency-dispatch practice: stay on the line, no redial loops, coach in parallel with reaching a human.</div>
      <div class="section-label">When someone dials 111</div>
      ${steps}
      <div class="section-label">Graceful degradation — why it holds in a disaster</div>
      <div class="table-wrap"><table><thead><tr><th>Route</th><th>Layer</th><th>Status</th><th>Role</th></tr></thead><tbody>
        ${layer("111", "Human ERT", "live", "ok", "Human-first (dial 111). No AI/internet/cellular in its path, ever.")}
        ${layer("101", "Online AI triage", "planned", "neutral", "AVA + Gemini. Rides a 111 call when the van is online — spoken pre-brief, escalates to humans. Falls back to 102 offline.")}
        ${layer("102", "Offline panic-coach", "live", "ok", "Deterministic first-aid guidance. Zero internet, zero AI service — the guaranteed floor. Auto-fallback + direct test dial.")}
        ${layer("VM", "Emergency voicemail", "live", "ok", "Final catch — becomes a Missed Emergency Incident for guaranteed callback.")}
      </tbody></table></div>
      <div class="callout"><span class="ct">Order of preference</span> on an unanswered 111:
        <strong>human → 101 (if online) → 102 (always) → voicemail</strong>. Every fallback works with no internet.</div>`;
  },
});

function bannerSkeleton() {
  return `<div class="banner s-neutral"><div class="banner-badge skel">·····</div>` +
    `<div class="banner-text"><div class="h skel">Connecting to the PBX…</div>` +
    `<div class="p">Reading status.json</div></div></div>`;
}
function bannerHtml(info, overrideText, updated) {
  return `<div class="banner ${info[0]}"><div class="banner-badge">${esc(info[1])}</div>` +
    `<div class="banner-text"><div class="h">${overrideText ? esc(overrideText) : esc(info[2])}</div>` +
    `<div class="p">Dial 111 — the campus emergency hotline. This wallboard refreshes automatically.</div></div>` +
    `${updated ? `<div class="banner-time">as of<br>${esc(updated)}</div>` : ""}</div>`;
}
function tile(k, v, kind, foot, isDim) {
  return `<div class="tile is-${kind || "info"}"><div class="tile-k">${esc(k)}</div>` +
    `<div class="tile-v${isDim ? " small" : ""}">${v}</div>` +
    `<div class="tile-foot">${esc(foot || "")}</div></div>`;
}
function tileSkeletons(n) {
  let out = "";
  for (let i = 0; i < n; i++) out += `<div class="tile"><div class="tile-k skel">····</div>` +
    `<div class="tile-v skel" style="width:60%">··</div><div class="tile-foot skel" style="width:40%">·</div></div>`;
  return out;
}
function memberState(st) {
  const s = String(st || "").toLowerCase();
  if (/not in use|idle|available|ready/.test(s)) return pill(st || "Available", "ok", true);
  if (/in use|busy|ringing|on hold|paused/.test(s)) return pill(st || "In use", "warn", true);
  if (/unavailable|invalid|unreachable|offline/.test(s)) return pill(st || "Unavailable", "crit", true);
  return pill(st || "Unknown", "neutral", true);
}
function severityPill(sev) {
  const s = String(sev || "").toLowerCase();
  if (/crit|high|1|red/.test(s)) return pill(sev || "critical", "crit");
  if (/med|warn|2|amber/.test(s)) return pill(sev || "medium", "warn");
  if (/low|3|minor/.test(s)) return pill(sev || "low", "neutral");
  return pill(sev || "—", "neutral");
}

/* ---- 5.2  Register a Client -------------------------------------------- */
const ROLE_MAP = {
  student:   ["ctx_student", "SAP ID (9-digit)", false],
  staff:     ["ctx_staff", "Employee ID (8-digit)", false],
  ert:       ["ctx_ert", "Position ext (4110–4119)", true],
  ertlead:   ["ctx_ert_lead", "Position ext (4101)", true],
  responder: ["ctx_responder", "Position ext (4200-4202 / 4302-4303 / …)", true],
  responderlead: ["ctx_responder_lead", "Dept-lead ext (4301)", true],
  fixed:     ["ctx_fixed_device", "Device ext (4700+)", true],
};
register({
  id: "register", group: "Operations", icon: "register",
  title: "Register a Client", subtitle: "Generate the import line, a secret, and Linphone settings",
  render() {
    return `
      <div class="callout"><span class="ct">Onboard a phone</span>
        Fill this in to generate the CSV import line, a strong crypto-random secret, and the exact
        Linphone settings to hand to the user. Everything is computed locally — nothing leaves this page.</div>
      <div class="grid grid-2" style="margin-top:var(--sp-5)">
        <div class="panel">
          <div class="panel-head"><h3>New client</h3></div>
          <div class="field"><label class="field-label" for="r-name">Full name</label>
            <input id="r-name" placeholder="e.g. Staff Member One"></div>
          <div class="field"><label class="field-label" for="r-role">Role</label>
            <select id="r-role">
              <option value="student">Student (SAP ID = extension)</option>
              <option value="staff">Staff / Faculty (employee ID = extension)</option>
              <option value="ert">ERT Operator position (answers 111 queue)</option>
              <option value="ertlead">ERT Lead position</option>
              <option value="responder">Responder position (Medical / Security / …)</option>
              <option value="responderlead">Department lead position (Security 4301)</option>
              <option value="fixed">Fixed device (speaker / gate phone)</option>
            </select></div>
          <div class="field"><label class="field-label" for="r-id"><span id="r-idlabel">SAP ID (9-digit)</span></label>
            <input id="r-id" placeholder="e.g. 500120597">
            <div class="help" id="r-idhelp"></div></div>
          <div class="field"><label class="field-label" for="r-dev">Max devices</label>
            <input id="r-dev" type="number" value="2" min="1" max="5"></div>
          <div class="field"><button class="btn" id="r-gen" type="button">${ICONS.register}Generate</button></div>
          <div class="help">The secret is crypto-random and generated in your browser. Deliver it once, securely; never store it in plain text.</div>
        </div>
        <div class="panel" id="r-out" hidden>
          <div class="panel-head"><h3>Result</h3></div>
          <div id="r-outbody"></div>
        </div>
      </div>
      <div class="section-label">How registration works</div>
      <div class="panel lead stack">
        <p><b>Humans</b> use their SAP / employee ID as the extension. <b>Responder roles are positions</b>
          (4xxx) staffed by shift — never a person's personal account. <b>Fixed devices</b> (4700s) are location-bound.</p>
        <p>Two ways to add the account:</p>
        <ol style="margin:0;padding-left:20px">
          <li><b>FreePBX / bulk:</b> add the CSV line to <code>provisioning/*.csv</code> → <em>Bulk Handler → Import</em>. See <a href="../provisioning/README.md">provisioning/README</a>.</li>
          <li><b>Direct on the PBX</b> (advanced): add a PJSIP endpoint / auth / aor to <code>pjsip.conf</code> and reload.</li>
        </ol>
        <p>Then the user installs <b>Linphone</b>, enters the settings above, and dials <span class="num">111</span> for emergencies.</p>
      </div>`;
  },
  mount(root) {
    const roleSel = $("#r-role", root);
    const syncLabel = () => {
      const [, label, isPos] = ROLE_MAP[roleSel.value];
      $("#r-idlabel", root).textContent = label;
      $("#r-idhelp", root).textContent = isPos ? "This is a POSITION staffed by shift, not a person's account." : "";
    };
    roleSel.addEventListener("change", syncLabel);
    syncLabel();
    $("#r-gen", root).addEventListener("click", () => {
      const name = ($("#r-name", root).value.trim()) || "(name)";
      const id   = ($("#r-id", root).value.trim()) || "(ext)";
      const role = roleSel.value;
      const [ctx, , isPos] = ROLE_MAP[role];
      const dev = $("#r-dev", root).value || 1;
      const sec = secret();
      const cid = isPos ? name : `${name} - ${id}`;
      const csvHeader = "extension,name,secret,tech,context,outbound_cid,voicemail,max_contacts";
      const csv = `${id},${name},${sec},pjsip,${ctx},"${cid}",no,${dev}`;
      const linphone =
        `SIP server : ${App.serverIp}\nUsername   : ${id}\nPassword   : ${sec}\nTransport  : UDP\nDisplay    : ${cid}`;
      $("#r-outbody", root).innerHTML =
        `<p class="lead">Extension <span class="num">${esc(id)}</span> · context <code>${esc(ctx)}</code>` +
        `${isPos ? ` · ${pill("position", "info")}` : ""}</p>` +
        `<div class="field"><label class="field-label">CSV import line — add to provisioning, then Bulk Handler → Import</label>` +
        code(`${csvHeader}\n${csv}`) + `</div>` +
        `<div class="field"><label class="field-label">Linphone settings — give to the user</label>` +
        code(linphone) + `</div>` +
        `<div class="help">On this network the PBX is <b>${esc(App.serverIp)}</b>. It updates automatically when the van rebinds to another network.</div>`;
      $("#r-out", root).hidden = false;
    });
  },
});
function secret(n = 18) {
  const a = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#%^*-_";
  const v = crypto.getRandomValues(new Uint32Array(n));
  return Array.from(v, (x) => a[x % a.length]).join("");
}

/* ---- 5.3  Mass Callout -------------------------------------------------- */
register({
  id: "callout", group: "Emergency tools", icon: "callout",
  title: "Mass Callout", subtitle: "Trigger a recorded message to a group of phones",
  render() {
    return toolIntro("Mass Callout",
      "Pick a target group and a recorded message. The Console is a LAN-static page and cannot place calls itself — it produces the exact command / CSV for an operator to run on the PBX.") +
      `<div class="grid grid-2" style="margin-top:var(--sp-5)">
        <div class="panel">
          <div class="field"><label class="field-label" for="c-group">Target group</label>
            <select id="c-group">${CALLOUT_GROUPS.map((g) => `<option value="${g.id}">${esc(g.label)}</option>`).join("")}</select></div>
          <div class="field"><label class="field-label" for="c-msg">Recorded message</label>
            <select id="c-msg">${MESSAGES.map((m) => `<option value="${m.id}">${esc(m.label)}</option>`).join("")}</select>
            <div class="help">Recording names follow the SOP 28 convention — confirm the actual prompt on the PBX.</div></div>
          <div class="field"><button class="btn danger" id="c-gen" type="button">Generate callout command</button></div>
        </div>
        <div class="panel" id="c-out"><div class="panel-head"><h3>Command</h3></div>
          <div id="c-body">${empty("callout", "No command yet", "Choose a group and message, then generate.")}</div></div>
      </div>`;
  },
  mount(root) {
    $("#c-gen", root).addEventListener("click", () => {
      const g = CALLOUT_GROUPS.find((x) => x.id === $("#c-group", root).value);
      const m = MESSAGES.find((x) => x.id === $("#c-msg", root).value);
      const cmd = `sudo /opt/upes-ecs/mass_callout.sh /opt/upes-ecs/groups/${g.id}.csv ${m.prompt} notify`;
      $("#c-body", root).innerHTML =
        `<p class="lead">Calls out <b>${esc(g.label)}</b> with <b>${esc(m.label)}</b>.</p>` +
        code(cmd, "callout command") +
        `<div class="exec-row">${execButton("Execute callout")}</div>` +
        pbxNote(`Rings every phone in the group and plays <code>${esc(m.prompt)}</code>. Unregistered phones are skipped. Restricted to Control / ERT-Lead.`);
      $("#c-body .exec-btn", root).addEventListener("click", () => confirmExec({
        title: "Run mass callout — " + g.label,
        what: `This <b>calls every phone</b> in <b>${esc(g.label)}</b> and plays <b>${esc(m.label)}</b>. Each phone rings; on answer it hears the recording. Unregistered phones are skipped and logged.`,
        command: cmd, action: "callout", args: { group: g.id, sound: m.prompt, mode: "notify" },
      }));
    });
  },
});

/* ---- 5.4  Roll-call / Headcount ---------------------------------------- */
register({
  id: "rollcall", group: "Emergency tools", icon: "rollcall",
  title: "Roll-call / Headcount", subtitle: "Start a press-1-safe headcount and tally responses",
  render() {
    return toolIntro("Roll-call / Headcount",
      "Start a headcount: the PBX pages the group with a press-1-if-safe prompt. Generate the command below, run it on the PBX, then tally responses here as they come in.") +
      `<div class="grid grid-2" style="margin-top:var(--sp-5)">
        <div class="panel">
          <div class="field"><label class="field-label" for="rc-group">Group to count</label>
            <select id="rc-group">${CALLOUT_GROUPS.map((g) => `<option value="${g.id}">${esc(g.label)}</option>`).join("")}</select></div>
          <div class="field"><button class="btn" id="rc-gen" type="button">Generate roll-call command</button></div>
          <div id="rc-cmd"></div>
        </div>
        <div class="panel">
          <div class="panel-head"><h3>Tally</h3><span class="sub">live from the PBX · manual override</span></div>
          <div class="field-row">
            <div class="field"><label class="field-label" for="rc-safe">Responded safe (pressed 1)</label>
              <input id="rc-safe" type="number" min="0" value="0"></div>
            <div class="field"><label class="field-label" for="rc-total">Expected headcount</label>
              <input id="rc-total" type="number" min="0" value="0"></div>
          </div>
          <div class="tiles" style="margin-top:var(--sp-4)">
            <div class="tile is-ok"><div class="tile-k">Safe</div><div class="tile-v" id="rc-t-safe">0</div></div>
            <div class="tile is-crit"><div class="tile-k">Unaccounted</div><div class="tile-v" id="rc-t-miss">0</div></div>
            <div class="tile is-info"><div class="tile-k">Accounted</div><div class="tile-v" id="rc-t-pct">—</div></div>
          </div>
          <div id="rc-live" style="margin-top:var(--sp-4)"></div>
          <div class="help" style="margin-top:var(--sp-3)">Follow up on unaccounted names via Warden (4400) and the Directory.</div>
        </div>
      </div>`;
  },
  live(root, s) {
    const el = $("#rc-live", root); if (!el) return;
    const rc = s && s.rollcall ? s.rollcall : null;
    if (!rc) { el.innerHTML = empty("rollcall", "No roll-call run yet", "Start one — results appear here live as people press 1."); return; }
    // auto-fill the manual tally from the live run unless the operator has typed their own
    const safeIn = $("#rc-safe", root), totIn = $("#rc-total", root);
    if (safeIn && !safeIn.dataset.touched) { safeIn.value = rc.safe; }
    if (totIn && !totIn.dataset.touched) { totIn.value = rc.called; safeIn && safeIn.dispatchEvent(new Event("input")); }
    const un = Array.isArray(rc.unaccountedExts) ? rc.unaccountedExts : [];
    el.innerHTML =
      `<div class="section-label">Live results <span class="hint">run ${esc(rc.time || rc.runid || "")}</span></div>` +
      `<div class="tiles"><div class="tile is-ok"><div class="tile-k">Safe (pressed 1)</div><div class="tile-v">${esc(rc.safe)}</div><div class="tile-foot">of ${esc(rc.called)} called</div></div>` +
      `<div class="tile is-crit"><div class="tile-k">Unaccounted</div><div class="tile-v">${esc(rc.unaccounted)}</div><div class="tile-foot">no response yet</div></div></div>` +
      (un.length
        ? `<div class="section-label">Unaccounted (${un.length})</div><div class="roster-grid">` +
            un.map((e) => { const n = nameFor(e); return `<div class="person"><div class="avatar" style="background:var(--crit-ink)">${esc(String(e).slice(-2))}</div>` +
              `<div class="who"><div class="n">${n ? esc(n) : "not in roster"}</div><div class="e"><span class="num">${esc(e)}</span></div></div></div>`; }).join("") + `</div>`
        : `<div class="panel">${pill("all accounted", "ok")} &nbsp;everyone called has responded.</div>`);
  },
  mount(root) {
    $("#rc-gen", root).addEventListener("click", () => {
      const g = CALLOUT_GROUPS.find((x) => x.id === $("#rc-group", root).value);
      const cmd = `sudo /opt/upes-ecs/mass_callout.sh /opt/upes-ecs/groups/${g.id}.csv custom/upes-rollcall rollcall`;
      $("#rc-cmd", root).innerHTML = code(cmd, "roll-call command") +
        `<div class="exec-row">${execButton("Start roll-call")}</div>` +
        pbxNote("Pages the group and collects a “press 1” response per phone. Results log to <code>/var/lib/upes-ecs/rollcall/</code>.");
      $("#rc-cmd .exec-btn", root).addEventListener("click", () => confirmExec({
        title: "Start roll-call — " + g.label,
        what: `This <b>rings every phone</b> in <b>${esc(g.label)}</b> and asks each person to <b>press 1 if safe</b>. Responses are collected on the PBX — use the Tally panel to track safe vs unaccounted.`,
        command: cmd, action: "callout", args: { group: g.id, sound: "custom/upes-rollcall", mode: "rollcall" },
      }));
    });
    const safe = $("#rc-safe", root), total = $("#rc-total", root);
    const recalc = () => {
      const s = Math.max(0, parseInt(safe.value || 0, 10));
      const t = Math.max(0, parseInt(total.value || 0, 10));
      const miss = Math.max(0, t - s);
      $("#rc-t-safe", root).textContent = s;
      $("#rc-t-miss", root).textContent = miss;
      $("#rc-t-pct", root).innerHTML = t > 0 ? Math.round((s / t) * 100) + '<span class="unit">%</span>' : "—";
    };
    safe.addEventListener("input", () => { safe.dataset.touched = "1"; recalc(); });
    total.addEventListener("input", () => { total.dataset.touched = "1"; recalc(); });
    recalc();
  },
});

/* ---- 5.4b  Safety status (UPES Safe app: I'm safe / need help) ---------- */
register({
  id: "safety", group: "Emergency tools", icon: "rollcall",
  title: "Safety status", subtitle: "App 'I'm safe' / 'need help' + the emergency campaign",
  render() {
    return toolIntro("Safety status",
      "The UPES Safe app shows every student an <b>I'm safe / need help</b> prompt during an emergency, and parents see their child's status live. A real 111 call raises the campaign automatically; you can also raise/clear it here.") +
      `<div class="grid grid-2" style="margin-top:var(--sp-5)">
        <div class="panel">
          <div class="panel-head"><h3>Emergency campaign</h3><span class="sub" id="sf-state">—</span></div>
          <p class="help">Raising it pushes the "mark yourself safe" prompt to every app within ~10s and speeds up location reporting. Clear it once the incident is over.</p>
          <div class="exec-row" id="sf-actions"></div>
        </div>
        <div class="panel">
          <div class="panel-head"><h3>Responses</h3><span class="sub">live from the app</span></div>
          <div class="tiles">
            <div class="tile is-ok"><div class="tile-k">Declared safe</div><div class="tile-v" id="sf-safe">0</div></div>
            <div class="tile is-crit"><div class="tile-k">Need help</div><div class="tile-v" id="sf-need">0</div></div>
          </div>
          <div id="sf-list" style="margin-top:var(--sp-4)"></div>
        </div>
      </div>`;
  },
  live(root, s) {
    const sf = s && s.safety ? s.safety : null;
    const active = !!(sf && sf.emergency && sf.emergency.active);
    const stateEl = $("#sf-state", root), actEl = $("#sf-actions", root);
    if (stateEl) stateEl.innerHTML = active ? pill("emergency ACTIVE", "crit") : pill("no emergency", "ok");
    // Rebuild the action button only when the active-state flips (mount runs once and
    // can't know live state). dataset guards against re-binding every poll.
    if (actEl && actEl.dataset.state !== String(active)) {
      actEl.dataset.state = String(active);
      actEl.innerHTML = active
        ? `<button class="btn" id="sf-clear" type="button">Clear emergency</button>`
        : `<button class="btn danger" id="sf-raise" type="button">Raise emergency</button>`;
      const raise = $("#sf-raise", root), clear = $("#sf-clear", root);
      if (raise) raise.addEventListener("click", () => confirmExec({
        title: "Raise campus emergency",
        what: "This pushes an <b>I'm safe / need help</b> prompt to <b>every UPES Safe app</b> on campus and speeds up their location reporting. Parents see their child's status live.",
        command: "emergency raise", action: "emergency", args: { active: true, reason: "console" },
      }));
      if (clear) clear.addEventListener("click", () => confirmExec({
        title: "Clear campus emergency",
        what: "This ends the safe-check campaign. Location reporting returns to its normal (slower) cadence.",
        command: "emergency clear", action: "emergency", args: { active: false },
      }));
    }
    if (sf) {
      const safeEl = $("#sf-safe", root), needEl = $("#sf-need", root);
      if (safeEl) safeEl.textContent = sf.safeCount || 0;
      if (needEl) needEl.textContent = sf.needHelpCount || 0;
      const list = $("#sf-list", root);
      const nh = Array.isArray(sf.needHelp) ? sf.needHelp : [];
      if (list) list.innerHTML = nh.length
        ? `<div class="section-label">Need help (${nh.length})</div><div class="roster-grid">` +
          nh.map((h) => { const n = h.name || nameFor(h.sap) || "unknown";
            return `<div class="person"><div class="avatar" style="background:var(--crit-ink)">${esc(String(h.sap).slice(-2))}</div>` +
              `<div class="who"><div class="n">${esc(n)}</div><div class="e"><span class="num">${esc(h.sap)}</span>${h.note ? " · " + esc(h.note) : ""}</div></div></div>`; }).join("") + `</div>`
        : `<div class="panel">${pill("clear", "ok")} &nbsp;no help requests.</div>`;
    }
  },
});

/* ---- 5.4c  Live map (UPES Safe app positions, offline schematic) -------- */
function fmtAge(s) {
  if (s == null) return "—";
  if (s < 60) return s + "s ago";
  if (s < 3600) return Math.round(s / 60) + "m ago";
  return Math.round(s / 3600) + "h ago";
}
function drawLiveMap(root, d) {
  const camp = d.campus || {}, people = Array.isArray(d.people) ? d.people : [];
  const clat = camp.lat || 0, clon = camp.lon || 0, R = camp.radiusM || 900;
  const svgEl = root.querySelector("#lm-svg");

  if (!people.length) {
    if (svgEl) svgEl.innerHTML = empty("livemap", "Waiting for app check-ins",
      "Dots appear here as phones report their location.");
    ["#lm-on", "#lm-off", "#lm-tot"].forEach((id) => { const n = root.querySelector(id); if (n) n.textContent = 0; });
    return;
  }

  // Project lat/lon -> local metres around the campus centre (equirectangular; fine at
  // campus scale). No map tiles — this is an internet-isolated LAN.
  const cosLat = Math.cos(clat * Math.PI / 180);
  const pts = people.map((p) => ({ p,
    x: (p.lon - clon) * cosLat * 111320,
    y: (p.lat - clat) * 110540 }));
  let maxD = R * 1.35;
  pts.forEach((q) => { const dd = Math.hypot(q.x, q.y); if (dd > maxD) maxD = dd * 1.12; });

  const S = 300, cx = S / 2, cy = S / 2, pad = 30, scale = (S / 2 - pad) / maxD;
  const geoR = R * scale;
  const showLabels = people.length <= 12;   // avoid clutter on big crowds

  // dots (off-campus drawn last so they read on top)
  const draw = (q) => {
    const px = cx + q.x * scale, py = cy - q.y * scale;
    const off = !q.p.onCampus, active = q.p.appActive;
    const col = off ? "var(--crit-ink,#d5202b)" : (active ? "var(--ok-ink,#1a8a3a)" : "#8a8f98");
    let g = "";
    if (active && !off) g += `<circle cx="${px.toFixed(1)}" cy="${py.toFixed(1)}" r="9" fill="${col}" opacity=".16"/>`;
    // active = filled; stale = hollow ring
    g += active
      ? `<circle cx="${px.toFixed(1)}" cy="${py.toFixed(1)}" r="5" fill="${col}" stroke="var(--panel)" stroke-width="1.6"/>`
      : `<circle cx="${px.toFixed(1)}" cy="${py.toFixed(1)}" r="4.6" fill="var(--panel)" stroke="${col}" stroke-width="2"/>`;
    if (showLabels) g += `<text x="${(px + 8).toFixed(1)}" y="${(py + 3.5).toFixed(1)}" class="lm-lbl">${esc(q.p.name || q.p.sap)}</text>`;
    return g;
  };
  const onDots = pts.filter((q) => q.p.onCampus).map(draw).join("");
  const offDots = pts.filter((q) => !q.p.onCampus).map(draw).join("");

  const svg = `<svg viewBox="0 0 ${S} ${S}" width="100%" style="max-height:56vh" role="img" aria-label="Live campus positions">
    <style>
      .lm-lbl{font-size:8.5px;fill:var(--ink);paint-order:stroke;stroke:var(--panel);stroke-width:2.4px;stroke-linejoin:round}
      .lm-pulse{animation:lmPulse 2.6s ease-out infinite}
      @keyframes lmPulse{0%{r:4;opacity:.5}100%{r:${geoR.toFixed(0)};opacity:0}}
      @media (prefers-reduced-motion:reduce){.lm-pulse{display:none}}
    </style>
    <circle cx="${cx}" cy="${cy}" r="${(geoR).toFixed(1)}" fill="rgba(26,138,58,.06)" stroke="var(--ok-ink,#1a8a3a)" stroke-dasharray="5 5" stroke-width="1.4"/>
    <circle cx="${cx}" cy="${cy}" r="${(geoR * 0.5).toFixed(1)}" fill="none" stroke="var(--line)" stroke-width="1"/>
    <circle class="lm-pulse" cx="${cx}" cy="${cy}" fill="none" stroke="var(--ok-ink,#1a8a3a)" stroke-width="1.2"/>
    <line x1="${cx}" y1="10" x2="${cx}" y2="18" stroke="var(--muted)" stroke-width="1"/>
    <text x="${cx}" y="9" text-anchor="middle" font-size="8" fill="var(--muted)">N</text>
    <circle cx="${cx}" cy="${cy}" r="2.6" fill="var(--ok-ink,#1a8a3a)"/>
    <text x="${cx}" y="${(cy - geoR - 6).toFixed(1)}" text-anchor="middle" font-size="9" fill="var(--ok-ink,#1a8a3a)">campus · ${Math.round(R)} m</text>
    ${onDots}${offDots}
  </svg>`;
  if (svgEl) svgEl.innerHTML = svg;

  const on = people.filter((p) => p.onCampus).length;
  const stale = people.filter((p) => !p.appActive).length;
  const setv = (id, v) => { const n = root.querySelector(id); if (n) n.textContent = v; };
  setv("#lm-on", on); setv("#lm-off", people.length - on); setv("#lm-tot", people.length);
  const freshest = people.reduce((m, p) => (p.ageSec != null && (m == null || p.ageSec < m) ? p.ageSec : m), null);
  const sub = root.querySelector("#lm-sub");
  if (sub) sub.textContent = `${people.length} reporting · newest ${fmtAge(freshest)}${stale ? " · " + stale + " stale" : ""}`;
}
register({
  id: "livemap", group: "Operations", icon: "livemap",
  title: "Live map", subtitle: "Where UPES Safe app users are now (campus geofence)",
  render() {
    return `<div class="panel">
        <div class="panel-head"><h3>Live positions</h3><span class="sub" id="lm-sub">loading…</span></div>
        <div id="lm-svg" style="text-align:center;color:var(--ink);min-height:180px">${empty("livemap", "Waiting for app check-ins", "Dots appear here as phones report their location.")}</div>
        <div class="tiles" style="margin-top:var(--sp-4)">
          <div class="tile is-ok"><div class="tile-k">On campus</div><div class="tile-v" id="lm-on">0</div></div>
          <div class="tile is-crit"><div class="tile-k">Off campus</div><div class="tile-v" id="lm-off">0</div></div>
          <div class="tile is-info"><div class="tile-k">Reporting</div><div class="tile-v" id="lm-tot">0</div></div>
        </div>
        <div class="help" style="margin-top:var(--sp-3);display:flex;gap:16px;flex-wrap:wrap;align-items:center">
          <span><span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:var(--ok-ink);vertical-align:middle;margin-right:5px"></span>on campus · active</span>
          <span><span style="display:inline-block;width:9px;height:9px;border-radius:50%;border:2px solid #8a8f98;vertical-align:middle;margin-right:5px"></span>stale (no recent ping)</span>
          <span><span style="display:inline-block;width:9px;height:9px;border-radius:50%;background:var(--crit-ink);vertical-align:middle;margin-right:5px"></span>off campus</span>
          <span class="muted">· offline schematic, GPS relative to campus centre — no internet map tiles</span>
        </div>
      </div>`;
  },
  live(root) {
    const now = Date.now();
    if (root.dataset.lmAt && now - (+root.dataset.lmAt) < 4000) return;  // throttle to ~4s
    root.dataset.lmAt = String(now);
    fetch("/api/map", { cache: "no-store" })
      .then((r) => (r.ok ? r.json() : null))
      .then((d) => { if (d && root.isConnected) drawLiveMap(root, d); })
      .catch(() => {});
  },
});

/* ---- 5.5  Announcements ------------------------------------------------- */
register({
  id: "announce", group: "Emergency tools", icon: "announce",
  title: "Announcements", subtitle: "Page a zone with a pre-recorded message",
  render() {
    return toolIntro("Announcements",
      "Pick a paging zone and a pre-recorded message to produce the exact page command. Paging is restricted to ERT-Lead / Control.") +
      `<div class="callout warn"><span class="ct">Restricted control</span>
        Paging zones override every phone in the zone. Only ERT-Lead / Control may page; zone 700 (all-campus) is PIN-restricted.</div>
      <div class="grid grid-2" style="margin-top:var(--sp-5)">
        <div class="panel">
          <div class="field"><label class="field-label" for="a-zone">Paging zone</label>
            <select id="a-zone">${REF.paging.map((z) => `<option value="${z[0]}">${z[0]} · ${esc(z[1])}${z[2] ? " (" + z[2] + ")" : ""}</option>`).join("")}</select></div>
          <div class="field"><label class="field-label" for="a-msg">Message</label>
            <select id="a-msg">${MESSAGES.map((m) => `<option value="${m.id}">${esc(m.label)}</option>`).join("")}</select>
            <div class="help">Recording names follow the SOP 28 convention — confirm the actual prompt on the PBX.</div></div>
          <div class="field"><button class="btn danger" id="a-gen" type="button">Generate page command</button></div>
        </div>
        <div class="panel"><div class="panel-head"><h3>Command</h3></div>
          <div id="a-body">${empty("announce", "No command yet", "Choose a zone and message, then generate.")}</div></div>
      </div>`;
  },
  mount(root) {
    $("#a-gen", root).addEventListener("click", () => {
      const zoneVal = $("#a-zone", root).value;
      const zone = REF.paging.find((z) => z[0] === zoneVal);
      const m = MESSAGES.find((x) => x.id === $("#a-msg", root).value);
      const cmd = `sudo /opt/upes-ecs/mass_callout.sh /opt/upes-ecs/groups/${zone[0]}.csv ${m.prompt} notify`;
      $("#a-body", root).innerHTML =
        `<p class="lead">Pages <b>${esc(zone[1])}</b> (zone <span class="num">${esc(zone[0])}</span>) with <b>${esc(m.label)}</b>.</p>` +
        code(cmd, "page command") +
        `<div class="exec-row">${execButton("Page this zone")}</div>` +
        pbxNote(zone[2] === "PIN-restricted"
          ? "Zone 700 is all-campus — page every registered phone with the message."
          : "Restricted to ERT-Lead / Control positions.");
      $("#a-body .exec-btn", root).addEventListener("click", () => confirmExec({
        title: "Page zone " + zone[0] + " — " + zone[1],
        what: `This <b>pages every phone</b> in <b>${esc(zone[1])}</b> (zone ${esc(zone[0])}) and plays <b>${esc(m.label)}</b>. Phones ring and play the message.`,
        command: cmd, action: "callout", args: { group: zone[0], sound: m.prompt, mode: "notify" },
      }));
    });
  },
});

/* ---- 5.6  Directory ----------------------------------------------------- */
register({
  id: "directory", group: "Directory & comms", icon: "directory",
  title: "Directory", subtitle: "Searchable roster — dial the SAP / employee ID to reach a person",
  render() {
    return `
      <div class="callout"><span class="ct">How to call a person</span>
        Every person's extension is their SAP ID (students) or employee ID (staff). To reach them, just dial that ID from any campus phone.</div>
      <div class="searchbar" style="margin-top:var(--sp-5)">
        <div style="position:relative;flex:1;max-width:420px">
          <input id="dir-q" placeholder="Search name or ID…" aria-label="Search directory" autocomplete="off">
        </div>
        <span class="count-chip" id="dir-count"></span>
      </div>
      <div class="roster-grid" id="dir-grid"></div>
      <div id="dir-emptywrap"></div>`;
  },
  mount(root) {
    const grid = $("#dir-grid", root);
    const countEl = $("#dir-count", root);
    const emptyWrap = $("#dir-emptywrap", root);
    const draw = (q) => {
      const term = q.trim().toLowerCase();
      const list = ROSTER.filter((r) =>
        !term || r.name.toLowerCase().includes(term) || r.id.includes(term));
      const kind = (id) => id.length === 9 ? "SAP ID" : "Employee ID";
      grid.innerHTML = list.map((r) =>
        `<div class="person"><div class="avatar">${esc(initials(r.name))}</div>` +
        `<div class="who"><div class="n">${esc(r.name)}</div>` +
        `<div class="e">${esc(r.id)} · ${kind(r.id)}</div></div></div>`).join("");
      countEl.textContent = `${list.length} of ${ROSTER.length} people`;
      emptyWrap.innerHTML = list.length ? "" :
        empty("search", "No matches", "Try a different name or ID.");
    };
    draw("");
    $("#dir-q", root).addEventListener("input", (e) => draw(e.target.value));
  },
});

/* ---- 5.7  Hunt Groups --------------------------------------------------- */
register({
  id: "hunt", group: "Directory & comms", icon: "hunt",
  title: "Hunt Groups", subtitle: "Department desks and the short codes to reach them",
  render() {
    return `
      <div class="callout"><span class="ct">Department desks</span>
        Each department answers on a short 4xxx code. Dial the code to reach whoever is staffing that desk — the seat stays constant even as the person on shift changes.</div>
      <div class="table-wrap" style="margin-top:var(--sp-5)">
        <table><thead><tr><th>Short code</th><th>Desk</th><th>Handles</th></tr></thead><tbody>` +
        REF.huntGroups.map((h) =>
          `<tr><td><span class="num">${esc(h[0])}</span></td><td class="name">${esc(h[1])}</td><td class="muted">${esc(h[2])}</td></tr>`).join("") +
      `</tbody></table></div>
      <div class="callout" style="margin-top:var(--sp-4)"><span class="ct">In an emergency</span>
        Do not dial a department desk directly for a life-safety event — dial <span class="num">111</span>.
        ERT dispatches the right responders and keeps the caller on the line.</div>`;
  },
});

/* ---- 5.8  Numbering (reference) ---------------------------------------- */
register({
  id: "numbering", group: "Reference", icon: "numbering",
  title: "Numbering", subtitle: "Every number, code, position and context in the system",
  render() {
    const svc = REF.services.map((r) => `<tr><td><span class="num">${esc(r[0])}</span></td><td>${esc(r[1])}</td><td>${statusPill(r[2])}</td></tr>`).join("");
    const pos = REF.positions.map((r) => `<tr><td><span class="num">${esc(r[0])}</span></td><td>${esc(r[1])}</td><td><code>${esc(r[2])}</code></td><td>${queuePill(r[3])}</td></tr>`).join("");
    const pg = REF.paging.map((r) => `<tr><td><span class="num">${esc(r[0])}</span></td><td>${esc(r[1])}${r[2] ? ` <span class="muted">· ${esc(r[2])}</span>` : ""}</td></tr>`).join("");
    const cf = REF.conf.map((r) => `<tr><td><span class="num">${esc(r[0])}</span></td><td>${esc(r[1])}</td></tr>`).join("");
    const cx = REF.contexts.map((r) => `<tr><td><code>${esc(r[0])}</code></td><td>${esc(r[1])}</td></tr>`).join("");
    return `
      <div class="dial-hero"><div class="eyebrow">Campus emergency — the only number students must remember</div>
        <div class="dial">DIAL&nbsp;111</div></div>
      <div class="section-label">Service codes</div>
      <div class="table-wrap"><table><thead><tr><th>Code</th><th>Meaning</th><th>Status</th></tr></thead><tbody>${svc}</tbody></table></div>
      <div class="section-label">Responder positions &amp; devices (4000–4999)</div>
      <div class="table-wrap"><table><thead><tr><th>Ext</th><th>Role</th><th>Context</th><th>Queue</th></tr></thead><tbody>${pos}</tbody></table></div>
      <div class="grid grid-2" style="margin-top:var(--sp-4)">
        <div><div class="section-label">Paging zones (700–705)</div>
          <div class="table-wrap"><table><thead><tr><th>Code</th><th>Zone</th></tr></thead><tbody>${pg}</tbody></table></div></div>
        <div><div class="section-label">Conference rooms (9000–9004)</div>
          <div class="table-wrap"><table><thead><tr><th>Room</th><th>Purpose</th></tr></thead><tbody>${cf}</tbody></table></div></div>
      </div>
      <div class="section-label">Dialplan contexts (permissions)</div>
      <div class="table-wrap"><table><thead><tr><th>Context</th><th>Who / what</th></tr></thead><tbody>${cx}</tbody></table></div>`;
  },
});
function statusPill(s) {
  if (/live/i.test(s)) return pill("live", "ok");
  if (/later/i.test(s)) return pill("later", "neutral");
  return esc(s);
}
function queuePill(s) {
  if (/queue/i.test(s)) return pill(s, "ok");
  return `<span class="muted">${esc(s)}</span>`;
}

/* ---- 5.9  ERT & Shifts (reference) ------------------------------------- */
register({
  id: "ert", group: "Reference", icon: "ert",
  title: "ERT & Shifts", subtitle: "How responders answer, dispatch, and staff positions by shift",
  render() {
    return `
      <div class="callout"><span class="ct">Positions, not people</span>
        Responder roles are generic positions staffed by shift — trained officers step in with no crisis-time registration. Only ERT positions answer the 111 queue.</div>
      <div class="section-label">Answer script — say it every time</div>
      <div class="panel">
        ${code('"UPES Emergency Response, this is [name]. What is your emergency and where are you located?"')}
        <div class="help"><b>Ask (6):</b> what happened · WHERE · injured / danger · name / SAP ID · callback number · still ongoing?</div>
      </div>
      <div class="section-label">Dispatch</div>
      <div class="table-wrap"><table><thead><tr><th>Situation</th><th>Mode</th></tr></thead><tbody>
        <tr><td>Life / safety risk</td><td>Send help NOW; open <span class="num">9000</span> / bridge if multi-team</td></tr>
        <tr><td>Unclear</td><td>Three-way bridge, keep caller on the line, tell Lead</td></tr>
        <tr><td>Minor</td><td>Dispatch without transfer, log the incident</td></tr>
        <tr><td>Silent / can't speak</td><td><b>Treat as critical.</b> Don't hang up. “If you can't speak, press any key.” Dispatch to known location.</td></tr>
        <tr><td>Mass event (surge)</td><td>Lead declares incident → <b>page first</b> (700s), open 9000, pull in reserves, triage by severity</td></tr>
      </tbody></table></div>
      <div class="section-label">Shift model</div>
      <div class="panel lead">Positions (<span class="num">4101</span> Lead · <span class="num">4110/4111/4112</span> Operators · <span class="num">4120</span> Control)
        are occupied by trained officers per shift. Hand over live — the seat stays in the queue, only the person changes.
        Accountability = incident log (position) + shift log (officer). Pause / resume the queue with <code>*45</code> / <code>*46</code>.
        Full detail: <a href="../SOP/30-ERT-Roles-and-Shifts.md">SOP 30</a>.</div>`;
  },
});

/* ---- 5.10  Network (reference) ----------------------------------------- */
register({
  id: "network", group: "Reference", icon: "network",
  title: "Network", subtitle: "How phones connect, and how the PBX follows the van across routers",
  render() {
    const ip = App.serverIp;
    return `
      <div class="section-label">How phones connect</div>
      <div class="table-wrap"><table><thead><tr><th>Setting</th><th>Value</th></tr></thead><tbody>
        <tr><td>SIP server / domain</td><td><span class="num net-ip">${esc(ip)}</span> : 5060</td></tr>
        <tr><td>Username</td><td>the user's SAP ID (or 4xxx position)</td></tr>
        <tr><td>Transport</td><td>UDP</td></tr>
        <tr><td>Media (RTP)</td><td><code>udp 10000–10019</code></td></tr>
      </tbody></table></div>
      <div class="section-label">Dynamic across routers (moving the van)</div>
      <div class="panel stack">
        <p class="lead">On a new network the laptop's IP changes; the PBX <b>auto-rebinds on boot</b>. Switched to a new router / OTG hotspot while running? Rebind live — <b>right here, no internet needed</b>:</p>
        <div id="rebind-cmd" class="stack">
          ${execButton("Rebind PBX to this network")}
        </div>
        <p class="muted">Detects the laptop's current LAN IP, updates what Asterisk advertises to phones, and reloads. Prints the new IP to give the ERT phones. Or run it standalone on the laptop:</p>
        ${code('powershell -File C:\\Users\\Rohan\\qemu\\Set-UpesLanIp.ps1     (or double-click Rebind-Network.cmd)')}
        <p class="muted">For zero phone reconfig, use a DHCP reservation, or bridged + <code>upes-ecs-pbx-01.local</code> (mDNS).</p>
      </div>
      <div class="section-label">Check on every new router (30 s)</div>
      <div class="table-wrap"><table class="table-plain"><tbody>
        <tr><td style="width:34px">☐</td><td><b>Wi-Fi client isolation OFF</b> — AP isolation blocks phone ↔ PBX (the #1 gotcha)</td></tr>
        <tr><td>☐</td><td>Firewall rule present on the laptop (one-time)</td></tr>
        <tr><td>☐</td><td>Phones and laptop on the same subnet</td></tr>
      </tbody></table></div>
      <div class="section-label">Firewall (one-time, admin)</div>
      <div class="panel">${code('New-NetFirewallRule -DisplayName "UPES-ECS SIP-RTP" -Direction Inbound `\n  -Protocol UDP -LocalPort 5060,10000-10019 -Action Allow -Profile Any')}</div>`;
  },
  live(root) {
    $$(".net-ip", root).forEach((el) => { el.textContent = App.serverIp; });
    const btn = $("#rebind-cmd .exec-btn", root);
    if (btn && !btn.dataset.bound) {
      btn.dataset.bound = "1";
      btn.addEventListener("click", () => confirmExec({
        title: "Rebind PBX to this network",
        what: "Re-detects the laptop's current LAN IP and updates the address Asterisk advertises to phones, then reloads PJSIP. Existing calls are not dropped. Do this once after moving to a new router / OTG hotspot. Takes ~60–90s on the emulated PBX; the new IP appears here automatically.",
        command: "powershell -File Set-UpesLanIp.ps1   (runs on the laptop hosting the PBX)",
        endpoint: "api/rebind",
        args: {},
        poll: true,
        onDone: () => { if (typeof poll === "function") poll(); },
      }));
    }
  },
});

/* ---- 5.11  Operations (reference) -------------------------------------- */
register({
  id: "ops", group: "Reference", icon: "ops",
  title: "Operations", subtitle: "Start, stop, rebind, health, backup — the day-to-day commands",
  render() {
    return `
      <div class="section-label">Lifecycle (Windows host)</div>
      <div class="panel">${code(
`# start (auto-binds to current network)
powershell -File C:\\Users\\Rohan\\qemu\\start-vm.ps1

# stop (graceful)
powershell -File C:\\Users\\Rohan\\qemu\\stop-vm.ps1

# rebind after changing network
powershell -File C:\\Users\\Rohan\\qemu\\Set-UpesLanIp.ps1

# full rebuild on a fresh laptop
powershell -ExecutionPolicy Bypass -File deploy\\qemu\\Deploy-UpesEcsVm.ps1 -AddFirewallRule`)}
        <div class="help">Autostarts on Windows logon. Asterisk autostarts in the VM. Admin / SSH: <code>ssh -p 2222 ubuntu@localhost</code></div>
      </div>
      <div class="section-label">Inside the PBX (over SSH)</div>
      <div class="panel">${code(
`sudo /opt/upes-ecs/upes-ecs-healthcheck.sh        # readiness
sudo asterisk -rx "queue show ${QUEUE}"
sudo asterisk -rx "pjsip show contacts"            # who's registered
sudo asterisk -rx "dialplan reload"`)}</div>
      <div class="section-label">Data &amp; retention</div>
      <div class="panel lead">Recordings <code>/var/spool/asterisk/monitor/upes-ecs/</code> (90 days) ·
        incidents <code>/var/lib/upes-ecs/</code> · config in git <code>upes-ecs-config</code>.
        Back up before every change — <a href="../SOP/11-Backup-Restore-Procedure.md">SOP 11</a>.</div>`;
  },
});

/* ---- 5.12  Docs (reference) -------------------------------------------- */
/* ---- 5.1h  Architecture & desk placement (reference SVG diagrams) ------- */
register({
  id: "architecture", group: "Reference", icon: "network",
  title: "Architecture", subtitle: "System architecture and where each department desk sits",
  render() {
    const B = (x, y, w, h, t, s, cls) =>
      `<g class="ab ${cls || ""}"><rect x="${x}" y="${y}" width="${w}" height="${h}" rx="9"/>` +
      `<text class="ab-t" x="${x + w / 2}" y="${y + (s ? h / 2 - 3 : h / 2 + 5)}">${t}</text>` +
      (s ? `<text class="ab-s" x="${x + w / 2}" y="${y + h / 2 + 13}">${s}</text>` : "") + `</g>`;
    const A = (x1, y1, x2, y2, l) =>
      `<line class="ab-arrow" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" marker-end="url(#ah)"/>` +
      (l ? `<text class="ab-l" x="${(x1 + x2) / 2 + 8}" y="${(y1 + y2) / 2 + 3}">${l}</text>` : "");
    const Z = (x, y, w, h, l) => `<rect class="ab-zone" x="${x}" y="${y}" width="${w}" height="${h}" rx="10"/>` +
      `<text class="ab-zlabel" x="${x + 10}" y="${y + 18}">${l}</text>`;
    const C = (x1, y1, x2, y2) => `<line class="ab-conn" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"/>`;
    const defs = `<defs><marker id="ah" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="ab-ah" d="M0 0L10 5L0 10z"/></marker></defs>`;

    const arch = `<svg class="arch-svg" viewBox="0 0 820 500" role="img" aria-label="System architecture">${defs}
      ${B(260, 18, 300, 48, "Responder &amp; caller handsets", "Android softphones today · IP phones later")}
      ${A(410, 66, 410, 92, "SIP + RTP · Wi-Fi (G.711)")}
      ${B(250, 96, 320, 44, "Wi-Fi AP → campus LAN / repeaters", "dynamic across routers as the van moves", "net")}
      ${A(410, 140, 410, 168)}<text class="ab-l" x="418" y="158">port-forward 5060 + RTP 10000-10019</text>
      <rect class="ab-host" x="70" y="176" width="680" height="300" rx="12"/><text class="ab-hostlabel" x="86" y="196">Windows van laptop (no admin)</text>
      <rect class="ab-host" x="92" y="206" width="440" height="255" rx="10"/><text class="ab-hostlabel" x="108" y="224">QEMU · Ubuntu 22.04 VM</text>
      <rect class="ab-host" x="110" y="232" width="404" height="216" rx="10"/><text class="ab-hostlabel" x="126" y="250">Asterisk 18 PBX (PJSIP)</text>
      ${B(122, 258, 180, 40, "Dialplan", "111 · 102 coach · *codes")}
      ${B(316, 258, 186, 40, "Emergency queue", "on-shift answer points")}
      ${B(122, 304, 180, 40, "Recording", "whole-call MixMonitor")}
      ${B(316, 304, 186, 40, "Voicemail + incidents", "missed → callback")}
      ${B(122, 350, 380, 40, "Escalation + background responder alert", "call-files ring Lead/backup while the coach runs")}
      ${B(122, 396, 380, 40, "fail2ban · retention · health cron", "SIP guard + housekeeping")}
      <rect class="ab-host" x="556" y="232" width="176" height="216" rx="10"/><text class="ab-hostlabel" x="572" y="250">Operations Console</text>
      ${B(568, 258, 150, 44, "Update-Status.ps1", "SSH → status.json")}
      ${B(568, 308, 150, 44, "Serve.ps1", "LAN web + doc viewer")}
      ${B(568, 396, 150, 40, "This dashboard", "browser on the LAN")}
      ${A(556, 322, 516, 322, "SSH")}</svg>`;

    const desks = `<svg class="arch-svg" viewBox="0 0 820 520" role="img" aria-label="Department desk placement">${defs}
      <rect class="ab-zone-outer" x="16" y="16" width="788" height="488" rx="14"/><text class="ab-hostlabel" x="32" y="38">UPES campus — LAN / Wi-Fi coverage</text>
      ${Z(40, 54, 210, 120, "Academic blocks")}${Z(570, 54, 210, 120, "Medical centre")}
      ${Z(40, 205, 180, 120, "Main gate / perimeter")}${Z(600, 205, 180, 120, "Hostels")}
      ${Z(40, 356, 210, 120, "Admin / facilities")}${Z(570, 356, 210, 120, "IT / server room")}
      ${C(232, 113, 340, 250)}${C(588, 113, 480, 250)}${C(208, 262, 330, 262)}${C(612, 262, 490, 262)}${C(232, 415, 340, 272)}${C(588, 415, 480, 272)}
      ${B(330, 222, 160, 76, "Van PBX", "dial 111", "accent")}
      ${B(58, 86, 174, 54, "ERT Control / Lead", "4101 · 4120", "crit")}
      ${B(588, 86, 174, 54, "Medical desk", "4200")}
      ${B(52, 235, 156, 54, "Security desk", "4300")}
      ${B(612, 235, 156, 54, "Warden desk", "4400")}
      ${B(58, 388, 174, 54, "Operations desk", "4500")}
      ${B(588, 388, 174, 54, "IT / Network desk", "4600")}</svg>`;

    return `
      <div class="callout"><span class="ct">How it fits together</span> Everything runs on the van laptop, on the LAN, with no cloud in the emergency path. Diagrams are live SVG (scale + theme with the page).</div>
      <div class="section-label">System architecture</div>
      ${arch}
      <div class="panel lead">Handsets register over Wi-Fi to Asterisk inside the QEMU VM; the PBX runs the queue, dialplan (111 + the 102 offline coach + feature codes), whole-call recording, voicemail and incident logging. The Console reads live state over SSH into <code>status.json</code> and serves this dashboard on the LAN.</div>
      <div class="section-label">Where each department desk sits</div>
      ${desks}
      <div class="panel lead">Each department keeps a desk (or on-shift handset) in its own zone but all register to the one PBX and answer/receive dispatch on the shared plan: <strong>ERT</strong> (4101/4120) answers 111; <strong>Medical</strong> 4200, <strong>Security</strong> 4300, <strong>Warden</strong> 4400, <strong>Operations</strong> 4500, <strong>IT</strong> 4600 are dispatch targets. Placement is a template — put each desk where that team actually works; the numbering travels with the person via shift login (<code>*22</code>).</div>`;
  },
});

const DOCS = {
  "Operational SOP": [
    ["SOP/00-README.md", "SOP index", "00"],
    ["SOP/01-Numbering-Plan.md", "Numbering Plan", "01"],
    ["SOP/02-ERT-SOP.md", "ERT SOP", "02"],
    ["SOP/03-Drill-Test-SOP.md", "Drill & Test SOP", "03"],
    ["SOP/09-Dialplan-Design.md", "Dialplan Design", "09"],
    ["SOP/12-Incident-Logging-Schema.md", "Incident Logging Schema", "12"],
    ["SOP/19-AI-101-Design.md", "AI-101 Design (local-first)", "19"],
    ["SOP/25-Quick-Cards.md", "Quick Cards", "25"],
    ["SOP/28-Voice-Prompt-Scripts.md", "Voice Prompt Scripts", "28"],
    ["SOP/30-ERT-Roles-and-Shifts.md", "ERT Roles & Shifts", "30"],
  ],
  "Engineering Blueprint": [
    ["Blueprint/00-README.md", "Blueprint index", "00"],
    ["Blueprint/02-System-Architecture.md", "System Architecture", "02"],
    ["Blueprint/03-Call-Flows.md", "Call Flows (disaster-ready)", "03"],
    ["Blueprint/04-Network-and-Deployment.md", "Network & Deployment", "04"],
    ["Blueprint/06-Numbering-and-Data-Map.md", "Numbering & Data Map", "06"],
    ["Blueprint/07-Deployment-Runbook.md", "Deployment Runbook", "07"],
    ["Blueprint/08-Responder-Department-Architecture.md", "Responder Dept Architecture & Live Map", "08"],
  ],
  "Build, run & roadmap": [
    ["Notes/DEMO-TEAM-ASSIGNMENTS.md", "Demo team assignments (TODO)", "☐"],
    ["Journal/Production-Readiness.md", "Production readiness & go-live", "★"],
    ["deploy/qemu/README.md", "QEMU server runbook", "▸"],
    ["deploy/qemu/Autostart-Setup.md", "Autostart setup notes (always-on Console)", "▸"],
    ["config/FEATURES.md", "Feature catalog", "▸"],
    ["AI-101/README.md", "AI-101 (local-first AI)", "▸"],
    ["Journal/Feature-Roadmap.md", "Feature roadmap", "▸"],
    ["Journal/Roadblocks-and-Solutions.md", "Roadblocks & solutions", "▸"],
  ],
};
register({
  id: "docs", group: "Reference", icon: "docs",
  title: "Docs", subtitle: "Read the SOP, blueprint and runbooks — rendered in-app",
  render() {
    const cards = (list) => `<div class="roster-grid">` + list.map((r) =>
      `<a class="person" href="#doc:${r[0]}" title="${esc(r[1])}">` +
      `<div class="avatar" style="background:var(--slate)">${esc(r[2])}</div>` +
      `<div class="who"><div class="n">${esc(r[1])}</div><div class="e">${esc(r[0])}</div></div></a>`).join("") + `</div>`;
    return `
      <div class="callout"><span class="ct">Reference library</span>
        Click any document — it renders right here in the Console (served over the LAN, no editor needed).
        Diagrams written as <code>mermaid</code> show as code; ASCII diagrams render as-is.</div>` +
      Object.keys(DOCS).map((g) => `<div class="section-label">${esc(g)}</div>${cards(DOCS[g])}`).join("");
  },
});

// Shared intro block for the emergency tools
function toolIntro(title, desc) {
  return `<div class="callout"><span class="ct">${esc(title)}</span>${esc(desc)}</div>`;
}

/* ---------------------------------------------------------------------------
   5.x  Region & language  (read-only — reflects the active deployment)
   region.json is written by the deploy tool (Deploy-UPES). When it is ABSENT the
   active region is English (the base). languages.json lists every supported voice
   pack; it lives in i18n/ (not on the Console web root), so we fetch a few candidate
   paths and fall back to this embedded copy so the view never blanks.
   ------------------------------------------------------------------------- */
const LANGS_FALLBACK = {
  default: "en",
  languages: [
    { code: "en", name: "English", native: "English", status: "shipped" },
    { code: "hi", name: "Hindi",   native: "हिन्दी",   status: "needs-translation" },
  ],
};

// Normalise region.json (or its absence) into a single shape the chip + view read.
function regionInfo(r) {
  const isDefault = !r || !(r.language || r.languageName);
  r = r || {};
  const code = String(r.language || "en").toLowerCase();
  const isEn = !code || code === "en";
  const native = r.native || r.languageName || (isEn ? "English" : code.toUpperCase());
  const name = r.languageName || (isEn ? "English" : native);
  // english-fallback = prompts pack not localised yet (audio still plays in English).
  const fallback = !isEn && r.prompts === "english-fallback";
  return {
    code, isEn, native, name, fallback, isDefault,
    label: isEn ? "EN" : native,
    deployedAt: r.deployedAt || null,
    source: r.source || null,
  };
}
function regionDeployedShort(iso) {
  if (!iso) return null;
  return String(iso).replace("T", " ").replace(/(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/, "").slice(0, 16) || null;
}
function langStatusPill(st) {
  const s = String(st || "").toLowerCase();
  if (s === "shipped") return pill("shipped", "ok");
  if (/needs|translat|progress|draft/.test(s)) return pill(st || "needs translation", "warn");
  if (/planned|later|future|todo/.test(s)) return pill(st || "planned", "neutral");
  return pill(st || "—", "neutral");
}

// The top-bar chip: shows the active language (native / "EN") + a soft audio-fallback flag.
function updateRegionChip() {
  const chip = document.getElementById("region-chip"); if (!chip) return;
  const info = regionInfo(App.region);
  const nat = document.getElementById("region-native"); if (nat) nat.textContent = info.label;
  const sep = document.getElementById("region-fb-sep"), fb = document.getElementById("region-fb");
  if (sep) sep.hidden = !info.fallback;
  if (fb) fb.hidden = !info.fallback;
  chip.title = "Active deployed language: " + info.name +
    (info.fallback ? " — voice prompts still play in English (pack not localised yet)" : "") +
    ". Change by re-running Deploy-UPES.";
}

// Load region.json (absent ⇒ keep English default) and repaint chip + view.
async function loadRegion() {
  try {
    const res = await fetch("region.json?_=" + Date.now(), { cache: "no-store" });
    if (res.ok) { const r = await res.json(); if (r && (r.language || r.languageName)) App.region = r; }
  } catch (_) { /* absent / offline — English default */ }
  updateRegionChip();
  if (App.current && App.current.id === "region") renderRegionView();
}

// Fetch the supported-language catalogue (candidate paths → embedded fallback).
async function loadLanguages() {
  if (!App._langs) {
    const urls = ["languages.json", "i18n/languages.json", "../i18n/languages.json"];
    for (const u of urls) {
      try {
        const res = await fetch(u + "?_=" + Date.now(), { cache: "no-store" });
        if (res.ok) { const j = await res.json(); if (j && Array.isArray(j.languages)) { App._langs = j; break; } }
      } catch (_) { /* try next */ }
    }
    if (!App._langs) App._langs = LANGS_FALLBACK;
  }
  renderRegionView();
}

// Paint the Region feature view from App.region + App._langs (safe to call anytime).
function renderRegionView() {
  const info = regionInfo(App.region);
  const active = document.getElementById("region-active");
  if (active) {
    active.innerHTML = [
      tile("Language", esc(info.name) + (info.isEn ? "" : ` <span class="unit">${esc(info.native)}</span>`),
           info.isDefault ? "info" : "ok", info.isDefault ? "default — region.json absent" : "active deployment"),
      tile("Voice prompts", info.fallback ? "English" : "Localized",
           info.fallback ? "warn" : "ok", info.fallback ? "pack not translated yet" : "111 · coach · announcements"),
      tile("Deployed", regionDeployedShort(info.deployedAt) || "—", "info",
           info.source ? "source: " + info.source : "by Deploy-UPES"),
    ].join("");
  }
  const note = document.getElementById("region-note");
  if (note) {
    note.innerHTML = info.fallback
      ? `<div class="callout warn"><span class="ct">Audio not localised yet</span>` +
        `Labels are set to ${esc(info.name)}, but the voice prompts still play in English — the ${esc(info.name)} ` +
        `voice pack has not been generated. Generate it, then re-deploy with Deploy-UPES.</div>`
      : `<div class="callout"><span class="ct">Deployed region</span>` +
        `This reflects the last deployment. To change the campus-wide region metadata, re-run <code>Deploy-UPES</code>. ` +
        `For a live demo, use the voice-language switch below — it changes what callers hear on the next call, no redeploy.</div>`;
  }

  // Live voice-language switch: swap the emergency-IVR prompt set on the running PBX.
  // Only en/hi have prompt stores on the VM, so those are the two options. The current
  // language (from region.json) is marked and disabled; clicking the other confirms + runs
  // the host-side api/ivrlang endpoint. Buttons carry data-lang; a single delegated click
  // handler (below, near the copy handler) wires them so repeated live() repaints are safe.
  const sw = document.getElementById("region-switch");
  if (sw) {
    const mk = (lc, label) => {
      const on = info.code === lc;
      return `<button class="btn ivr-switch-btn${on ? " active" : ""}" data-lang="${lc}" type="button"` +
             `${on ? " disabled aria-current=\"true\"" : ""}>${esc(label)}${on ? " ✓" : ""}</button>`;
    };
    sw.innerHTML =
      `<div class="callout"><span class="ct">Live switch — no redeploy</span>` +
      `Swap the emergency-IVR voice prompts (111 guidance, panic-coach, announcements) on the running PBX. ` +
      `Takes effect on the <b>next</b> call.</div>` +
      `<div class="stack" style="margin-top:var(--sp-3)">${mk("en", "English")} ${mk("hi", "हिन्दी · Hindi")}</div>`;
  }
  const box = document.getElementById("region-langs");
  const cnt = document.getElementById("region-langcount");
  if (box) {
    const cat = App._langs;
    const langs = cat && Array.isArray(cat.languages) ? cat.languages : null;
    const def = String((cat && cat.default) || "en").toLowerCase();
    if (!langs) {
      box.innerHTML = empty("network", "Loading languages…", "");
    } else {
      if (cnt) cnt.textContent = langs.length + " configured";
      box.innerHTML = `<table><thead><tr><th>Language</th><th>Code</th><th>Prompts</th><th>Role</th></tr></thead><tbody>` +
        langs.map((l) => {
          const lc = String(l.code || "").toLowerCase();
          const roles = [];
          if (lc === def) roles.push(pill("base", "info"));
          if (lc === info.code) roles.push(pill("active", "ok"));
          return `<tr><td class="name">${esc(l.name || l.code)}` +
            `${l.native && l.native !== l.name ? ` <span class="muted">· ${esc(l.native)}</span>` : ""}</td>` +
            `<td><span class="num">${esc(l.code || "—")}</span></td>` +
            `<td>${langStatusPill(l.status)}</td>` +
            `<td>${roles.join(" ") || '<span class="muted">—</span>'}</td></tr>`;
        }).join("") + `</tbody></table>`;
    }
  }
}

register({
  id: "region", group: "Reference", icon: "network",
  title: "Region & language", subtitle: "Active deployment language and the regional voice packs available",
  render() {
    return `
      ${toolIntro("Region & language", "The language the campus emergency system currently speaks — its voice prompts (111 guidance, panic-coach, announcements) and this deployment's regional setting. Read-only: switch language by re-running the deployment tool.")}
      <div class="section-label">Active deployment</div>
      <div class="tiles" id="region-active">${tileSkeletons(3)}</div>
      <div id="region-note" style="margin-top:var(--sp-4)"></div>
      <div class="section-label" style="margin-top:var(--sp-6)">Live voice-language switch</div>
      <div id="region-switch"></div>
      <div class="section-label" style="margin-top:var(--sp-6)">Supported languages <span class="hint" id="region-langcount"></span></div>
      <div class="table-wrap" id="region-langs">${empty("network", "Loading languages…", "")}</div>`;
  },
  mount() { loadLanguages(); },      // pulls languages.json (once) then repaints
  live() { renderRegionView(); },    // repaint on every status poll (cheap, region rarely changes)
});

/* ---------------------------------------------------------------------------
   5.x  ADMINISTRATION — full sysadmin control (users, per-user language,
        campus default, VM lifecycle, deploy, prompt generation)
   ------------------------------------------------------------------------- */

// Ensure the supported-language catalogue is loaded (shared with the Region view).
async function ensureLangs() {
  if (App._langs && Array.isArray(App._langs.languages)) return App._langs;
  const urls = ["languages.json", "i18n/languages.json", "../i18n/languages.json"];
  for (const u of urls) {
    try {
      const r = await fetch(u + "?_=" + Date.now(), { cache: "no-store" });
      if (r.ok) { const j = await r.json(); if (j && Array.isArray(j.languages)) { App._langs = j; break; } }
    } catch (_) { /* try next */ }
  }
  if (!App._langs && typeof LANGS_FALLBACK !== "undefined") App._langs = LANGS_FALLBACK;
  return App._langs;
}
// <option> list of every supported language, `sel` pre-selected.
function langOptionList(sel) {
  const cat = App._langs;
  const langs = (cat && Array.isArray(cat.languages)) ? cat.languages.slice() : [];
  if (!langs.some((l) => String(l.code).toLowerCase() === "en")) langs.unshift({ code: "en", name: "English", native: "English" });
  const s = String(sel || "").toLowerCase();
  return langs.map((l) => {
    const lc = String(l.code || "").toLowerCase();
    const label = (l.name || lc) + (l.native && l.native !== l.name ? " · " + l.native : "");
    return `<option value="${lc}"${lc === s ? " selected" : ""}>${esc(label)}</option>`;
  }).join("");
}

// Load the user roster (name/ext/type + current language) into the Users view.
async function loadUsers() {
  const box = document.getElementById("adm-users");
  if (!box) return;
  try {
    const r = await fetch("api/users", { cache: "no-store" });
    const j = await r.json();
    const users = (j && j.users) || [];
    if (!users.length) { box.innerHTML = empty("inbox", "No users yet", "Add one with the form below."); return; }
    box.innerHTML = `<table><thead><tr><th>Name</th><th>Extension</th><th>Type</th><th>Voice language</th></tr></thead><tbody>` +
      users.map((u) =>
        `<tr><td class="name">${esc(u.name || "—")}</td>` +
        `<td><span class="num">${esc(u.ext)}</span></td>` +
        `<td>${esc(u.kind || "")}</td>` +
        `<td><select class="usr-lang" data-ext="${esc(u.ext)}" aria-label="Language for ${esc(u.ext)}">${langOptionList(u.lang || "")}</select>` +
        `<span class="usr-lang-msg" data-ext="${esc(u.ext)}"></span></td></tr>`).join("") +
      `</tbody></table>`;
  } catch (e) {
    box.innerHTML = empty("network", "Could not load users", "Is Serve.ps1 running?");
  }
}
// Delegated: changing a per-user language dropdown saves immediately (low-risk, no modal).
document.addEventListener("change", async (e) => {
  const sel = e.target.closest(".usr-lang");
  if (!sel) return;
  const ext = sel.dataset.ext, lang = sel.value;
  const msg = document.querySelector(`.usr-lang-msg[data-ext="${CSS.escape(ext)}"]`);
  if (msg) msg.innerHTML = ' ' + pill("saving…", "warn");
  sel.disabled = true;
  try {
    const r = await fetch("api/setlang", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ ext, lang }) });
    const j = await r.json();
    if (msg) msg.innerHTML = ' ' + (j && j.ok !== false ? pill("saved", "ok") : pill("failed", "crit"));
  } catch (_) { if (msg) msg.innerHTML = ' ' + pill("error", "crit"); }
  sel.disabled = false;
  if (msg) setTimeout(() => { msg.innerHTML = ""; }, 2200);
});

// Load + wire the campus-default language selector.
async function loadDefaultLang() {
  const wrap = document.getElementById("adm-deflang");
  if (!wrap) return;
  let cur = "en";
  try { const r = await fetch("api/deflang", { cache: "no-store" }); const j = await r.json(); if (j && j.default) cur = j.default; } catch (_) {}
  wrap.innerHTML =
    `<div class="callout"><span class="ct">Campus default</span>` +
    `The language an <b>un-mapped</b> caller hears (astdb <code>lang/_default</code>). Applies on the next call — no redeploy.</div>` +
    `<div class="stack" style="margin-top:var(--sp-3)"><select id="adm-deflang-sel" aria-label="Campus default language">${langOptionList(cur)}</select>` +
    `<button class="btn" id="adm-deflang-set" type="button">${ICONS.phone || ""}<span>Set default</span></button></div>`;
  const btn = document.getElementById("adm-deflang-set");
  if (btn) btn.addEventListener("click", () => {
    const lang = document.getElementById("adm-deflang-sel").value;
    confirmExec({
      title: "Set campus default language",
      what: `Set the default emergency-IVR language to <b>${esc(lang)}</b> for any caller without a personal preference. Takes effect on the next call.`,
      command: `asterisk -rx "database put lang _default ${lang}"`,
      endpoint: "api/deflang", args: { lang },
    });
  });
}

register({
  id: "admin-users", group: "Administration", icon: "directory",
  title: "Users & Languages", subtitle: "Add SIP users and set each caller's voice language",
  render() {
    return `
      ${toolIntro("Users & Languages", "Every campus SIP user, and the language the emergency IVR speaks to each of them. Change a user's language from the dropdown — it applies to their next 111 call with no redeploy. Add a new user with the form below (pins the SIP secret the one safe way).")}
      <div class="section-label">Campus default language</div>
      <div id="adm-deflang"></div>
      <div class="section-label" style="margin-top:var(--sp-6)">Users <span class="hint">per-caller voice language</span></div>
      <div class="table-wrap" id="adm-users">${empty("inbox", "Loading users…", "")}</div>
      <div class="section-label" style="margin-top:var(--sp-6)">Add a user</div>
      <div class="form-grid" id="adm-adduser">
        <label>SAP ID / extension<input type="text" id="au-sap" placeholder="500123456" autocomplete="off"></label>
        <label>Full name<input type="text" id="au-name" placeholder="Jane Doe" autocomplete="off"></label>
        <label>Type<select id="au-kind"><option value="student">student</option><option value="staff">staff</option><option value="ert">ert</option></select></label>
        <label>Voice language<select id="au-lang">${langOptionList("en")}</select></label>
        <div><button class="btn primary" id="au-go" type="button">${ICONS.phone || ""}<span>Add user</span></button></div>
      </div>`;
  },
  mount() {
    ensureLangs().then(() => { loadUsers(); loadDefaultLang(); });
    const go = document.getElementById("au-go");
    if (go) go.addEventListener("click", () => {
      const sapId = (document.getElementById("au-sap").value || "").trim();
      const name = (document.getElementById("au-name").value || "").trim();
      const kind = document.getElementById("au-kind").value;
      const lang = document.getElementById("au-lang").value;
      if (!/^[0-9A-Za-z]{2,20}$/.test(sapId) || !name) {
        alert("Enter a valid SAP ID (2-20 alphanumerics) and a name."); return;
      }
      confirmExec({
        title: "Add SIP user",
        what: `Create/heal SIP user <b>${esc(name)}</b> (ext <b>${esc(sapId)}</b>), voice language <b>${esc(lang)}</b>. ` +
              `Pins the secret the one safe way, provisions on the PBX, and refreshes the directory.`,
        command: `powershell -File deploy\\qemu\\Add-UpesUser.ps1 -SapId ${sapId} -Name "${name}" -Lang ${lang}`,
        endpoint: "api/adduser", args: { sapId, name, kind, lang }, poll: true,
        onDone: () => { try { loadUsers(); } catch (_) {} },
      });
    });
  },
});

register({
  id: "admin-system", group: "Administration", icon: "network",
  title: "System & Deploy", subtitle: "VM lifecycle, voice-pack deploy, and prompt generation",
  render() {
    // env-specific: VM lifecycle + host-side deploy/prompt-gen only exist on the Windows/QEMU path
    // (Serve.ps1). On bare metal (serve-console.py) those endpoints return 404, so gate them behind
    // the bareMetal flag. Registered feature is NEVER removed — only its VM sections are hidden.
    const vm = !App.bareMetal;
    return `
      ${toolIntro("System & Deploy", vm
        ? "Operate the emergency PBX from here: start/stop the VM, push the language voice packs + per-caller routing to it, and generate a new language's voice pack on this host."
        : "This node runs Asterisk <b>natively</b> (bare metal) &mdash; there is no VM to start/stop, and voice packs are already local. Live-call controls remain below.")}
      ${vm ? `<div class="section-label">Virtual PBX</div>
      <div id="adm-vm" class="stack">
        <button class="btn" id="vm-status" type="button">${ICONS.network || ""}<span>Check status</span></button>
        <button class="btn" id="vm-start" type="button">Start VM</button>
        <button class="btn danger" id="vm-stop" type="button">Stop VM</button>
        <span id="vm-msg" class="hint"></span>
      </div>` : ``}
      <div class="section-label"${vm ? ` style="margin-top:var(--sp-6)"` : ``}>Live calls</div>
      <div class="callout warn"><span class="ct">Destructive</span>Immediately hangs up <b>every</b> active channel on the PBX &mdash; <b>including any live 111 emergency call</b>. Use only to clear stuck/zombie legs or reset the board before a demo. Anything dropped is still logged for follow-up, so it is never a dead end.</div>
      <div class="stack" style="margin-top:var(--sp-3)"><button class="btn danger" id="hangup-all" type="button">${ICONS.phone || ""}<span>Hang up ALL calls</span></button><span id="hangup-msg" class="hint"></span></div>
      ${vm ? `<div class="section-label" style="margin-top:var(--sp-6)">Deploy voice packs + routing</div>
      <div class="callout"><span class="ct">Idempotent</span>Pushes every language pack (8 kHz) and the per-caller routing dialplan to the running VM, backs up first, then reloads. English stays pristine.</div>
      <div class="stack" style="margin-top:var(--sp-3)"><button class="btn primary" id="dep-go" type="button">${ICONS.phone || ""}<span>Deploy to VM</span></button></div>
      <div class="section-label" style="margin-top:var(--sp-6)">Generate a voice pack</div>
      <div class="stack"><select id="gp-lang">${langOptionList("")}</select>
        <button class="btn" id="gp-go" type="button">Generate on this host</button></div>
      <div class="hint" style="margin-top:var(--sp-2)">Runs Piper/eSpeak locally into <code>deploy\\asterisk\\sounds\\lang\\&lt;code&gt;</code>. Deploy afterwards to push it to the VM.</div>` : ``}`;
  },
  mount() {
    ensureLangs().then(() => {
      const sel = document.getElementById("gp-lang"); if (sel) sel.innerHTML = langOptionList("");
    });
    const vmMsg = document.getElementById("vm-msg");
    const st = document.getElementById("vm-status");
    if (st) st.addEventListener("click", async () => {
      if (vmMsg) vmMsg.textContent = "checking…";
      try { const r = await fetch("api/vm", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action: "status" }) }); const j = await r.json();
        if (vmMsg) vmMsg.innerHTML = j && j.up ? pill("up", "ok") : pill("down", "crit"); }
      catch (_) { if (vmMsg) vmMsg.innerHTML = pill("error", "crit"); }
    });
    const start = document.getElementById("vm-start");
    if (start) start.addEventListener("click", () => confirmExec({
      title: "Start the virtual PBX", what: "Boot the QEMU Asterisk VM on this host.",
      command: "powershell -File deploy\\qemu\\start-vm.ps1", endpoint: "api/vm", args: { action: "start" },
    }));
    const stop = document.getElementById("vm-stop");
    if (stop) stop.addEventListener("click", () => confirmExec({
      title: "Stop the virtual PBX", what: "Shut down the QEMU Asterisk VM. <b>Emergency calls will stop working</b> until it is started again.",
      command: "powershell -File deploy\\qemu\\stop-vm.ps1", endpoint: "api/vm", args: { action: "stop" },
    }));
    // DESTRUCTIVE: no `endpoint` => apiExec POSTs {action:"hangup",args} to the VM /exec whitelist.
    // Gated behind confirmExec (shows the exact CLI + an Execute-now step). The onDone repaints the
    // live tiles so the board drops to 0 immediately instead of waiting for the next poll.
    const hangup = document.getElementById("hangup-all");
    if (hangup) hangup.addEventListener("click", () => confirmExec({
      title: "Hang up ALL active calls",
      what: "Immediately drops <b>every</b> channel on the PBX, <b>including any live 111 emergency call in progress</b>. Only do this to clear stuck/zombie legs or reset the board for a demo.",
      action: "hangup", args: { scope: "all" },
      command: 'asterisk -rx "channel request hangup all"',
      // Force an immediate cache-bypassing re-read (twice, to beat any race with the hangup
      // completing) so the board shows the true count the instant the call is dropped.
      onDone: () => { try { livePoll(true); setTimeout(() => livePoll(true), 400); } catch (_) {} },
    }));
    const dep = document.getElementById("dep-go");
    if (dep) dep.addEventListener("click", () => confirmExec({
      title: "Deploy voice packs + routing", what: "Push all language voice packs and the per-caller routing dialplan to the running VM. Backs up first; English stays pristine. Slow (minutes).",
      command: "powershell -File deploy\\qemu\\Deploy-LangPacks.ps1", endpoint: "api/deploy", args: {}, poll: true,
    }));
    const gp = document.getElementById("gp-go");
    if (gp) gp.addEventListener("click", () => {
      const lang = document.getElementById("gp-lang").value;
      confirmExec({
        title: "Generate a voice pack", what: `Synthesize the <b>${esc(lang)}</b> voice pack on this host with Piper/eSpeak. Slow (minutes).`,
        command: `powershell -File scripts\\gen-lang-prompts.win.ps1 -Lang ${lang}`,
        endpoint: "api/genprompt", args: { lang }, poll: true,
      });
    });
  },
});

/* ---------------------------------------------------------------------------
   6. SHELL: nav build, router, live poll, theme
   ------------------------------------------------------------------------- */
function buildNav() {
  const nav = $("#nav");
  const byGroup = {};
  App.features.forEach((f) => { (byGroup[f.group] = byGroup[f.group] || []).push(f); });
  const groups = App.GROUP_ORDER.filter((g) => byGroup[g])
    .concat(Object.keys(byGroup).filter((g) => !App.GROUP_ORDER.includes(g)));
  nav.innerHTML = groups.map((g) =>
    `<div class="nav-group"><div class="nav-group-label">${esc(g)}</div>` +
    byGroup[g].map((f) =>
      `<a class="nav-link" href="#${f.id}" data-id="${f.id}" title="${esc(f.title)}">` +
      `<span class="ic">${ICONS[f.icon] || ""}</span><span>${esc(f.title)}</span></a>`).join("") +
    `</div>`).join("");
}

const view = () => $("#view");

function renderFeature(f) {
  App.current = f;
  $("#pg-title").textContent = f.title;
  $("#pg-sub").textContent = f.subtitle || "";
  document.title = `${f.title} · UPES-ECS Console`;
  const root = view();
  root.innerHTML = f.render();
  if (typeof f.mount === "function") f.mount(root);
  if (typeof f.live === "function") f.live(root, App.statusError ? null : App.status);
  $$("#nav .nav-link").forEach((a) =>
    a.setAttribute("aria-current", a.dataset.id === f.id ? "page" : "false"));
  document.querySelector(".app").classList.remove("nav-open");
  window.scrollTo(0, 0);
}

function route() {
  const hash = (location.hash || "").replace(/^#/, "");
  if (hash.indexOf("doc:") === 0) { renderDoc(hash.slice(4)); return; }
  const f = App.features.find((x) => x.id === hash) || App.features[0];
  renderFeature(f);
}

async function renderDoc(path) {
  App.current = null;
  path = String(path || "").replace(/^\/+/, "");
  $("#pg-title").textContent = "Docs";
  $("#pg-sub").textContent = path;
  document.title = `${path} · UPES-ECS Console`;
  $$("#nav .nav-link").forEach((a) => a.setAttribute("aria-current", a.dataset.id === "docs" ? "page" : "false"));
  document.querySelector(".app").classList.remove("nav-open");
  const root = view();
  root.innerHTML = `<div class="panel"><span class="muted">Loading ${esc(path)}…</span></div>`;
  try {
    const res = await fetch(path + "?_=" + Date.now(), { cache: "no-store" });
    if (!res.ok) throw new Error("HTTP " + res.status);
    const md = await res.text();
    root.innerHTML = `<div class="docview"><div class="doc-bar"><a class="chip" href="#docs">← All docs</a>` +
      `<span class="doc-path">${esc(path)}</span></div>` +
      `<article class="markdown">${renderMarkdown(md)}</article></div>`;
    window.scrollTo(0, 0);
  } catch (e) {
    root.innerHTML = `<div class="panel">${empty("docs", "Couldn't load this document",
      esc(path) + " — " + esc(e.message) + ". It must be served (run Serve.ps1; file:// won't work).")}` +
      `<div style="margin-top:var(--sp-3)"><a class="chip" href="#docs">← All docs</a></div></div>`;
  }
}

// Auto-update: if the Console's own assets changed on disk (a deploy), reload the page
// so the wallboard picks up the new code without anyone hard-refreshing the browser.
// Served by Serve.ps1 at /__build; absent when opened via file:// — then this is a no-op.
async function checkBuild() {
  try {
    const res = await fetch("__build?_=" + Date.now(), { cache: "no-store" });
    if (!res.ok) return;
    const tag = (await res.json()).build;
    if (!tag) return;
    if (App.buildTag && tag !== App.buildTag) { location.reload(); return; }
    App.buildTag = tag;
  } catch (e) { /* no build endpoint — ignore */ }
}

// Emergency guardrail: can this live/status RESPONSE be trusted as realtime? A 200 alone can't —
// the console serves a frozen last-good body (X-Upes-Cache: stale) when the VM/tunnel is down.
// Returns {stale, ageMs}. We deliberately do NOT trust the payload's own `updated` clock (the
// emulated VM clock drifts); only the console's single-clock signals: the stale header (works
// today) and X-Upes-Age-Ms (Serve.ps1 G3). Same-origin, so custom headers are readable.
function assessFreshness(res) {
  let cache = "", ageMs = null;
  try { cache = (res.headers.get("X-Upes-Cache") || "").toLowerCase(); } catch (_) {}
  try { const a = res.headers.get("X-Upes-Age-Ms"); if (a != null && a !== "") ageMs = +a; } catch (_) {}
  const stale = (cache === "stale") || (ageMs != null && isFinite(ageMs) && ageMs > App.LIVE_STALE_MS);
  return { stale: stale, ageMs: ageMs };
}

async function poll() {
  await checkBuild();
  // Prefer the live API (fast, realtime); fall back to the static status.json snapshot.
  let data = null, fresh = { stale: false, ageMs: null };
  try {
    const res = await fetch("api/status?_=" + Date.now(), { cache: "no-store" });
    if (res.ok) { data = await res.json(); fresh = assessFreshness(res); }
  } catch (e) { /* API down — fall through */ }
  if (!data) {
    try {
      const res = await fetch("status.json?_=" + Date.now(), { cache: "no-store" });
      // status.json is a disk snapshot refreshed every ~20s — never realtime; force UNKNOWN.
      if (res.ok) { data = await res.json(); fresh = { stale: true, ageMs: null }; }
    } catch (e) { /* both unavailable */ }
  }
  if (data) {
    App.status = data; App.statusError = false; App.everLoaded = true;
    App.liveStale = fresh.stale; App.liveAgeMs = fresh.ageMs;
    if (data.serverIp) App.serverIp = data.serverIp;
    if (typeof data.bareMetal === "boolean") App.bareMetal = data.bareMetal;   // env-specific: hides VM UI
  } else {
    App.statusError = true; App.status = null; App.liveStale = false; App.liveAgeMs = null;
  }
  updateChip();
  if (App.current && typeof App.current.live === "function") {
    App.current.live(view(), App.statusError ? null : App.status);
  }
}

// G2: realtime sub-poll for the fast-changing call fields. The 4s /status poll is too slow for a
// live 111 count, so — like the wallboard — merge the light /api/live payload every ~1.3s onto the
// last full snapshot. Fan-in caching means the VM barely feels the extra polls. Freshness is
// re-assessed on every response so the Active-calls tile flips to UNKNOWN the instant the link drops.
const LIVE_MERGE_FIELDS = ["asterisk", "activeCalls", "liveCalls", "queueAvailable", "queueMembers", "updated"];
// forceFresh=true appends ?fresh=1 so the Console proxy BYPASSES its fan-in cache and reads the VM
// live -- used the instant a call is hung up so the board drops to the true count without waiting a TTL.
async function livePoll(forceFresh) {
  try {
    const res = await fetch("api/live?_=" + Date.now() + (forceFresh ? "&fresh=1" : ""), { cache: "no-store" });
    if (!res.ok) return;
    const d = await res.json();
    const fresh = assessFreshness(res);
    App.liveStale = fresh.stale; App.liveAgeMs = fresh.ageMs;
    if (!App.status) return;   // wait for the first full /status to establish the base snapshot
    LIVE_MERGE_FIELDS.forEach((k) => { if (k in d) App.status[k] = d[k]; });
    if (App.current && typeof App.current.live === "function") {
      App.current.live(view(), App.statusError ? null : App.status);
    }
  } catch (_) { /* keep the loop alive; the next /status poll re-establishes state */ }
}

function updateChip() {
  const map = {
    READY:    ["ok", "READY"], DEGRADED: ["warn", "DEGRADED"],
    CRITICAL: ["crit", "CRITICAL"], OFFLINE: ["crit", "OFFLINE"],
  };
  const dot = $("#chip-dot"), ipEl = $("#chip-ip"), stateEl = $("#chip-state");
  ipEl.textContent = App.serverIp;
  if (App.statusError || !App.status) {
    stateEl.className = "pill crit";
    stateEl.textContent = App.everLoaded ? "OFFLINE" : "no status";
    dot.className = "livedot off";
    dot.title = "status.json unreachable";
  } else {
    const m = map[App.status.state] || ["neutral", App.status.state || "unknown"];
    stateEl.className = "pill " + m[0];
    stateEl.textContent = m[1];
    dot.className = "livedot" + (m[0] === "crit" ? " stale" : "");
    dot.title = "live · updated " + (App.status.updated || "");
  }
}

/* ---- theme ---- */
function applyTheme(t) {
  const root = document.documentElement;
  if (t === "light" || t === "dark") root.setAttribute("data-theme", t);
  else root.removeAttribute("data-theme");
  const isDark = t === "dark" || (t !== "light" &&
    matchMedia("(prefers-color-scheme:dark)").matches);
  const btn = $("#theme-btn");
  if (btn) { btn.innerHTML = isDark ? ICONS.sun : ICONS.moon;
    btn.setAttribute("aria-label", isDark ? "Switch to light theme" : "Switch to dark theme"); }
}
function initTheme() {
  let saved = null;
  try { saved = localStorage.getItem("upes-theme"); } catch (_) {}
  applyTheme(saved || "system");
  $("#theme-btn").addEventListener("click", () => {
    const cur = document.documentElement.getAttribute("data-theme") ||
      (matchMedia("(prefers-color-scheme:dark)").matches ? "dark" : "light");
    const next = cur === "dark" ? "light" : "dark";
    applyTheme(next);
    try { localStorage.setItem("upes-theme", next); } catch (_) {}
  });
}

/* ---- collapsible sidebar (desktop rail) ---- */
function initNavCollapse() {
  const app = document.querySelector(".app");
  const btn = $("#nav-collapse");
  if (!app || !btn) return;
  let collapsed = false;
  try { collapsed = localStorage.getItem("upes.navCollapsed") === "1"; } catch (_) {}
  const apply = (c) => {
    app.classList.toggle("nav-collapsed", c);
    btn.setAttribute("aria-expanded", c ? "false" : "true");
    btn.setAttribute("aria-label", c ? "Expand sidebar" : "Collapse sidebar");
    btn.setAttribute("title", c ? "Expand sidebar" : "Collapse sidebar");
  };
  apply(collapsed);
  btn.addEventListener("click", () => {
    collapsed = !app.classList.contains("nav-collapsed");
    apply(collapsed);
    try { localStorage.setItem("upes.navCollapsed", collapsed ? "1" : "0"); } catch (_) {}
  });
}

/* ---------------------------------------------------------------------------
   7. BOOT
   ------------------------------------------------------------------------- */
function boot() {
  buildNav();
  initTheme();
  initNavCollapse();
  window.addEventListener("hashchange", route);
  $("#hamburger").addEventListener("click", () =>
    document.querySelector(".app").classList.toggle("nav-open"));
  $("#mobile-overlay").addEventListener("click", () =>
    document.querySelector(".app").classList.remove("nav-open"));
  updateChip();
  updateRegionChip();        // paint the region chip with the English default before the fetch lands
  route();
  poll();                    // immediate sync the moment the client connects
  loadRegion();              // active deployed language (region.json) — absent ⇒ English
  // anti-stampede: self-rescheduling poll with jitter + error backoff, so many dashboards/TVs don't
  // hammer the API in lockstep (esp. after a deploy auto-reload or a network blip resyncs them all).
  let pollGap = 4000;                            // normal cadence (replaces setInterval(poll, 4000))
  const schedulePoll = () => setTimeout(() => {
    poll().finally(() => {
      // grow the gap up to ~15s while the API is failing; snap back to 4s the moment a poll succeeds
      pollGap = App.statusError ? Math.min(15000, pollGap * 1.5) : 4000;
      schedulePoll();
    });
  }, pollGap * (0.85 + Math.random() * 0.3));    // +/-15% jitter breaks client lockstep
  schedulePoll();
  // G2: fast realtime sub-poll for the live call count (self-rescheduling + jitter + gentle backoff,
  // same anti-stampede shape as the full poll). Base ~1.3s so the Active-calls tile is genuinely live.
  let liveGap = 500, liveErr = 0;   // fast base so a call-end (or hangup) clears within ~1s
  const scheduleLive = () => setTimeout(() => {
    livePoll().finally(() => {
      liveErr = App.statusError ? Math.min(liveErr + 1, 6) : 0;
      liveGap = 500 + liveErr * 600;   // back off up to ~4s while failing, snap back on recovery
      scheduleLive();
    });
  }, liveGap * (0.7 + Math.random() * 0.6));
  scheduleLive();
  setInterval(loadRegion, 180000);   // re-check the deployed region every 3 min
}
if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", boot);
else boot();

})();
