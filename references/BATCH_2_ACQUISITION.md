# Period Specification Acquisition — Batch 2

**Public Reference — Information Only**

`public-spec-downloads.csv` now contains the original verified acquisition set plus the second controlled period-specification batch.

The existing `scripts/archive_public_period_specs.sh` is intentionally reused. It:
- retrieves the official QuickSearch record page,
- selects the requested revision row,
- requires Distribution Statement A on that row,
- follows only the expected QuickSearch document-generation path,
- accepts the result only when it begins with `%PDF`,
- and never stores the transient/session URL as a permanent source.

New high-value targets include 2190 TEP, MIL-PRF-17672 hydraulic fluid, CFC-113 cleaning solvent, silicone compound, high-temperature antiseize, submarine camouflage paint, NAVSEA welding consumables, an epoxy-polyamide coating formulation, and epoxy metal-repair/hull-smoothing cement.

After acquisition, do not commit immediately. Run the archive verifier first; the manifest/index integration must be updated for every successfully acquired PDF.
