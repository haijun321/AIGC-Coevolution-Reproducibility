# Exp05-P1 and Figure 5 validation

## Frozen workflow

`RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX.m` is the v1.0.0 primary Exp05-P1 runner. It implements independent LHS designs, the three AIGC branches (no AIGC, capacity-matched fixed AIGC, and dynamic AIGC), PRCC analyses for state levels and paired effects, and bootstrap confidence intervals for the primary design.

`BUILD_SR_FIGURE5_FINAL_REPAIRED_V1.m` reads the validated FULL tables and exports the Figure 5 panel source CSVs together with PDF/PNG figure files.

## Archived FULL design

The release contains:

- 15 independent raw designs: five repetitions at each of `N = 160, 320, 640`;
- 5,600 rows in `exp05_p1_raw_all_independent_designs.csv`;
- all-design PRCC and convergence summaries;
- the primary `N = 640`, repetition-1 design;
- 2,000-resample bootstrap summaries for eight responses × three subsets × 20 sampled parameters (480 rows);
- threshold/direction summaries;
- parameter-range audit and 10/10 archived quality gates;
- Figure 5 panel A–D source CSVs, summary CSV, PDF, and PNG.

Regenerable checkpoints, transient run logs, MATLAB `.fig`/EPS intermediates, and other nonessential working artifacts are intentionally excluded from the public archive.

## Primary-design checks

For the primary `N = 640`, repetition-1 design:

- strict `SameRegimeThree` subset: **638/640**;
- maximum archived capacity-matching error: **1.66533453693773e-16**;
- maximum archived risk decomposition error: **9.43689574653696e-16**;
- median `abs(DeltaI_capacity / DeltaI_net)`: **0.999999999864181** for rows with `abs(DeltaI_net) > 1e-10`;
- median `abs(DeltaI_adapt / DeltaI_net)`: **2.12259527155812e-9** under the same denominator safeguard.

The maximum adaptation/net ratio is much larger than the median because ratios become unstable when the net-effect denominator is very small. Interpretation should therefore use the archived absolute component values and the reported denominator rule rather than the maximum ratio alone.

Within the 638-row strict subset, the archived direction/magnitude summaries give:

- risk adverse direction: **97.80564%**;
- risk adverse and `abs(effect) > 1e-3`: **79.15361%**;
- trust adverse direction: **100%**;
- trust adverse and `abs(effect) > 1e-3`: **77.11599%**.

These percentages describe sampled model configurations under the stated numerical design. They are not empirical event probabilities.

## Independent static/data validation

Run from the repository root:

```bash
python tools/preflight_sr.py
```

The validator independently checks arithmetic identities, design counts, branch matching, Figure 5 source-to-panel consistency, quality-gate records, required release metadata, and SHA-256 integrity. It does not execute MATLAB.
