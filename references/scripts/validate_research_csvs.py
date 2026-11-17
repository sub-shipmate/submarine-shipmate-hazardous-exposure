#!/usr/bin/env python3
from pathlib import Path
import csv, re, sys
ROOT=Path(__file__).resolve().parents[2]
url_cols={"url","source_url","record_url","document_url","public_record_or_pdf_url","public_research_url"}
bad=[]
for p in sorted((ROOT/"references").rglob("*.csv")):
    with p.open(newline="",encoding="utf-8-sig") as f:
        rd=csv.DictReader(f)
        if not rd.fieldnames:
            bad.append((p,"missing header")); continue
        for n,row in enumerate(rd,2):
            if None in row:
                bad.append((p,f"line {n}: extra positional fields"))
            for k,v in row.items():
                if k and (k.lower() in url_cols or k.lower().endswith("_url")) and (v or "").strip():
                    v=v.strip()
                    if not re.match(r"^https?://",v):
                        bad.append((p,f"line {n}: {k} is not an http(s) URL: {v[:90]}"))
if bad:
    print("Research CSV schema/URL guard: FAIL")
    for p,msg in bad: print(" ",p.relative_to(ROOT),"->",msg)
    raise SystemExit(1)
print("Research CSV schema/URL guard: PASS")
