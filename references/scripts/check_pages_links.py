#!/usr/bin/env python3
from pathlib import Path
import re, sys
from urllib.parse import urlparse, unquote

ROOT=Path(__file__).resolve().parents[2]
import subprocess
subprocess.run([sys.executable, str(ROOT/"references/scripts/generate_public_archive_indexes.py"), "--check"], check=True)
subprocess.run([sys.executable, str(ROOT/"references/scripts/validate_research_csvs.py")], check=True)
BASE="/submarine-shipmate-hazardous-exposure"
HOST="sub-shipmate.github.io"
bad=[]
html_files=[p for p in ROOT.rglob("*.html") if ".git" not in p.parts]
markdown_files=[p for p in ROOT.rglob("*.md") if ".git" not in p.parts]

def check(source, href):
    href=href.strip()
    if not href: return
    if any(x in href for x in ("index.htmlcatalog","index.htmlpublic","index.htmlforms","index.htmlreferences")):
        bad.append((source,href,"malformed concatenated URL")); return
    if href.startswith(("mailto:","data:","javascript:","#")): return
    if href.startswith(("http://","https://")):
        u=urlparse(href)
        if u.netloc==HOST and u.path.startswith(BASE+"/"):
            target=ROOT/unquote(u.path[len(BASE)+1:])
            if not target.exists(): bad.append((source,href,"GitHub Pages target missing locally"))
        return
    clean=unquote(href.split("#",1)[0].split("?",1)[0])
    if href.startswith(BASE+"/"):
        target=ROOT/clean[len(BASE)+1:]
    else:
        target=(source.parent/clean).resolve()
        try: target.relative_to(ROOT.resolve())
        except ValueError:
            bad.append((source,href,"target escapes repository")); return
    if not target.exists(): bad.append((source,href,"target missing locally"))

for p in html_files:
    t=p.read_text(encoding="utf-8",errors="replace")
    for href in re.findall(r'href=["\']([^"\']+)["\']',t,re.I): check(p,href)

for p in markdown_files:
    t=p.read_text(encoding="utf-8",errors="replace")
    for href in re.findall(r'\[[^\]]*\]\(([^)\s]+)(?:\s+["\'][^"\']*["\'])?\)',t): check(p,href)


# Research evidence CSV schema and evidence-scope validation.
import csv

research_csv_specs = {
    ROOT / "references/catalog-only/hazard-health-evidence.csv": {
        "fields": [
            "evidence_id",
            "hazard",
            "cas_number",
            "exposure_route",
            "target_system",
            "effect_or_finding",
            "timeframe",
            "source",
            "source_url",
            "evidence_scope",
            "limitations",
        ],
        "id_prefix": "HHE-",
        "allowed_scopes": {
            "AUTHORITATIVE_HAZARD",
        },
        "forbidden_scopes": {
            "INDIVIDUAL_EXPOSURE_EVIDENCE",
        },
        "required": {
            "evidence_id",
            "hazard",
            "source",
            "source_url",
            "evidence_scope",
            "limitations",
        },
    },
    ROOT / "references/catalog-only/exposure-evidence.csv": {
        "fields": [
            "evidence_id",
            "hazard",
            "cas_number",
            "evidence_type",
            "specimen_or_medium",
            "measurement",
            "evidence_interpretation",
            "temporal_scope",
            "source",
            "source_url",
            "evidence_scope",
            "limitations",
        ],
        "id_prefix": "EXP-",
        "allowed_scopes": {
            "INDIVIDUAL_EXPOSURE_EVIDENCE",
        },
        "forbidden_scopes": {
            "AUTHORITATIVE_HAZARD",
        },
        "required": {
            "evidence_id",
            "hazard",
            "evidence_type",
            "evidence_interpretation",
            "source",
            "source_url",
            "evidence_scope",
            "limitations",
        },
    },
    ROOT / "references/catalog-only/occupational-comparison-evidence.csv": {
        "fields": [
            "evidence_id",
            "hazard",
            "cas_number",
            "workplace_or_process",
            "evidence_type",
            "measurement_or_observation",
            "finding",
            "source",
            "source_url",
            "evidence_scope",
            "limitations",
        ],
        "id_prefix": "OCC-",
        "allowed_scopes": {
            "OCCUPATIONAL_COMPARISON",
        },
        "forbidden_scopes": {
            "AUTHORITATIVE_HAZARD",
            "INDIVIDUAL_EXPOSURE_EVIDENCE",
        },
        "required": {
            "evidence_id",
            "hazard",
            "workplace_or_process",
            "evidence_type",
            "finding",
            "source",
            "source_url",
            "evidence_scope",
            "limitations",
        },
    },
}

schema_problems = []

for cp, spec in research_csv_specs.items():
    if not cp.exists():
        schema_problems.append(
            (cp, "required research evidence CSV is missing")
        )
        continue

    with cp.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)

        if reader.fieldnames != spec["fields"]:
            schema_problems.append(
                (
                    cp,
                    "schema mismatch: "
                    f"expected {spec['fields']!r}, got {reader.fieldnames!r}",
                )
            )
            continue

        seen_evidence_ids = set()

        for line_no, row in enumerate(reader, start=2):
            for field in spec["required"]:
                if not (row.get(field) or "").strip():
                    schema_problems.append(
                        (cp, f"line {line_no}: required field {field!r} is empty")
                    )

            evidence_id = (row.get("evidence_id") or "").strip()

            if evidence_id:
                if not evidence_id.startswith(spec["id_prefix"]):
                    schema_problems.append(
                        (
                            cp,
                            f"line {line_no}: evidence_id {evidence_id!r} "
                            f"must start with {spec['id_prefix']!r}",
                        )
                    )

                if evidence_id in seen_evidence_ids:
                    schema_problems.append(
                        (
                            cp,
                            f"line {line_no}: duplicate evidence_id "
                            f"{evidence_id!r}",
                        )
                    )

                seen_evidence_ids.add(evidence_id)

            scope = (row.get("evidence_scope") or "").strip()

            if scope in spec["forbidden_scopes"]:
                schema_problems.append(
                    (
                        cp,
                        f"line {line_no}: forbidden evidence_scope {scope!r}",
                    )
                )
            elif scope not in spec["allowed_scopes"]:
                schema_problems.append(
                    (
                        cp,
                        f"line {line_no}: unknown evidence_scope {scope!r}; "
                        f"allowed: {sorted(spec['allowed_scopes'])!r}",
                    )
                )

if schema_problems:
    print("Research evidence CSV schema/scope check: FAIL")
    for cp, why in schema_problems:
        print(f"  {cp.relative_to(ROOT)} -> {why}")
    sys.exit(1)

print(
    "Research evidence CSV schema/scope check: PASS "
    f"({len(research_csv_specs)} evidence datasets)"
)


# Canonical hazard registry validation.
hazards_csv = ROOT / "references/catalog-only/hazards.csv"
hazard_registry_problems = []
hazard_ids = set()
hazard_names = set()

expected_hazard_fields = [
    "hazard_id",
    "hazard",
    "cas_number",
    "entity_type",
    "notes",
]

if not hazards_csv.exists():
    hazard_registry_problems.append(
        (hazards_csv, "missing canonical hazard registry")
    )
else:
    with hazards_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        if reader.fieldnames != expected_hazard_fields:
            hazard_registry_problems.append(
                (
                    hazards_csv,
                    "unexpected fields: "
                    f"{reader.fieldnames!r}; "
                    f"expected {expected_hazard_fields!r}",
                )
            )
        else:
            for line_no, row in enumerate(reader, start=2):
                hazard_id = (row.get("hazard_id") or "").strip()
                hazard = (row.get("hazard") or "").strip()
                entity_type = (row.get("entity_type") or "").strip()
                notes = (row.get("notes") or "").strip()

                for field, value in (
                    ("hazard_id", hazard_id),
                    ("hazard", hazard),
                    ("entity_type", entity_type),
                    ("notes", notes),
                ):
                    if not value:
                        hazard_registry_problems.append(
                            (
                                hazards_csv,
                                f"line {line_no}: required field "
                                f"{field!r} is empty",
                            )
                        )

                if hazard_id and not hazard_id.startswith("HAZ-"):
                    hazard_registry_problems.append(
                        (
                            hazards_csv,
                            f"line {line_no}: hazard_id "
                            f"{hazard_id!r} must start with 'HAZ-'",
                        )
                    )

                if hazard_id in hazard_ids:
                    hazard_registry_problems.append(
                        (
                            hazards_csv,
                            f"line {line_no}: duplicate hazard_id "
                            f"{hazard_id!r}",
                        )
                    )

                if hazard in hazard_names:
                    hazard_registry_problems.append(
                        (
                            hazards_csv,
                            f"line {line_no}: duplicate hazard name "
                            f"{hazard!r}",
                        )
                    )

                if hazard_id:
                    hazard_ids.add(hazard_id)

                if hazard:
                    hazard_names.add(hazard)

if hazard_registry_problems:
    print("Canonical hazard registry check: FAIL")
    for cp, msg in hazard_registry_problems:
        print(f"  {cp.relative_to(ROOT)} -> {msg}")
    raise SystemExit(1)

print(
    "Canonical hazard registry check: PASS "
    f"({len(hazard_ids)} hazards)"
)

# Evidence-to-hazard referential integrity validation.
hazard_reference_problems = []

hazards_by_name = {}
if hazards_csv.exists():
    with hazards_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            hazard = (row.get("hazard") or "").strip()
            if hazard:
                hazards_by_name[hazard] = {
                    "hazard_id": (row.get("hazard_id") or "").strip(),
                    "cas_number": (row.get("cas_number") or "").strip(),
                }

for evidence_csv in research_csv_specs:
    if not evidence_csv.exists():
        continue

    with evidence_csv.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)

        for line_no, row in enumerate(reader, start=2):
            evidence_id = (row.get("evidence_id") or "").strip()
            hazard = (row.get("hazard") or "").strip()
            cas_number = (row.get("cas_number") or "").strip()

            canonical = hazards_by_name.get(hazard)

            if canonical is None:
                hazard_reference_problems.append(
                    (
                        evidence_csv,
                        f"line {line_no}: evidence_id "
                        f"{evidence_id!r} references unregistered "
                        f"hazard {hazard!r}",
                    )
                )
                continue

            canonical_cas = canonical["cas_number"]

            if cas_number != canonical_cas:
                hazard_reference_problems.append(
                    (
                        evidence_csv,
                        f"line {line_no}: evidence_id "
                        f"{evidence_id!r} CAS {cas_number!r} "
                        f"does not match canonical hazard "
                        f"{canonical['hazard_id']!r} CAS "
                        f"{canonical_cas!r}",
                    )
                )

if hazard_reference_problems:
    print("Evidence-to-hazard reference check: FAIL")
    for cp, msg in hazard_reference_problems:
        print(f"  {cp.relative_to(ROOT)} -> {msg}")
    raise SystemExit(1)

print(
    "Evidence-to-hazard reference check: PASS "
    f"({len(hazards_by_name)} canonical hazards)"
)

# CSV URL validation for public research catalogs.
csv_files = sorted((ROOT / "references").rglob("*.csv"))
csv_urls_checked = 0
for cp in csv_files:
    if not cp.exists():
        continue
    with cp.open(newline="", encoding="utf-8-sig") as fh:
        for row in csv.DictReader(fh):
            for key, value in row.items():
                if not value or "url" not in (key or "").lower():
                    continue
                value=value.strip()
                if not value:
                    continue
                csv_urls_checked += 1
                u=urlparse(value)
                if u.scheme not in ("http","https") or not u.netloc:
                    bad.append((cp, value, f"invalid URL in CSV column {key}"))
                elif u.netloc == HOST and u.path.startswith(BASE + "/"):
                    target=ROOT/unquote(u.path[len(BASE)+1:])
                    if not target.exists():
                        bad.append((cp, value, f"CSV GitHub Pages target missing locally ({key})"))

if bad:
    print("Pages/Markdown link check: FAIL")
    for p,href,why in bad: print(f"  {p.relative_to(ROOT)} -> {href} [{why}]")
    print(f"\nProblems found: {len(bad)}")
    sys.exit(1)
print(f"Pages/Markdown/CSV link check: PASS ({len(html_files)} HTML files, {len(markdown_files)} Markdown files, {csv_urls_checked} CSV URLs checked)")
