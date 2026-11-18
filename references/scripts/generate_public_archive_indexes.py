#!/usr/bin/env python3
from pathlib import Path
import csv, html, sys
ROOT=Path(__file__).resolve().parents[2]
REFS=ROOT/"references"; MANIFEST=REFS/"reference-manifest.csv"; ARCH=REFS/"public-archive"
BASE="/submarine-shipmate-hazardous-exposure"
CATS=[
("occupational-health","Occupational Health"),("ship-repair","Ship Repair & Naval Shipyards"),
("asbestos-insulation-packing","Asbestos / Insulation / Packing"),("fuels-lubricants-hydraulics","Fuels / Lubricants / Hydraulics"),
("industrial-hygiene","Industrial Hygiene"),("maintenance-pms","Maintenance / PMS"),
("materials-specifications","Materials & Specifications"),("refrigerants","Refrigerants"),
("submarine-atmosphere","Submarine Atmosphere"),("submarine-systems","Submarine Systems"),
("tender-ship-repair","Tender / Ship Repair")]
STYLE='body{font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;max-width:1100px;margin:0 auto;padding:24px;line-height:1.55}header{border-bottom:1px solid #8885;margin-bottom:24px;padding-bottom:16px}nav a{margin-right:18px}.card{border:1px solid #8886;border-radius:10px;padding:18px;margin:16px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:14px}a{overflow-wrap:anywhere}small,.muted{opacity:.75}.warning{border-left:5px solid #888;padding-left:14px}ul{padding-left:24px}'
ANALYTICS='''<!-- Cloudflare Web Analytics --><script type="module" src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon='{"token": "7646b5697782467286d83a3a2e828ade"}'></script><!-- End Cloudflare Web Analytics -->'''
def nav():
    return f'<nav><a href="{BASE}/index.html">Home</a><a href="{BASE}/forms/Submarine_Shipmate_Private_Reconstruction_Form.html">Private Reconstruction Form</a><a href="{BASE}/references/index.html">Research Library</a><a href="{BASE}/references/public-archive/index.html">Public Archive</a><a href="{BASE}/references/catalog-only/index.html">Catalog-Only</a></nav>'
def shell(title,body):
    return f'<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title><style>{STYLE}</style></head><body><header><h1>{html.escape(title)}</h1>{nav()}</header>{body}<footer><hr><p class="muted"><strong>Public Reference — Information Only.</strong> Inclusion does not by itself establish individual exposure, dose, diagnosis, causation, or VA service connection.</p></footer>{ANALYTICS}</body></html>'
with MANIFEST.open(newline="",encoding="utf-8-sig") as f: rows=list(csv.DictReader(f))
files=[r for r in rows if (r.get("archive_path") or "").strip()]
by={k:[] for k,_ in CATS}
for r in files:
    p=Path(r["archive_path"])
    if len(p.parts)>=3 and p.parts[0]=="public-archive" and p.parts[1] in by: by[p.parts[1]].append(r)
for k in by: by[k].sort(key=lambda r:((r.get("date") or ""),(r.get("title") or "").lower(),r["archive_path"]))
cards=[]
for k,label in CATS:
    n=len(by[k]); status=f"{n} preserved PDF"+("" if n==1 else "s") if n else "Research in progress"
    cards.append(f'<div class="card"><h3><a href="{BASE}/references/public-archive/{k}/index.html">{html.escape(label)}</a></h3><p>{status}</p></div>')
body=f'<p>This library provides direct access to <strong>{len(files)} preserved PDFs</strong>, grouped by research category.</p><p class="warning"><strong>Evidence limitation:</strong> inclusion does not establish that a material was aboard a particular submarine or tender or that any individual encountered it.</p><div class="grid">'+"".join(cards)+"</div>"
outputs={ARCH/"index.html":shell("Public Research Archive",body)}
for k,label in CATS:
    items=[]
    for r in by[k]:
        fn=Path(r["archive_path"]).name; title=r.get("title") or fn
        date=r.get("date") or ""; org=r.get("organization") or ""; use=r.get("research_use") or ""
        meta=" — ".join(x for x in (date,org) if x)
        detail=(f"<br><small>{html.escape(meta)}</small>" if meta else "")+(f"<br><small>{html.escape(use)}</small>" if use else "")
        items.append(f'<li><a href="{html.escape(fn)}">{html.escape(title)}</a>{detail}</li>')
    if items:
        content=f'<p><strong>{len(items)} preserved PDF'+("" if len(items)==1 else "s")+'.</strong></p><ul>'+"".join(items)+"</ul>"
    else:
        content="<p>Research in progress. No preserved PDFs are currently assigned to this category in the manifest.</p>"
    content+='<p class="warning"><strong>Evidence limitation:</strong> a document in this category is research evidence only; it does not by itself establish ship-specific use or individual exposure.</p>'
    outputs[ARCH/k/"index.html"]=shell(label,content)

# Keep top-level Research Library and Catalog landing pages synchronized too.
research_body = (
    '<p>The research library separates documents selected for public preservation from catalog and discovery references that remain link-only or under review.</p>'
    '<div class="grid">'
    f'<div class="card"><h2><a href="{BASE}/references/public-archive/index.html">Public Research Archive</a></h2><p>Browse the <strong>{len(files)} preserved PDFs</strong>, grouped by research category.</p></div>'
    f'<div class="card"><h2><a href="{BASE}/references/catalog-only/index.html">Catalog-Only References</a></h2><p>Browse public-source leads, controlled/restricted link-only records, Navy specification discovery, and material/MSDS research registers.</p></div>'
    f'<div class="card"><h2><a href="{BASE}/forms/Submarine_Shipmate_Private_Reconstruction_Form.html">Shipmate Private Reconstruction Form</a></h2><p>The form operates locally in the browser and is not a public submission mechanism.</p></div>'
    '</div><h2>Research data and methodology</h2><ul>'
    f'<li><a href="{BASE}/references/reference-manifest.csv">Reference manifest</a></li>'
    f'<li><a href="{BASE}/references/archive-inventory.csv">Archive inventory and checksums</a></li>'
    f'<li><a href="{BASE}/references/task-to-evidence-matrix.csv">Task-to-evidence matrix</a></li>'
    f'<li><a href="{BASE}/references/research-leads.csv">Research leads</a></li>'
    f'<li><a href="{BASE}/references/README.md">Reference archive documentation</a></li></ul>'
)
outputs[REFS/"index.html"] = shell("Research Library", research_body)

def csv_count(path):
    with path.open(newline="", encoding="utf-8-sig") as f:
        return sum(1 for _ in csv.DictReader(f))

registers = [
    ("General catalog", REFS/"catalog-only/reference-links.csv", "catalog-only/reference-links.csv", "Public source/reference leads not automatically mirrored."),
    ("Chemical evidence chains", REFS/"catalog-only/chemical-evidence-chain.csv", "catalog-only/chemical-evidence-chain.csv", "Hazard/material-to-submarine evidence chains with explicit limitations; system or material evidence is not proof of individual exposure or causation."),
    ("Hazard / health evidence", REFS/"catalog-only/hazard-health-evidence.csv", "catalog-only/hazard-health-evidence.csv", "Authoritative hazard-to-health-effect research used for research leads; symptom or finding matches are not proof of exposure, diagnosis, or causation."),
    ("Individual exposure evidence", REFS/"catalog-only/exposure-evidence.csv", "catalog-only/exposure-evidence.csv", "Biomarkers and other evidence capable of supporting individual exposure assessment; exposure evidence does not by itself establish the source, historical setting, diagnosis, or causation."),
    ("Controlled / restricted document links", REFS/"catalog-only/controlled-restricted-document-links.csv", "catalog-only/controlled-restricted-document-links.csv", "Distribution-C, export-controlled, or otherwise restricted documents: metadata/link only; PDFs are not mirrored."),
    ("Navy period material/spec discovery", REFS/"navy-period-material-spec-discovery.csv", "navy-period-material-spec-discovery.csv", "Period specification and standard discovery queue, including revision/distribution research."),
    ("Industry MSDS/SDS discovery", REFS/"industry-msds-sds-discovery.csv", "industry-msds-sds-discovery.csv", "Manufacturer/product/MSDS/SDS identity and period-lineage research."),
    ("Material/MSDS candidates", REFS/"materials-msds-candidates.csv", "materials-msds-candidates.csv", "Candidate material/product safety-sheet research; candidate status is not exposure proof."),
    ("Material sheet downloads", REFS/"material-sheet-downloads.csv", "material-sheet-downloads.csv", "Safety-sheet acquisition/download tracking."),
    ("Research leads", REFS/"research-leads.csv", "research-leads.csv", "Additional evidence and document leads.")
]
cards=[]
for label,path,href,note in registers:
    cards.append(f'<div class="card"><h3><a href="{BASE}/references/{href}">{html.escape(label)}</a></h3><p><strong>{csv_count(path)} records</strong></p><p>{html.escape(note)}</p></div>')
catalog_body = (
    '<p class="warning"><strong>Catalog-only policy.</strong> These are research leads, metadata registers, and public source links. A public link does not by itself authorize republication. Restricted/export-controlled PDFs are not mirrored.</p>'
    f'<p>The original general catalog contains <strong>{csv_count(REFS/"catalog-only/reference-links.csv")} records</strong>. The registers below are intentionally separate because they track different evidence and distribution states.</p>'
    '<div class="grid">' + "".join(cards) + '</div>'
    '<h2>How to read these registers</h2><p>Specification, product, NSN, MSDS/SDS, and shipboard-maintenance evidence are kept as separate links in the evidence chain. None of these records alone establishes that a product was aboard a particular submarine or tender or that an individual encountered it.</p>'
)
outputs[REFS/"catalog-only/index.html"] = shell("Catalog-Only / Research Registers", catalog_body)

check="--check" in sys.argv
bad=[]
for p,text in outputs.items():
    if check:
        if not p.exists() or p.read_text(encoding="utf-8")!=text: bad.append(p)
    else:
        p.parent.mkdir(parents=True,exist_ok=True); p.write_text(text,encoding="utf-8")
if check and bad:
    print("Public archive index sync: FAIL")
    for p in bad: print("  stale/missing:",p.relative_to(ROOT))
    print("Run: python3 references/scripts/generate_public_archive_indexes.py")
    raise SystemExit(1)
print(f'Public archive index sync: PASS ({len(files)} manifest PDFs, {len(CATS)} categories)' if check else f'Generated public archive indexes from manifest: {len(files)} PDFs, {len(CATS)} categories')
