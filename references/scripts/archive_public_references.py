#!/usr/bin/env python3
"""
Verify the local public reference archive and rebuild archive-inventory.csv.

This program DOES NOT download anything.

Workflow:
  1. ./references/scripts/archive_public_references.sh
  2. python3 references/scripts/archive_public_references.py

Checks:
- manifest archive paths are safe and unique
- expected files exist
- PDF files have a PDF signature
- size, SHA-256, SHA-512, UTC mtime are recorded
- unmanifested files are reported
- duplicate file content is reported
- suspicious/invalid files produce a non-zero exit status
"""
from pathlib import Path, PurePosixPath
import csv, hashlib, datetime, sys, collections

R = Path(__file__).resolve().parents[1]
M = R / "reference-manifest.csv"
A = R / "public-archive"
O = R / "archive-inventory.csv"

def digest(path, algorithm):
    h = hashlib.new(algorithm)
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def is_pdf(path):
    try:
        with path.open("rb") as f:
            return f.read(5).startswith(b"%PDF")
    except OSError:
        return False

if not M.exists():
    print(f"ERROR: manifest not found: {M}", file=sys.stderr)
    sys.exit(2)

manifest = []
seen_paths = {}
problems = []
with M.open(newline="", encoding="utf-8-sig") as f:
    for n, row in enumerate(csv.DictReader(f), start=2):
        sid = (row.get("source_id") or "").strip()
        rel = (row.get("archive_path") or "").strip()
        url = (row.get("source_url") or "").strip()
        if not sid:
            problems.append(f"manifest line {n}: missing source_id")
            continue
        if not rel:
            # Link-only/catalog metadata may intentionally have no archive file.
            continue
        pp = PurePosixPath(rel)
        if pp.is_absolute() or ".." in pp.parts:
            problems.append(f"{sid}: unsafe archive_path: {rel}")
            continue
        # Only public-archive entries represent binaries that must exist locally.
        # catalog-only and other metadata/link records never create missing-file errors.
        if not rel.startswith("public-archive/"):
            continue
        if rel in seen_paths:
            problems.append(f"{sid}: duplicate archive_path also used by {seen_paths[rel]}: {rel}")
        seen_paths[rel] = sid
        manifest.append((sid, rel, url))

rows = []
missing = []
invalid = []
hash_to_paths = collections.defaultdict(list)
expected_abs = set()

for sid, rel, url in manifest:
    p = R / rel
    expected_abs.add(p.resolve())
    if not p.exists():
        missing.append((sid, rel))
        rows.append([sid, rel, "MISSING", "", "", "", "", url, "missing"])
        continue
    if not p.is_file():
        invalid.append((sid, rel, "not a regular file"))
        rows.append([sid, rel, "INVALID", "", "", "", "", url, "not-regular-file"])
        continue

    size = p.stat().st_size
    sha256 = digest(p, "sha256")
    sha512 = digest(p, "sha512")
    hash_to_paths[sha256].append(rel)
    pdf_ok = ""
    status = "verified"

    if p.suffix.lower() == ".pdf":
        pdf_ok = "yes" if is_pdf(p) else "no"
        if pdf_ok == "no":
            invalid.append((sid, rel, "expected PDF signature not found"))
            status = "invalid-pdf"

    mtime = datetime.datetime.fromtimestamp(
        p.stat().st_mtime, datetime.timezone.utc
    ).isoformat()

    rows.append([sid, rel, size, sha256, sha512, pdf_ok, mtime, url, status])

unmanifested = []
if A.exists():
    for p in sorted(A.rglob("*")):
        # README.md and index.html are archive documentation / GitHub Pages
        # navigation, not preserved evidence binaries. Do not require manifest entries.
        if (
            p.is_file()
            and p.name.lower() not in {"readme.md", "index.html"}
            and p.resolve() not in expected_abs
        ):
            unmanifested.append(str(p.relative_to(R)))

duplicates = {h: paths for h, paths in hash_to_paths.items() if len(paths) > 1}

with O.open("w", newline="", encoding="utf-8") as f:
    w = csv.writer(f, lineterminator="\n")
    w.writerow([
        "source_id", "archive_path", "bytes", "sha256", "sha512",
        "pdf_signature_ok", "file_mtime_utc", "source_url", "status"
    ])
    w.writerows(rows)



print("Submarine Shipmate Hazardous Exposure Research Archive")
print("Archive verification / inventory")
print()
print(f"Manifest file records checked: {len(manifest)}")
print(f"Verified local files:         {sum(r[-1] == 'verified' for r in rows)}")
print(f"Missing expected files:       {len(missing)}")
print(f"Invalid/suspicious files:     {len(invalid)}")
print(f"Unmanifested archive files:   {len(unmanifested)}")
print(f"Duplicate-content groups:     {len(duplicates)}")
print(f"Inventory written:            {O}")
print()

if missing:
    print("MISSING:")
    for sid, rel in missing:
        print(f"  {sid}: {rel}")
    print()

if invalid:
    print("INVALID/SUSPICIOUS:")
    for sid, rel, why in invalid:
        print(f"  {sid}: {rel} — {why}")
    print()

if unmanifested:
    print("UNMANIFESTED:")
    for rel in unmanifested:
        print(f"  {rel}")
    print()

if duplicates:
    print("DUPLICATE CONTENT:")
    for h, paths in duplicates.items():
        print(f"  SHA-256 {h}")
        for rel in paths:
            print(f"    {rel}")
    print()

if problems:
    print("MANIFEST PROBLEMS:")
    for x in problems:
        print(f"  {x}")
    print()

bad = bool(invalid or problems)
if bad:
    print("RESULT: FAIL — fix invalid files or manifest problems.")
    sys.exit(1)
elif missing or unmanifested:
    print("RESULT: REVIEW — archive is structurally valid but incomplete or has unmanifested files.")
    sys.exit(0)
else:
    print("RESULT: PASS")
