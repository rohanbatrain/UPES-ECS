#!/usr/bin/env python3
"""Merge landing/_i18n/*.json into landing/index.html at the /*__I18N_DATA__*/ marker.
Produces a single self-contained, local landing/index.html (no external deps)."""
import glob
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
i18n_dir = os.path.join(HERE, "_i18n")
template_path = os.path.join(HERE, "_template.html")
html_path = os.path.join(HERE, "index.html")

en = json.load(open(os.path.join(i18n_dir, "en.json"), encoding="utf-8"))
en_keys = set(en)

data, report = {}, []
for f in sorted(glob.glob(os.path.join(i18n_dir, "*.json"))):
    code = os.path.splitext(os.path.basename(f))[0]
    try:
        obj = json.load(open(f, encoding="utf-8"))
    except Exception as e:
        report.append(f"{code}: INVALID JSON ({e})"); continue
    missing = en_keys - set(obj)
    extra = set(obj) - en_keys
    if missing: report.append(f"{code}: missing {sorted(missing)}")
    if extra:   report.append(f"{code}: extra {sorted(extra)}")
    # fill any missing keys from English so the page never shows blanks
    for k in en_keys:
        obj.setdefault(k, en[k])
    data[code] = {k: obj[k] for k in en}  # stable key order

# compact but readable JSON, ensure_ascii=False keeps native scripts
blob = json.dumps(data, ensure_ascii=False, separators=(",", ":"))

html = open(template_path, encoding="utf-8").read()
html = re.sub(r"/\*__I18N_DATA__\*/\{\}", "/*__I18N_DATA__*/" + blob, html, count=1)
open(html_path, "w", encoding="utf-8").write(html)

print(f"languages merged: {len(data)}")
print("codes:", " ".join(sorted(data)))
print("report:", "; ".join(report) if report else "all languages complete, keys aligned")
