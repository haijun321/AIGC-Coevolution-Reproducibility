#!/usr/bin/env python3
"""Independent checks of released numerical CSVs; does not execute MATLAB."""
import csv
import hashlib
import math
from pathlib import Path
import re
import statistics
import sys

ROOT = Path(__file__).resolve().parents[1]
EXP = ROOT / 'results/exp05_independent_aigc_prcc'
issues = []

# Public-release metadata and hygiene.
required_release_files = (
    'README.md', 'LICENSE', 'CITATION.cff', 'MATLAB_ENVIRONMENT.md',
    'RELEASE_NOTES.md', 'RESULTS_INDEX.md', 'EXP05_VALIDATION.md',
    'run_manifest.csv', 'SHA256SUMS.txt'
)
for rel in required_release_files:
    check_path = ROOT / rel
    if not check_path.is_file():
        issues.append(f'Missing required release file: {rel}')

for rel in ('MANUSCRIPT_RECONCILIATION.md','DATA_CODE_AVAILABILITY_DRAFT.md','LICENSE_STATUS.md'):
    if (ROOT / rel).exists():
        issues.append(f'Internal/pre-publication file should not be released: {rel}')

for doc in ROOT.glob('*.md'):
    txt = doc.read_text(encoding='utf-8-sig')
    if re.search(r'\[actual (?:repository|tag|doi)|PLACEHOLDER|TO BE COMPLETED', txt, re.I):
        issues.append(f'Unresolved public-release placeholder: {doc.name}')

fig2_audits = list((ROOT/'results/Exp01_representative_regimes/publication_figures').glob('Figure2_Exp01_extraction_audit*.csv'))
if len(fig2_audits) != 1:
    issues.append(f'Expected one canonical Figure 2 extraction audit, found {len(fig2_audits)}')

def check(condition, message):
    if not condition:
        issues.append(message)

def rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))

def num(row, col):
    return float(row[col])

def near(x, y, atol=1e-12):
    return math.isfinite(x) and math.isfinite(y) and abs(x-y) <= atol

for f in ROOT.rglob('*.m'):
    content = f.read_text(encoding='utf-8-sig')
    legacy=('HSS'+'C', 'HSIS'+'SA')
    check(not any(token in content for token in legacy) and not re.search('[A-Z]:\\\\(?:Users|Students)', content), f'Legacy text/path: {f.relative_to(ROOT)}')
    m = re.search(r'^function\s+(?:\[[^]]+\]\s*=\s*|\w+\s*=\s*)?(\w+)\s*\(', content, re.M)
    if m:
        check(m.group(1)==f.stem, f'MATLAB function/file mismatch: {f.relative_to(ROOT)}: {m.group(1)}')

for plane in ('rhoE_s','psiE_FP'):
    plane_rows=rows(ROOT/f'results/exp04_adaptation_risk/exp04_plane_{plane}.csv')
    check(len(plane_rows)==961, f'Exp04 {plane} count')
    for k,r in enumerate(plane_rows,1):
        for label in ('I','T'):
            check(near(num(r,f'NetDelta{label}'),num(r,f'CapacityDelta{label}')+num(r,f'AdaptationDelta{label}'),1e-10), f'Exp04 {plane} {k}: {label} decomposition')

combined=rows(EXP/'exp05_p1_raw_all_independent_designs.csv')
check(len(combined)==5600, 'Exp05 FULL total must be 5600')
by_key={}
for r in combined:
    key=(int(r['DesignN']), int(r['DesignRep']), int(r['Sample']))
    check(key not in by_key, f'Duplicate combined row {key}')
    by_key[key]=r
    for label in ('I','T'):
        check(near(num(r,f'Delta{label}_net'),num(r,f'Delta{label}_capacity')+num(r,f'Delta{label}_adapt')), f'Exp05 decomposition {key} {label}')
    check(abs(num(r,'CapacityMatchError'))<=1e-10, f'Capacity matching {key}')
    check(near(num(r,'E_FixedEffective'),num(r,'MatchedE'),1e-10), f'Effective E matching {key}')

for n in (160,320,640):
    for rep in range(1,6):
        design=rows(EXP/f'exp05_p1_raw_N{n}_rep{rep:02}.csv')
        check(len(design)==n, f'Exp05 N{n} rep{rep:02} count')
        for r in design:
            key=(n,rep,int(r['Sample']))
            check(key in by_key and r==by_key[key], f'Combined/raw disagreement {key}')

primary=rows(EXP/'exp05_p1_raw_N640_rep01.csv')
same=[r for r in primary if r['SameRegimeThree'].strip().lower() in ('1','true')]
check(len(same)==638, f'Primary same-regime N={len(same)}')
check(any(abs(num(r,'I_Fixed')-num(r,'I_No'))>1e-8 for r in primary), 'Fixed branch duplicates no-AIGC')
ratio=[abs(num(r,'DeltaI_adapt')/num(r,'DeltaI_net')) for r in same if abs(num(r,'DeltaI_net'))>1e-10]
check(near(statistics.median(ratio),2.12259527155812e-9,1e-12), 'Primary adaptation/net median')

quality=rows(EXP/'experiment_quality_check.csv')
check(len(quality)==10 and all(int(float(r['Pass']))==1 for r in quality),'Exp05 10 quality gates')
boot=rows(EXP/'exp05_p1_primary_effect_prcc_bootstrap.csv')
check(len(boot)==480,'Exp05 480 bootstrap rows')
check(len({(r['Response'],r['Subset'],r['Parameter']) for r in boot})==480,'Exp05 bootstrap unique keys')
for response in ('DeltaI_capacity','DeltaT_capacity','DeltaI_adapt','DeltaT_adapt','DeltaI_net','DeltaT_net','I_Dynamic','T_Dynamic'):
    check(sum(r['Response']==response for r in boot)==60, f'Bootstrap missing {response}')

fig=EXP/'Figure5_FINAL_REPAIRED_V1'
for panel_name,response,subset in (('Figure5_panelA_PRCC.csv','I_Dynamic','AllFinite'),('Figure5_panelB_PRCC.csv','DeltaI_net','SameRegimeThree')):
    panel=rows(fig/panel_name)
    reference=sorted((r for r in boot if r['Response']==response and r['Subset']==subset), key=lambda r: -abs(float(r['PRCC'])))[:8]
    check(len(panel)==8 and panel==reference, f'Figure5 {panel_name} disagrees with primary bootstrap')

panel_c=rows(fig/'Figure5_panelC_effect_decomposition.csv')
check(len(panel_c)==638,'Figure5 panel C count')
for source,target in zip(same,panel_c):
    check(all(source[k]==target[k] for k in target),'Figure5 panel C differs from primary rows')

prob=rows(EXP/'exp05_p1_primary_effect_probabilities.csv')
panel_d=rows(fig/'Figure5_panelD_probabilities.csv')
reference=[r for r in prob if r['Subset']=='SameRegimeThree' and near(float(r['Threshold']),1e-3,1e-14) and r['Response'] in ('DeltaI_net','DeltaT_net','DeltaI_adapt','DeltaT_adapt')]
check(len(panel_d)==4 and panel_d==reference,'Figure5 panel D disagrees with probabilities')
summary=rows(fig/'Figure5_SR_FINAL_REPAIRED_V1_summary.csv')
check(len(summary)==1 and int(summary[0]['FullRows'])==5600 and int(summary[0]['PrimarySameRegimeN'])==638,'Figure5 summary counts')
if summary:
    check(near(float(summary[0]['MedianAbsAdaptToNet']),statistics.median(ratio),1e-12),'Figure5 summary median')
    check(near(float(summary[0]['RiskAdverseDirection']),float(panel_d[0]['AdverseDirection'])),'Figure5 risk frequency')

hashed = set()
for line in (ROOT/'SHA256SUMS.txt').read_text().splitlines():
    if not line.strip():
        continue
    digest, rel=line.split('  ',1)
    hashed.add(rel)
    target=ROOT/rel
    check(target.is_file() and hashlib.sha256(target.read_bytes()).hexdigest()==digest, f'Hash mismatch {rel}')
release_files = {str(p.relative_to(ROOT)).replace('\\','/') for p in ROOT.rglob('*') if p.is_file() and p.name != 'SHA256SUMS.txt'}
check(hashed == release_files, f'SHA256 coverage mismatch: manifest={len(hashed)} release={len(release_files)}')

print(f'Exp05: {len(combined)} rows; {len(same)}/640 same-regime; {len(boot)} bootstrap rows; {len(quality)} quality checks')
print(f'Median |adapt/net|: {statistics.median(ratio):.14g}')
print('Static/data validation:', 'PASS' if not issues else f'FAIL ({len(issues)} issues)')
for issue in issues[:40]:print('-',issue)
sys.exit(bool(issues))
