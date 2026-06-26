#!/usr/bin/env python3
"""Quick check that website embed JSON is valid."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
html = (ROOT / "website" / "index.html").read_text(encoding="utf-8")
m = re.search(
    r'<script type="application/json" id="lumina-embed-data">\s*(\{.*?\})\s*</script>',
    html,
    re.DOTALL,
)
if not m:
    raise SystemExit("embed block not found")
data = json.loads(m.group(1))
site = data["site"]
kb = site["keybindings"]
print(f"version={site['version']} files={site['fileCount']} docs={len(data['docs'])}")
print(f"keybindings={len(kb)} all_have_order={all('order' in x for x in kb)}")
print("top 5:", [(x["order"], x["bind"]) for x in sorted(kb, key=lambda x: x["order"])[:5]])
