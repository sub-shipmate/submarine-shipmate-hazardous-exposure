#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSV="$ROOT/references/public-spec-downloads.csv"
UA='Mozilla/5.0 (X11; Linux x86_64; rv:145.0) Gecko/20100101 Firefox/145.0'

command -v curl >/dev/null || { echo "curl is required"; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required"; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 - "$CSV" <<'PY' > "$tmp/rows"
import csv,sys
with open(sys.argv[1],newline='',encoding='utf-8-sig') as f:
    for r in csv.DictReader(f):
        vals=[r[k] for k in ("acquisition_id","document_id","revision_match",
                             "distribution_statement","record_url","archive_path")]
        print("\0".join(vals)+"\0",end="")
PY

downloaded=0; skipped=0; failed=0

while IFS= read -r -d '' aid &&
      IFS= read -r -d '' docid &&
      IFS= read -r -d '' revision &&
      IFS= read -r -d '' dist &&
      IFS= read -r -d '' record &&
      IFS= read -r -d '' rel; do

  echo
  echo "=== $aid :: $docid :: $revision ==="

  [[ "$dist" == "A" ]] || {
    echo "SKIP: acquisition manifest does not mark this document part A"
    ((skipped+=1)); continue
  }
  [[ "$rel" != /* && "$rel" != *".."* ]] || {
    echo "FAIL: unsafe archive path"; ((failed+=1)); continue
  }

  dest="$ROOT/references/$rel"
  mkdir -p "$(dirname "$dest")"
  if [[ -s "$dest" ]]; then
    if [[ "$(head -c 4 "$dest" 2>/dev/null || true)" == "%PDF" ]]; then
      echo "EXISTS: $dest"
      sha256sum "$dest"
      ((skipped+=1)); continue
    else
      echo "FAIL: existing destination is not a PDF: $dest"
      ((failed+=1)); continue
    fi
  fi

  page="$tmp/$aid.html"
  jar="$tmp/$aid.cookies"
  headers="$tmp/$aid.headers"

  if ! curl --http2 --location --fail --compressed \
      -A "$UA" -c "$jar" -b "$jar" \
      -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
      -H 'Accept-Language: en-US,en;q=0.9' \
      --retry 2 --connect-timeout 20 --max-time 90 \
      -o "$page" "$record"; then
    echo "FAIL: official QuickSearch record page could not be retrieved"
    ((failed+=1)); continue
  fi

  meta="$tmp/$aid.meta"
  if ! python3 - "$page" "$revision" > "$meta" <<'PY'
from html.parser import HTMLParser
import re,sys
page,needle=sys.argv[1],sys.argv[2]

class P(HTMLParser):
    def __init__(self):
        super().__init__(); self.rows=[]; self.row=None
    def handle_starttag(self,t,a):
        d=dict(a)
        if t.lower()=="tr":
            self.row={"text":[],"anchors":[]}
        elif self.row is not None and t.lower()=="a":
            self.row["anchors"].append(d)
    def handle_data(self,d):
        if self.row is not None:self.row["text"].append(d)
    def handle_endtag(self,t):
        if t.lower()=="tr" and self.row is not None:
            self.rows.append(self.row); self.row=None

p=P()
p.feed(open(page,encoding="utf-8",errors="replace").read())
want=" ".join(needle.split()).lower()
matches=[]
for r in p.rows:
    text=" ".join(" ".join(r["text"]).split())
    if want in text.lower():
        matches.append((text,r))
if not matches:
    print("ERROR\tREVISION_NOT_FOUND"); raise SystemExit(2)

# Base revisions should not accidentally select an amendment. The shortest
# matching row is the exact base row; amendment requests remain longer and
# match their full requested phrase.
matches.sort(key=lambda x:(len(x[0]),x[0].lower()))
text,row=matches[0]

# Distribution Statement A must be visible on the same exact revision row.
if not re.search(r'(?:^|\s)A(?:\s|$)',text):
    print("ERROR\tROW_NOT_STATEMENT_A\t"+text); raise SystemExit(3)

redirect=None
token=None
for a in row["anchors"]:
    href=a.get("href","")
    # Verified QuickSearch form:
    # javascript:spawnPDFWindow('./ImageRedirector.aspx?token=174765.48543',174765);
    m=re.search(
        r"""spawnPDFWindow\(\s*['"]([^'"]*ImageRedirector\.aspx\?token=([^'"]+))['"]""",
        href,re.I)
    if m:
        redirect=m.group(1)
        token=m.group(2)
        break

if not redirect:
    print("ERROR\tNO_IMAGE_REDIRECTOR\t"+text); raise SystemExit(4)

# Keep the request on QuickSearch and reject unexpected schemes/paths.
if "://" in redirect or not re.match(r"^\./ImageRedirector\.aspx\?token=[A-Za-z0-9._-]+$",redirect,re.I):
    print("ERROR\tUNSAFE_REDIRECTOR\t"+redirect); raise SystemExit(5)

print("ROW\t"+text)
print("REDIRECTOR\t"+redirect)
print("TOKEN\t"+token)
PY
  then
    echo "FAIL: exact public document action could not be resolved"
    sed -n '1,8p' "$meta" 2>/dev/null || true
    ((failed+=1)); continue
  fi

  rowtext="$(awk -F '\t' '$1=="ROW"{sub(/^ROW\t/,"");print;exit}' "$meta")"
  redirect="$(awk -F '\t' '$1=="REDIRECTOR"{print $2;exit}' "$meta")"
  token="$(awk -F '\t' '$1=="TOKEN"{print $2;exit}' "$meta")"

  echo "MATCHED ROW: $rowtext"
  echo "VERIFIED: exact revision row carries Distribution Statement A"
  echo "DOCUMENT ACTION: ImageRedirector token=$token"

  # Resolve the verified relative endpoint against the fixed official host.
  url="https://quicksearch.dla.mil/${redirect#./}"
  part="$dest.part"
  rm -f "$part" "$headers"

  intermediate="$tmp/$aid.redirector.html"
  if ! curl --http2 --location --fail --compressed \
      -A "$UA" -c "$jar" -b "$jar" \
      -H "Referer: $record" \
      -H 'Accept: text/html,application/xhtml+xml,application/pdf;q=0.9,*/*;q=0.7' \
      -D "$headers" \
      --retry 2 --connect-timeout 20 --max-time 180 \
      -o "$intermediate" "$url"; then
    echo "FAIL: ImageRedirector request failed"
    ((failed+=1)); continue
  fi

  echo "IMAGEREDIRECTOR RESPONSE:"
  grep -iE '^(HTTP/|content-type:|content-disposition:|location:)' "$headers" | tail -12 || true

  # If DLA ever changes ImageRedirector to return the PDF directly, accept it.
  if [[ "$(head -c 4 "$intermediate" 2>/dev/null || true)" == "%PDF" ]]; then
    cp "$intermediate" "$part"
  else
    wmx="$(python3 - "$intermediate" "$token" <<'PY'
from html.parser import HTMLParser
import re,sys
page,fulltoken=sys.argv[1:3]
component=fulltoken.split(".",1)[0]
class P(HTMLParser):
    def __init__(self): super().__init__(); self.links=[]
    def handle_starttag(self,t,a):
        if t.lower()=="a":
            h=dict(a).get("href")
            if h:self.links.append(h)
p=P();p.feed(open(page,encoding="utf-8",errors="replace").read())
for h in p.links:
    # Observed public QuickSearch intermediary:
    # ../../WMX/Default.aspx?token=174765
    m=re.fullmatch(r"\.\./\.\./WMX/Default\.aspx\?token=([A-Za-z0-9_-]+)",h,re.I)
    if m and m.group(1)==component:
        print(h);break
PY
)"
    if [[ -z "$wmx" ]]; then
      echo "FAIL: ImageRedirector HTML did not contain the expected WMX action"
      ((failed+=1)); continue
    fi

    component="${token%%.*}"
    echo "VERIFIED WMX ACTION: component token=$component"
    wmx_url="https://quicksearch.dla.mil/WMX/Default.aspx?token=$component"
    wmx_headers="$tmp/$aid.wmx.headers"
    wmx_body="$tmp/$aid.wmx.body"

    if ! curl --http2 --location --fail --compressed \
        -A "$UA" -c "$jar" -b "$jar" \
        -H "Referer: $url" \
        -H 'Accept: application/pdf,application/octet-stream;q=0.9,text/html;q=0.8,*/*;q=0.7' \
        -D "$wmx_headers" \
        --retry 2 --connect-timeout 20 --max-time 240 \
        -o "$wmx_body" "$wmx_url"; then
      echo "FAIL: WMX document-preparation request failed"
      ((failed+=1)); continue
    fi

    echo "WMX RESPONSE:"
    grep -iE '^(HTTP/|content-type:|content-disposition:|location:)' "$wmx_headers" | tail -16 || true

    if [[ "$(head -c 4 "$wmx_body" 2>/dev/null || true)" == "%PDF" ]]; then
      cp "$wmx_body" "$part"
    else
      # WMX may itself return a small preparation page containing a generated
      # public document target. Follow only explicit HTTP(S) or relative links
      # that identify a PDF/Transient/download resource on QuickSearch.
      final="$(python3 - "$wmx_body" <<'PY'
from html.parser import HTMLParser
from urllib.parse import urljoin,urlparse
import html,re,sys
raw=open(sys.argv[1],encoding="utf-8",errors="replace").read()
base="https://quicksearch.dla.mil/WMX/Default.aspx"
class P(HTMLParser):
    def __init__(self): super().__init__(); self.urls=[]
    def handle_starttag(self,t,a):
        d=dict(a)
        for k in ("href","src","data"):
            if d.get(k): self.urls.append(d[k])
p=P();p.feed(raw)
cands=p.urls[:]
patterns=[
 r'window\.location(?:\.href)?\s*=\s*["\']([^"\']+)["\']',
 r'location(?:\.href)?\s*=\s*["\']([^"\']+)["\']',
 r'window\.open\(\s*["\']([^"\']+)["\']',
 r'["\']([^"\']*(?:/Transient/|\.pdf(?:\?|$)|download)[^"\']*)["\']'
]
for pat in patterns:
    cands += re.findall(pat,raw,re.I)
for u in cands:
    u=html.unescape(u.strip())
    full=urljoin(base,u)
    q=urlparse(full)
    if q.scheme=="https" and q.hostname=="quicksearch.dla.mil":
        low=full.lower()
        if ".pdf" in low or "/transient/" in low or "download" in low:
            print(full);break
PY
)"
      if [[ -z "$final" ]]; then
        echo "FAIL: WMX returned HTML but no safe final PDF/Transient target was found"
        echo "WMX bytes: $(wc -c < "$wmx_body")"
        file "$wmx_body" || true
        ((failed+=1)); continue
      fi
      echo "FINAL DOCUMENT TARGET: verified QuickSearch-hosted PDF/Transient link"
      if ! curl --http2 --location --fail --compressed \
          -A "$UA" -c "$jar" -b "$jar" \
          -H "Referer: $wmx_url" \
          --retry 2 --connect-timeout 20 --max-time 240 \
          -o "$part" "$final"; then
        echo "FAIL: final generated document request failed"
        rm -f "$part"; ((failed+=1)); continue
      fi
    fi
  fi

  if [[ "$(head -c 4 "$part" 2>/dev/null || true)" != "%PDF" ]]; then
    echo "FAIL: final content is not a PDF; nothing archived"
    rm -f "$part"; ((failed+=1)); continue
  fi

  mv "$part" "$dest"
  echo "SAVED: $dest"
  ls -lh "$dest"
  file "$dest" || true
  sha256sum "$dest"
  sha512sum "$dest"
  ((downloaded+=1))

done < "$tmp/rows"

echo
echo "=== PERIOD SPEC ACQUISITION SUMMARY ==="
echo "Downloaded: $downloaded"
echo "Skipped:    $skipped"
echo "Failed:     $failed"
[[ "$failed" -eq 0 ]]
