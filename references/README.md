# Reference Archive

This directory preserves public/releasable historical research material and provenance for the **Submarine Shipmate Hazardous Exposure Research Archive**.

## Normal workflow

```bash
./references/scripts/archive_public_references.sh
python3 references/scripts/archive_public_references.py
```

The shell script acquires files. The Python script verifies the local archive and regenerates `archive-inventory.csv`.

`reference-manifest.csv` is the authoritative list of intended archived files and destination paths. `research-leads.csv` contains candidates for future acquisition and evidence development.

The archive is organized by evidence domain rather than by individual veteran. Candidate material/system references do not establish individual exposure, dose, diagnosis or causation.

See `ARCHIVE_SCRIPT_INSTRUCTIONS.md` before committing new binaries.

## Catalog-only references

Potentially useful documents whose download or redistribution status is not yet confirmed belong in `catalog-only/`, not `public-archive/`.

Use `catalog-only/reference-links.csv` for provenance and link metadata. Catalog-only records do not create a requirement for a local PDF and are intentionally excluded from archive verification.

## MSDS/SDS research

See `MATERIAL_SAFETY_DATA_SHEETS.md`, `materials-msds-candidates.csv`, and `material-sheet-downloads.csv`. The material-sheet acquisition script downloads only rows explicitly marked `CONFIRMED_PUBLIC_DOWNLOAD`; it does not bypass authentication.

## Period public-specification acquisition

- `public-spec-downloads.csv` — exact historical Statement-A document parts selected for controlled acquisition.
- `scripts/archive_public_period_specs.sh` — resolves temporary DLA document links from official revision-history pages and validates PDFs before preservation.

## Expanded MILSPEC / MSDS-SDS research

See `NAVY_MILSPEC_MSDS_RESEARCH_PLAN.md`, `navy-period-material-spec-discovery.csv`, and `industry-msds-sds-discovery.csv` for the controlled discovery register and product-level research leads.
