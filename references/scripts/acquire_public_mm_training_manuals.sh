#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="$ROOT/references/public-archive/maintenance-pms"
mkdir -p "$DEST"
url="https://files.eric.ed.gov/fulltext/ED106658.pdf"
out="$DEST/NAVEDTRA_10525-D_Machinists_Mate_1_and_C_1974.pdf"
tmp="${out}.part"
echo "Downloading public ERIC scan: NAVEDTRA 10525-D"
curl -L --fail --retry 3 -A 'Mozilla/5.0' -o "$tmp" "$url"
if [[ "$(head -c 4 "$tmp")" != "%PDF" ]]; then
  echo "ERROR: response is not a PDF" >&2
  rm -f "$tmp"; exit 1
fi
mv "$tmp" "$out"
sha256sum "$out"
sha512sum "$out"
echo "Saved: $out"
echo "NOTE: add to reference-manifest.csv only after reviewing the downloaded scan and redistribution/source metadata."
