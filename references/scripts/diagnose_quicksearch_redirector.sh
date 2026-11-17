#!/usr/bin/env bash
set -euo pipefail

record="${1:-https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=48543}"
revision="${2:-Revision A}"
out="${3:-quicksearch-redirector-diagnostic.txt}"
UA='Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0'

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
page="$tmp/page.html"
jar="$tmp/cookies"
redir="$tmp/redirector.html"
headers="$tmp/headers"

curl --http2 --location --fail --compressed \
  -A "$UA" -c "$jar" -b "$jar" \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -o "$page" "$record"

action="$(python3 - "$page" "$revision" <<'PY'
from html.parser import HTMLParser
import re,sys
page,needle=sys.argv[1:3]
class P(HTMLParser):
    def __init__(self): super().__init__(); self.rows=[]; self.r=None
    def handle_starttag(self,t,a):
        if t.lower()=="tr": self.r={"text":[],"a":[]}
        elif self.r is not None and t.lower()=="a": self.r["a"].append(dict(a))
    def handle_data(self,d):
        if self.r is not None:self.r["text"].append(d)
    def handle_endtag(self,t):
        if t.lower()=="tr" and self.r is not None:self.rows.append(self.r);self.r=None
p=P();p.feed(open(page,encoding="utf-8",errors="replace").read())
want=" ".join(needle.split()).lower()
m=[]
for r in p.rows:
    text=" ".join(" ".join(r["text"]).split())
    if want in text.lower():m.append((text,r))
m.sort(key=lambda x:len(x[0]))
if not m: raise SystemExit("revision not found")
text,r=m[0]
if not re.search(r'(?:^|\s)A(?:\s|$)',text): raise SystemExit("not Statement A")
for a in r["a"]:
    h=a.get("href","")
    x=re.search(r"""spawnPDFWindow\(\s*['"]([^'"]*ImageRedirector\.aspx\?token=[^'"]+)['"]""",h,re.I)
    if x:
        print(x.group(1));break
else: raise SystemExit("redirector not found")
PY
)"

url="https://quicksearch.dla.mil/${action#./}"
curl --http2 --location --fail --compressed \
  -A "$UA" -c "$jar" -b "$jar" -H "Referer: $record" \
  -D "$headers" -o "$redir" "$url"

python3 - "$redir" "$headers" "$record" "$revision" > "$out" <<'PY'
from html.parser import HTMLParser
from urllib.parse import urljoin
import html,re,sys
body,headers,record,revision=sys.argv[1:5]
raw=open(body,encoding="utf-8",errors="replace").read()

print("QUICKSEARCH IMAGEREDIRECTOR DIAGNOSTIC")
print("Record:",record)
print("Revision:",revision)
print("Response bytes:",len(raw.encode("utf-8")))
print()
print("=== RESPONSE HEADERS ===")
for line in open(headers,encoding="latin-1",errors="replace"):
    if re.match(r'^(HTTP/|content-type:|content-disposition:|location:)',line,re.I):
        print(line.rstrip())
print()

print("=== INTERMEDIATE HTML ===")
# This page is public response markup. Avoid dumping ASP.NET state values if
# DLA ever adds them; redact long hidden values.
safe=re.sub(r'(<input[^>]+type=["\']hidden["\'][^>]+value=["\'])[^"\']{80,}(["\'])',
            r'\1[REDACTED-LONG-HIDDEN-VALUE]\2',raw,flags=re.I)
print(safe)
print()

class P(HTMLParser):
    def __init__(self): super().__init__(); self.urls=[]
    def handle_starttag(self,t,a):
        d=dict(a)
        for k in ("href","src","data","action"):
            if d.get(k): self.urls.append((t,k,d[k]))
p=P();p.feed(raw)

print("=== URL-BEARING ATTRIBUTES ===")
for t,k,u in p.urls:
    print(t,k,html.unescape(u),"=>",urljoin("https://quicksearch.dla.mil/ImageRedirector.aspx",html.unescape(u)))
print()

print("=== SCRIPT / NAVIGATION CANDIDATES ===")
patterns=[
 r'window\.location(?:\.href)?\s*=\s*["\']([^"\']+)["\']',
 r'location(?:\.href)?\s*=\s*["\']([^"\']+)["\']',
 r'window\.open\(\s*["\']([^"\']+)["\']',
 r'content\s*=\s*["\'][^"\']*url\s*=\s*([^"\';]+)',
 r'["\']([^"\']*(?:/Transient/|\.pdf(?:\?|$))[^"\']*)["\']',
]
seen=set()
for pat in patterns:
    for m in re.finditer(pat,raw,re.I):
        u=html.unescape(m.group(1).strip())
        if u not in seen:
            seen.add(u)
            print(u,"=>",urljoin("https://quicksearch.dla.mil/ImageRedirector.aspx",u))
PY

echo "Diagnostic written: $out"
echo "No document was added to public-archive."
