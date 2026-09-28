# Results index

This index maps the principal manuscript items and supporting analyses to the frozen v1.0.0 workflows and machine-readable outputs.

| Manuscript item / analysis | Workflow | Primary frozen source data |
|---|---|---|
| Numerical validation (Results 3.1; Supplementary Fig. S1 / Table S7) | `RUN_CORE_SR.m` → Exp00 | `results/exp00_numerical_validation/` |
| Representative long-run regimes / Figure 2 | `RUN_CORE_SR.m` → Exp01 | `results/Exp01_representative_regimes/exp01_regime_raw.csv`, `exp01_regime_summary.csv`, `publication_figures/Figure2_Exp01_extraction_audit.csv` |
| Feedback closure, capacity/provenance mechanism comparisons / Table 1 | `RUN_CORE_SR.m` → Exp02 | `results/exp02_feedback_mechanisms/` |
| Governance-channel factorial analysis / Figure 3 | `RUN_CORE_SR.m` → Exp03 | `results/exp03_governance_factorial/` |
| Controlled AIGC planes, effect magnitude, matched shocks / Figure 4 | `exp04_final_code/RUN_EXP04_FINAL_SR_V4.m` | `results/exp04_adaptation_risk/` and `results/exp04_three_branch_comparability/` |
| Global sensitivity and AIGC decomposition / Figure 5 | `RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX.m`; `BUILD_SR_FIGURE5_FINAL_REPAIRED_V1.m` | `results/exp05_independent_aigc_prcc/` and `.../Figure5_FINAL_REPAIRED_V1/` |
| Separate Morris screening | `v10_core/+aigc/exp05_global_sensitivity.m` | `results/exp05_morris_screening/` |
| Equilibrium–periodic transition and timescale interventions / Figure 6 | `RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01.m` → Exp06 | `results/exp06_stability_timescales/` |
| Trust-shock analysis / Figure 7 | `RUN_CORE_SR.m` → Exp07 | `results/exp07_trust_shocks/` |
| Fixed vs dynamic moderation policy comparison | `RUN_CORE_SR.m` → Exp08 main | `results/exp08_main_policy_comparison/` |
| Policy-class nesting / extended Exp08 audit | `RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01.m` → Exp08 | `results/exp08_nesting_audit/` |
| Structural robustness | `RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL.m` | `results/exp09_structural_robustness/` |
| Reduced direct risk–user stability audit | `RUN_THEORY_P1_IZ_STABILITY_AUDIT_V10_SR_V2.m` | `theory_iz_stability/` |

## Notes

1. Figure 5 has an archived publication builder plus panel-level source CSVs and PDF/PNG outputs.
2. For other figures/tables, this release guarantees the archived numerical inputs and experiment workflows listed above; it does not claim that every final typeset panel can be regenerated pixel-for-pixel from a dedicated layout script.
3. `run_manifest.csv` records the V10 versus V10-P0.1 source lineage used for each workflow.
