function outputDir = RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL(runMode)
%RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL
% ========================================================================
% Publication-grade Exp09 structural robustness audit for ACTIVE modular V10.
%
% PURPOSE
%   This runner resolves the denominator/no-op problem in Exp09 by enforcing
%   the following evidence chain:
%
%     candidate variant
%        -> static field/token support
%        -> numerical RHS activation audit
%        -> active, non-duplicate structural variant
%        -> both branches long-run resolved
%        -> same dynamical regime
%        -> directional retention
%
% SCIENTIFIC LOCKS
%   1) Unsupported or numerically no-op structural variants NEVER enter the
%      structural denominator.
%   2) Baseline-equivalent and duplicate variants are excluded.
%   3) Unresolved == unresolved is NEVER counted as a valid comparison.
%   4) The structural variant, not the IC trajectory, is the primary unit
%      for the strict denominator table. Trajectory-level counts are also
%      saved for transparency.
%   5) Near-ideal governance uses primitive-channel floors/ceilings at
%      0.90/0.95/0.98. These are NOT end-to-end p_act targets.
%   6) The current file does NOT fabricate the manuscript's historical
%      "19 variants". It audits the candidate structural families that can
%      be reconstructed safely from the accessible V10 lineage. If the
%      exact historical 19-variant factory is later recovered, merge it
%      only inside build_candidate_library_locked(); the activation and
%      denominator logic below should remain unchanged.
%
% DIRECT RUN
%   RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL('preview')
%   RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL('quick')
%   RUN_EXP09_STRUCTURAL_ROBUSTNESS_AUDIT_V10_FINAL('full')
%
% OUTPUTS
%   exp09_structural_support_manifest.csv
%   exp09_structural_candidate_manifest.csv
%   exp09_structural_activation_audit.csv
%   exp09_active_variant_manifest.csv
%   exp09_exclusion_log.csv
%   exp09_common_initial_conditions.csv
%   exp09_near_ideal_all_runs.csv
%   exp09_variant_level_summary.csv
%   exp09_conclusion_denominator_audit.csv
%   experiment_quality_check.csv
%   EXP09_STRUCTURAL_ROBUSTNESS_REPORT.txt
%   EXP09_STRUCTURAL_ROBUSTNESS_AUDIT.mat
%   fig_exp09_main.{fig,png,pdf}                  % supplementary structural audit figure
%   fig_exp09_risk_gap_level095_supp.{fig,png,pdf} % supplementary variant-level audit
% ========================================================================

if nargin < 1 || isempty(runMode), runMode = 'full'; end
runMode = lower(char(runMode));
if ~ismember(runMode,{'preview','quick','full'})
    error('runMode must be preview, quick, or full.');
end

clc;
close all force;

%% ======================================================================
% 0. LOCKED PROTOCOL
% =======================================================================
CFG = struct();
CFG.RUN_MODE = runMode;
CFG.RUN_TAG = 'paper_exp09_final_audit_v1';
CFG.SEED = 20260813;
CFG.LEVELS = [0.90 0.95 0.98];

% Manuscript-locked long-run certification.
CFG.HORIZONS = [600 1200 2400];
CFG.TAIL_FRACTIONS = [0.25 0.40 0.50];
CFG.PRIMARY_TAIL = 0.40;
CFG.OUTPUT_DT = 0.025;
CFG.EQ_ACTIVE_AMP_TOL = 1e-4;
CFG.DERIVATIVE_TOL = 1e-6;
CFG.CYCLE_RISK_AMP_MIN = 2e-3;
CFG.CYCLE_MIN_PERIODS = 8;
CFG.CYCLE_PERIOD_CV_MAX = 0.02;
CFG.CYCLE_AMP_DRIFT_MAX = 0.05;

% RHS activation audit.
CFG.RHS_TOL = 1e-10;
CFG.DUPLICATE_RHS_TOL = 1e-10;
CFG.PROBE_MARGIN = 0.10;       % probes stay in [0.10,0.90]^10
CFG.MIN_CHANGED_PROBES = 1;    % active if at least one probe changes RHS
CFG.SHOW_FIGURES = true;

switch runMode
    case 'preview'
        CFG.N_IC = 2;
        CFG.N_RHS_PROBES = 10;
    case 'quick'
        CFG.N_IC = 5;
        CFG.N_RHS_PROBES = 20;
    case 'full'
        CFG.N_IC = 12;
        CFG.N_RHS_PROBES = 40;
end

fprintf('\n====================================================================\n');
fprintf(' Exp09 | STRUCTURAL ROBUSTNESS + RHS ACTIVATION AUDIT | %s\n',upper(runMode));
fprintf('====================================================================\n');

%% ======================================================================
% 1. LOCATE AND VERIFY ACTIVE V10 PACKAGE
% =======================================================================
thisFile = mfilename('fullpath');
if isempty(thisFile), startDir = pwd; else, startDir = fileparts(thisFile); end
root = locate_project_root_locked(startDir);
if isempty(root)
    selected = uigetdir(pwd,'Select V10 root containing +aigc');
    if isequal(selected,0) || exist(fullfile(selected,'+aigc'),'dir') ~= 7
        error('No valid V10 root selected.');
    end
    root = selected;
end

% Do not recursively add old V9/V10 snapshots.
addpath(root);
rehash;

required = {'default_parameters','default_options','experiment_settings', ...
            'full_mode','solve_model','model_rhs'};
for k = 1:numel(required)
    f = fullfile(root,'+aigc',[required{k} '.m']);
    if exist(f,'file') ~= 2
        error('Missing required ACTIVE V10 file: %s',f);
    end
end

% Hard-lock every required +aigc function to one unique ACTIVE V10 copy.
for k = 1:numel(required)
    assert_unique_package_version_locked(['aigc.' required{k}], root);
end

pBase = aigc.default_parameters();
opt = aigc.default_options(runMode);
settings = aigc.experiment_settings(runMode); %#ok<NASGU>
[p0,parameterSource] = get_R1_parameters_locked(pBase);
baseMode = aigc.full_mode();

if ~isfield(opt,'X0') || numel(opt.X0) ~= 10
    error('Active opt.X0 must be 10-D.');
end

outputDir = fullfile(root,'outputs', ...
    ['Exp09_structural_robustness_' CFG.RUN_TAG '_' runMode]);
if ~exist(outputDir,'dir'), mkdir(outputDir); end

diary(fullfile(outputDir,'run_log.txt'));
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('Project root      : %s\n',root);
fprintf('Parameter source  : %s\n',parameterSource);
fprintf('RHS tolerance     : %.3e\n',CFG.RHS_TOL);
fprintf('RHS probes        : %d\n',CFG.N_RHS_PROBES);
fprintf('Common ICs        : %d\n',CFG.N_IC);

%% ======================================================================
% 2. COMMON ICs AND INTERIOR RHS PROBES
% =======================================================================
rng(CFG.SEED,'twister');
X0Set = get_common_initial_conditions_locked(CFG.N_IC,opt.X0(:));
Tic = array2table(X0Set,'VariableNames', ...
    {'x0','y0','z0','I0','T0','M0','u0','A0','L0','E0'});
Tic.Run = (1:CFG.N_IC)';
Tic = movevars(Tic,'Run','Before','x0');
writetable(Tic,fullfile(outputDir,'exp09_common_initial_conditions.csv'));

probeStates = build_rhs_probe_states_locked(CFG.N_RHS_PROBES,opt.X0(:),CFG);
Tprobe = array2table(probeStates,'VariableNames', ...
    {'x','y','z','I','T','M','u','A','L','E'});
Tprobe.Probe = (1:CFG.N_RHS_PROBES)';
Tprobe = movevars(Tprobe,'Probe','Before','x');
writetable(Tprobe,fullfile(outputDir,'exp09_rhs_probe_states.csv'));

%% ======================================================================
% 3. STATIC SUPPORT MANIFEST + CANDIDATE LIBRARY
% =======================================================================
support = detect_structural_support_locked(root);
Tsupport = structural_support_manifest(support);
writetable(Tsupport,fullfile(outputDir,'exp09_structural_support_manifest.csv'));

V = build_candidate_library_locked(p0,baseMode);
Tcand = candidate_manifest(V,support);
writetable(Tcand,fullfile(outputDir,'exp09_structural_candidate_manifest.csv'));

fprintf('\nCandidate structural variants (excluding baseline): %d\n',size(V,1)-1);

%% ======================================================================
% 4. NUMERICAL RHS ACTIVATION + DUPLICATE AUDIT
% =======================================================================
[Tact,rhsCache] = rhs_activation_audit_locked(V,p0,baseMode,probeStates,support,CFG);
writetable(Tact,fullfile(outputDir,'exp09_structural_activation_audit.csv'));

activeMask = Tact.Active & ~Tact.IsBaseline;
Tactive = Tact(activeMask,:);
writetable(Tactive,fullfile(outputDir,'exp09_active_variant_manifest.csv'));
Texcl = Tact(~Tact.Active & ~Tact.IsBaseline,:);
writetable(Texcl,fullfile(outputDir,'exp09_exclusion_log.csv'));

fprintf('\n--- RHS activation audit ---\n');
fprintf('Candidates excluding baseline : %d\n',sum(~Tact.IsBaseline));
fprintf('Active unique variants        : %d\n',sum(activeMask));
fprintf('Excluded variants             : %d\n',height(Texcl));
if ~isempty(Texcl)
    for i = 1:height(Texcl)
        fprintf('  EXCLUDE %-18s %-12s | %s | maxRhsDiff=%.3e\n', ...
            char(Texcl.Family(i)),char(Texcl.Setting(i)), ...
            char(Texcl.ExclusionReason(i)),Texcl.MaxRHSDiff(i));
    end
end

if ~any(activeMask)
    error('No active structural variants survived the RHS activation audit.');
end

% Map active audit rows back to candidate cells.
activeCandidateIndices = Tact.CandidateIndex(activeMask);

%% ======================================================================
% 5. NEAR-IDEAL STRUCTURAL COMPARISONS
% =======================================================================
rows = struct([]);
for ia = 1:numel(activeCandidateIndices)
    iv = activeCandidateIndices(ia);
    family = string(V{iv,1});
    setting = string(V{iv,2});
    pFinite = V{iv,3};
    mode = V{iv,4};

    fprintf('\n[%d/%d] %s / %s\n',ia,numel(activeCandidateIndices),family,setting);

    for level = CFG.LEVELS
        pNear = make_near_ideal_governance(pFinite,level);

        for r = 1:CFG.N_IC
            x0 = X0Set(r,:)';
            a = certify_branch_locked(x0,pFinite,mode,opt,CFG);
            b = certify_branch_locked(x0,pNear,mode,opt,CFG);

            q = struct();
            q.CandidateIndex = iv;
            q.Family = family;
            q.Setting = setting;
            q.Level = level;
            q.Run = r;

            q.FiniteI = a.I;
            q.NearIdealI = b.I;
            q.DeltaI_FiniteMinusNear = binary_delta(a.I,b.I);
            q.FiniteT = a.T;
            q.NearIdealT = b.T;
            q.DeltaT_FiniteMinusNear = binary_delta(a.T,b.T);

            q.FiniteResolved = a.resolved;
            q.NearIdealResolved = b.resolved;
            q.BothResolved = a.resolved && b.resolved;
            q.FiniteClass = a.coarse;
            q.NearIdealClass = b.coarse;
            q.SameRegime = q.BothResolved && a.coarse == b.coarse;

            q.RiskDirectionFiniteWorse = q.BothResolved && ...
                isfinite(q.DeltaI_FiniteMinusNear) && q.DeltaI_FiniteMinusNear > 0;
            q.TrustDirectionFiniteWorse = q.BothResolved && ...
                isfinite(q.DeltaT_FiniteMinusNear) && q.DeltaT_FiniteMinusNear < 0;
            q.RiskDirectionFiniteWorseSameRegime = q.SameRegime && ...
                q.DeltaI_FiniteMinusNear > 0;
            q.TrustDirectionFiniteWorseSameRegime = q.SameRegime && ...
                q.DeltaT_FiniteMinusNear < 0;

            q.FiniteHorizon = a.horizon;
            q.NearIdealHorizon = b.horizon;
            rows = append_struct(rows,q); %#ok<AGROW>
        end

        Qtmp = struct2table(rows);
        mask = Qtmp.CandidateIndex == iv & abs(Qtmp.Level-level) < 1e-12;
        fprintf('  level %.2f | both-resolved %d/%d | same-regime %d/%d\n', ...
            level,sum(Qtmp.BothResolved(mask)),sum(mask), ...
            sum(Qtmp.SameRegime(mask)),sum(mask));
    end
end

Tall = struct2table(rows);
writetable(Tall,fullfile(outputDir,'exp09_near_ideal_all_runs.csv'));

%% ======================================================================
% 6. VARIANT-LEVEL AND CONCLUSION-LEVEL DENOMINATORS
% =======================================================================
Tvarsum = summarize_variant_level_locked(Tall,CFG);
writetable(Tvarsum,fullfile(outputDir,'exp09_variant_level_summary.csv'));

Tden = build_conclusion_denominator_audit_locked(Tvarsum,Tactive,CFG);
writetable(Tden,fullfile(outputDir,'exp09_conclusion_denominator_audit.csv'));

%% ======================================================================
% 7. QUALITY GATES
% =======================================================================
Tqc = quality_gate_locked(Tact,Tactive,Tvarsum,Tden,CFG);
writetable(Tqc,fullfile(outputDir,'experiment_quality_check.csv'));

if any(~Tqc.Pass)
    warning('At least one Exp09 quality gate failed. Do NOT use the results in the manuscript until resolved.');
end

%% ======================================================================
% 8. REPORT, MAT, FIGURES
% =======================================================================
save(fullfile(outputDir,'EXP09_STRUCTURAL_ROBUSTNESS_AUDIT.mat'), ...
    'CFG','root','p0','baseMode','opt','X0Set','probeStates','support', ...
    'V','Tcand','Tact','Tactive','Texcl','Tall','Tvarsum','Tden','Tqc', ...
    'parameterSource','rhsCache','-v7.3');

write_report_locked(fullfile(outputDir,'EXP09_STRUCTURAL_ROBUSTNESS_REPORT.txt'), ...
    CFG,root,parameterSource,Tact,Tactive,Tvarsum,Tden,Tqc);

if CFG.SHOW_FIGURES
    try
        % Supplementary structural audit figure:
        %   (a) RHS activation qualification
        %   (b) structural evidence funnel
        %   (c) same-regime coverage vs conditional direction retention
        plot_figure9_publication_locked(Tact,Tden,CFG,outputDir);

        % Supplementary variant-level magnitude plot at L = 0.95.
        % This preserves the detailed risk-gap information without
        % overloading the supplementary structural audit figure.
        plot_risk_gap_supplement_locked(Tvarsum,outputDir);
    catch ME
        warning('Figure generation failed: %s',ME.message);
    end
end

fprintf('\n====================================================================\n');
fprintf('Exp09 audit completed.\n');
fprintf('Output: %s\n',outputDir);
fprintf('ACTIVE structural denominator = %d variants (baseline excluded).\n',height(Tactive));
fprintf(['IMPORTANT: report ACTIVE/SAME-REGIME denominators from ', ...
    'exp09_conclusion_denominator_audit.csv; do not reuse historical 19.\n']);
fprintf('====================================================================\n');
end

%% ======================================================================
% CANDIDATE LIBRARY
% =======================================================================
function V = build_candidate_library_locked(p0,baseMode)
% Candidate set reconstructed safely from the accessible V10 lineage.
% IMPORTANT: this is a candidate library, NOT an automatically valid
% denominator. Every row must survive the activation audit below.
%
% Columns:
%   1 Family
%   2 Setting
%   3 Parameters
%   4 Mode
%   5 TargetEquation
%   6 MATLABField
%   7 StructuralType

V = {};
V(end+1,:) = {'baseline','baseline',p0,baseMode, ...
    'FULL baseline','baseline','baseline'}; %#ok<AGROW>

% A. Trust-loss threshold functional forms.
for form = {'hill','piecewise'}
    p = p0;
    if isfield(p,'kB') && isfield(p,'thetaB')
        p.hillN = p.kB*p.thetaB;
        p.pieceWidth = 4/max(p.kB,eps);
    end
    m = aigc.full_mode();
    m.thresholdForm = form{1};
    V(end+1,:) = {'thresholdForm',form{1},p,m, ...
        'trust threshold/gating function','mode.thresholdForm','functional_form'}; %#ok<AGROW>
end

% B. Audit boundary functional forms; locally speed-matched at uRef.
baseFactor = audit_boundary_factor_local(getfield_default(p0,'uRef',0.5),baseMode);
for form = {'sqrt','projected'}
    p = p0;
    m = aigc.full_mode();
    m.auditBoundaryForm = form{1};
    f = audit_boundary_factor_local(getfield_default(p,'uRef',0.5),m);
    if isfield(p,'auditSpeed')
        p.auditSpeed = p0.auditSpeed*baseFactor/max(f,eps);
    end
    V(end+1,:) = {'auditBoundary',form{1},p,m, ...
        'audit-controller boundary factor','mode.auditBoundaryForm','functional_form'}; %#ok<AGROW>
end

% C. AIGC risk-amplification functional forms. These candidates are kept in
% the manifest even if ACTIVE modular V10 does not consume aigcRiskForm;
% they will then be excluded by the support/RHS audit rather than silently
% entering the denominator.
for form = {'saturating','hill'}
    p = p0;
    m = aigc.full_mode();
    m.aigcRiskForm = form{1};
    if isfield(p,'psiE')
        p.psiE = matched_aigc_psi_local(p0,form{1},0.10);
    end
    V(end+1,:) = {'aigcRiskForm',form{1},p,m, ...
        'AIGC risk-injection amplification','mode.aigcRiskForm','functional_form'}; %#ok<AGROW>
end

% D. Evolutionary switching-rate robustness. This family changes a model
% parameter rather than the functional form. Keep it as a separate
% StructuralType so the manuscript can distinguish function-form and
% switching-structure robustness.
mutationGrid = [0 1e-5 1e-4 1e-3 5e-3 1e-2 5e-2];
for e = mutationGrid
    if isfield(p0,'epsP') && isfield(p0,'epsF') && isfield(p0,'epsU') && ...
            max(abs([p0.epsP p0.epsF p0.epsU]-e)) <= 1e-14
        continue; % identity setting must not enter candidate denominator
    end
    p = p0;
    p.epsP = e;
    p.epsF = e;
    p.epsU = e;
    m = aigc.full_mode();
    V(end+1,:) = {'mutationRate',sprintf('%.6g',e),p,m, ...
        'replicator-switching terms','p.epsP/p.epsF/p.epsU','switching_parameter'}; %#ok<AGROW>
end
end

function T = candidate_manifest(V,support)
n = size(V,1);
CandidateIndex = (1:n)';
Family = strings(n,1);
Setting = strings(n,1);
TargetEquation = strings(n,1);
MATLABField = strings(n,1);
StructuralType = strings(n,1);
StaticSupported = false(n,1);
for i = 1:n
    Family(i) = string(V{i,1});
    Setting(i) = string(V{i,2});
    TargetEquation(i) = string(V{i,5});
    MATLABField(i) = string(V{i,6});
    StructuralType(i) = string(V{i,7});
    StaticSupported(i) = family_static_supported(Family(i),support);
    if Family(i) == "baseline", StaticSupported(i) = true; end
end
T = table(CandidateIndex,Family,Setting,StructuralType,TargetEquation,MATLABField,StaticSupported);
end

%% ======================================================================
% STATIC SUPPORT + NUMERICAL ACTIVATION AUDIT
% =======================================================================
function support = detect_structural_support_locked(root)
files = dir(fullfile(root,'+aigc','*.m'));
support = struct();
support.thresholdForm = token_present_local(files,'thresholdForm');
support.auditBoundaryForm = token_present_local(files,'auditBoundaryForm');
support.aigcRiskForm = token_present_local(files,'aigcRiskForm');
support.epsP = token_present_local(files,'epsP');
support.epsF = token_present_local(files,'epsF');
support.epsU = token_present_local(files,'epsU');
support.mutationRate = support.epsP && support.epsF && support.epsU;

fprintf('\n--- STATIC structural support audit ---\n');
fprintf('thresholdForm     : %d\n',support.thresholdForm);
fprintf('auditBoundaryForm : %d\n',support.auditBoundaryForm);
fprintf('aigcRiskForm      : %d\n',support.aigcRiskForm);
fprintf('mutationRate      : %d (epsP/epsF/epsU=%d/%d/%d)\n', ...
    support.mutationRate,support.epsP,support.epsF,support.epsU);
end

function tf = family_static_supported(family,s)
switch char(family)
    case 'baseline', tf = true;
    case 'thresholdForm', tf = s.thresholdForm;
    case 'auditBoundary', tf = s.auditBoundaryForm;
    case 'aigcRiskForm', tf = s.aigcRiskForm;
    case 'mutationRate', tf = s.mutationRate;
    otherwise, tf = false;
end
end

function T = structural_support_manifest(s)
Family = ["thresholdForm";"auditBoundary";"aigcRiskForm";"mutationRate"];
Supported = [s.thresholdForm;s.auditBoundaryForm;s.aigcRiskForm;s.mutationRate];
Action = repmat("candidate_allowed",4,1);
Action(~Supported) = "excluded_static_unsupported";
T = table(Family,Supported,Action);
end

function [T,rhsCache] = rhs_activation_audit_locked(V,p0,baseMode,probes,support,CFG)
n = size(V,1);
K = size(probes,1);

% Baseline RHS on all probes.
Fbase = nan(K,10);
for k = 1:K
    Fbase(k,:) = rhs_safe(0,probes(k,:)',p0,baseMode)';
end
if any(~isfinite(Fbase(:)))
    error('Baseline RHS returned non-finite values on activation probes.');
end

rhsAll = cell(n,1);
for i = 1:n
    Fi = nan(K,10);
    for k = 1:K
        Fi(k,:) = rhs_safe(0,probes(k,:)',V{i,3},V{i,4})';
    end
    rhsAll{i} = Fi;
end

CandidateIndex = (1:n)';
Family = strings(n,1);
Setting = strings(n,1);
StructuralType = strings(n,1);
TargetEquation = strings(n,1);
MATLABField = strings(n,1);
IsBaseline = false(n,1);
StaticSupported = false(n,1);
MaxRHSDiff = nan(n,1);
MedianRHSDiff = nan(n,1);
NChangedProbes = zeros(n,1);
BaselineEquivalent = false(n,1);
DuplicateOf = strings(n,1);
Active = false(n,1);
ExclusionReason = strings(n,1);

for i = 1:n
    Family(i) = string(V{i,1});
    Setting(i) = string(V{i,2});
    StructuralType(i) = string(V{i,7});
    TargetEquation(i) = string(V{i,5});
    MATLABField(i) = string(V{i,6});
    IsBaseline(i) = Family(i) == "baseline";
    StaticSupported(i) = family_static_supported(Family(i),support);

    dByProbe = max(abs(rhsAll{i}-Fbase),[],2);
    MaxRHSDiff(i) = max(dByProbe);
    MedianRHSDiff(i) = median(dByProbe);
    NChangedProbes(i) = sum(dByProbe > CFG.RHS_TOL);
    BaselineEquivalent(i) = MaxRHSDiff(i) <= CFG.RHS_TOL;

    if IsBaseline(i)
        Active(i) = true;
        ExclusionReason(i) = "baseline_reference";
    elseif ~StaticSupported(i)
        Active(i) = false;
        ExclusionReason(i) = "unsupported_static";
    elseif BaselineEquivalent(i) || NChangedProbes(i) < CFG.MIN_CHANGED_PROBES
        Active(i) = false;
        ExclusionReason(i) = "no_op_rhs";
    else
        Active(i) = true;
        ExclusionReason(i) = "active";
    end
end

% Exclude numerical duplicates among currently active non-baseline variants.
for i = 2:n
    if ~Active(i), continue; end
    for j = 2:i-1
        if ~Active(j), continue; end
        pairDiff = max(abs(rhsAll{i}(:)-rhsAll{j}(:)));
        if pairDiff <= CFG.DUPLICATE_RHS_TOL
            Active(i) = false;
            DuplicateOf(i) = Family(j)+"/"+Setting(j);
            ExclusionReason(i) = "duplicate_rhs";
            break;
        end
    end
end

T = table(CandidateIndex,Family,Setting,StructuralType,TargetEquation,MATLABField, ...
    IsBaseline,StaticSupported,MaxRHSDiff,MedianRHSDiff,NChangedProbes, ...
    BaselineEquivalent,DuplicateOf,Active,ExclusionReason);

rhsCache = struct('Fbase',Fbase,'rhsAll',{rhsAll});
end

function f = rhs_safe(t,X,p,mode)
try
    f = aigc.model_rhs(t,X,p,mode);
catch ME
    error('RHS activation audit failed for a candidate: %s',ME.message);
end
f = f(:);
if numel(f) ~= 10
    error('aigc.model_rhs must return a 10-D derivative.');
end
end

function probes = build_rhs_probe_states_locked(K,x0,CFG)
% Deterministic interior probes. Includes perturbed X0 plus global interior
% probes so a mode is not declared no-op merely because one baseline state
% happens to sit on a local equality.
rng(CFG.SEED+991,'twister');
lo = CFG.PROBE_MARGIN;
hi = 1-CFG.PROBE_MARGIN;
probes = lo + (hi-lo)*rand(K,10);

x0 = x0(:)';
if numel(x0)==10
    probes(1,:) = min(max(x0,lo),hi);
end

% Force a few diagnostically useful interior values for u, I, T, A, L, E.
if K >= 2, probes(2,:) = [0.25 0.65 0.35 0.20 0.75 0.55 0.30 0.20 0.70 0.15]; end
if K >= 3, probes(3,:) = [0.70 0.30 0.80 0.65 0.25 0.40 0.75 0.60 0.25 0.70]; end
if K >= 4, probes(4,:) = [0.45 0.55 0.25 0.45 0.50 0.80 0.55 0.35 0.55 0.40]; end
probes = min(max(probes,lo),hi);
end

%% ======================================================================
% NEAR-IDEAL COMPARATOR
% =======================================================================
function p = make_near_ideal_governance(p,level)
% level is a floor for favorable primitive channels and 1-level is a cap
% for primitive adverse/error/evasion baselines. It is NOT an end-to-end
% p_act target. The structural variant remains identical between branches.
favorable = {'s','h','c','r','chi','attn'};
adverse = {'f','eD0','eL0','eDetect','eLabel'};
for k = 1:numel(favorable)
    nm = favorable{k};
    if isfield(p,nm), p.(nm) = max(p.(nm),level); end
end
for k = 1:numel(adverse)
    nm = adverse{k};
    if isfield(p,nm), p.(nm) = min(p.(nm),1-level); end
end
end

%% ======================================================================
% LONG-RUN CERTIFICATION
% =======================================================================
function out = certify_branch_locked(X0,p,mode,optBase,CFG)
out = struct('I',NaN,'T',NaN,'coarse',"unresolved", ...
    'resolved',false,'horizon',NaN,'period',NaN);
last = [];
diag = empty_diag();

for h = CFG.HORIZONS
    o = optBase;
    o.t0 = 0;
    o.tEnd = h;
    o.allowEarlyStop = false;
    o.solver = 'ode45';
    if isfield(o,'odeRelTol'), o.odeRelTol = min(o.odeRelTol,1e-9); end
    if isfield(o,'odeAbsTol'), o.odeAbsTol = min(o.odeAbsTol,1e-11); end

    try
        sol = aigc.solve_model(X0,p,mode,o);
    catch ME
        out.horizon = h;
        fprintf(2,'  branch solve failed at H=%g: %s\n',h,ME.message);
        return;
    end

    [t,X] = uniform_resample_solution(sol,CFG.OUTPUT_DT);
    diag = classify_tail(t,X,p,mode,CFG);
    last = struct('t',t,'X',X);
    out.horizon = h;
    if diag.resolved, break; end
end

if isempty(last), return; end
out.I = longrun_mean(last.t,last.X(:,4),diag,CFG);
out.T = longrun_mean(last.t,last.X(:,5),diag,CFG);
out.coarse = diag.coarse;
out.resolved = diag.resolved;
out.period = diag.period;
end

function d = classify_tail(t,X,p,mode,CFG)
d = empty_diag();
active = 1:10;
eq = true;

for f = CFG.TAIL_FRACTIONS
    idx = tail_index_time(t,f);
    amp = max(max(X(idx,active),[],1)-min(X(idx,active),[],1));
    xm = time_weighted_vector_mean(t(idx),X(idx,:));
    q = aigc.model_rhs(t(idx(end)),xm(:),p,mode);
    res = max(abs(q(active)));
    eq = eq && amp <= CFG.EQ_ACTIVE_AMP_TOL && res <= CFG.DERIVATIVE_TOL;
end

if eq
    d.coarse = "equilibrium";
    d.resolved = true;
    return;
end

idx = tail_index_time(t,CFG.PRIMARY_TAIL);
y = X(idx,4);
tt = t(idx);
amp = max(y)-min(y);
[per,cv,np] = cycle_period(tt,y);
dr = amplitude_drift(y);

if amp >= CFG.CYCLE_RISK_AMP_MIN && ...
        np >= CFG.CYCLE_MIN_PERIODS && ...
        cv <= CFG.CYCLE_PERIOD_CV_MAX && ...
        dr <= CFG.CYCLE_AMP_DRIFT_MAX
    d.coarse = "cycle";
    d.resolved = true;
    d.period = per;
else
    d.coarse = "unresolved";
    d.resolved = false;
end
end

function d = empty_diag()
d = struct('coarse',"unresolved",'resolved',false,'period',NaN);
end

function v = longrun_mean(t,y,d,CFG)
idx = tail_index_time(t,CFG.PRIMARY_TAIL);
if d.coarse == "cycle" && isfinite(d.period) && d.period > 0
    t0 = max(t(idx(1)),t(end)-8*d.period);
    idx = find(t>=t0);
end
v = trapz(t(idx),y(idx))/max(t(idx(end))-t(idx(1)),eps);
end

%% ======================================================================
% SUMMARIES AND STRUCTURAL DENOMINATORS
% =======================================================================
function T = summarize_variant_level_locked(A,CFG)
keys = unique(A(:,{'CandidateIndex','Family','Setting','Level'}),'rows','stable');
rows = struct([]);

for i = 1:height(keys)
    m = A.CandidateIndex == keys.CandidateIndex(i) & ...
        abs(A.Level-keys.Level(i)) < 1e-12;
    S = A(m,:);

    r = struct();
    r.CandidateIndex = keys.CandidateIndex(i);
    r.Family = keys.Family(i);
    r.Setting = keys.Setting(i);
    r.Level = keys.Level(i);
    r.NTotalIC = height(S);
    r.NBothResolvedIC = sum(S.BothResolved);
    r.NSameRegimeIC = sum(S.SameRegime);
    r.ResolvedRateIC = mean(S.BothResolved);
    r.SameRegimeRateIC = mean(S.SameRegime);

    r.AllICBothResolved = r.NBothResolvedIC == CFG.N_IC;
    r.AllICSameRegime = r.NSameRegimeIC == CFG.N_IC;

    rb = S.DeltaI_FiniteMinusNear(S.BothResolved);
    tb = S.DeltaT_FiniteMinusNear(S.BothResolved);
    rs = S.DeltaI_FiniteMinusNear(S.SameRegime);
    ts = S.DeltaT_FiniteMinusNear(S.SameRegime);

    r.MeanDeltaI_AllResolved = mean_nan(rb);
    r.MeanDeltaT_AllResolved = mean_nan(tb);
    r.MeanDeltaI_SameRegime = mean_nan(rs);
    r.MeanDeltaT_SameRegime = mean_nan(ts);

    r.RiskWorseRate_AllResolvedIC = mean_bool(rb>0);
    r.TrustWorseRate_AllResolvedIC = mean_bool(tb<0);
    r.RiskWorseRate_SameRegimeIC = mean_bool(rs>0);
    r.TrustWorseRate_SameRegimeIC = mean_bool(ts<0);

    % Strict variant-level eligibility/retention: all common ICs must be
    % resolved and in the same attractor class. This prevents pseudo-
    % replication by treating trajectories as independent structures.
    r.StrictRiskRetained = r.AllICSameRegime && ~isempty(rs) && all(rs>0);
    r.StrictTrustRetained = r.AllICSameRegime && ~isempty(ts) && all(ts<0);

    rows = append_struct(rows,r);
end
T = struct2table(rows);
end

function T = build_conclusion_denominator_audit_locked(S,Tactive,CFG)
rows = struct([]);
Nactive = height(Tactive);

for level = CFG.LEVELS
    Q = S(abs(S.Level-level)<1e-12,:);

    % There should be one summary row per active structural variant.
    if height(Q) ~= Nactive
        warning('Level %.2f has %d variant summaries but %d active variants.', ...
            level,height(Q),Nactive);
    end

    Nboth = sum(Q.AllICBothResolved);
    Nsame = sum(Q.AllICSameRegime);

    r = struct();
    r.Level = level;
    r.Conclusion = "FiniteGovernance_RiskWorse";
    r.NActiveVariants = Nactive;
    r.NBothResolvedVariants = Nboth;
    r.NSameRegimeVariants = Nsame;
    r.NRetainedVariants = sum(Q.StrictRiskRetained);
    r.BothResolvedCoverage = safe_ratio(Nboth,Nactive);
    r.SameRegimeCoverage = safe_ratio(Nsame,Nactive);
    r.DirectionalRetention = safe_ratio(r.NRetainedVariants,Nsame);
    rows = append_struct(rows,r);

    r2 = r;
    r2.Conclusion = "FiniteGovernance_TrustWorse";
    r2.NRetainedVariants = sum(Q.StrictTrustRetained);
    r2.DirectionalRetention = safe_ratio(r2.NRetainedVariants,Nsame);
    rows = append_struct(rows,r2);
end

T = struct2table(rows);
end

%% ======================================================================
% QC
% =======================================================================
function T = quality_gate_locked(Tact,Tactive,Tvarsum,Tden,CFG)
rows = struct([]);

rows = qc_add(rows,'At least one active structural variant', ...
    height(Tactive)>=1,height(Tactive),1,'');
rows = qc_add(rows,'No unsupported variant entered active denominator', ...
    all(Tactive.StaticSupported),sum(~Tactive.StaticSupported),0,'');
rows = qc_add(rows,'No no-op variant entered active denominator', ...
    all(Tactive.MaxRHSDiff>CFG.RHS_TOL),min(Tactive.MaxRHSDiff),CFG.RHS_TOL,'');
rows = qc_add(rows,'No baseline-equivalent variant entered active denominator', ...
    all(~Tactive.BaselineEquivalent),sum(Tactive.BaselineEquivalent),0,'');
rows = qc_add(rows,'No duplicate variant entered active denominator', ...
    all(Tactive.DuplicateOf==""),sum(Tactive.DuplicateOf~=""),0,'');
rows = qc_add(rows,'All requested near-ideal levels present', ...
    all(ismember(CFG.LEVELS,unique(Tvarsum.Level)')), ...
    numel(unique(Tvarsum.Level)),numel(CFG.LEVELS),'');
rows = qc_add(rows,'Denominator ordering valid', ...
    all(Tden.NRetainedVariants<=Tden.NSameRegimeVariants & ...
        Tden.NSameRegimeVariants<=Tden.NBothResolvedVariants & ...
        Tden.NBothResolvedVariants<=Tden.NActiveVariants), ...
    max(Tden.NSameRegimeVariants-Tden.NBothResolvedVariants),0,'');
rows = qc_add(rows,'Activation audit includes every candidate', ...
    height(Tact)>=height(Tactive)+1,height(Tact),height(Tactive)+1,'');

T = struct2table(rows);
end

function rows = qc_add(rows,name,pass,value,tolerance,note)
r = struct('Check',string(name),'Pass',logical(pass),'Value',value, ...
    'Tolerance',tolerance,'Note',string(note));
rows = append_struct(rows,r);
end

%% ======================================================================
% REPORTING
% =======================================================================
function write_report_locked(fn,CFG,root,parameterSource,Tact,Tactive,S,D,Q)
fid = fopen(fn,'w');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'Exp09 structural robustness + RHS activation audit\n');
fprintf(fid,'===================================================\n');
fprintf(fid,'Project: %s\n',root);
fprintf(fid,'Run mode: %s\n',CFG.RUN_MODE);
fprintf(fid,'Parameter source: %s\n',parameterSource);
fprintf(fid,'RHS activation tolerance: %.3e\n',CFG.RHS_TOL);
fprintf(fid,'RHS probes: %d\n',CFG.N_RHS_PROBES);
fprintf(fid,'Common ICs: %d\n',CFG.N_IC);
fprintf(fid,'Near-ideal primitive levels: %s\n\n',mat2str(CFG.LEVELS));

fprintf(fid,'STRUCTURAL QUALIFICATION\n');
fprintf(fid,'------------------------\n');
fprintf(fid,'Candidate variants excluding baseline: %d\n',sum(~Tact.IsBaseline));
fprintf(fid,'Active unique variants: %d\n',height(Tactive));
fprintf(fid,'Excluded variants: %d\n\n',sum(~Tact.Active & ~Tact.IsBaseline));

for i = 1:height(Tact)
    if Tact.IsBaseline(i), continue; end
    fprintf(fid,'%-18s %-12s | static=%d | maxRhsDiff=%.3e | changedProbes=%d | active=%d | %s\n', ...
        char(Tact.Family(i)),char(Tact.Setting(i)),Tact.StaticSupported(i), ...
        Tact.MaxRHSDiff(i),Tact.NChangedProbes(i),Tact.Active(i), ...
        char(Tact.ExclusionReason(i)));
end

fprintf(fid,'\nSTRICT STRUCTURAL DENOMINATORS\n');
fprintf(fid,'------------------------------\n');
for i = 1:height(D)
    fprintf(fid,'%s | level=%.2f | active=%d | both-resolved=%d | same-regime=%d | retained=%d | same coverage=%.1f%% | retention=%s\n', ...
        char(D.Conclusion(i)),D.Level(i),D.NActiveVariants(i), ...
        D.NBothResolvedVariants(i),D.NSameRegimeVariants(i),D.NRetainedVariants(i), ...
        100*D.SameRegimeCoverage(i),pct_or_na(D.DirectionalRetention(i)));
end

fprintf(fid,'\nIMPORTANT INTERPRETATION\n');
fprintf(fid,['1) The active structural denominator is determined by the code/RHS audit, ', ...
    'not by a historical planned number.\n']);
fprintf(fid,['2) Directional retention is computed only on strict same-regime structural ', ...
    'variants; unresolved comparisons are excluded.\n']);
fprintf(fid,['3) 0.90/0.95/0.98 are primitive governance-channel floors/ceilings, ', ...
    'not end-to-end p_act targets.\n']);
fprintf(fid,['4) This runner audits the safely reconstructable structural candidate ', ...
    'families; it must not be relabeled as an exact historical 19-variant ', ...
    'factory unless that factory is explicitly recovered and merged.\n']);

fprintf(fid,'\nQUALITY GATES\n');
fprintf(fid,'-------------\n');
for i = 1:height(Q)
    fprintf(fid,'%s: %d\n',char(Q.Check(i)),Q.Pass(i));
end

fprintf(fid,'\nVariant-level details are in exp09_variant_level_summary.csv.\n');
end

function s = pct_or_na(x)
if isfinite(x), s = sprintf('%.1f%%',100*x); else, s = 'NA'; end
end

%% ======================================================================
% FIGURES
% =======================================================================
function plot_figure9_publication_locked(Tact,Tden,CFG,outDir)
%PLOT_FIGURE9_PUBLICATION_LOCKED
% Supplementary structural audit figure designed around the evidence logic used in Sec. 3.8:
%
%   RHS activation
%      -> valid structural denominator
%      -> both-resolved
%      -> same-regime
%      -> conditional directional retention
%
% Layout:
%   (a) full-width RHS activation qualification
%   (b) structural evidence funnel
%   (c) same-regime coverage vs conditional direction retention
%
% Important visual rule:
%   Detailed variant-level risk gaps are intentionally NOT placed in the
%   main figure; they are exported separately for the Supplement.

fig = figure( ...
    'Visible','off', ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 18.0 13.2], ...
    'Renderer','painters');

set(fig,'InvertHardcopy','off');

tl = tiledlayout(fig,2,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

%% ----------------------------------------------------------------------
% (a) RHS activation qualification
% -----------------------------------------------------------------------
ax1 = nexttile(tl,[1 2]);
hold(ax1,'on');

Q = Tact(~Tact.IsBaseline,:);
if isempty(Q)
    error('structural audit figure: no non-baseline structural candidates are available.');
end

% Never use REALMIN here: log10(realmin) is approximately -308 and would
% destroy the useful vertical scale.  No-op/unsupported candidates are
% drawn two decades below the activation threshold instead.
plotFloor = CFG.RHS_TOL*1e-2;
xval = log10(max(Q.MaxRHSDiff,plotFloor));

labels = strings(height(Q),1);
for i = 1:height(Q)
    labels(i) = short_variant_name_local(Q.Family(i),Q.Setting(i));
end

y = (1:height(Q))';
active = Q.Active;
excluded = ~Q.Active;

% Active variants: filled circles.
if any(active)
    scatter(ax1,xval(active),y(active),46,'o','filled', ...
        'DisplayName','Active');
end

% Excluded/no-op variants: open squares.
if any(excluded)
    scatter(ax1,xval(excluded),y(excluded),48,'s', ...
        'LineWidth',1.15, ...
        'DisplayName','Excluded / no-op');
end

xline(ax1,log10(CFG.RHS_TOL),'--', ...
    'RHS activation threshold', ...
    'LineWidth',1.0, ...
    'LabelVerticalAlignment','bottom', ...
    'LabelHorizontalAlignment','left');

yticks(ax1,y);
yticklabels(ax1,cellstr(labels));
set(ax1,'YDir','reverse','TickLabelInterpreter','tex');

xlabel(ax1,'$\log_{10}\!\left(\max_k\|F_v(X^{(k)})-F_0(X^{(k)})\|_\infty\right)$', ...
    'Interpreter','latex');
ylabel(ax1,'Candidate structural variant');

% Keep a compact, scientifically useful x-range.
xmin = min([xval(:); log10(CFG.RHS_TOL)-2]);
xmax = max([xval(:); log10(CFG.RHS_TOL)+1]);
xlim(ax1,[floor(xmin)-0.25 ceil(xmax)+0.25]);

grid(ax1,'on');
ax1.YGrid = 'off';
ax1.GridAlpha = 0.12;
ax1.MinorGridAlpha = 0.06;
ax1.Box = 'off';
ax1.FontName = 'Arial';
ax1.FontSize = 8.5;
ax1.LineWidth = 0.8;

legend(ax1,'Location','best','Box','off');

text(ax1,0.01,0.98,'(a)', ...
    'Units','normalized', ...
    'VerticalAlignment','top', ...
    'FontWeight','bold', ...
    'FontSize',10.5);

%% ----------------------------------------------------------------------
% (b) Structural evidence funnel
% -----------------------------------------------------------------------
ax2 = nexttile(tl,3);
hold(ax2,'on');

R = Tden(Tden.Conclusion=="FiniteGovernance_RiskWorse",:);
R = sortrows(R,'Level');
if isempty(R)
    error('structural audit figure: risk conclusion denominator audit is empty.');
end

Y = [ ...
    R.NActiveVariants, ...
    R.NBothResolvedVariants, ...
    R.NSameRegimeVariants, ...
    R.NRetainedVariants];

stages = 1:4;

% Slight horizontal offsets prevent exactly overlapping trajectories
% (e.g. the 0.95 and 0.98 levels can have identical counts).
if height(R)==1
    offsets = 0;
else
    offsets = linspace(-0.07,0.07,height(R));
end
markers = {'o','s','^','d','v','>'};

for i = 1:height(R)
    mk = markers{1+mod(i-1,numel(markers))};
    xx = stages + offsets(i);

    plot(ax2,xx,Y(i,:),['-' mk], ...
        'LineWidth',1.35, ...
        'MarkerSize',5.8, ...
        'DisplayName',sprintf('L = %.2f',R.Level(i)));

    % Count labels.  Small level-specific vertical offsets reduce overlap.
    dy = 0.16 + 0.14*(i-1);
    for j = 1:4
        text(ax2,xx(j),Y(i,j)+dy,sprintf('%d',Y(i,j)), ...
            'HorizontalAlignment','center', ...
            'VerticalAlignment','bottom', ...
            'FontSize',7.3);
    end
end

xlim(ax2,[0.72 4.28]);
ylim(ax2,[0 max(R.NActiveVariants)+1.8]);

xticks(ax2,stages);
xticklabels(ax2,{'Active','Both resolved','Same regime','Retained'});
xtickangle(ax2,16);

ylabel(ax2,'Number of structural variants');

grid(ax2,'on');
ax2.XGrid = 'off';
ax2.GridAlpha = 0.12;
ax2.Box = 'off';
ax2.FontName = 'Arial';
ax2.FontSize = 8.3;
ax2.LineWidth = 0.8;

legend(ax2,'Location','southwest','Box','off');

text(ax2,0.01,0.98,'(b)', ...
    'Units','normalized', ...
    'VerticalAlignment','top', ...
    'FontWeight','bold', ...
    'FontSize',10.5);

%% ----------------------------------------------------------------------
% (c) Same-regime coverage vs conditional directional retention
% -----------------------------------------------------------------------
ax3 = nexttile(tl,4);
hold(ax3,'on');

coverage = 100*R.SameRegimeCoverage;
retention = 100*R.DirectionalRetention;

levelLabels = categorical(compose('L = %.2f',R.Level));
levelLabels = reordercats(levelLabels,cellstr(compose('L = %.2f',R.Level)));

B = bar(ax3,levelLabels,[coverage retention],'grouped');

ylabel(ax3,'Rate (%)');
ylim(ax3,[0 110]);
yticks(ax3,0:20:100);

legend(ax3, ...
    {'Same-regime coverage', ...
     'Conditional direction retention'}, ...
    'Location','southoutside', ...
    'Orientation','vertical', ...
    'Box','off');

grid(ax3,'on');
ax3.XGrid = 'off';
ax3.GridAlpha = 0.12;
ax3.Box = 'off';
ax3.FontName = 'Arial';
ax3.FontSize = 8.5;
ax3.LineWidth = 0.8;

% Direct data labels make the central result immediately readable.
for k = 1:numel(B)
    try
        xt = B(k).XEndPoints;
        yt = B(k).YEndPoints;
    catch
        % Compatibility fallback for older MATLAB releases.
        ngroups = numel(coverage);
        nbars = numel(B);
        groupWidth = min(0.8,nbars/(nbars+1.5));
        xt = (1:ngroups) - groupWidth/2 + ...
            (2*k-1)*groupWidth/(2*nbars);
        yt = B(k).YData;
    end

    for j = 1:numel(yt)
        if isfinite(yt(j))
            text(ax3,xt(j),yt(j)+2,sprintf('%.0f%%',yt(j)), ...
                'HorizontalAlignment','center', ...
                'VerticalAlignment','bottom', ...
                'FontSize',7.8);
        end
    end
end

% Short explanatory cue: retention is conditional on same-regime
% eligibility, not on the full active denominator.
text(ax3,0.50,0.04, ...
    'Retention is conditional on same-regime eligibility', ...
    'Units','normalized', ...
    'HorizontalAlignment','center', ...
    'FontSize',7.1);

text(ax3,0.01,0.98,'(c)', ...
    'Units','normalized', ...
    'VerticalAlignment','top', ...
    'FontWeight','bold', ...
    'FontSize',10.5);

%% ----------------------------------------------------------------------
% Export
% -----------------------------------------------------------------------
outBase = fullfile(outDir,'fig_exp09_main');

savefig(fig,[outBase '.fig']);

try
    exportgraphics(fig,[outBase '.pdf'], ...
        'ContentType','vector', ...
        'BackgroundColor','white');
    exportgraphics(fig,[outBase '.png'], ...
        'Resolution',600, ...
        'BackgroundColor','white');
catch
    % Compatibility fallback.
    print(fig,[outBase '.pdf'],'-dpdf','-painters','-bestfit');
    print(fig,[outBase '.png'],'-dpng','-r600');
end

close(fig);
end

function plot_risk_gap_supplement_locked(S,outDir)
%PLOT_RISK_GAP_SUPPLEMENT_LOCKED
% Detailed variant-level signed risk-gap evidence for the Supplement.
% Horizontal bars avoid the long/angled x-label problem of the old figure.

Q = S(abs(S.Level-0.95)<1e-12,:);
if isempty(Q), return; end

labels = strings(height(Q),1);
for i = 1:height(Q)
    labels(i) = short_variant_name_local(Q.Family(i),Q.Setting(i));
end

vals = Q.MeanDeltaI_SameRegime;

% Place finite values first and preserve a stable order within equal status.
finiteMask = isfinite(vals);
order = [find(finiteMask); find(~finiteMask)];
Q = Q(order,:);
labels = labels(order);
vals = vals(order);

fig = figure( ...
    'Visible','off', ...
    'Color','w', ...
    'Units','centimeters', ...
    'Position',[2 2 17.5 11.5], ...
    'Renderer','painters');

ax = axes(fig);
hold(ax,'on');

y = (1:height(Q))';
barh(ax,y,vals,0.68);
xline(ax,0,'--','LineWidth',0.9);

yticks(ax,y);
yticklabels(ax,cellstr(labels));
set(ax,'YDir','reverse','TickLabelInterpreter','tex');

xlabel(ax,'Mean $I_{\rm finite}-I_{\rm near\mbox{-}ideal}$ (same-regime ICs)', ...
    'Interpreter','latex');
ylabel(ax,'Active structural variant');

grid(ax,'on');
ax.YGrid = 'off';
ax.GridAlpha = 0.12;
ax.Box = 'off';
ax.FontName = 'Arial';
ax.FontSize = 8.5;
ax.LineWidth = 0.8;

outBase = fullfile(outDir,'fig_exp09_risk_gap_level095_supp');
savefig(fig,[outBase '.fig']);

try
    exportgraphics(fig,[outBase '.pdf'], ...
        'ContentType','vector', ...
        'BackgroundColor','white');
    exportgraphics(fig,[outBase '.png'], ...
        'Resolution',600, ...
        'BackgroundColor','white');
catch
    print(fig,[outBase '.pdf'],'-dpdf','-painters','-bestfit');
    print(fig,[outBase '.png'],'-dpng','-r600');
end

close(fig);
end

function s = short_variant_name_local(family,setting)
%SHORT_VARIANT_NAME_LOCAL Compact publication labels.

family = string(family);
setting = string(setting);

switch family
    case "thresholdForm"
        if setting=="hill"
            s = "Threshold: Hill";
        elseif setting=="piecewise"
            s = "Threshold: piecewise";
        else
            s = "Threshold: " + setting;
        end

    case "auditBoundary"
        if setting=="sqrt"
            s = "Audit boundary: sqrt";
        elseif setting=="projected"
            s = "Audit boundary: projected";
        else
            s = "Audit boundary: " + setting;
        end

    case "aigcRiskForm"
        if setting=="saturating"
            s = "AIGC risk: saturating";
        elseif setting=="hill"
            s = "AIGC risk: Hill";
        else
            s = "AIGC risk: " + setting;
        end

    case "mutationRate"
        s = "\epsilon = " + setting;

    otherwise
        s = family + ": " + setting;
end
end

%% ======================================================================
% VARIANT MATCHING HELPERS
% =======================================================================
function f = audit_boundary_factor_local(u,mode)
form = 'logistic';
if isfield(mode,'auditBoundaryForm'), form = lower(char(mode.auditBoundaryForm)); end
switch form
    case 'sqrt', f = sqrt(max(u*(1-u),0));
    case 'projected', f = 1;
    otherwise, f = u*(1-u);
end
f = max(f,1e-12);
end

function psi = matched_aigc_psi_local(p0,form,Eref)
baseForm = 'linear';
m = aigc.full_mode();
if isfield(m,'aigcRiskForm'), baseForm = char(m.aigcRiskForm); end
baseVal = aigc_shape_local(baseForm,Eref,p0);
newVal = aigc_shape_local(form,Eref,p0);
psi = getfield_default(p0,'psiE',0)*baseVal/max(newVal,eps);
end

function g = aigc_shape_local(form,E,p)
K = getfield_default(p,'KE',0.25);
n = getfield_default(p,'hillE',2);
switch lower(form)
    case 'linear', g = E;
    case 'saturating', g = E/(K+E+eps);
    case 'hill', g = E^n/(K^n+E^n+eps);
    otherwise, g = E;
end
end

%% ======================================================================
% COMMON UTILITIES
% =======================================================================
function tf = token_present_local(files,token)
tf = false;
for k = 1:numel(files)
    try
        txt = fileread(fullfile(files(k).folder,files(k).name));
        if contains(txt,token)
            tf = true;
            return;
        end
    catch
    end
end
end

function X = get_common_initial_conditions_locked(n,x0)
if exist('aigc.random_initial_states','file') == 2
    try
        X = aigc.random_initial_states(n);
        if size(X,2)==10, return; end
    catch
    end
end
X = repmat(x0(:)',n,1);
for i = 1:n
    X(i,:) = min(max(x0(:)'+0.08*(2*rand(1,10)-1),0.02),0.98);
end
end

function [p,source] = get_R1_parameters_locked(pBase)
if exist('aigc.representative_regimes','file') == 2
    try
        R = aigc.representative_regimes(pBase);
        if ~isempty(R) && isfield(R(1),'p')
            p = R(1).p;
            source = 'aigc.representative_regimes(1).p';
            return;
        end
    catch
    end
end

% Audited fallback used by the existing Exp09-P1 runner.
p = pBase;
if isfield(p,'epsP'), p.epsP = .05; end
if isfield(p,'epsF'), p.epsF = .05; end
if isfield(p,'epsU'), p.epsU = .05; end
if isfield(p,'alpha'), p.alpha = .30; end
if isfield(p,'delta'), p.delta = .40; end
if isfield(p,'etaC'), p.etaC = 4; end
if isfield(p,'Cstar'), p.Cstar = .25; end
source = 'local audited R1 fallback';
end

function idx = tail_index_time(t,f)
t = t(:);
idx = find(t >= t(end)-f*(t(end)-t(1)));
end

function v = time_weighted_vector_mean(t,X)
t = t(:);
v = trapz(t,X,1)/max(t(end)-t(1),eps);
end

function [p,cv,n] = cycle_period(t,y)
pk = find(y(2:end-1)>y(1:end-2) & y(2:end-1)>=y(3:end))+1;
if numel(pk)<2
    p = NaN; cv = Inf; n = 0; return;
end
q = diff(t(pk));
p = mean(q);
cv = std(q)/max(p,eps);
n = numel(q);
end

function d = amplitude_drift(y)
m = floor(numel(y)/2);
if m<2, d=Inf; return; end
a = max(y(1:m))-min(y(1:m));
b = max(y(m+1:end))-min(y(m+1:end));
d = abs(a-b)/max([a,b,eps]);
end

function [tOut,XOut] = uniform_resample_solution(sol,dt)
t = sol.t(:);
X = sol.X;
if numel(t)<2
    tOut=t; XOut=X; return;
end
tOut = (t(1):dt:t(end))';
if tOut(end)<t(end)-1e-12
    tOut = [tOut;t(end)];
else
    tOut(end)=t(end);
end
XOut = interp1(t,X,tOut,'pchip');
XOut = min(max(XOut,0),1);
end

function rows = append_struct(rows,r)
if isempty(rows), rows=r; else, rows(end+1)=r; end
end

function d = binary_delta(a,b)
if isfinite(a) && isfinite(b), d=a-b; else, d=NaN; end
end

function v = mean_nan(x)
x = x(isfinite(x));
if isempty(x), v=NaN; else, v=mean(x); end
end

function v = mean_bool(x)
if isempty(x), v=NaN; else, v=mean(x); end
end

function r = safe_ratio(a,b)
if b<=0, r=NaN; else, r=a/b; end
end

function v = getfield_default(S,n,d)
if isfield(S,n) && ~isempty(S.(n)), v=S.(n); else, v=d; end
end

function save_figure_local(fig,outDir,name)
savefig(fig,fullfile(outDir,[name '.fig']));
try
    exportgraphics(fig,fullfile(outDir,[name '.png']),'Resolution',600);
    exportgraphics(fig,fullfile(outDir,[name '.pdf']),'ContentType','vector');
catch
    print(fig,fullfile(outDir,[name '.png']),'-dpng','-r600');
    print(fig,fullfile(outDir,[name '.pdf']),'-dpdf','-bestfit');
end
close(fig);
end

function root = locate_project_root_locked(startDir)
root = '';
probe = which('aigc.default_parameters');
if ~isempty(probe)
    c = fileparts(fileparts(probe));
    if exist(fullfile(c,'+aigc'),'dir')==7
        root=c; return;
    end
end
C = {startDir,pwd};
for b = {startDir,pwd}
    c = b{1};
    for u = 1:7
        if isempty(c), break; end
        C{end+1} = c; %#ok<AGROW>
        c2 = fileparts(c);
        if strcmp(c2,c), break; end
        c = c2;
    end
end
for k = 1:numel(C)
    if ~isempty(C{k}) && exist(fullfile(C{k},'+aigc'),'dir')==7
        root=C{k}; return;
    end
end
end


function resolvedPath = assert_unique_package_version_locked(fn,expectedRoot)
%ASSERT_UNIQUE_PACKAGE_VERSION_LOCKED
% Publication hard lock for MATLAB package-path ambiguity.
% The function must:
%   (i) be resolvable on the current MATLAB path;
%   (ii) resolve to exactly one unique file;
%   (iii) resolve inside the selected ACTIVE V10 project root.
%
% This prevents a stale V9/V10 snapshot elsewhere on the MATLAB path from
% silently supplying model_rhs / solve_model / parameter files.

if nargin < 2 || isempty(expectedRoot)
    expectedRoot = '';
end

hits = which(fn,'-all');
if isempty(hits)
    error('EXP09:PackageFunctionMissing', ...
        'Required package function is not on the MATLAB path: %s',fn);
end

% Normalize WHICH -ALL output across MATLAB releases.
if ischar(hits)
    if size(hits,1) > 1
        hits = cellstr(hits);
    else
        hits = {hits};
    end
elseif isstring(hits)
    hits = cellstr(hits(:));
elseif iscell(hits)
    hits = hits(:);
else
    error('EXP09:UnexpectedWhichOutput', ...
        'Unexpected output type from which(''%s'',''-all'').',fn);
end

hits = cellfun(@strtrim,hits,'UniformOutput',false);
hits = hits(~cellfun(@isempty,hits));
hits = unique(hits,'stable');

if numel(hits) ~= 1
    msg = sprintf('Multiple MATLAB implementations of %s are active on the path:\n',fn);
    for ii = 1:numel(hits)
        msg = sprintf('%s  [%d] %s\n',msg,ii,hits{ii}); %#ok<AGROW>
    end
    msg = sprintf(['%sExp09 is stopped deliberately because structural activation auditing ' ...
        'is invalid under path ambiguity. Remove old V9/V10 snapshots from the path, ' ...
        'run clear functions; rehash; and rerun.'],msg);
    error('EXP09:MultiplePackageVersions','%s',msg);
end

resolvedPath = hits{1};

% Check that the unique implementation is the one under the selected root.
if ~isempty(expectedRoot)
    expectedRoot = char(java.io.File(expectedRoot).getCanonicalPath());
    resolvedCanon = char(java.io.File(resolvedPath).getCanonicalPath());
    expectedPrefix = [expectedRoot filesep];

    if ispc
        inExpectedRoot = strncmpi(resolvedCanon,expectedPrefix,numel(expectedPrefix));
    else
        inExpectedRoot = strncmp(resolvedCanon,expectedPrefix,numel(expectedPrefix));
    end

    if ~inExpectedRoot
        error('EXP09:WrongPackageRoot', ...
            ['%s resolves outside the selected ACTIVE V10 root.\n' ...
             'Selected root : %s\n' ...
             'Resolved file : %s\n' ...
             'Remove the conflicting path entry before running Exp09.'], ...
             fn,expectedRoot,resolvedCanon);
    end
end

fprintf('  [PATH LOCK] %-30s -> %s\n',fn,resolvedPath);
end

function warn_if_multiple_package_versions(fn)
h = which(fn,'-all');
if ischar(h), h={h}; end
if numel(h)>1
    fprintf(2,'WARNING: multiple %s versions on path.\n',fn);
    for k=1:numel(h), fprintf(2,'  %s\n',h{k}); end
end
end
