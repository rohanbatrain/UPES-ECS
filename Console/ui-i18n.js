/*
 * ui-i18n.js — non-invasive DOM localization layer for the UPES-ECS Console + TV boards.
 *
 * How it works:
 *   - Reads the active deployed language from region.json (`language`, lowercased).
 *   - If absent or "en", does nothing: English is the source language.
 *   - Otherwise loads ui-lang/<code>.json — a flat { "<English UI string>": "<translated>" } map —
 *     and translates matching text nodes + [placeholder|title|aria-label] attributes in place.
 *   - Keys are English; translated (e.g. Hindi) output never matches a key, so the pass is
 *     idempotent and safe to re-run: it never double-translates or loops.
 *   - A debounced MutationObserver keeps the fast-polling dashboard localized as app.js / tv.js
 *     re-render, translating only the added/changed subtrees (cheap), not the whole document.
 *   - region.json is re-polled periodically; if the deployed language changes the page reloads
 *     so the correct catalogue is applied from scratch.
 *
 * This file owns NO application logic — it only rewrites visible strings after render.
 */
(function () {
  "use strict";

  var SKIP_TAGS = { SCRIPT: 1, STYLE: 1, CODE: 1, PRE: 1, NOSCRIPT: 1, TEXTAREA: 1 };
  var ATTRS = ["placeholder", "title", "aria-label"];
  var POLL_MS = 3 * 60 * 1000; // re-check region.json every 3 minutes

  var exactMap = Object.create(null);  // trimmed English  -> translation
  var normMap = Object.create(null);   // whitespace-collapsed English -> translation
  var currentLang = null;
  var observer = null;

  function norm(s) { return s.replace(/\s+/g, " ").trim(); }

  /* Translate a raw attribute/text value; returns the new value or null if unchanged. */
  function translate(raw) {
    if (!raw) return null;
    var trimmed = raw.trim();
    if (!trimmed) return null;
    var hit = exactMap[trimmed];
    if (hit === undefined) hit = normMap[norm(raw)];
    if (hit === undefined) return null;
    var out = raw.match(/^\s*/)[0] + hit + raw.match(/\s*$/)[0];
    return out === raw ? null : out;
  }

  function skipEl(el) {
    return !!el && (SKIP_TAGS[el.nodeName] === 1 ||
      (el.nodeType === 1 && el.hasAttribute("data-noi18n")));
  }

  /* True if any ancestor (or the node's parent) is a skip tag / data-noi18n. */
  function blockedByAncestor(el) {
    for (var n = el; n; n = n.parentElement) {
      if (skipEl(n)) return true;
    }
    return false;
  }

  function processTextNode(node) {
    if (!node || node.nodeType !== 3) return;
    var parent = node.parentNode;
    if (!parent || parent.nodeType !== 1) return;
    if (blockedByAncestor(parent)) return;
    var out = translate(node.nodeValue);
    if (out !== null) node.nodeValue = out;
  }

  function processAttrs(el) {
    if (!el || el.nodeType !== 1) return;
    if (blockedByAncestor(el)) return;
    for (var i = 0; i < ATTRS.length; i++) {
      var a = ATTRS[i];
      if (el.hasAttribute(a)) {
        var out = translate(el.getAttribute(a));
        if (out !== null) el.setAttribute(a, out);
      }
    }
  }

  /* Walk a root (element or text node), translating text nodes + attributes. */
  function walk(root) {
    if (!root) return;
    if (root.nodeType === 3) { processTextNode(root); return; }
    if (root.nodeType !== 1 && root.nodeType !== 9 && root.nodeType !== 11) return;
    if (root.nodeType === 1) {
      if (skipEl(root)) return;
      processAttrs(root);
    }
    var doc = root.ownerDocument || document;
    var tw = doc.createTreeWalker(
      root,
      NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT,
      {
        acceptNode: function (n) {
          if (n.nodeType === 1 && skipEl(n)) return NodeFilter.FILTER_REJECT;
          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );
    var n;
    while ((n = tw.nextNode())) {
      if (n.nodeType === 3) processTextNode(n);
      else if (n.nodeType === 1) processAttrs(n);
    }
  }

  /* ---- Live updates -------------------------------------------------------- */

  // Translate SYNCHRONOUSLY inside the observer callback. MutationObserver callbacks run as
  // microtasks — after app.js/tv.js finish a render but BEFORE the browser paints — so doing
  // the translation here (no setTimeout debounce) swaps English->target before the frame is
  // shown. That eliminates the English-then-translated flash on every poll re-render.
  function onMutations(mutations) {
    if (observer) observer.disconnect(); // don't observe our own writes
    try {
      for (var i = 0; i < mutations.length; i++) {
        var m = mutations[i];
        if (m.type === "childList") {
          for (var j = 0; j < m.addedNodes.length; j++) walk(m.addedNodes[j]);
        } else {
          walk(m.target); // characterData / attributes
        }
      }
    } finally {
      if (observer) connectObserver();
    }
  }

  function connectObserver() {
    observer.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ATTRS
    });
  }

  function start() {
    walk(document.body);
    observer = new MutationObserver(onMutations);
    connectObserver();
  }

  /* ---- Bootstrapping ------------------------------------------------------- */

  function fetchJSON(url) {
    return fetch(url + (url.indexOf("?") < 0 ? "?" : "&") + "_=" + Date.now(),
      { cache: "no-store" }).then(function (r) {
      if (!r.ok) throw new Error(url + " " + r.status);
      return r.json();
    });
  }

  function readRegionLang() {
    return fetchJSON("region.json").then(function (r) {
      return (r && r.language ? String(r.language) : "").toLowerCase().trim();
    }).catch(function () { return null; });
  }

  function loadCatalogueAndRun(lang) {
    return fetchJSON("ui-lang/" + lang + ".json").then(function (map) {
      exactMap = Object.create(null);
      normMap = Object.create(null);
      for (var k in map) {
        if (!Object.prototype.hasOwnProperty.call(map, k)) continue;
        var v = map[k];
        if (typeof v !== "string" || !v) continue;
        exactMap[k] = v;
        normMap[norm(k)] = v;
      }
      if (document.body) start();
      else document.addEventListener("DOMContentLoaded", start);
    }).catch(function (e) {
      // Missing/invalid catalogue: leave the UI in English rather than break the page.
      if (window.console) console.warn("[ui-i18n] catalogue load failed:", e);
    });
  }

  function startPolling(initialLang) {
    setInterval(function () {
      readRegionLang().then(function (lang) {
        if (lang !== null && lang !== initialLang) {
          // Deployed language changed since load: reload so the right catalogue applies cleanly.
          location.reload();
        }
      });
    }, POLL_MS);
  }

  readRegionLang().then(function (lang) {
    currentLang = lang;
    startPolling(lang);
    if (!lang || lang === "en") return; // English is the source — nothing to translate.
    loadCatalogueAndRun(lang);
  });
})();
