#!/usr/bin/env python3
from pathlib import Path
import re, sys
ROOT=Path(__file__).resolve().parents[2]
BASE="/submarine-shipmate-hazardous-exposure"
bad=[]
html_files=list(ROOT.rglob("*.html"))
for p in html_files:
    text=p.read_text(encoding="utf-8",errors="replace")
    for href in re.findall(r'href=["\']([^"\']+)["\']',text):
        if href.startswith(("http://","https://","mailto:","#","data:","javascript:")):
            continue
        if "index.htmlcatalog" in href or "index.htmlpublic" in href:
            bad.append((p,href,"malformed concatenated URL"))
            continue
        if href.startswith(BASE+"/"):
            rel=href[len(BASE)+1:].split("#",1)[0].split("?",1)[0]
            target=ROOT/rel
            if not target.exists():
                bad.append((p,href,"target missing locally"))
if bad:
    print("Pages link check: FAIL")
    for p,href,why in bad:
        print(f"  {p.relative_to(ROOT)} -> {href} [{why}]")
    sys.exit(1)
print(f"Pages link check: PASS ({len(html_files)} HTML files checked)")
