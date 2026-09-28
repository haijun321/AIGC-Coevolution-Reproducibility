# AIGC Coevolution — reproducibility package v1.0.0

This repository contains the MATLAB source code, experiment configurations, machine-readable numerical outputs, validation utilities, and selected publication-source files supporting the manuscript:

**“Coevolution in generative AI content ecosystems: behaviour–risk feedback, governance chains and dynamic stability.”**

The study is simulation based. No external empirical dataset is required to reproduce the numerical analyses represented in this release.

## Contents

- `RUN_CORE_SR.m` — V10 core workflows for Exp00–Exp03, Exp07, and the main Exp08 policy comparison.
- `exp04_final_code/` — final Exp04 controlled AIGC parameter-plane workflow.
- `RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX.m` — Exp05-P1 independent LHS/PRCC workflow used for the primary Figure 5 analysis.
- `BUILD_SR_FIGURE5_FINAL_REPAIRED_V1.m` — Figure 5 reconstruction and source-data export.
- `RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01.m` — V10-P0.1 Exp06 stability/timescale and Exp08 nesting workflows.
- `RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL.m` — Exp09 structural robustness workflow.
- `RUN_THEORY_P1_IZ_STABILITY_AUDIT_V10_SR_V2.m` — reduced risk–user stability audit.
- `results/` — frozen machine-readable results supporting the manuscript and Supplementary Information.
- `run_manifest.csv` — source-lineage, runner, and result mapping.
- `RESULTS_INDEX.md` — manuscript-item to experiment/source-data map.
- `EXP05_VALIDATION.md` — validation details for the corrected Exp05-P1/Figure 5 branch comparison.
- `MATLAB_ENVIRONMENT.md` — recorded computational environment and dependency notes.
- `tools/preflight_sr.py` — independent release/data consistency checks using Python standard library only.
- `tools/report_matlab_environment.m` — helper for recording a local MATLAB environment.
- `SHA256SUMS.txt` — SHA-256 digests for all released files except the checksum file itself.

## Quick start

Extract or clone the repository, start MATLAB in the repository root, and use a fresh MATLAB session for each source lineage.

### Core V10 experiments

```matlab
addpath(pwd)
RUN_CORE_SR('full')
```

This runs Exp00–Exp03, Exp07, and the main Exp08 workflow. A full run can be computationally expensive.

### Exp04 controlled AIGC planes

```matlab
addpath(pwd)
addpath(fullfile(pwd,'exp04_final_code'))
RUN_EXP04_FINAL_SR_V4()
```

### Exp05-P1 independent LHS/PRCC and Figure 5

```matlab
addpath(pwd)
outDir = RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX('full');
BUILD_SR_FIGURE5_FINAL_REPAIRED_V1(outDir);
```

To redraw Figure 5 directly from the frozen v1.0.0 result tables:

```matlab
addpath(pwd)
BUILD_SR_FIGURE5_FINAL_REPAIRED_V1( ...
    fullfile(pwd,'results','exp05_independent_aigc_prcc'));
```

The frozen Figure 5 PDF/PNG and its four panel-level source CSVs are stored under:

`results/exp05_independent_aigc_prcc/Figure5_FINAL_REPAIRED_V1/`

### Exp06 stability/timescale and Exp08 nesting audit

```matlab
addpath(pwd)
RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01('full')
```

### Exp09 structural robustness

```matlab
addpath(pwd)
RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL('full')
```

### Reduced I–z stability audit

```matlab
addpath(pwd)
RUN_THEORY_P1_IZ_STABILITY_AUDIT_V10_SR_V2('full')
```

## Source-lineage isolation

The V10 and V10-P0.1 `+aigc` package trees support different experiments. Do **not** manually add both package roots to the MATLAB path in one session. The dedicated runners reset/configure the intended source lineage. `run_manifest.csv` records the mapping used in this release.

## Frozen results and Figure 5 primary design

The Exp05-P1 archive contains 15 independent LHS designs: five repetitions at each of `N = 160, 320, 640` (5,600 rows total). The primary analysis uses `N = 640`, repetition 1. Of those 640 configurations, 638 satisfy the strict three-branch same-regime criterion used for the paired effect analyses. The release includes the 2,000-resample bootstrap summaries used for the reported pointwise confidence intervals.

The fixed-AIGC branch is capacity matched to the corresponding dynamic branch and is distinct from the no-AIGC branch. Detailed arithmetic and source-to-panel checks are documented in `EXP05_VALIDATION.md`.

## Independent release validation

From the repository root, run:

```bash
python tools/preflight_sr.py
```

The validator checks, among other items:

- MATLAB function/file-name consistency and private-path leakage;
- Exp04 31×31 plane sizes and risk/trust decomposition identities;
- Exp05 design sizes, combined/raw-table agreement, branch matching, and effect decomposition;
- the 638/640 strict primary subset;
- the 480-row Exp05 bootstrap table;
- Figure 5 panel-source agreement;
- reported output quality gates;
- required public-release documentation; and
- SHA-256 integrity/coverage of released files.

The validator does not execute MATLAB and is not a substitute for a full clean-environment numerical rerun.

## Data scope

No external empirical data are bundled or required. The `results/` tree contains the archived simulation summaries and source data used for the reported numerical claims. Large or regenerable transient artifacts such as checkpoints, run logs, and intermediate MATLAB figure objects are intentionally excluded.

For manuscript mapping, see `RESULTS_INDEX.md`.

## Computational environment

Author records identify Windows 11 and the MATLAB R2025 release family. The exact `a`/`b` suffix was not preserved in the archived execution record, so this release does not invent a more specific version. See `MATLAB_ENVIRONMENT.md` for the dependency audit and a helper command for recording a local environment.

## Citation

Citation metadata are provided in `CITATION.cff`. When a permanent repository/archive DOI is assigned, cite the archived release together with the associated manuscript/article as appropriate.

## License

The source code and release materials are distributed under the MIT License. See `LICENSE`.
