# CSV-driven public archive indexes

`reference-manifest.csv` is the single source of truth for preserved-PDF category counts and public PDF listings.

Regenerate after manifest changes:

```bash
python3 references/scripts/generate_public_archive_indexes.py
```

Verify synchronization:

```bash
python3 references/scripts/generate_public_archive_indexes.py --check
python3 references/scripts/check_pages_links.py
```

`check_pages_links.py` now fails when generated public-archive HTML is stale relative to the manifest and validates URL fields across all research CSV files.
