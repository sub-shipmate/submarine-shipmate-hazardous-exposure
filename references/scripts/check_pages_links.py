#!/usr/bin/env python3
from pathlib import Path
import re, sys
from urllib.parse import urlparse, unquote

ROOT=Path(__file__).resolve().parents[2]
BASE="/submarine-shipmate-hazardous-exposure"
HOST="sub-shipmate.github.io"
bad=[]
html_files=[p for p in ROOT.rglob("*.html") if ".git" not in p.parts]
markdown_files=[p for p in ROOT.rglob("*.md") if ".git" not in p.parts]

def check(source, href):
    href=href.strip()
    if not href: return
    if any(x in href for x in ("index.htmlcatalog","index.htmlpublic","index.htmlforms","index.htmlreferences")):
        bad.append((source,href,"malformed concatenated URL")); return
    if href.startswith(("mailto:","data:","javascript:","#")): return
    if href.startswith(("http://","https://")):
        u=urlparse(href)
        if u.netloc==HOST and u.path.startswith(BASE+"/"):
            target=ROOT/unquote(u.path[len(BASE)+1:])
            if not target.exists(): bad.append((source,href,"GitHub Pages target missing locally"))
        return
    clean=unquote(href.split("#",1)[0].split("?",1)[0])
    if href.startswith(BASE+"/"):
        target=ROOT/clean[len(BASE)+1:]
    else:
        target=(source.parent/clean).resolve()
        try: target.relative_to(ROOT.resolve())
        except ValueError:
            bad.append((source,href,"target escapes repository")); return
    if not target.exists(): bad.append((source,href,"target missing locally"))

for p in html_files:
    t=p.read_text(encoding="utf-8",errors="replace")
    for href in re.findall(r'href=["\']([^"\']+)["\']',t,re.I): check(p,href)

for p in markdown_files:
    t=p.read_text(encoding="utf-8",errors="replace")
    for href in re.findall(r'\[[^\]]*\]\(([^)\s]+)(?:\s+["\'][^"\']*["\'])?\)',t): check(p,href)

if bad:
    print("Pages/Markdown link check: FAIL")
    for p,href,why in bad: print(f"  {p.relative_to(ROOT)} -> {href} [{why}]")
    print(f"\nProblems found: {len(bad)}")
    sys.exit(1)
print(f"Pages/Markdown link check: PASS ({len(html_files)} HTML files, {len(markdown_files)} Markdown files checked)")
