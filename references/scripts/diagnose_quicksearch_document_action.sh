#!/usr/bin/env bash
set -euo pipefail

# Diagnostic only. Fetches a PUBLIC QuickSearch document-detail page and
# extracts markup/scripts around the requested revision. It does not download
# or archive a document.
record="${1:-https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=48543}"
revision="${2:-Revision A}"
out="${3:-quicksearch-diagnostic.txt}"
UA='Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
page="$tmp/page.html"
jar="$tmp/cookies"

curl --http2 --location --fail --compressed \
  -A "$UA" -c "$jar" -b "$jar" \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  --connect-timeout 20 --max-time 90 \
  -o "$page" "$record"

python3 - "$page" "$revision" "$record" > "$out" <<'PY'
from html.parser import HTMLParser
import re,sys,html
page,needle,url=sys.argv[1:4]
raw=open(page,encoding="utf-8",errors="replace").read()

print("QUICKSEARCH PUBLIC DOCUMENT-ACTION DIAGNOSTIC")
print("Record:",url)
print("Requested revision:",needle)
print("HTML bytes:",len(raw))
print()

class P(HTMLParser):
    def __init__(self):
        super().__init__(); self.rows=[]; self.row=None
    def handle_starttag(self,t,a):
        attrs=dict(a)
        if t.lower()=="tr":
            self.row={"start":self.get_starttag_text(),"text":[],"tags":[]}
        if self.row is not None:
            self.row["tags"].append((t,attrs,self.get_starttag_text()))
    def handle_data(self,d):
        if self.row is not None:self.row["text"].append(d)
    def handle_endtag(self,t):
        if t.lower()=="tr" and self.row is not None:
            self.rows.append(self.row); self.row=None
p=P();p.feed(raw)
want=" ".join(needle.split()).lower()
matches=[]
for r in p.rows:
    text=" ".join(" ".join(r["text"]).split())
    if want in text.lower(): matches.append((text,r))
matches.sort(key=lambda x:len(x[0]))

print("=== MATCHED REVISION ROW ===")
if not matches:
    print("NOT FOUND"); sys.exit(2)
text,row=matches[0]
print(text)
print()
print("=== ALL START TAGS INSIDE MATCHED ROW ===")
for t,a,source in row["tags"]:
    print(source)
print()

# Raw source lines are valuable because browser DOM parsers can hide malformed
# or generated attributes.
lines=raw.splitlines()
hits=[]
for i,line in enumerate(lines):
    low=line.lower()
    if want in " ".join(re.sub(r"<[^>]+>"," ",line).split()).lower():
        hits.append(i)
if not hits:
    # locate by distinctive visible date/text fragments from matched row
    words=[w for w in re.split(r"\s+",text) if len(w)>5]
    for i,line in enumerate(lines):
        if any(w.lower() in line.lower() for w in words):
            hits.append(i)

print("=== RAW SOURCE NEAR MATCH ===")
for i in sorted(set(hits))[:10]:
    lo=max(0,i-4); hi=min(len(lines),i+5)
    print(f"--- lines {lo+1}-{hi} ---")
    for n in range(lo,hi):
        print(f"{n+1}: {lines[n]}")
print()

print("=== PDF.GIF / DOCUMENT IMAGE OCCURRENCES ===")
for m in re.finditer(r'.{0,300}(?:pdf\.gif|Document Image).{0,500}',raw,re.I|re.S):
    print(" ".join(m.group(0).split()))
    print("---")
print()

print("=== JAVASCRIPT / EVENT / DOWNLOAD TOKENS ===")
patterns=[
    r'__doPostBack\([^)]{0,500}\)',
    r'onclick\s*=\s*["\'][^"\']+["\']',
    r'href\s*=\s*["\'][^"\']+["\']',
    r'(?:window\.open|location(?:\.href)?|open)\s*\([^)]{0,500}\)',
    r'[^"\'\s<>]{0,100}(?:Transient|pdf|download)[^"\'\s<>]{0,200}',
]
seen=set()
for pat in patterns:
    for m in re.finditer(pat,raw,re.I):
        x=html.unescape(" ".join(m.group(0).split()))
        if x not in seen:
            seen.add(x); print(x)
print()

print("=== FORM CONTROLS / HIDDEN STATE NAMES ===")
for m in re.finditer(r'<(?:form|input|button)[^>]*>',raw,re.I):
    x=" ".join(m.group(0).split())
    low=x.lower()
    if any(k in low for k in ("__event","viewstate","eventvalidation","form","button","image","pdf")):
        print(x)
PY

echo "Diagnostic written: $out"
echo "No PDF was downloaded or archived."
echo
echo "Please send the contents of $out back for analysis."
