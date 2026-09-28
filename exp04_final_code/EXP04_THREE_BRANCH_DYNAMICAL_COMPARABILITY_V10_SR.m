function outputDir = EXP04_THREE_BRANCH_DYNAMICAL_COMPARABILITY_V10_SR()
%EXP04_THREE_BRANCH_DYNAMICAL_COMPARABILITY_V10_SR
% ========================================================================
% Exp04 supplementary audit: three-branch long-run dynamical comparability
%
% PURPOSE
%   Close the remaining Exp04 evidence gap by auditing, at every point of
%   both 31x31 parameter planes, whether the following three branches are
%   in comparable certified long-run dynamical states:
%
%       no AIGC  |  capacity-matched fixed AIGC  |  dynamic AIGC
%
%   The script reports
%       P_cap   = P(C_fix = C_no,   both certified)
%       P_adapt = P(C_dyn = C_fix,  both certified)
%       P_net   = P(C_dyn = C_no,   both certified)
%       P_three = P(C_no = C_fix = C_dyn, all certified)
%
%   and re-evaluates the locked Exp04 effect-direction statistics on the
%   SAME-DYNAMICAL-REGIME subsets. Unresolved trajectories are NEVER
%   treated as mutually comparable merely because both are unresolved.
%
% IMPORTANT SCIENTIFIC RULES
%   1) The existing locked effect values (NetDeltaI, NetDeltaT,
%      AdaptationDeltaI) are not overwritten.
%   2) If the locked CSV already contains no/fixed branch classification,
%      those classifications are reused. Missing branches are rerun.
%   3) If a matched fixed-E column exists, it is reused. Otherwise the
%      dynamic branch is rerun and its certified long-run mean E is used.
%   4) For no/fixed AIGC, E is frozen and EXCLUDED from active-state
%      equilibrium residual/amplitude checks.
%   5) The default classifier below is manuscript-locked:
%        H = 600 -> 1200 -> 2400
%        tail windows = 25%, 40%, 50%
%        equilibrium active-state amplitude <= 1e-4
%        active vector-field residual <= 1e-6
%        boundary tolerance = 1e-4
%        certified cycle: risk amplitude >= 2e-3,
%                         >= 8 periods,
%                         period CV <= 0.02,
%                         amplitude drift <= 0.05
%
% EXPECTED INPUTS
%   Rich V10 FULL Exp04 CSV files containing at least:
%       exp04_plane_rhoE_s*.csv
%       exp04_plane_psiE_FP*.csv
%
%   The script automatically searches the active V10 project outputs.
%   If it cannot find them, a folder chooser is shown.
%
% OUTPUTS
%   outputs/Exp04_three_branch_comparability_<timestamp>/
%       exp04_three_branch_comparability_rhoE_s.csv
%       exp04_three_branch_comparability_psiE_FP.csv
%       exp04_three_branch_comparability_summary.csv
%       exp04_transition_counts_*.csv
%       fig_exp04_three_branch_comparability_mask_rhoE_s.{png,pdf,fig}
%       fig_exp04_three_branch_dynamics_supplement.{png,pdf,fig}
%       EXP04_THREE_BRANCH_COMPARABILITY_REPORT.txt
%       EXP04_three_branch_protocol.mat
%
% DIRECT RUN
%   Put this file anywhere, make sure the intended V10 +aigc package is
%   available, and run:
%
%       EXP04_THREE_BRANCH_DYNAMICAL_COMPARABILITY_V10
%
% ========================================================================

clc;
close all force;

fprintf('\n====================================================================\n');
fprintf(' Exp04 | THREE-BRANCH DYNAMICAL COMPARABILITY AUDIT | V10\n');
fprintf('====================================================================\n');

%% ========================================================================
% 0. USER-LEVEL SETTINGS
% ========================================================================
CFG.RUN_MODE = 'full';
CFG.SHOW_FIGURES = true;

% Reuse exact locked classifications if the CSV already contains them.
% This preserves the original Exp04 numerical protocol whenever possible.
CFG.PREFER_LOCKED_BRANCH_CLASSES = true;

% Set true only if you want a fully independent re-certification of all
% three branches with THIS audit script. The default false preserves the
% locked dynamic classification and reruns only missing no/fixed classes.
CFG.FORCE_RERUN_ALL_THREE = false;

% When a required branch class is absent from the CSV, rerun that branch.
CFG.RERUN_MISSING_BRANCHES = true;

% If no explicit matched fixed-E column exists, recompute matched E from
% the dynamic branch. The script records this in the protocol report.
CFG.ALLOW_RECOMPUTE_MATCHED_E = true;

% Resume long audits after interruption.
CFG.RESUME_FROM_CHECKPOINT = true;
CFG.CHECKPOINT_EVERY = 20;

% Manuscript-locked classifier.
CFG.HORIZONS = [600 1200 2400];
CFG.TAIL_FRACTIONS = [0.25 0.40 0.50];
CFG.PRIMARY_TAIL_FRACTION = 0.40;
CFG.CLASSIFIER_SOLVER = 'ode45';
CFG.ODE_REL_TOL = 1e-9;
CFG.ODE_ABS_TOL = 1e-11;
CFG.OUTPUT_DT = 0.025;  % manuscript-unified diagnostic output grid
CFG.EQ_ACTIVE_AMP_TOL = 1e-4;
CFG.DERIVATIVE_TOL = 1e-6;
CFG.BOUNDARY_TOL = 1e-4;
CFG.CYCLE_RISK_AMP_MIN = 2e-3;
CFG.CYCLE_MIN_PERIODS = 8;
CFG.CYCLE_PERIOD_CV_MAX = 0.02;
CFG.CYCLE_AMP_DRIFT_MAX = 0.05;

% Optional consistency warning thresholds.
CFG.EXPECTED_RHO_NET_RISK_PCT = 11.3;
CFG.EXPECTED_RHO_ADAPT_RISK_PCT = 94.9;
CFG.EXPECTED_PSI_NET_RISK_PCT = 34.3;
CFG.EXPECTED_PSI_ADAPT_RISK_PCT = 93.8;
CFG.EXPECTED_TOL_PCT = 0.20;

%% ========================================================================
% 1. LOCATE AND VERIFY ACTIVE V10 PACKAGE
% ========================================================================
thisFile = mfilename('fullpath');
if isempty(thisFile)
    startDir = pwd;
else
    startDir = fileparts(thisFile);
end

projectRoot = locate_project_root_locked(startDir);
if isempty(projectRoot)
    error(['Could not locate the active V10 project root. ', ...
           'Run this audit through RUN_EXP04_FINAL_SR_V4.m so the ', ...
           'archive-relative V10 path is activated automatically.']);
end

addpath(projectRoot);
rehash;

requiredPkg = {'default_parameters','default_options','experiment_settings', ...
               'full_mode','solve_model','model_rhs'};
for k = 1:numel(requiredPkg)
    f = fullfile(projectRoot,'+aigc',[requiredPkg{k} '.m']);
    if exist(f,'file') ~= 2
        error('Incomplete V10 package. Missing required file: %s',f);
    end
end

warn_if_multiple_package_versions('aigc.solve_model');
warn_if_multiple_package_versions('aigc.model_rhs');

fprintf('Project root      : %s\n',projectRoot);
fprintf('Resolved solver   : %s\n',which('aigc.solve_model'));
fprintf('Resolved RHS      : %s\n',which('aigc.model_rhs'));

%% ========================================================================
% 2. LOAD OFFICIAL V10 CONFIGURATION AND R1 PARAMETERS
% ========================================================================
pBase = aigc.default_parameters();
optBase = aigc.default_options(CFG.RUN_MODE);
settings = aigc.experiment_settings(CFG.RUN_MODE);

try
    aigc.validate_model_configuration(pBase,optBase,settings);
catch
    try
        aigc.validate_model_configuration(pBase,optBase);
    catch ME
        warning('validate_model_configuration could not be called: %s',ME.message);
    end
end

[pRef,parameterSource] = get_R1_parameters_locked(pBase);

if ~isfield(optBase,'X0') || numel(optBase.X0) ~= 10
    error('The active V10 default_options does not provide a 10-D opt.X0.');
end
X0Base = optBase.X0(:);

fprintf('Parameter source  : %s\n',parameterSource);
fprintf('Initial-state src : active V10 opt.X0\n');

%% ========================================================================
% 3. LOCATE THE LOCKED V10 FULL EXP04 CSV FOLDER
% ========================================================================
dataDir = locate_rich_exp04_data_dir(projectRoot,startDir);
if isempty(dataDir)
    error(['Could not locate the newly generated Exp04 primary plane CSVs. ', ...
           'Run this audit through RUN_EXP04_FINAL_SR_V4.m.']);
end

rhoFile = find_rich_plane_file(dataDir,'exp04_plane_rhoE_s');
psiFile = find_rich_plane_file(dataDir,'exp04_plane_psiE_FP');

if isempty(rhoFile) || isempty(psiFile)
    error(['Could not find both rich V10 FULL Exp04 plane CSV files in: ' dataDir]);
end

Trho0 = readtable(rhoFile,'VariableNamingRule','preserve');
Tpsi0 = readtable(psiFile,'VariableNamingRule','preserve');

assert_required_vars(Trho0,{'rhoE','s','NetDeltaI','NetDeltaT', ...
    'AdaptationDeltaI','DynamicDynamics','DynamicResolved','CapacityMatchError'});
assert_required_vars(Tpsi0,{'psiE','FP','NetDeltaI','NetDeltaT', ...
    'AdaptationDeltaI','DynamicDynamics','DynamicResolved','CapacityMatchError'});

fprintf('\nLocked Exp04 inputs:\n');
fprintf('  rho_E x s : %s\n',rhoFile);
fprintf('  psi_E x F_P: %s\n',psiFile);
fprintf('  rows       : %d and %d\n',height(Trho0),height(Tpsi0));

check_locked_effect_map(Trho0,'rhoE_s',CFG);
check_locked_effect_map(Tpsi0,'psiE_FP',CFG);

if height(Trho0) ~= 961 || height(Tpsi0) ~= 961
    warning('One or both planes do not contain exactly 961 points. Audit will still proceed.');
end

%% ========================================================================
% 4. OUTPUT DIRECTORY / DIARY / PROTOCOL
% ========================================================================
stamp = datestr(now,'yyyymmdd_HHMMSS');
outputDir = fullfile(projectRoot,'outputs', ...
    ['Exp04_three_branch_comparability_' stamp]);
if ~exist(outputDir,'dir'), mkdir(outputDir); end

diaryFile = fullfile(outputDir,'run_log.txt');
diary(diaryFile);
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('\nOutput directory : %s\n',outputDir);

save(fullfile(outputDir,'EXP04_three_branch_protocol.mat'), ...
    'CFG','pBase','pRef','optBase','settings','X0Base', ...
    'projectRoot','dataDir','rhoFile','psiFile','parameterSource','-v7.3');

write_protocol_text(fullfile(outputDir,'EXP04_three_branch_protocol.txt'), ...
    CFG,projectRoot,dataDir,rhoFile,psiFile,parameterSource,X0Base);

%% ========================================================================
% 5. AUDIT BOTH PARAMETER PLANES
% ========================================================================
planeRho = make_plane_spec('rhoE_s','rhoE','s', ...
    '\rho_E','s','AIGC adaptation induction','Detection sensitivity');
planePsi = make_plane_spec('psiE_FP','psiE','FP', ...
    '\psi_E','F_P','AIGC risk amplification','Penalty pressure');

fprintf('\n====================================================================\n');
fprintf(' AUDIT 1/2: rho_E x s\n');
fprintf('====================================================================\n');
[Trho,metaRho] = audit_one_plane(Trho0,planeRho,pRef,X0Base,optBase,CFG,outputDir);

fprintf('\n====================================================================\n');
fprintf(' AUDIT 2/2: psi_E x F_P\n');
fprintf('====================================================================\n');
[Tpsi,metaPsi] = audit_one_plane(Tpsi0,planePsi,pRef,X0Base,optBase,CFG,outputDir);

rhoOut = fullfile(outputDir,'exp04_three_branch_comparability_rhoE_s.csv');
psiOut = fullfile(outputDir,'exp04_three_branch_comparability_psiE_FP.csv');
writetable(Trho,rhoOut);
writetable(Tpsi,psiOut);

%% ========================================================================
% 6. SUMMARY STATISTICS: COVERAGE + CONDITIONAL AGREEMENT + EFFECT ROBUSTNESS
% ========================================================================
Srho = summarize_comparability(Trho,'rho_E x s');
Spsi = summarize_comparability(Tpsi,'psi_E x F_P');
S = [Srho; Spsi];
summaryFile = fullfile(outputDir,'exp04_three_branch_comparability_summary.csv');
writetable(S,summaryFile);

% Pairwise transition tables.
write_transition_tables(Trho,'rhoE_s',outputDir);
write_transition_tables(Tpsi,'psiE_FP',outputDir);

%% ========================================================================
% 7. FIGURES
% ========================================================================
figMain = plot_main_comparability_mask(Trho,planeRho,CFG);
export_figure_set(figMain,outputDir,'fig_exp04_three_branch_comparability_mask_rhoE_s');
if ~CFG.SHOW_FIGURES, close(figMain); end

figSupp = plot_supplementary_class_maps(Trho,Tpsi,planeRho,planePsi,CFG);
export_figure_set(figSupp,outputDir,'fig_exp04_three_branch_dynamics_supplement');
if ~CFG.SHOW_FIGURES, close(figSupp); end

figRob = plot_same_regime_robustness(S,CFG);
export_figure_set(figRob,outputDir,'fig_exp04_same_regime_effect_robustness');
if ~CFG.SHOW_FIGURES, close(figRob); end

%% ========================================================================
% 8. HUMAN-READABLE REPORT + MANUSCRIPT-READY SENTENCES
% ========================================================================
reportFile = fullfile(outputDir,'EXP04_THREE_BRANCH_COMPARABILITY_REPORT.txt');
write_final_report(reportFile,S,Trho,Tpsi,metaRho,metaPsi,CFG,rhoFile,psiFile);

fprintf('\n====================================================================\n');
fprintf(' EXP04 THREE-BRANCH AUDIT COMPLETED\n');
fprintf('====================================================================\n');
disp(S);
fprintf('\nKey outputs:\n');
fprintf('  Summary CSV : %s\n',summaryFile);
fprintf('  rho audit   : %s\n',rhoOut);
fprintf('  psi audit   : %s\n',psiOut);
fprintf('  Report      : %s\n',reportFile);
fprintf('  Main mask   : %s\n',fullfile(outputDir, ...
    'fig_exp04_three_branch_comparability_mask_rhoE_s.pdf'));
fprintf('====================================================================\n');

end

%% ========================================================================
% PLANE AUDIT
% ========================================================================
function [T,meta] = audit_one_plane(Tin,spec,pRef,X0Base,optBase,CFG,outputDir)

T = initialize_audit_columns(Tin);
N = height(T);

checkpointFile = fullfile(outputDir,['checkpoint_' spec.tag '.mat']);
if CFG.RESUME_FROM_CHECKPOINT && exist(checkpointFile,'file') == 2
    C = load(checkpointFile,'Tcheckpoint','metaCheckpoint');
    if isfield(C,'Tcheckpoint') && height(C.Tcheckpoint)==N && ...
            coordinates_match(C.Tcheckpoint,T,spec)
        fprintf('Resuming checkpoint: %s\n',checkpointFile);
        T = C.Tcheckpoint;
    else
        warning('Checkpoint exists but is incompatible; starting this plane from scratch.');
    end
end

% Detect reusable source columns once.
source = detect_source_columns(T);
meta = struct();
meta.planeTag = spec.tag;
meta.sourceColumns = source;
meta.matchedESource = source.MatchedE;
meta.noClassSource = source.NoDynamics;
meta.fixedClassSource = source.FixedDynamics;
meta.dynamicClassSource = source.DynamicDynamics;
meta.nRerunNo = 0;
meta.nRerunFix = 0;
meta.nRerunDyn = 0;
meta.nMatchedERecomputed = 0;

% No-AIGC is invariant to the AIGC-specific first axis (rhoE or psiE).
% Cache it by the second-axis value (s or FP) to avoid redundant ODE runs.
noCache = containers.Map('KeyType','char','ValueType','any');

fprintf('Detected source columns:\n');
fprintf('  no dynamics    : %s\n',empty_to_none(source.NoDynamics));
fprintf('  fixed dynamics : %s\n',empty_to_none(source.FixedDynamics));
fprintf('  dyn dynamics   : %s\n',empty_to_none(source.DynamicDynamics));
fprintf('  matched E      : %s\n',empty_to_none(source.MatchedE));

for i = 1:N
    if logical(T.AuditDone(i))
        continue;
    end

    pNow = pRef;
    pNow.(spec.param1) = T.(spec.param1)(i);
    pNow.(spec.param2) = T.(spec.param2)(i);

    % --------------------------------------------------------------------
    % Dynamic branch: locked class preferred; rerun if needed for class or E.
    % --------------------------------------------------------------------
    dynInfo = empty_branch_info();
    haveDynClass = false;
    if CFG.PREFER_LOCKED_BRANCH_CLASSES && ~CFG.FORCE_RERUN_ALL_THREE && ~isempty(source.DynamicDynamics)
        dynInfo = branch_info_from_source(T,i,source.DynamicDynamics,source.DynamicResolved);
        haveDynClass = strlength(dynInfo.coarse)>0;
    end

    matchedE = NaN;
    if ~isempty(source.MatchedE)
        matchedE = numeric_value(T.(source.MatchedE)(i));
    end

    needDynRun = ~haveDynClass || ~isfinite(matchedE);
    if needDynRun
        if ~CFG.RERUN_MISSING_BRANCHES && ~haveDynClass
            error('Dynamic class is missing and RERUN_MISSING_BRANCHES=false.');
        end
        if ~isfinite(matchedE) && ~CFG.ALLOW_RECOMPUTE_MATCHED_E
            error('No matched-E column found and ALLOW_RECOMPUTE_MATCHED_E=false.');
        end

        modeDyn = make_dynamic_mode();
        dynRun = certify_branch_locked(X0Base,pNow,modeDyn,optBase,CFG);
        meta.nRerunDyn = meta.nRerunDyn + 1;

        if ~haveDynClass
            dynInfo = dynRun;
        else
            % Preserve locked class but keep rerun diagnostics and compare.
            T.DynamicRerunCoarse(i) = dynRun.coarse;
            T.DynamicRerunResolved(i) = dynRun.resolved;
            if dynInfo.resolved && dynRun.resolved
                T.DynamicLockedRerunClassAgree(i) = dynInfo.coarse == dynRun.coarse;
            end
        end

        if ~isfinite(matchedE)
            matchedE = dynRun.EMean;
            meta.nMatchedERecomputed = meta.nMatchedERecomputed + 1;
        end

        % If source class was used, retain the rerun means for optional checks.
        T.DynamicRerunIMean(i) = dynRun.IMean;
        T.DynamicRerunTMean(i) = dynRun.TMean;
        T.DynamicRerunEMean(i) = dynRun.EMean;
        T.DynamicRerunHorizon(i) = dynRun.horizon;
    end

    if ~isfinite(matchedE)
        error('Could not obtain a finite matched E at row %d (%s plane).',i,spec.tag);
    end
    matchedE = min(max(matchedE,0),1);
    T.AuditMatchedE(i) = matchedE;

    % --------------------------------------------------------------------
    % Fixed branch.
    % --------------------------------------------------------------------
    fixInfo = empty_branch_info();
    haveFixClass = false;
    if CFG.PREFER_LOCKED_BRANCH_CLASSES && ~CFG.FORCE_RERUN_ALL_THREE && ~isempty(source.FixedDynamics)
        fixInfo = branch_info_from_source(T,i,source.FixedDynamics,source.FixedResolved);
        haveFixClass = strlength(fixInfo.coarse)>0;
    end
    if ~haveFixClass
        if ~CFG.RERUN_MISSING_BRANCHES
            error('Fixed class is missing and RERUN_MISSING_BRANCHES=false.');
        end
        modeFix = make_fixed_mode(matchedE);
        X0Fix = X0Base;
        X0Fix(10) = matchedE;
        fixInfo = certify_branch_locked(X0Fix,pNow,modeFix,optBase,CFG);
        meta.nRerunFix = meta.nRerunFix + 1;
    end

    % --------------------------------------------------------------------
    % No-AIGC branch.
    % --------------------------------------------------------------------
    noInfo = empty_branch_info();
    haveNoClass = false;
    if CFG.PREFER_LOCKED_BRANCH_CLASSES && ~CFG.FORCE_RERUN_ALL_THREE && ~isempty(source.NoDynamics)
        noInfo = branch_info_from_source(T,i,source.NoDynamics,source.NoResolved);
        haveNoClass = strlength(noInfo.coarse)>0;
    end
    if ~haveNoClass
        if ~CFG.RERUN_MISSING_BRANCHES
            error('No-AIGC class is missing and RERUN_MISSING_BRANCHES=false.');
        end
        noKey = sprintf('%.16g',T.(spec.param2)(i));
        if isKey(noCache,noKey)
            noInfo = noCache(noKey);
        else
            modeNo = make_no_aigc_mode();
            X0No = X0Base;
            X0No(10) = 0;
            noInfo = certify_branch_locked(X0No,pNow,modeNo,optBase,CFG);
            noCache(noKey) = noInfo;
            meta.nRerunNo = meta.nRerunNo + 1;
        end
    end

    % --------------------------------------------------------------------
    % Store branch classifications and diagnostics.
    % --------------------------------------------------------------------
    T.NoDynamicsAudit(i)       = noInfo.detail;
    T.NoCoarseClass(i)         = noInfo.coarse;
    T.NoResolvedAudit(i)       = noInfo.resolved;
    T.NoHorizon(i)             = noInfo.horizon;
    T.NoIMeanAudit(i)          = noInfo.IMean;
    T.NoTMeanAudit(i)          = noInfo.TMean;
    T.NoRiskAmplitude(i)       = noInfo.riskAmp;
    T.NoActiveAmplitude(i)     = noInfo.activeAmp;
    T.NoPeriod(i)              = noInfo.period;
    T.NoPeriodCV(i)            = noInfo.periodCV;
    T.NoAmplitudeDrift(i)      = noInfo.ampDrift;
    T.NoDerivativeResidual(i)  = noInfo.derivativeResidual;

    T.FixedDynamicsAudit(i)      = fixInfo.detail;
    T.FixedCoarseClass(i)        = fixInfo.coarse;
    T.FixedResolvedAudit(i)      = fixInfo.resolved;
    T.FixedHorizon(i)            = fixInfo.horizon;
    T.FixedIMeanAudit(i)         = fixInfo.IMean;
    T.FixedTMeanAudit(i)         = fixInfo.TMean;
    T.FixedRiskAmplitude(i)      = fixInfo.riskAmp;
    T.FixedActiveAmplitude(i)    = fixInfo.activeAmp;
    T.FixedPeriod(i)             = fixInfo.period;
    T.FixedPeriodCV(i)           = fixInfo.periodCV;
    T.FixedAmplitudeDrift(i)     = fixInfo.ampDrift;
    T.FixedDerivativeResidual(i) = fixInfo.derivativeResidual;

    T.DynamicDynamicsAudit(i)      = dynInfo.detail;
    T.DynamicCoarseClass(i)        = dynInfo.coarse;
    T.DynamicResolvedAudit(i)      = dynInfo.resolved;
    T.DynamicHorizonAudit(i)       = dynInfo.horizon;
    T.DynamicIMeanAudit(i)         = dynInfo.IMean;
    T.DynamicTMeanAudit(i)         = dynInfo.TMean;
    T.DynamicRiskAmplitudeAudit(i) = dynInfo.riskAmp;
    T.DynamicActiveAmplitudeAudit(i)= dynInfo.activeAmp;
    T.DynamicPeriodAudit(i)        = dynInfo.period;
    T.DynamicPeriodCVAudit(i)      = dynInfo.periodCV;
    T.DynamicAmplitudeDriftAudit(i)= dynInfo.ampDrift;
    T.DynamicDerivativeResidualAudit(i)=dynInfo.derivativeResidual;

    % Capacity audit. If dynamic run was performed, use its E mean.
    if isfinite(T.DynamicRerunEMean(i))
        T.RecomputedCapacityMatchError(i) = abs(T.DynamicRerunEMean(i)-matchedE);
    end

    % Recomputed effect metrics are diagnostic only; locked manuscript values
    % remain the primary effect values. They are available when branches ran.
    if isfinite(noInfo.IMean) && isfinite(fixInfo.IMean) && isfinite(dynInfo.IMean)
        T.RecomputedCapacityDeltaI(i)   = fixInfo.IMean-noInfo.IMean;
        T.RecomputedAdaptationDeltaI(i) = dynInfo.IMean-fixInfo.IMean;
        T.RecomputedNetDeltaI(i)        = dynInfo.IMean-noInfo.IMean;
    end
    if isfinite(noInfo.TMean) && isfinite(fixInfo.TMean) && isfinite(dynInfo.TMean)
        T.RecomputedCapacityDeltaT(i)   = fixInfo.TMean-noInfo.TMean;
        T.RecomputedAdaptationDeltaT(i) = dynInfo.TMean-fixInfo.TMean;
        T.RecomputedNetDeltaT(i)        = dynInfo.TMean-noInfo.TMean;
    end

    % --------------------------------------------------------------------
    % Strict comparability masks. Unresolved == unresolved is NOT counted.
    % --------------------------------------------------------------------
    noR  = logical(noInfo.resolved);
    fixR = logical(fixInfo.resolved);
    dynR = logical(dynInfo.resolved);

    T.M_cap(i)   = noR && fixR && (noInfo.coarse == fixInfo.coarse);
    T.M_adapt(i) = fixR && dynR && (fixInfo.coarse == dynInfo.coarse);
    T.M_net(i)   = noR && dynR && (noInfo.coarse == dynInfo.coarse);
    T.M_three(i) = noR && fixR && dynR && ...
        (noInfo.coarse == fixInfo.coarse) && (fixInfo.coarse == dynInfo.coarse);

    T.AllThreeResolved(i) = noR && fixR && dynR;

    if T.M_three(i)
        T.ThreeBranchMaskCode(i) = 1; % same certified regime
        T.ThreeBranchMaskLabel(i) = "same_certified_regime";
    elseif T.AllThreeResolved(i)
        T.ThreeBranchMaskCode(i) = 2; % all certified, different regime(s)
        T.ThreeBranchMaskLabel(i) = "certified_but_different";
    else
        T.ThreeBranchMaskCode(i) = 3; % at least one unresolved/noncomparable
        T.ThreeBranchMaskLabel(i) = "noncomparable_unresolved";
    end

    T.ThreeBranchPattern(i) = noInfo.coarse + "|" + fixInfo.coarse + "|" + dynInfo.coarse;
    T.AuditDone(i) = true;

    if mod(i,10)==0 || i==1 || i==N
        fprintf('  %s: %4d / %4d | no=%s | fix=%s | dyn=%s | M3=%d\n', ...
            spec.tag,i,N,char(noInfo.coarse),char(fixInfo.coarse), ...
            char(dynInfo.coarse),T.M_three(i));
    end

    if mod(i,CFG.CHECKPOINT_EVERY)==0 || i==N
        Tcheckpoint = T; %#ok<NASGU>
        metaCheckpoint = meta; %#ok<NASGU>
        save(checkpointFile,'Tcheckpoint','metaCheckpoint','-v7.3');
    end
end

% Final synchronization: if the dynamic audit columns were source-only and
% therefore diagnostic values are NaN, preserve the exact source label.
% This is intentional: class comparisons require class + resolved status,
% not an invented rerun metric.

meta.nPoints = N;
meta.checkpointFile = checkpointFile;
meta.completed = all(T.AuditDone);
meta.sourceCapacityMaxError = max(abs(T.CapacityMatchError),[],'omitnan');

fprintf('\n%s audit run counts:\n',spec.tag);
fprintf('  rerun no-AIGC : %d\n',meta.nRerunNo);
fprintf('  rerun fixed   : %d\n',meta.nRerunFix);
fprintf('  rerun dynamic : %d\n',meta.nRerunDyn);
fprintf('  matched E recomputed: %d\n',meta.nMatchedERecomputed);

end

%% ========================================================================
% MANUSCRIPT-LOCKED BRANCH CERTIFICATION
% ========================================================================
function info = certify_branch_locked(X0,p,mode,optBase,CFG)

info = empty_branch_info();
lastDiag = empty_tail_diag();
lastSol = [];

for H = CFG.HORIZONS
    opt = optBase;
    opt.t0 = 0;
    opt.tEnd = H;
    opt.solver = CFG.CLASSIFIER_SOLVER;
    opt.allowEarlyStop = false;
    if isfield(opt,'odeRelTol'), opt.odeRelTol = CFG.ODE_REL_TOL; end
    if isfield(opt,'odeAbsTol'), opt.odeAbsTol = CFG.ODE_ABS_TOL; end

    sol = aigc.solve_model(X0,p,mode,opt);
    validate_solution_shape(sol);
    lastSol = sol;

    D = repmat(empty_tail_diag(),numel(CFG.TAIL_FRACTIONS),1);
    for j = 1:numel(CFG.TAIL_FRACTIONS)
        D(j) = classify_one_tail(sol,p,mode,CFG.TAIL_FRACTIONS(j),CFG);
    end

    coarse = string({D.coarse});
    resolved = [D.resolved];

    % Certification requires agreement across all three prescribed tails.
    if all(resolved) && numel(unique(coarse))==1
        jPrimary = find(abs(CFG.TAIL_FRACTIONS-CFG.PRIMARY_TAIL_FRACTION) < 1e-12,1);
        if isempty(jPrimary), jPrimary = ceil(numel(D)/2); end
        chosen = D(jPrimary);

        info = branch_info_from_tail(chosen,H,sol,p,mode,CFG);
        return;
    end

    jPrimary = find(abs(CFG.TAIL_FRACTIONS-CFG.PRIMARY_TAIL_FRACTION) < 1e-12,1);
    if isempty(jPrimary), jPrimary = ceil(numel(D)/2); end
    lastDiag = D(jPrimary);
end

% Still unresolved after the longest horizon.
info = branch_info_from_tail(lastDiag,CFG.HORIZONS(end),lastSol,p,mode,CFG);
info.resolved = false;
info.coarse = "unresolved";
if lastDiag.riskAmp >= CFG.CYCLE_RISK_AMP_MIN
    info.detail = "unresolved_oscillation";
else
    info.detail = "unresolved_transient";
end

end

function D = classify_one_tail(sol,p,mode,tailFraction,CFG)
D = empty_tail_diag();

[t,X] = uniform_resample_solution(sol,CFG.OUTPUT_DT);
active = active_state_indices_locked(mode);

if isempty(active)
    error('No active states available for branch classification.');
end

cut = t(end)-tailFraction*(t(end)-t(1));
idx = find(t>=cut);
if numel(idx)<10
    idx = max(1,numel(t)-9):numel(t);
end

tt = t(idx);
XX = X(idx,:);

D.activeAmp = max(max(XX(:,active),[],1)-min(XX(:,active),[],1));
D.riskAmp = max(XX(:,4))-min(XX(:,4));
D.ampDrift = amplitude_drift(XX(:,4));

xEnd = X(end,:)';
fEnd = aigc.model_rhs(t(end),xEnd,p,mode);
D.derivativeResidual = norm(fEnd(active),inf);
D.boundary = any(xEnd(active)<=CFG.BOUNDARY_TOL | ...
                 xEnd(active)>=1-CFG.BOUNDARY_TOL);

[D.period,D.periodCV,D.nPeriods,D.peakIdxLocal] = ...
    cycle_period_diagnostics(tt,XX(:,4));

if D.activeAmp <= CFG.EQ_ACTIVE_AMP_TOL && ...
        D.derivativeResidual <= CFG.DERIVATIVE_TOL
    D.resolved = true;
    D.coarse = "equilibrium";
    if D.boundary
        D.detail = "boundary_equilibrium";
    else
        D.detail = "internal_equilibrium";
    end
elseif D.riskAmp >= CFG.CYCLE_RISK_AMP_MIN && ...
        D.nPeriods >= CFG.CYCLE_MIN_PERIODS && ...
        isfinite(D.periodCV) && D.periodCV <= CFG.CYCLE_PERIOD_CV_MAX && ...
        isfinite(D.ampDrift) && D.ampDrift <= CFG.CYCLE_AMP_DRIFT_MAX
    D.resolved = true;
    D.coarse = "cycle";
    D.detail = "certified_cycle";
else
    D.resolved = false;
    D.coarse = "unresolved";
    if D.riskAmp >= CFG.CYCLE_RISK_AMP_MIN
        D.detail = "unresolved_oscillation";
    else
        D.detail = "unresolved_transient";
    end
end

D.tailFraction = tailFraction;
D.tStart = tt(1);
D.tEnd = tt(end);
end

function info = branch_info_from_tail(D,H,sol,p,mode,CFG)
info = empty_branch_info();
info.detail = D.detail;
info.coarse = D.coarse;
info.resolved = D.resolved;
info.horizon = H;
info.riskAmp = D.riskAmp;
info.activeAmp = D.activeAmp;
info.period = D.period;
info.periodCV = D.periodCV;
info.nPeriods = D.nPeriods;
info.ampDrift = D.ampDrift;
info.derivativeResidual = D.derivativeResidual;

if isempty(sol)
    return;
end

% Long-run means. For certified cycles, use complete periods whenever
% possible; otherwise use time-weighted mean over the primary tail.
if info.resolved && info.coarse=="cycle"
    [iMean,tMean,eMean] = complete_cycle_means(sol,CFG.PRIMARY_TAIL_FRACTION,CFG.CYCLE_MIN_PERIODS,CFG.OUTPUT_DT);
else
    [tUniform,XUniform] = uniform_resample_solution(sol,CFG.OUTPUT_DT);
    iMean = tail_time_mean(tUniform,XUniform(:,4),CFG.PRIMARY_TAIL_FRACTION);
    tMean = tail_time_mean(tUniform,XUniform(:,5),CFG.PRIMARY_TAIL_FRACTION);
    if mode_uses_dynamic_aigc(mode)
        eMean = tail_time_mean(tUniform,XUniform(:,10),CFG.PRIMARY_TAIL_FRACTION);
    elseif mode_uses_fixed_aigc(mode)
        eMean = mode.fixedE;
    else
        eMean = 0;
    end
end

info.IMean = iMean;
info.TMean = tMean;
info.EMean = eMean;
end

function [iMean,tMean,eMean] = complete_cycle_means(sol,tailFraction,minPeriods,outputDt)
[t,X] = uniform_resample_solution(sol,outputDt);
cut = t(end)-tailFraction*(t(end)-t(1));
idx0 = find(t>=cut);
if numel(idx0)<20
    idx0 = max(1,numel(t)-19):numel(t);
end

tt = t(idx0);
I = X(idx0,4);
[~,~,~,pkLocal] = cycle_period_diagnostics(tt,I);

if numel(pkLocal) >= minPeriods+1
    pkLocal = pkLocal(max(1,end-minPeriods):end);
    i1 = idx0(pkLocal(1));
    i2 = idx0(pkLocal(end));
    use = i1:i2;
else
    use = idx0;
end

iMean = time_weighted_mean(t(use),X(use,4));
tMean = time_weighted_mean(t(use),X(use,5));
eMean = time_weighted_mean(t(use),X(use,10));
end

function [tOut,XOut] = uniform_resample_solution(sol,dt)
% Resample adaptive-solver output to the manuscript's unified output grid.
% This prevents peak counts / amplitude diagnostics from depending on the
% solver's internal adaptive time stamps. The terminal point is retained.
tRaw = sol.t(:);
XRaw = sol.X;
if numel(tRaw)<2
    tOut=tRaw; XOut=XRaw; return;
end
if ~(isfinite(dt) && dt>0)
    tOut=tRaw; XOut=XRaw; return;
end
tOut = (tRaw(1):dt:tRaw(end))';
if isempty(tOut) || tOut(end) < tRaw(end)-100*eps(max(1,abs(tRaw(end))))
    tOut = [tOut; tRaw(end)]; %#ok<AGROW>
elseif abs(tOut(end)-tRaw(end)) <= 100*eps(max(1,abs(tRaw(end))))
    tOut(end)=tRaw(end);
end
if numel(tRaw)==numel(tOut) && max(abs(tRaw-tOut)) <= 100*eps(max(1,max(abs(tRaw))))
    XOut=XRaw;
else
    XOut=interp1(tRaw,XRaw,tOut,'pchip');
end
XOut=min(max(XOut,0),1);
end

function [period,periodCV,nPeriods,pk] = cycle_period_diagnostics(t,y)
t = t(:); y = y(:);
period = NaN; periodCV = Inf; nPeriods = 0; pk = [];
if numel(y)<5 || max(y)-min(y)<1e-10
    return;
end
pk = find(y(2:end-1)>y(1:end-2) & y(2:end-1)>=y(3:end))+1;
if numel(pk)<2
    return;
end
periods = diff(t(pk));
periods = periods(isfinite(periods) & periods>0);
if isempty(periods), return; end
period = mean(periods);
periodCV = std(periods)/max(period,eps);
nPeriods = numel(periods);
end

function d = amplitude_drift(y)
y = y(:);
if numel(y)<4
    d = Inf; return;
end
m = floor(numel(y)/2);
a1 = max(y(1:m))-min(y(1:m));
a2 = max(y(m+1:end))-min(y(m+1:end));
d = abs(a2-a1)/max([a1,a2,eps]);
end

%% ========================================================================
% MODES / ACTIVE STATES
% ========================================================================
function mode = make_dynamic_mode()
mode = aigc.full_mode();
mode.useAIGC = true;
mode.aigcForm = 'dynamic';
if isfield(mode,'name'), mode.name='EXP04_DynamicAIGC_Audit'; end
end

function mode = make_fixed_mode(fixedE)
mode = aigc.full_mode();
mode.useAIGC = true;
mode.aigcForm = 'fixed';
mode.fixedE = fixedE;
if isfield(mode,'name'), mode.name='EXP04_CapacityMatchedFixedAIGC_Audit'; end
end

function mode = make_no_aigc_mode()
mode = aigc.full_mode();
mode.useAIGC = false;
mode.aigcForm = 'none';
if isfield(mode,'fixedE'), mode.fixedE=0; end
if isfield(mode,'name'), mode.name='EXP04_NoAIGC_Audit'; end
end

function idx = active_state_indices_locked(mode)
% Full branch active states: x,y,z,I,T,M,u,A,L plus E only for dynamic AIGC.
idx = 1:9;
if mode_uses_dynamic_aigc(mode)
    idx = 1:10;
end
end

function tf = mode_uses_dynamic_aigc(mode)
tf = isfield(mode,'useAIGC') && logical(mode.useAIGC) && ...
    isfield(mode,'aigcForm') && strcmpi(mode.aigcForm,'dynamic');
end

function tf = mode_uses_fixed_aigc(mode)
tf = isfield(mode,'useAIGC') && logical(mode.useAIGC) && ...
    isfield(mode,'aigcForm') && strcmpi(mode.aigcForm,'fixed');
end

%% ========================================================================
% SOURCE-COLUMN ADAPTERS
% ========================================================================
function source = detect_source_columns(T)
source.DynamicDynamics = find_var(T,{'DynamicDynamics','DynamicDynamicsType','DynamicClass','DynamicRegime'});
source.DynamicResolved = find_var(T,{'DynamicResolved','DynamicIsResolved','DynamicCertified'});
source.FixedDynamics = find_var(T,{'FixedDynamics','FixedMatchedDynamics','MatchedFixedDynamics', ...
    'CapacityMatchedFixedDynamics','FixedDynamicsType','FixedClass'});
source.FixedResolved = find_var(T,{'FixedResolved','FixedMatchedResolved','MatchedFixedResolved', ...
    'CapacityMatchedFixedResolved','FixedCertified'});
source.NoDynamics = find_var(T,{'NoDynamics','NoAIGCDynamics','NoAIGCDynamicsType','NoAIGCClass', ...
    'NoAIGCRegime','NoDynamicsType'});
source.NoResolved = find_var(T,{'NoResolved','NoAIGCResolved','NoAIGCCertified'});
source.MatchedE = find_var(T,{'MatchedE','FixedE','FixedMatchedE','MatchedFixedE', ...
    'CapacityMatchedE','CapacityMatchedFixedE','FixedEValue','MatchedFixedEValue', ...
    'EMatched','EFixed','DynamicMeanE','DynamicEMean','MeanEDynamic','EDynamicMean'});
end

function info = branch_info_from_source(T,i,classVar,resolvedVar)
info = empty_branch_info();
raw = string(T.(classVar)(i));
[coarse,detail,resolvedFromLabel] = canonicalize_class_label(raw);
info.coarse = coarse;
info.detail = detail;
if ~isempty(resolvedVar)
    info.resolved = logical(numeric_value(T.(resolvedVar)(i)));
else
    info.resolved = resolvedFromLabel;
end
if ~info.resolved && coarse~="unresolved"
    % Resolve-status column is authoritative. A named but uncertified state
    % is not admitted into comparability statistics.
    info.coarse = "unresolved";
end
end

function [coarse,detail,resolved] = canonicalize_class_label(raw)
s = lower(strtrim(string(raw)));
coarse = ""; detail = ""; resolved = false;
if ismissing(s) || strlength(s)==0
    return;
end
if contains(s,'unresolved') || contains(s,'transient') || ...
        contains(s,'non-smooth') || contains(s,'nonsmooth') || ...
        contains(s,'candidate')
    coarse = "unresolved";
    detail = normalize_detail_label(s);
    resolved = false;
elseif contains(s,'equilibrium') || contains(s,'steady') || contains(s,'fixed_point')
    coarse = "equilibrium";
    if contains(s,'boundary')
        detail = "boundary_equilibrium";
    else
        detail = "internal_equilibrium";
    end
    resolved = true;
elseif contains(s,'cycle') || contains(s,'limit_cycle')
    coarse = "cycle";
    detail = "certified_cycle";
    resolved = true;
elseif contains(s,'oscillat')
    % Generic oscillation without explicit certification is not promoted.
    coarse = "unresolved";
    detail = "unresolved_oscillation";
    resolved = false;
else
    coarse = "unresolved";
    detail = normalize_detail_label(s);
    resolved = false;
end
end

function s = normalize_detail_label(s)
s = regexprep(string(s),'[^a-z0-9]+','_');
s = strip(s,'_');
if strlength(s)==0, s="unresolved"; end
end

%% ========================================================================
% TABLE INITIALIZATION / COMPARABILITY SUMMARY
% ========================================================================
function T = initialize_audit_columns(T)
N = height(T);

strCols = {'NoDynamicsAudit','NoCoarseClass','FixedDynamicsAudit','FixedCoarseClass', ...
    'DynamicDynamicsAudit','DynamicCoarseClass','DynamicRerunCoarse', ...
    'ThreeBranchMaskLabel','ThreeBranchPattern'};
for k=1:numel(strCols), T.(strCols{k}) = strings(N,1); end

logCols = {'NoResolvedAudit','FixedResolvedAudit','DynamicResolvedAudit', ...
    'DynamicRerunResolved','DynamicLockedRerunClassAgree', ...
    'M_cap','M_adapt','M_net','M_three','AllThreeResolved','AuditDone'};
for k=1:numel(logCols), T.(logCols{k}) = false(N,1); end

numCols = {'AuditMatchedE','RecomputedCapacityMatchError', ...
    'NoHorizon','NoIMeanAudit','NoTMeanAudit','NoRiskAmplitude','NoActiveAmplitude', ...
    'NoPeriod','NoPeriodCV','NoAmplitudeDrift','NoDerivativeResidual', ...
    'FixedHorizon','FixedIMeanAudit','FixedTMeanAudit','FixedRiskAmplitude','FixedActiveAmplitude', ...
    'FixedPeriod','FixedPeriodCV','FixedAmplitudeDrift','FixedDerivativeResidual', ...
    'DynamicHorizonAudit','DynamicIMeanAudit','DynamicTMeanAudit','DynamicRiskAmplitudeAudit', ...
    'DynamicActiveAmplitudeAudit','DynamicPeriodAudit','DynamicPeriodCVAudit', ...
    'DynamicAmplitudeDriftAudit','DynamicDerivativeResidualAudit', ...
    'DynamicRerunIMean','DynamicRerunTMean','DynamicRerunEMean','DynamicRerunHorizon', ...
    'RecomputedCapacityDeltaI','RecomputedAdaptationDeltaI','RecomputedNetDeltaI', ...
    'RecomputedCapacityDeltaT','RecomputedAdaptationDeltaT','RecomputedNetDeltaT', ...
    'ThreeBranchMaskCode'};
for k=1:numel(numCols), T.(numCols{k}) = nan(N,1); end
end

function S = summarize_comparability(T,planeName)
N = height(T);
noR = logical(T.NoResolvedAudit);
fixR = logical(T.FixedResolvedAudit);
dynR = logical(T.DynamicResolvedAudit);
allR = noR & fixR & dynR;

Mcap = logical(T.M_cap);
Madapt = logical(T.M_adapt);
Mnet = logical(T.M_net);
Mthree = logical(T.M_three);

pairCapResolved   = noR & fixR;
pairAdaptResolved = fixR & dynR;
pairNetResolved   = noR & dynR;

NoResolvedRate = mean(noR);
FixedResolvedRate = mean(fixR);
DynamicResolvedRate = mean(dynR);
AllThreeResolvedRate = mean(allR);

PcapStrict = mean(Mcap);
PadaptStrict = mean(Madapt);
PnetStrict = mean(Mnet);
PthreeStrict = mean(Mthree);

PcapGivenResolved = conditional_rate(Mcap,pairCapResolved);
PadaptGivenResolved = conditional_rate(Madapt,pairAdaptResolved);
PnetGivenResolved = conditional_rate(Mnet,pairNetResolved);
PthreeGivenAllResolved = conditional_rate(Mthree,allR);

NetRiskPositiveAll = signed_rate(T.NetDeltaI,[],+1);
NetRiskPositiveSame = signed_rate(T.NetDeltaI,Mnet,+1);
NetTrustNegativeAll = signed_rate(T.NetDeltaT,[],-1);
NetTrustNegativeSame = signed_rate(T.NetDeltaT,Mnet,-1);
AdaptRiskPositiveAll = signed_rate(T.AdaptationDeltaI,[],+1);
AdaptRiskPositiveSame = signed_rate(T.AdaptationDeltaI,Madapt,+1);

adaptTVar = find_var(T,{'AdaptationDeltaT','AdaptDeltaT','DynamicMinusFixedDeltaT'});
if ~isempty(adaptTVar)
    AdaptTrustNegativeAll = signed_rate(T.(adaptTVar),[],-1);
    AdaptTrustNegativeSame = signed_rate(T.(adaptTVar),Madapt,-1);
else
    AdaptTrustNegativeAll = NaN;
    AdaptTrustNegativeSame = NaN;
end

SourceCapacityErrorMax = max(abs(T.CapacityMatchError),[],'omitnan');
RecomputedCapacityErrorMax = max(abs(T.RecomputedCapacityMatchError),[],'omitnan');
RecomputedCapacityErrorMean = mean(abs(T.RecomputedCapacityMatchError),'omitnan');

% Only rows where a rerun/locked comparison actually occurred.
checked = isfinite(double(T.DynamicLockedRerunClassAgree)) & ...
    (isfinite(T.DynamicRerunHorizon) | strlength(T.DynamicRerunCoarse)>0);
if any(checked)
    DynamicLockedRerunAgreement = mean(T.DynamicLockedRerunClassAgree(checked));
else
    DynamicLockedRerunAgreement = NaN;
end

N_NoResolved = sum(noR);
N_FixedResolved = sum(fixR);
N_DynamicResolved = sum(dynR);
N_AllThreeResolved = sum(allR);
N_Mcap = sum(Mcap);
N_Madapt = sum(Madapt);
N_Mnet = sum(Mnet);
N_Mthree = sum(Mthree);
N_RegimeSwitch_FixDyn = sum(pairAdaptResolved & ~Madapt);
N_RegimeSwitch_NoDyn = sum(pairNetResolved & ~Mnet);

S = table(string(planeName),N, ...
    N_NoResolved,N_FixedResolved,N_DynamicResolved,N_AllThreeResolved, ...
    NoResolvedRate,FixedResolvedRate,DynamicResolvedRate,AllThreeResolvedRate, ...
    N_Mcap,N_Madapt,N_Mnet,N_Mthree, ...
    PcapStrict,PadaptStrict,PnetStrict,PthreeStrict, ...
    PcapGivenResolved,PadaptGivenResolved,PnetGivenResolved,PthreeGivenAllResolved, ...
    N_RegimeSwitch_FixDyn,N_RegimeSwitch_NoDyn, ...
    NetRiskPositiveAll,NetRiskPositiveSame, ...
    NetTrustNegativeAll,NetTrustNegativeSame, ...
    AdaptRiskPositiveAll,AdaptRiskPositiveSame, ...
    AdaptTrustNegativeAll,AdaptTrustNegativeSame, ...
    SourceCapacityErrorMax,RecomputedCapacityErrorMean,RecomputedCapacityErrorMax, ...
    DynamicLockedRerunAgreement, ...
    'VariableNames',{'Plane','N', ...
    'N_NoResolved','N_FixedResolved','N_DynamicResolved','N_AllThreeResolved', ...
    'NoResolvedRate','FixedResolvedRate','DynamicResolvedRate','AllThreeResolvedRate', ...
    'N_Mcap','N_Madapt','N_Mnet','N_Mthree', ...
    'PcapStrict','PadaptStrict','PnetStrict','PthreeStrict', ...
    'PcapGivenResolved','PadaptGivenResolved','PnetGivenResolved','PthreeGivenAllResolved', ...
    'N_RegimeSwitch_FixDyn','N_RegimeSwitch_NoDyn', ...
    'NetRiskPositiveAll','NetRiskPositiveSameRegime', ...
    'NetTrustNegativeAll','NetTrustNegativeSameRegime', ...
    'AdaptRiskPositiveAll','AdaptRiskPositiveSameRegime', ...
    'AdaptTrustNegativeAll','AdaptTrustNegativeSameRegime', ...
    'SourceCapacityErrorMax','RecomputedCapacityErrorMean','RecomputedCapacityErrorMax', ...
    'DynamicLockedRerunAgreement'});
end

function write_transition_tables(T,tag,outDir)
write_one_pair_transition(T.NoCoarseClass,T.FixedCoarseClass, ...
    T.NoResolvedAudit,T.FixedResolvedAudit,'no_to_fixed',tag,outDir);
write_one_pair_transition(T.FixedCoarseClass,T.DynamicCoarseClass, ...
    T.FixedResolvedAudit,T.DynamicResolvedAudit,'fixed_to_dynamic',tag,outDir);
write_one_pair_transition(T.NoCoarseClass,T.DynamicCoarseClass, ...
    T.NoResolvedAudit,T.DynamicResolvedAudit,'no_to_dynamic',tag,outDir);
end

function write_one_pair_transition(A,B,Ar,Br,pairName,tag,outDir)
valid = logical(Ar) & logical(Br);
if ~any(valid)
    Tout = table(string(pairName),0,NaN, ...
        'VariableNames',{'Transition','Count','RateAmongResolvedPairs'});
else
    label = A(valid) + "->" + B(valid);
    u = unique(label,'stable');
    cnt = zeros(numel(u),1);
    for k=1:numel(u), cnt(k)=sum(label==u(k)); end
    rate = cnt/sum(cnt);
    Tout = table(u,cnt,rate,'VariableNames', ...
        {'Transition','Count','RateAmongResolvedPairs'});
end
writetable(Tout,fullfile(outDir,sprintf('exp04_transition_counts_%s_%s.csv',tag,pairName)));
end

%% ========================================================================
% FIGURES
% ========================================================================
function fig = plot_main_comparability_mask(T,spec,CFG)
[xVals,yVals,Z] = table_to_grid(T,spec.param2,spec.param1,'ThreeBranchMaskCode');

vis = ternary(CFG.SHOW_FIGURES,'on','off');
fig = figure('Visible',vis,'Color','w','Units','centimeters', ...
    'Position',[2 2 15.5 11.5],'Renderer','painters');
ax = axes(fig);
imagesc(ax,xVals,yVals,Z);
axis(ax,'xy');
colormap(ax,[0.20 0.68 0.35; 0.92 0.55 0.16; 0.68 0.68 0.68]);
clim(ax,[0.5 3.5]);
cb = colorbar(ax);
cb.Ticks = 1:3;
cb.TickLabels = {'same certified regime','certified but different','unresolved / non-comparable'};
xlabel(ax,spec.xLabel,'Interpreter','tex');
ylabel(ax,spec.yLabel,'Interpreter','tex');
title(ax,'Three-branch dynamical comparability','FontWeight','normal');
set(ax,'FontName','Arial','FontSize',10,'LineWidth',0.8,'Box','on');
end

function fig = plot_supplementary_class_maps(Trho,Tpsi,specRho,specPsi,CFG)
vis = ternary(CFG.SHOW_FIGURES,'on','off');
fig = figure('Visible',vis,'Color','w','Units','centimeters', ...
    'Position',[1 1 31 16.8],'Renderer','painters');
tl = tiledlayout(fig,2,4,'TileSpacing','compact','Padding','compact');

plot_class_row(tl,Trho,specRho,'rho');
plot_class_row(tl,Tpsi,specPsi,'psi');
end

function plot_class_row(tl,T,spec,rowTag)
vars = {'NoCoarseClass','FixedCoarseClass','DynamicCoarseClass','ThreeBranchMaskCode'};
titles = {'No AIGC','Capacity-matched fixed AIGC','Dynamic AIGC','Three-branch comparability'};
letters = {'(a)','(b)','(c)','(d)'};
if strcmp(rowTag,'psi'), letters={'(e)','(f)','(g)','(h)'}; end

for j=1:4
    ax = nexttile(tl);
    if j<=3
        code = class_string_to_code(T.(vars{j}));
        Ttmp=T; Ttmp.PlotCodeAudit=code;
        [xVals,yVals,Z] = table_to_grid(Ttmp,spec.param2,spec.param1,'PlotCodeAudit');
        imagesc(ax,xVals,yVals,Z); axis(ax,'xy');
        colormap(ax,[0.22 0.48 0.82; 0.20 0.70 0.72; 0.70 0.70 0.70]);
        clim(ax,[0.5 3.5]);
        cb=colorbar(ax); cb.Ticks=1:3; cb.TickLabels={'equilibrium','cycle','unresolved'};
    else
        [xVals,yVals,Z] = table_to_grid(T,spec.param2,spec.param1,'ThreeBranchMaskCode');
        imagesc(ax,xVals,yVals,Z); axis(ax,'xy');
        colormap(ax,[0.20 0.68 0.35; 0.92 0.55 0.16; 0.68 0.68 0.68]);
        clim(ax,[0.5 3.5]);
        cb=colorbar(ax); cb.Ticks=1:3;
        cb.TickLabels={'same','different','unresolved'};
    end
    xlabel(ax,spec.xLabel,'Interpreter','tex');
    ylabel(ax,spec.yLabel,'Interpreter','tex');
    title(ax,titles{j},'FontWeight','normal');
    text(ax,0.01,1.02,letters{j},'Units','normalized','FontWeight','bold','FontSize',11);
    set(ax,'FontName','Arial','FontSize',8.7,'LineWidth',0.7,'Box','on');
end
end

function fig = plot_same_regime_robustness(S,CFG)
vis = ternary(CFG.SHOW_FIGURES,'on','off');
fig = figure('Visible',vis,'Color','w','Units','centimeters', ...
    'Position',[2 2 22 9],'Renderer','painters');
tl = tiledlayout(fig,1,2,'TileSpacing','compact','Padding','compact');

for i=1:2
    ax=nexttile(tl);
    vals = 100*[S.NetRiskPositiveAll(i),S.NetRiskPositiveSameRegime(i); ...
                S.AdaptRiskPositiveAll(i),S.AdaptRiskPositiveSameRegime(i)];
    bar(ax,vals,'grouped');
    ylim(ax,[0 105]); grid(ax,'on');
    set(ax,'XTick',1:2,'XTickLabel',{'Net risk > 0','Adaptation risk > 0'});
    ylabel(ax,'Share of parameter points (%)');
    legend(ax,{'All valid points','Same-regime subset'},'Location','best','Box','off');
    title(ax,char(S.Plane(i)),'FontWeight','normal');
    set(ax,'FontName','Arial','FontSize',9,'LineWidth',0.7,'Box','on');
end
end

%% ========================================================================
% REPORT
% ========================================================================
function write_final_report(fileName,S,Trho,Tpsi,metaRho,metaPsi,CFG,rhoFile,psiFile)
fid = fopen(fileName,'w');
if fid<0
    warning('Could not write report: %s',fileName); return;
end
c = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid,'Exp04 three-branch dynamical comparability audit\n');
fprintf(fid,'================================================\n\n');
fprintf(fid,'Locked effect-map inputs:\n');
fprintf(fid,'rho_E x s : %s\n',rhoFile);
fprintf(fid,'psi_E x F_P: %s\n\n',psiFile);

fprintf(fid,'Classifier protocol\n');
fprintf(fid,'-------------------\n');
fprintf(fid,'Horizons: %s\n',mat2str(CFG.HORIZONS));
fprintf(fid,'Unified diagnostic output dt: %.6g\n',CFG.OUTPUT_DT);
fprintf(fid,'Tail fractions: %s\n',mat2str(CFG.TAIL_FRACTIONS));
fprintf(fid,'Equilibrium active amplitude <= %.3e\n',CFG.EQ_ACTIVE_AMP_TOL);
fprintf(fid,'Derivative residual <= %.3e\n',CFG.DERIVATIVE_TOL);
fprintf(fid,'Boundary tolerance = %.3e\n',CFG.BOUNDARY_TOL);
fprintf(fid,'Cycle risk amplitude >= %.3e\n',CFG.CYCLE_RISK_AMP_MIN);
fprintf(fid,'Cycle minimum periods = %d\n',CFG.CYCLE_MIN_PERIODS);
fprintf(fid,'Cycle period CV <= %.3f\n',CFG.CYCLE_PERIOD_CV_MAX);
fprintf(fid,'Cycle amplitude drift <= %.3f\n\n',CFG.CYCLE_AMP_DRIFT_MAX);

for i=1:height(S)
    fprintf(fid,'[%s]\n',char(S.Plane(i)));
    fprintf(fid,'N = %d\n',S.N(i));
    fprintf(fid,'Resolved no/fixed/dynamic/all-three = %d / %d / %d / %d\n', ...
        S.N_NoResolved(i),S.N_FixedResolved(i),S.N_DynamicResolved(i),S.N_AllThreeResolved(i));
    fprintf(fid,'Strict P_cap   = %.6f (%.3f%%)\n',S.PcapStrict(i),100*S.PcapStrict(i));
    fprintf(fid,'Strict P_adapt = %.6f (%.3f%%)\n',S.PadaptStrict(i),100*S.PadaptStrict(i));
    fprintf(fid,'Strict P_net   = %.6f (%.3f%%)\n',S.PnetStrict(i),100*S.PnetStrict(i));
    fprintf(fid,'Strict P_three = %.6f (%.3f%%)\n',S.PthreeStrict(i),100*S.PthreeStrict(i));
    fprintf(fid,'Agreement | relevant branches resolved: cap/adapt/net/three = %.3f%% / %.3f%% / %.3f%% / %.3f%%\n', ...
        100*S.PcapGivenResolved(i),100*S.PadaptGivenResolved(i), ...
        100*S.PnetGivenResolved(i),100*S.PthreeGivenAllResolved(i));
    fprintf(fid,'Regime switches fixed->dynamic = %d\n',S.N_RegimeSwitch_FixDyn(i));
    fprintf(fid,'Regime switches no->dynamic    = %d\n',S.N_RegimeSwitch_NoDyn(i));
    fprintf(fid,'P(Delta I_net > 0): all = %.3f%%, same-regime = %.3f%%\n', ...
        100*S.NetRiskPositiveAll(i),100*S.NetRiskPositiveSameRegime(i));
    fprintf(fid,'P(Delta T_net < 0): all = %.3f%%, same-regime = %.3f%%\n', ...
        100*S.NetTrustNegativeAll(i),100*S.NetTrustNegativeSameRegime(i));
    fprintf(fid,'P(Delta I_adapt > 0): all = %.3f%%, same-regime = %.3f%%\n', ...
        100*S.AdaptRiskPositiveAll(i),100*S.AdaptRiskPositiveSameRegime(i));
    fprintf(fid,'Source max capacity-match error = %.12e\n\n',S.SourceCapacityErrorMax(i));
end

fprintf(fid,'Execution provenance\n');
fprintf(fid,'--------------------\n');
fprintf(fid,'rho: rerun no/fix/dyn = %d/%d/%d; matched E recomputed = %d\n', ...
    metaRho.nRerunNo,metaRho.nRerunFix,metaRho.nRerunDyn,metaRho.nMatchedERecomputed);
fprintf(fid,'psi: rerun no/fix/dyn = %d/%d/%d; matched E recomputed = %d\n\n', ...
    metaPsi.nRerunNo,metaPsi.nRerunFix,metaPsi.nRerunDyn,metaPsi.nMatchedERecomputed);

fprintf(fid,'Manuscript-ready interpretation template\n');
fprintf(fid,'----------------------------------------\n');
for i=1:height(S)
    fprintf(fid,'%s: ',char(S.Plane(i)));
    if S.PthreeStrict(i) >= 1-1e-12
        commonClass = infer_common_certified_class(i,Trho,Tpsi);
        fprintf(fid,['all %d parameter points have the same certified three-branch ', ...
            'long-run class (%s), so the matched-capacity contrasts are not ', ...
            'confounded by equilibrium-cycle mixing. '],S.N(i),commonClass);
    else
        fprintf(fid,['the strict three-branch comparable subset contains %d/%d points (%.2f%%). ', ...
            'Points with certified regime changes are retained as system-level ', ...
            'effects but are not interpreted as within-regime level effects. '], ...
            S.N_Mthree(i),S.N(i),100*S.PthreeStrict(i));
    end
    fprintf(fid,['The adaptation-risk positive share is %.2f%% over all points ', ...
        'and %.2f%% within fixed-vs-dynamic same-regime points.\n'], ...
        100*S.AdaptRiskPositiveAll(i),100*S.AdaptRiskPositiveSameRegime(i));
end

fprintf(fid,'\nDo not delete regime-switch points. Report them separately as dynamical-regime effects.\n');
end

function s = infer_common_certified_class(i,Trho,Tpsi)
if i==1, T=Trho; else, T=Tpsi; end
v = T.DynamicCoarseClass(logical(T.M_three));
if isempty(v), s='unknown'; return; end
u=unique(v);
if numel(u)==1, s=char(u); else, s='mixed-but-pointwise-matched'; end
end

function write_protocol_text(fileName,CFG,projectRoot,dataDir,rhoFile,psiFile,parameterSource,X0)
fid=fopen(fileName,'w');
if fid<0, return; end
c=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'EXP04 three-branch comparability protocol\n');
fprintf(fid,'=========================================\n');
fprintf(fid,'Project root: %s\n',projectRoot);
fprintf(fid,'Data dir: %s\n',dataDir);
fprintf(fid,'rho file: %s\n',rhoFile);
fprintf(fid,'psi file: %s\n',psiFile);
fprintf(fid,'Parameter source: %s\n',parameterSource);
fprintf(fid,'X0: %s\n',mat2str(X0',16));
fprintf(fid,'Classifier solver: %s\n',CFG.CLASSIFIER_SOLVER);
fprintf(fid,'H: %s\n',mat2str(CFG.HORIZONS));
fprintf(fid,'dt_out: %.6g\n',CFG.OUTPUT_DT);
fprintf(fid,'tail fractions: %s\n',mat2str(CFG.TAIL_FRACTIONS));
fprintf(fid,'eq amp tol: %.12e\n',CFG.EQ_ACTIVE_AMP_TOL);
fprintf(fid,'derivative tol: %.12e\n',CFG.DERIVATIVE_TOL);
fprintf(fid,'boundary tol: %.12e\n',CFG.BOUNDARY_TOL);
fprintf(fid,'cycle risk amp min: %.12e\n',CFG.CYCLE_RISK_AMP_MIN);
fprintf(fid,'cycle min periods: %d\n',CFG.CYCLE_MIN_PERIODS);
fprintf(fid,'cycle period CV max: %.12e\n',CFG.CYCLE_PERIOD_CV_MAX);
fprintf(fid,'cycle amplitude drift max: %.12e\n',CFG.CYCLE_AMP_DRIFT_MAX);
fprintf(fid,'Prefer locked branch classes: %d\n',CFG.PREFER_LOCKED_BRANCH_CLASSES);
fprintf(fid,'Force rerun all three branches: %d\n',CFG.FORCE_RERUN_ALL_THREE);
fprintf(fid,'Allow recompute matched E: %d\n',CFG.ALLOW_RECOMPUTE_MATCHED_E);
end

%% ========================================================================
% VALIDATION / EXPECTED LOCKED EFFECT MAP
% ========================================================================
function check_locked_effect_map(T,tag,CFG)
if strcmp(tag,'rhoE_s')
    check_pct('rho net risk',100*signed_rate(T.NetDeltaI,[],+1), ...
        CFG.EXPECTED_RHO_NET_RISK_PCT,CFG.EXPECTED_TOL_PCT);
    check_pct('rho adaptation risk',100*signed_rate(T.AdaptationDeltaI,[],+1), ...
        CFG.EXPECTED_RHO_ADAPT_RISK_PCT,CFG.EXPECTED_TOL_PCT);
else
    check_pct('psi net risk',100*signed_rate(T.NetDeltaI,[],+1), ...
        CFG.EXPECTED_PSI_NET_RISK_PCT,CFG.EXPECTED_TOL_PCT);
    check_pct('psi adaptation risk',100*signed_rate(T.AdaptationDeltaI,[],+1), ...
        CFG.EXPECTED_PSI_ADAPT_RISK_PCT,CFG.EXPECTED_TOL_PCT);
end
end

function check_pct(name,val,target,tol)
if abs(val-target)>tol
    warning('%s = %.4f%%, expected approximately %.4f%%.',name,val,target);
end
end

%% ========================================================================
% DATA/FOLDER DISCOVERY
% ========================================================================
function root = locate_project_root_locked(startDir)
root='';
probe=which('aigc.default_parameters');
if ~isempty(probe)
    candidate=fileparts(fileparts(probe));
    if exist(fullfile(candidate,'+aigc'),'dir')==7
        root=candidate; return;
    end
end

candidates={startDir,pwd};
for base={startDir,pwd}
    c=base{1};
    for up=1:7
        if isempty(c), break; end
        candidates{end+1}=c; %#ok<AGROW>
        c2=fileparts(c); if strcmp(c2,c), break; end; c=c2;
    end
end
for k=1:numel(candidates)
    c=candidates{k};
    if ~isempty(c) && exist(fullfile(c,'+aigc'),'dir')==7
        root=c; return;
    end
end
end

function dataDir = locate_rich_exp04_data_dir(projectRoot,startDir)
dataDir='';
% First check beside the script/current folder.
for c={startDir,pwd}
    d=c{1};
    if folder_has_rich_planes(d), dataDir=d; return; end
end

outRoot=fullfile(projectRoot,'outputs');
if exist(outRoot,'dir')~=7, return; end
hits=dir(fullfile(outRoot,'**','exp04_plane_rhoE_s*.csv'));
if isempty(hits), return; end
[~,ord]=sort([hits.datenum],'descend'); hits=hits(ord);
for k=1:numel(hits)
    d=hits(k).folder;
    if folder_has_rich_planes(d)
        dataDir=d; return;
    end
end
end

function tf = folder_has_rich_planes(d)
tf=false;
if exist(d,'dir')~=7, return; end
rf=find_rich_plane_file(d,'exp04_plane_rhoE_s');
pf=find_rich_plane_file(d,'exp04_plane_psiE_FP');
if isempty(rf)||isempty(pf), return; end
try
    R=readtable(rf,'VariableNamingRule','preserve');
    P=readtable(pf,'VariableNamingRule','preserve');
    req={'NetDeltaI','AdaptationDeltaI','DynamicDynamics','DynamicResolved','CapacityMatchError'};
    tf=all(ismember(req,R.Properties.VariableNames)) && all(ismember(req,P.Properties.VariableNames));
catch
    tf=false;
end
end

function f = find_rich_plane_file(d,prefix)
f='';
if exist(d,'dir')~=7, return; end
hits=dir(fullfile(d,[prefix '*.csv']));
if isempty(hits), return; end
[~,ord]=sort([hits.datenum],'descend'); hits=hits(ord);
for k=1:numel(hits)
    cand=fullfile(hits(k).folder,hits(k).name);
    try
        T=readtable(cand,'VariableNamingRule','preserve');
        if all(ismember({'NetDeltaI','AdaptationDeltaI','DynamicDynamics','DynamicResolved','CapacityMatchError'}, ...
                T.Properties.VariableNames))
            f=cand; return;
        end
    catch
    end
end
end

%% ========================================================================
% R1 / PACKAGE HELPERS
% ========================================================================
function [p,source] = get_R1_parameters_locked(pBase)
% Use the single reviewer-facing frozen Exp04 R1 helper beside this audit.
if exist('exp04_reference_parameters','file') ~= 2
    error(['Missing exp04_reference_parameters.m beside the final Exp04 ', ...
           'runner/audit files.']);
end

[p,source] = exp04_reference_parameters(pBase);

fprintf('Exp04 R1 source   : %s\n',source);
fprintf('  epsP/epsF/epsU : %.4f / %.4f / %.4f\n',p.epsP,p.epsF,p.epsU);
fprintf('  alpha/delta    : %.4f / %.4f\n',p.alpha,p.delta);
fprintf('  etaC/Cstar     : %.4f / %.4f\n',p.etaC,p.Cstar);
end

function warn_if_multiple_package_versions(funcName)
hits=which(funcName,'-all');
if ischar(hits), hits={hits}; end
if numel(hits)>1
    fprintf(2,'\nWARNING: multiple versions of %s are on path:\n',funcName);
    for k=1:numel(hits), fprintf(2,'  %s\n',hits{k}); end
    fprintf(2,'Only the intended V10 package should remain active.\n\n');
end
end

%% ========================================================================
% GENERIC TABLE / NUMERICAL HELPERS
% ========================================================================
function spec = make_plane_spec(tag,param1,param2,yLabel,xLabel,yLong,xLong)
spec=struct('tag',tag,'param1',param1,'param2',param2, ...
    'yLabel',yLabel,'xLabel',xLabel,'yLong',yLong,'xLong',xLong);
end

function tf = coordinates_match(A,B,spec)
tf=height(A)==height(B) && ...
    max(abs(A.(spec.param1)-B.(spec.param1)),[],'omitnan')<1e-12 && ...
    max(abs(A.(spec.param2)-B.(spec.param2)),[],'omitnan')<1e-12;
end

function assert_required_vars(T,names)
missing=setdiff(names,T.Properties.VariableNames,'stable');
if ~isempty(missing)
    error('Input CSV is missing required fields: %s',strjoin(missing,', '));
end
end

function name = find_var(T,aliases)
name=''; vars=T.Properties.VariableNames;
for k=1:numel(aliases)
    idx=find(strcmpi(vars,aliases{k}),1);
    if ~isempty(idx), name=vars{idx}; return; end
end
end

function x = numeric_value(v)
if isnumeric(v) || islogical(v)
    x=double(v);
elseif iscell(v)
    x=str2double(string(v{1}));
else
    x=str2double(string(v));
end
end

function s = empty_to_none(s)
if isempty(s), s='[none]'; end
end

function [xVals,yVals,Z] = table_to_grid(T,xName,yName,zName)
xVals=unique(T.(xName),'sorted');
yVals=unique(T.(yName),'sorted');
Z=nan(numel(yVals),numel(xVals));
for i=1:height(T)
    ix=find(abs(xVals-T.(xName)(i))<1e-12,1);
    iy=find(abs(yVals-T.(yName)(i))<1e-12,1);
    Z(iy,ix)=T.(zName)(i);
end
end

function code = class_string_to_code(s)
s=string(s); code=3*ones(numel(s),1);
code(s=="equilibrium")=1;
code(s=="cycle")=2;
end

function r = conditional_rate(event,condition)
condition=logical(condition); event=logical(event);
if ~any(condition), r=NaN; else, r=mean(event(condition)); end
end

function r = signed_rate(v,mask,sgn)
v=double(v(:)); valid=isfinite(v);
if ~isempty(mask), valid=valid & logical(mask(:)); end
if ~any(valid), r=NaN; return; end
if sgn>0, r=mean(v(valid)>0); else, r=mean(v(valid)<0); end
end

function m = tail_time_mean(t,x,tailFraction)
t=t(:); x=x(:);
cut=t(end)-tailFraction*(t(end)-t(1)); idx=find(t>=cut);
if numel(idx)<2, idx=max(1,numel(t)-1):numel(t); end
m=time_weighted_mean(t(idx),x(idx));
end

function m = time_weighted_mean(t,x)
t=t(:); x=x(:);
if numel(t)<2 || t(end)<=t(1)
    m=mean(x,'omitnan');
else
    m=trapz(t,x)/(t(end)-t(1));
end
end

function validate_solution_shape(sol)
if ~isstruct(sol) || ~isfield(sol,'t') || ~isfield(sol,'X')
    error('aigc.solve_model returned an incompatible solution structure.');
end
if size(sol.X,2)~=10
    error('Expected a 10-state solution X=[x y z I T M u A L E].');
end
end

function info = empty_branch_info()
info=struct('detail',"",'coarse',"",'resolved',false,'horizon',NaN, ...
    'IMean',NaN,'TMean',NaN,'EMean',NaN,'riskAmp',NaN,'activeAmp',NaN, ...
    'period',NaN,'periodCV',NaN,'nPeriods',NaN,'ampDrift',NaN, ...
    'derivativeResidual',NaN);
end

function D = empty_tail_diag()
D=struct('detail',"",'coarse',"unresolved",'resolved',false, ...
    'activeAmp',NaN,'riskAmp',NaN,'period',NaN,'periodCV',Inf, ...
    'nPeriods',0,'ampDrift',Inf,'derivativeResidual',NaN,'boundary',false, ...
    'peakIdxLocal',[],'tailFraction',NaN,'tStart',NaN,'tEnd',NaN);
end

function export_figure_set(fig,outDir,baseName)
pngFile=fullfile(outDir,[baseName '.png']);
pdfFile=fullfile(outDir,[baseName '.pdf']);
figFile=fullfile(outDir,[baseName '.fig']);
try
    exportgraphics(fig,pngFile,'Resolution',600);
    exportgraphics(fig,pdfFile,'ContentType','vector');
catch
    print(fig,pngFile,'-dpng','-r600');
    print(fig,pdfFile,'-dpdf','-painters');
end
try, savefig(fig,figFile); catch, end
end

function out = ternary(cond,a,b)
if cond, out=a; else, out=b; end
end
