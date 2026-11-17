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

## Public-site link verification

Run `python3 references/scripts/check_pages_links.py`. The checker validates internal links in both HTML and Markdown, including `README.md`, and rejects malformed concatenated Pages paths.

## Statement-A historical specification acquisition

`public-spec-downloads.csv` lists exact period document parts whose official DLA QuickSearch revision tables were reviewed as Distribution Statement A.

Run:

```bash
references/scripts/archive_public_period_specs.sh
```

The script:
- retrieves the official QuickSearch document-detail page;
- finds the exact requested revision row;
- requires that row to contain Distribution Statement A;
- resolves the temporary PDF link at run time;
- downloads to `.part`;
- requires a `%PDF` signature;
- moves the validated file into `references/public-archive/`;
- prints SHA-256 and SHA-512.

Transient DLA PDF URLs are deliberately not stored in the catalog because they can expire. A public landing page alone is not enough: controlled/locked or non-A material remains catalog-only.

## v19 QuickSearch resolver correction

v18 incorrectly assumed the document image was an ordinary PDF hyperlink.
v19 parses the exact revision-history row, requires Distribution Statement A,
identifies the ASP.NET document-image control, submits that control with the
page's hidden form state and cookies, and then accepts either a direct PDF
response or a generated document target. No file is moved into the archive
unless the final response begins with `%PDF`.

The script prints `MATCHED ROW`, `VERIFIED`, `DOCUMENT CONTROL`, and response
headers so future QuickSearch layout changes are diagnosable.

## v20 QuickSearch postback correction

v19 proved that all selected historical revision rows could be matched and that
their Distribution Statement A markings were visible, but it incorrectly
treated the Document Image action as a literal URL. v20 distinguishes:
1. ASP.NET `__doPostBack` actions;
2. named image/submit form controls; and
3. genuine HTTP(S) PDF/Transient links.

JavaScript actions and icon GIFs are never passed to curl. ASP.NET hidden state
and cookies from the official record page are retained for the document-image
request. Final archive acceptance still requires a `%PDF` signature.

## v21 QuickSearch diagnostic

The v20 run proved exact revision matching and Statement-A verification but
showed that the Document Image action is not represented as a usable action
inside the revision `<tr>`. Before changing the downloader again, run:

```bash
references/scripts/diagnose_quicksearch_document_action.sh \
  'https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=48543' \
  'Revision A' \
  quicksearch-diagnostic.txt
```

This diagnostic fetches only the public document-detail HTML. It does not
download or archive a PDF. It records the matched row, raw nearby markup,
`pdf.gif`/Document Image occurrences, JavaScript/event tokens, and ASP.NET form
state names. Review that output before changing the acquisition mechanism.

## v22 verified QuickSearch ImageRedirector acquisition

The v21 diagnostic established the actual QuickSearch mechanism. Each
downloadable revision row contains a JavaScript call of the form:

`spawnPDFWindow('./ImageRedirector.aspx?token=<component>.<document>', ...)`

v22 therefore no longer guesses at ASP.NET postbacks or ordinary PDF links.
It:
1. fetches the official public document-detail page;
2. matches the exact requested revision;
3. requires Distribution Statement A on that same row;
4. extracts only a relative `./ImageRedirector.aspx?token=...` action;
5. requests that endpoint on `https://quicksearch.dla.mil/` with the same
   cookies and record-page Referer;
6. follows normal HTTP redirects;
7. accepts the result only when the final file begins with `%PDF`;
8. prints SHA-256 and SHA-512 after preservation.

Unexpected hosts, schemes, paths, non-A rows and non-PDF results are rejected.

## v23 ImageRedirector response diagnostic

v22 verified extraction of the correct `ImageRedirector.aspx?token=...` for all
six selected Statement-A revision rows. The endpoint returned a small HTML page
rather than an HTTP redirect or PDF. Run the diagnostic below before changing
the downloader again:

```bash
references/scripts/diagnose_quicksearch_redirector.sh \
  'https://quicksearch.dla.mil/qsDocDetails.aspx?ident_number=48543' \
  'Revision A' \
  quicksearch-redirector-diagnostic.txt
cat quicksearch-redirector-diagnostic.txt
```

It records response headers, the small intermediate HTML (with long hidden
values redacted), URL-bearing attributes, and script/navigation candidates.
It does not add anything to `public-archive/`.

## v24 verified WMX document-preparation hop

The v23 diagnostic established that `ImageRedirector.aspx` returns an HTML
intermediary whose onload script clicks a link of the form:

`../../WMX/Default.aspx?token=<component-id>`

For P-D-680 Revision A, the verified component ID is `174765`, derived from
the exact Statement-A row's `174765.48543` token.

v24 follows that explicitly observed WMX action. It requires the WMX token to
equal the component portion of the exact revision-row token. If WMX returns a
PDF directly, it is preserved. If WMX returns HTML, v24 follows only an
explicit QuickSearch-hosted PDF, `/Transient/`, or download target. The final
file must begin with `%PDF` before it is moved into `public-archive/`.

## v25 integration after successful six-document acquisition

The six successfully acquired Statement-A period specifications are now
permanent `reference-manifest.csv` records. Category and archive landing
indexes expose them as preserved PDFs. The obsolete optional-acquisition
verifier block was removed; the normal manifest is now the single source of
truth for required preserved binaries.

After overlaying v25 onto the working repository that already contains the six
PDFs, run:

```bash
references/scripts/check_reference_archive.sh
python3 references/scripts/check_pages_links.py
```

Expected preserved-file count: 29 (23 prior + 6 new). Do not commit until both
checks pass.
