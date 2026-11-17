#!/usr/bin/env bash
set -u
set -o pipefail

# Submarine Shipmate Hazardous Exposure Research Archive
# Public-reference downloader.
#
# Run from repository root:
#   ./references/scripts/archive_public_references.sh
#
# The manifest is authoritative for each file's archive_path.
# CSV parsing is done with Python's csv module so quoted commas do not
# shift fields. curl uses the browser-style headers that successfully
# retrieved CDC Stacks PDFs during testing.
#
# This script does not bypass authentication or access controls.
# HTTP 403/401 responses are reported and left for manual review.

MANIFEST="references/reference-manifest.csv"
ROOT="references"
INVENTORY="$ROOT/archive-inventory.csv"

if [[ ! -f "$MANIFEST" ]]; then
    echo "ERROR: Run this script from the repository root."
    echo "Missing: $MANIFEST"
    exit 1
fi

command -v curl >/dev/null || { echo "ERROR: curl is required."; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: python3 is required."; exit 1; }
command -v file >/dev/null || { echo "ERROR: file is required."; exit 1; }
command -v sha256sum >/dev/null || { echo "ERROR: sha256sum is required."; exit 1; }

mkdir -p "$ROOT/public-archive"

echo "Submarine Shipmate Hazardous Exposure Research Archive"
echo "Public reference download pass"
echo "Repository: $(pwd)"
echo "Manifest:   $MANIFEST"
echo

TMP_LIST="$(mktemp)"
trap 'rm -f "$TMP_LIST"' EXIT

# Properly parse CSV and emit NUL-delimited source_id, source_url, archive_path.
python3 - "$MANIFEST" "$TMP_LIST" <<'PY'
import csv, sys
manifest, output = sys.argv[1], sys.argv[2]
with open(manifest, newline="", encoding="utf-8-sig") as f, open(output, "wb") as o:
    for r in csv.DictReader(f):
        sid  = (r.get("source_id") or "").strip()
        url  = (r.get("source_url") or "").strip()
        path = (r.get("archive_path") or "").strip()
        if not sid or not url or not path:
            continue
        # Reject manifest paths that could escape references/.
        from pathlib import PurePosixPath
        pp = PurePosixPath(path)
        if pp.is_absolute() or ".." in pp.parts:
            print(f"SKIP unsafe archive_path for {sid}: {path}", file=sys.stderr)
            continue
        for value in (sid, url, path):
            o.write(value.encode("utf-8"))
            o.write(b"\0")
PY

download_file() {
    local source_id="$1"
    local url="$2"
    local relpath="$3"
    local outfile="$ROOT/$relpath"
    local outdir
    outdir="$(dirname "$outfile")"

    mkdir -p "$outdir"

    echo "============================================================"
    echo "SOURCE:       $source_id"
    echo "URL:          $url"
    echo "DESTINATION:  $outfile"
    echo "DIRECTORY:    $outdir"

    if [[ -s "$outfile" ]]; then
        echo "STATUS:       EXISTS — not downloaded again"
        echo
        echo "FILE:"
        ls -lh "$outfile"
        echo
        echo "TYPE:"
        file "$outfile"
        echo
        echo "SHA-256:"
        sha256sum "$outfile"
        echo
        echo "DIRECTORY CONTENTS:"
        ls -lah "$outdir"
        echo
        return 0
    fi

    rm -f "${outfile}.part"

    if curl \
        --http2 \
        --location \
        --fail \
        --show-error \
        --compressed \
        --retry 2 \
        --retry-delay 2 \
        --connect-timeout 30 \
        --max-time 300 \
        -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:160.0) Gecko/20100101 Firefox/160.0' \
        -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
        -H 'Accept-Language: en-US,en;q=0.9' \
        -H 'Upgrade-Insecure-Requests: 1' \
        -H 'Sec-Fetch-Dest: document' \
        -H 'Sec-Fetch-Mode: navigate' \
        -H 'Sec-Fetch-Site: none' \
        -H 'Sec-Fetch-User: ?1' \
        -H 'Pragma: no-cache' \
        -H 'Cache-Control: no-cache' \
        --output "${outfile}.part" \
        "$url"
    then
        if [[ "${outfile,,}" == *.pdf ]]; then
            if ! head -c 5 "${outfile}.part" | grep -q '^%PDF'; then
                echo "STATUS:       REJECTED — expected PDF but response is not a PDF"
                echo "RESPONSE:"
                file "${outfile}.part"
                rm -f "${outfile}.part"
                return 1
            fi
        fi

        mv "${outfile}.part" "$outfile"

        echo "STATUS:       SAVED"
        echo
        echo "FILE:"
        ls -lh "$outfile"
        echo
        echo "TYPE:"
        file "$outfile"
        echo
        echo "SHA-256:"
        sha256sum "$outfile"
        echo
        echo "DIRECTORY CONTENTS:"
        ls -lah "$outdir"
        echo
        return 0
    else
        local rc=$?
        rm -f "${outfile}.part"
        echo "STATUS:       BLOCKED/FAILED (curl exit $rc)"
        echo "EXPECTED AT:  $outfile"
        echo
        echo "CURRENT DIRECTORY CONTENTS:"
        ls -lah "$outdir"
        echo
        return "$rc"
    fi
}

while IFS= read -r -d '' source_id &&
      IFS= read -r -d '' source_url &&
      IFS= read -r -d '' archive_path
do
    # Landing/catalog pages that are not direct downloadable archive objects.
    case "$source_url" in
        *quicksearch.dla.mil/qsDocDetails*|*nap.nationalacademies.org/catalog/*)
            echo "============================================================"
            echo "SOURCE:       $source_id"
            echo "STATUS:       CATALOG/LANDING PAGE — no automatic file download"
            echo "URL:          $source_url"
            echo "ARCHIVE PATH: $ROOT/$archive_path"
            echo
            continue
            ;;
    esac

    download_file "$source_id" "$source_url" "$archive_path" || true
done < "$TMP_LIST"

echo "============================================================"
echo "DOWNLOAD PASS COMPLETE"
echo

echo "ALL ARCHIVED FILES:"
find "$ROOT/public-archive" -type f -printf '%p\t%k KB\n' | sort

echo
echo "ARCHIVE DISK USAGE:"
du -ah "$ROOT/public-archive" | sort -h

echo
echo "PDF COUNT:"
find "$ROOT/public-archive" -type f -iname '*.pdf' | wc -l

echo
echo "GIT STATUS FOR REFERENCES:"
git status --short references/ 2>/dev/null || true

echo
echo "TIP: rebuild the inventory/hash file with:"
echo "  python3 references/scripts/archive_public_references.py"
echo
echo "Before committing, inspect:"
echo "  git status"
echo "  git diff --cached"
echo "  git ls-files '*.zip'"
