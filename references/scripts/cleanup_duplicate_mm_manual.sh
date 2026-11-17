#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dup="$ROOT/references/public-archive/ship-repair/ED106658.pdf"
canonical="$ROOT/references/public-archive/maintenance-pms/NAVEDTRA_10525-D_Machinists_Mate_1_and_C_1974.pdf"
expected="be1c584caa9cf0f9daf25c66006dd37b425a914d64a977507979065a218ed138"
[[ -f "$canonical" ]] || { echo "ERROR: canonical MM manual missing"; exit 1; }
actual="$(sha256sum "$canonical" | awk '{print $1}')"
[[ "$actual" == "$expected" ]] || { echo "ERROR: canonical MM manual hash mismatch"; exit 1; }
if [[ -f "$dup" ]]; then
  d="$(sha256sum "$dup" | awk '{print $1}')"
  [[ "$d" == "$expected" ]] || { echo "ERROR: duplicate candidate is not byte-identical; refusing deletion." >&2; exit 1; }
  rm -f "$dup"; echo "Removed byte-identical duplicate: $dup"
else
  echo "Duplicate already absent."
fi
