# Public Reference Archive Workflow

The acquisition and verification jobs are intentionally separate.

## Step 1 — acquire public documents

From the repository root:

```bash
./references/scripts/archive_public_references.sh
```

The Bash downloader reads `reference-manifest.csv`, places files at the manifest's `archive_path`, validates expected PDFs before accepting them, and prints the exact destination, file details, hash and directory listing.

## Step 2 — verify and rebuild inventory

Run:

```bash
python3 references/scripts/archive_public_references.py
```

The Python program **does not download anything**. It:

- validates manifest paths;
- checks expected local files;
- validates PDF signatures;
- records byte size, SHA-256 and SHA-512;
- reports missing files;
- reports unmanifested files;
- reports duplicate file content;
- regenerates `references/archive-inventory.csv`.

A `PASS` means every manifested archive file exists and passes structural checks. `REVIEW` means files are missing or unmanifested but no invalid file/manifest defect was found. `FAIL` means an invalid file or manifest defect was found.

## Step 3 — inspect before Git commit

```bash
git status
git add references README.md index.html docs forms sources examples
git status
git diff --cached --stat
git ls-files '*.zip'
```

`git ls-files '*.zip'` should produce no output.

Then, only after reviewing the staged files:

```bash
git commit -m "Add historical hazardous exposure research archive"
git push
```

## Public-distribution rule

Do not commit classified, CUI, NOFORN, export-controlled, Distribution Statement B–F, or otherwise restricted technical material. A document being discoverable online does not by itself establish redistribution authority. Prefer Distribution Statement A/public-domain/government-publication material and retain source/provenance metadata.

## Research leads

`research-leads.csv` contains promising documents that are not yet necessarily archived. A research lead is not proof that a material was aboard a specific submarine/tender or that a particular sailor was exposed.

## Catalog-only / unverified documents

If a potentially useful document has uncertain download, access, or redistribution status, do not add its binary file to `public-archive/`.

Record it in:

```text
references/catalog-only/reference-links.csv
```

and consult:

```text
references/catalog-only/README.md
```

The verifier only requires local binaries for manifest paths beginning with `public-archive/`. README documentation files inside archive category directories are ignored when checking for unmanifested evidence files.

## GitHub Pages files inside the archive

`README.md` and `index.html` files under `references/public-archive/` are documentation/navigation files, not preserved source documents. The verifier intentionally excludes them from the unmanifested-evidence check. PDFs and other evidence binaries remain subject to manifest verification.

## GitHub Pages link verification

After changing site navigation, run:

```bash
python3 references/scripts/check_pages_links.py
```

The checker validates root-relative internal Pages targets and rejects known malformed concatenated URLs.
