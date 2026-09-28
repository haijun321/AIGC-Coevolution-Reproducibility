# Computational environment and dependencies

## Archived execution record

The records accompanying the frozen numerical outputs identify:

- **Operating system:** Windows 11
- **MATLAB:** R2025 release family

The exact `R2025a`/`R2025b` suffix and the original `ver` listing were not preserved in the archived execution record. This release reports that limitation explicitly rather than inferring a more specific environment.

## Dependency audit

A static scan of the released MATLAB source found use of core numerical/data/graphics functions including `ode45`, `ode15s`, `eig`, `interp1`, `corrcoef`, `readtable`, `writetable`, `tiledlayout`, and `exportgraphics`. The released source does not directly call common toolbox-specific routines such as `lhsdesign`, `partialcorr`, `bootstrp`, `fmincon`, `parfor`, or `parpool`; the LHS/PRCC/bootstrap logic required by the primary Exp05 workflow is implemented within the released code.

Because static inspection cannot replace execution on every MATLAB installation, this file does not claim a universal minimum release or guarantee absence of release-specific toolbox licensing differences. The frozen results correspond to the R2025-family Windows environment described above.

## Python validator

`tools/preflight_sr.py` uses only the Python 3 standard library.

## Record a local MATLAB environment

From the repository root, run:

```matlab
addpath(fullfile(pwd,'tools'))
report_matlab_environment()
```

or save the report to a text file:

```matlab
addpath(fullfile(pwd,'tools'))
report_matlab_environment('MATLAB_ENVIRONMENT_LOCAL.txt')
```

The helper reports `version`, `version('-release')`, architecture, operating system information available to MATLAB, and the installed-product list returned by `ver`.
