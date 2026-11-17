#!/usr/bin/env bash
set -u
set -o pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CSV="$ROOT/references/material-sheet-downloads.csv"
DEST="$ROOT/references/public-archive/materials-specifications"
mkdir -p "$DEST"
python3 - "$CSV" <<'PY' |
import csv,sys
with open(sys.argv[1],newline='',encoding='utf-8') as f:
    for r in csv.DictReader(f):
        if r.get("download_status","").strip()=="CONFIRMED_PUBLIC_DOWNLOAD":
            print("\0".join([r.get("id",""),r.get("title",""),r.get("direct_public_url",""),r.get("filename","")]),end="\0")
PY
while IFS= read -r -d '' id && IFS= read -r -d '' title && IFS= read -r -d '' url && IFS= read -r -d '' filename; do
  [[ -n "$url" && -n "$filename" ]] || continue
  case "$filename" in */*|*..*) echo "Unsafe filename: $filename"; continue;; esac
  final="$DEST/$filename"; part="$final.part"
  [[ -s "$final" ]] && { echo "EXISTS: $final"; continue; }
  echo "Downloading [$id] $title"
  curl --http2 --location --fail --compressed --retry 3 --retry-delay 2 \
    --connect-timeout 20 --max-time 180 \
    -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:160.0) Gecko/20100101 Firefox/160.0' \
    -H 'Accept: application/pdf,text/html;q=0.9,*/*;q=0.8' \
    -H 'Accept-Language: en-US,en;q=0.9' -o "$part" "$url" ||
      { rm -f "$part"; echo "FAILED: $url"; continue; }
  if [[ "$filename" == *.pdf ]] && ! head -c 5 "$part" | grep -q '%PDF'; then
    echo "REJECTED: not PDF"; rm -f "$part"; continue
  fi
  mv "$part" "$final"; sha256sum "$final"
done
