# Submarine Shipmate Hazardous Exposure Research Archive

Historical research and private reconstruction tools for U.S. **submarine and submarine-tender shipmates**.

The repository name recommended for the new public account is:

`submarine-shipmate-hazardous-exposure`

“Hazardous exposure” describes the overall research archive. **Reconstruction** is retained for the private form and research method because the form reconstructs service, compartments/shops, equipment, tasks, materials, routes, controls, incidents, symptoms and record leads.

## Open the private reconstruction form

When GitHub Pages is enabled for the new repository, use:

`https://NEW-ACCOUNT.github.io/submarine-shipmate-hazardous-exposure/forms/Submarine_Shipmate_Private_Reconstruction_Form.html`

The form is for service aboard a **submarine, submarine tender, or both**. USS Guardfish is not referenced in the general form; it remains a separate historical example under `examples/`.

## Public Reference — Information Only

This is a read-only public informational and research resource. Do **not** upload completed questionnaires, medical records, VA claim material, private witness information, contact information or other PII.

A document, material, chemical, symptom, task or equipment item appearing here does **not** by itself establish individual exposure, dose, diagnosis, causation, or VA service connection.

## Research archive

`references/` contains:

- `reference-manifest.csv` — source catalog and original URLs
- `task-to-evidence-matrix.csv` — task/system → candidate material family → best record targets
- `scripts/archive_public_references.py` — helper for attempting preservation downloads
- `ARCHIVE_SCRIPT_INSTRUCTIONS.md` — exact instructions for running and interpreting the script
- `public-archive/` — successfully preserved public/releasable documents
- `catalog-only/` — sources that should be cataloged rather than redistributed

The evidence path should remain:

**platform → ship/tender → shop/compartment → equipment → task/work package/PMS → material/product → exposure route → toxicology/medical evidence**

Candidate material lists are research prompts, not proof of exposure.

## Moving to the new public GitHub account

For the clean public repository, create:

`submarine-shipmate-hazardous-exposure`

Prefer a fresh Git history rather than copying the old `.git/` directory. Review every staged file before the first public push.

Distribution ZIP files are intentionally excluded by `.gitignore` using `*.zip`.
