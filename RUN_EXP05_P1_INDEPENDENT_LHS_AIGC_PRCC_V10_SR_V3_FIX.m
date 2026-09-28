function outputDir = RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX(runMode)
%RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX
% ========================================================================
% Exp05-P1 review-closure experiment for the AIGC coevolution manuscript.
%
% WHAT THIS ADDS
%   (1) Independent LHS designs instead of N=160/320 prefixes of one N=640
%       design.
%   (2) PRCC for paired AIGC effects, not only state levels:
%           DeltaI_net   = I_dynamic - I_noAIGC
%           DeltaT_net   = T_dynamic - T_noAIGC
%           DeltaI_adapt = I_dynamic - I_fixedMatched
%           DeltaT_adapt = T_dynamic - T_fixedMatched
%   (3) All-finite, all-three-resolved, and strict same-regime PRCC.
%   (4) Repeated independent designs and rank/sign stability summaries.
%   (5) N=640, repetition-1, 2000-bootstrap CIs in FULL mode.
%   (6) Material-effect threshold sensitivity for 5e-4/1e-3/2e-3.
%
% SCIENTIFIC LOCKS
%   - Dynamic branch is simulated first.
%   - Capacity-matched fixed AIGC freezes E at the dynamic branch long-run
%     mean E for the SAME parameter sample.
%   - No-AIGC/fixed-AIGC E is not treated as an active dynamical state.
%   - Unresolved == unresolved is NEVER accepted as a same-regime match.
%   - Primary publication estimate: FULL, N=640, repetition 1.
%   - Other independent repetitions are robustness evidence, not pooled as
%     if they were one larger LHS design.
%
% DIRECT RUN
%   RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX('preview')
%   RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX('quick')
%   RUN_EXP05_P1_INDEPENDENT_LHS_AIGC_PRCC_V10_SR_V3_FIX('full')
%
% The file can be placed anywhere. It searches for the intended V10 project
% root containing +aigc and does NOT recursively add old project versions.
% ========================================================================

if nargin < 1 || isempty(runMode), runMode = 'full'; end
runMode = lower(char(runMode));
if ~ismember(runMode,{'preview','quick','full'})
    error('runMode must be preview, quick, or full.');
end
clc; close all force;

fprintf('\n====================================================================\n');
fprintf(' Exp05-P1 | INDEPENDENT LHS + AIGC EFFECT PRCC | V10 | %s\n',upper(runMode));
fprintf('====================================================================\n');

%% ======================================================================
% 0. Protocol
% =======================================================================
CFG = struct();
CFG.RUN_MODE = runMode;
CFG.SEED_BASE = 20260810;
CFG.RESUME = false;
CFG.CHECKPOINT_EVERY = 20;
CFG.TAIL_FRACTIONS = [0.25 0.40 0.50];
CFG.PRIMARY_TAIL = 0.40;
CFG.HORIZONS = [600 1200 2400];
CFG.EQ_ACTIVE_AMP_TOL = 1e-4;
CFG.DERIVATIVE_TOL = 1e-6;
CFG.BOUNDARY_TOL = 1e-4;
CFG.CYCLE_RISK_AMP_MIN = 2e-3;
CFG.CYCLE_MIN_PERIODS = 8;
CFG.CYCLE_PERIOD_CV_MAX = 0.02;
CFG.CYCLE_AMP_DRIFT_MAX = 0.05;
CFG.OUTPUT_DT = 0.025;
CFG.EFFECT_THRESHOLDS = [5e-4 1e-3 2e-3];
CFG.TOP_K = 5;
CFG.PRIMARY_N = 640;
CFG.PRIMARY_REP = 1;
CFG.SHOW_FIGURES = true;
CFG.RUN_TAG = 'SR_fixedE_interface_repaired_v1';   % fresh repaired-output namespace

switch runMode
    case 'preview'
        CFG.N_LIST = [40 80 160];
        CFG.N_REP = 1;
        CFG.BOOTSTRAP = 50;
    case 'quick'
        CFG.N_LIST = [80 160 320];
        CFG.N_REP = 2;
        CFG.BOOTSTRAP = 200;
    case 'full'
        CFG.N_LIST = [160 320 640];
        CFG.N_REP = 5;
        CFG.BOOTSTRAP = 2000;
end

%% ======================================================================
% 1. Locate V10 package
% =======================================================================
thisFile = mfilename('fullpath');
if isempty(thisFile), startDir = pwd; else, startDir = fileparts(thisFile); end
projectRoot = locate_v10_root_locked(startDir);
if isempty(projectRoot)
    fprintf(2,'Could not automatically find the ORIGINAL V10 root.\n');
    fprintf(2,'Select the folder that DIRECTLY contains the V10 +aigc folder.\n');
    fprintf(2,'Do NOT select v10_p01_core for Exp05-P1.\n');
    selected = uigetdir(pwd,'Select ORIGINAL V10 root containing +aigc');
    if isequal(selected,0)
        error('No V10 project root selected.');
    end
    [~,leaf] = fileparts(selected);
    if strcmp(leaf,'+aigc'), selected = fileparts(selected); end
    if ~is_valid_v10_root(selected)
        error(['Selected folder is not the required ORIGINAL V10 root. ', ...
               'Exp05-P1 must not run from the P0.1 source tree.']);
    end
    projectRoot = selected;
end

remove_competing_aigc_roots(projectRoot);
addpath(projectRoot,'-begin');
rehash;
clear functions; %#ok<CLFUNC>
addpath(projectRoot,'-begin');
rehash;
validate_exp05_v10_source_tree(projectRoot);

required = {'default_parameters','default_options','experiment_settings', ...
            'full_mode','solve_model','model_rhs'};
for k=1:numel(required)
    f=fullfile(projectRoot,'+aigc',[required{k} '.m']);
    if exist(f,'file')~=2, error('Missing required V10 file: %s',f); end
end
warn_if_multiple_package_versions('aigc.solve_model');
warn_if_multiple_package_versions('aigc.model_rhs');

pBase = aigc.default_parameters();
optBase = aigc.default_options(runMode);
settings = aigc.experiment_settings(runMode);
try
    aigc.validate_model_configuration(pBase,optBase,settings);
catch
    try, aigc.validate_model_configuration(pBase,optBase); catch, end
end
[pRef,parameterSource] = get_R1_parameters_locked(pBase);
if ~isfield(optBase,'X0') || numel(optBase.X0)~=10
    error('Active V10 default_options must provide a 10-D opt.X0.');
end
X0Base = optBase.X0(:);

[names,ranges,nameAudit] = sensitivity_spec_locked(settings,pRef);
D = numel(names);

fprintf('Project root      : %s\n',projectRoot);
fprintf('Resolved RHS      : %s\n',which('aigc.model_rhs'));
fprintf('Parameter source  : %s\n',parameterSource);
fprintf('Sensitivity D     : %d\n',D);
fprintf('Independent N     : %s\n',mat2str(CFG.N_LIST));
fprintf('Repetitions / N   : %d\n',CFG.N_REP);
fprintf('Bootstrap primary : %d\n',CFG.BOOTSTRAP);

%% ======================================================================
% 2. Output package
% =======================================================================
outputDir = fullfile(projectRoot,'outputs', ...
    ['Exp05_P1_independent_LHS_AIGC_PRCC_' CFG.RUN_TAG '_' runMode]);
if ~exist(outputDir,'dir'), mkdir(outputDir); end

diary(fullfile(outputDir,'run_log.txt'));
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

writetable(nameAudit,fullfile(outputDir,'parameter_name_range_audit.csv'));
save(fullfile(outputDir,'EXP05_P1_protocol.mat'), ...
    'CFG','pBase','pRef','optBase','settings','names','ranges','X0Base', ...
    'parameterSource','projectRoot','-v7.3');
write_protocol_text(fullfile(outputDir,'EXP05_P1_PROTOCOL.txt'), ...
    CFG,projectRoot,parameterSource,names,ranges,X0Base);

%% ======================================================================
% 3. Independent LHS simulations
% =======================================================================
Tall = table();
for iN = 1:numel(CFG.N_LIST)
    N = CFG.N_LIST(iN);
    for rep = 1:CFG.N_REP
        seed = CFG.SEED_BASE + 100000*N + 1000*rep + iN;
        fprintf('\n--------------------------------------------------------------------\n');
        fprintf(' Independent design: N=%d | rep=%d/%d | seed=%d\n',N,rep,CFG.N_REP,seed);
        fprintf('--------------------------------------------------------------------\n');
        T = run_one_independent_design(N,rep,seed,names,ranges,pRef,X0Base, ...
            optBase,CFG,outputDir);
        writetable(T,fullfile(outputDir,sprintf('exp05_p1_raw_N%d_rep%02d.csv',N,rep)));
        Tall = [Tall; T]; %#ok<AGROW>
    end
end
writetable(Tall,fullfile(outputDir,'exp05_p1_raw_all_independent_designs.csv'));

%% ======================================================================
% 4. PRCC for state levels + AIGC paired effects
% =======================================================================
responseNames = {'I_Dynamic','T_Dynamic', ...
                 'DeltaI_net','DeltaT_net','DeltaI_adapt','DeltaT_adapt'};
subsetNames = {'AllFinite','AllThreeResolved','SameRegimeThree'};
Tprcc = build_prcc_table(Tall,names,responseNames,subsetNames,CFG);
writetable(Tprcc,fullfile(outputDir,'exp05_p1_prcc_all_designs.csv'));

Tconv = build_convergence_summary(Tprcc,CFG.TOP_K);
writetable(Tconv,fullfile(outputDir,'exp05_p1_independent_design_convergence.csv'));

%% ======================================================================
% 5. Primary N=640 rep1 bootstrap
% =======================================================================
primaryMask = Tall.DesignN==CFG.PRIMARY_N & Tall.DesignRep==CFG.PRIMARY_REP;
if ~any(primaryMask)
    % PREVIEW does not necessarily contain N=640. Use largest available.
    maxN = max(Tall.DesignN);
    primaryMask = Tall.DesignN==maxN & Tall.DesignRep==1;
    primaryNActual = maxN;
else
    primaryNActual = CFG.PRIMARY_N;
end
Tprimary = Tall(primaryMask,:);

bootResponses = { ...
    'I_Dynamic','T_Dynamic', ...
    'DeltaI_net','DeltaT_net', ...
    'DeltaI_capacity','DeltaT_capacity', ...
    'DeltaI_adapt','DeltaT_adapt'};
Tboot = bootstrap_primary_prcc(Tprimary,names,bootResponses,subsetNames, ...
    CFG.BOOTSTRAP,CFG.SEED_BASE+90901);
writetable(Tboot,fullfile(outputDir,'exp05_p1_primary_effect_prcc_bootstrap.csv'));

%% ======================================================================
% 6. Effect direction/material threshold sensitivity
% =======================================================================
Tprob = effect_probability_table(Tprimary,CFG.EFFECT_THRESHOLDS);
writetable(Tprob,fullfile(outputDir,'exp05_p1_primary_effect_probabilities.csv'));

%% ======================================================================
% 7. Quality gate
% =======================================================================
Tqc = quality_gate(Tall,Tprcc,Tboot,CFG,primaryNActual);
writetable(Tqc,fullfile(outputDir,'experiment_quality_check.csv'));

%% ======================================================================
% 8. Figures
% =======================================================================
if CFG.SHOW_FIGURES
    try
        plot_primary_prcc(Tboot,outputDir);
        plot_convergence(Tconv,outputDir,CFG.TOP_K);
        plot_effect_probabilities(Tprob,outputDir);
    catch ME
        warning('Plotting failed but numerical outputs were saved: %s',ME.message);
    end
end

%% ======================================================================
% 9. Report
% =======================================================================
write_final_report(fullfile(outputDir,'EXP05_P1_REPORT.txt'), ...
    Tall,Tconv,Tboot,Tprob,Tqc,CFG,primaryNActual,names);

fprintf('\n====================================================================\n');
fprintf(' Exp05-P1 completed.\n');
fprintf(' Output: %s\n',outputDir);
fprintf(' Primary PRCC bootstrap: exp05_p1_primary_effect_prcc_bootstrap.csv\n');
fprintf(' Independent convergence: exp05_p1_independent_design_convergence.csv\n');
fprintf(' Effect probabilities: exp05_p1_primary_effect_probabilities.csv\n');
fprintf('====================================================================\n');
end

%% ======================================================================
% DESIGN RUNNER
% =======================================================================
function T = run_one_independent_design(N,rep,seed,names,ranges,pRef,X0Base,optBase,CFG,outDir)
D=numel(names);
checkpointFile=fullfile(outDir,sprintf('checkpoint_N%d_rep%02d.mat',N,rep));

if CFG.RESUME && exist(checkpointFile,'file')==2
    C=load(checkpointFile);
    if isfield(C,'state') && C.state.N==N && C.state.rep==rep && C.state.seed==seed
        state=C.state;
        fprintf('Resuming checkpoint: %d/%d samples done.\n',sum(state.done),N);
    else
        state=initialize_design_state(N,rep,seed,D,ranges);
    end
else
    state=initialize_design_state(N,rep,seed,D,ranges);
end

% Generate the design exactly once. A resumed run reuses the same Xparam.
if isempty(state.Xparam)
    rng(seed,'twister');
    U=lhs_unit_local(N,D);
    state.Xparam=zeros(N,D);
    for j=1:D
        state.Xparam(:,j)=ranges(j,1)+U(:,j)*(ranges(j,2)-ranges(j,1));
    end
end

for i=1:N
    if state.done(i), continue; end
    pp=set_parameter_vector_locked(pRef,names,state.Xparam(i,:));

    % Dynamic branch first: its long-run E defines the capacity-matched fixed branch.
    modeDyn=make_dynamic_mode();
    d=certify_branch_locked(X0Base,pp,modeDyn,optBase,CFG);
    if isfinite(d.EEffective)
        matchedE=min(max(d.EEffective,0),1);
        modeFix=make_fixed_mode(matchedE);
        X0Fix=X0Base; X0Fix(10)=matchedE;
        f=certify_branch_locked(X0Fix,pp,modeFix,optBase,CFG);
    else
        matchedE=NaN;
        f=empty_branch(); f.detail="skipped_nonfinite_dynamic_E";
    end

    modeNo=make_no_aigc_mode();
    X0No=X0Base; X0No(10)=0;
    n=certify_branch_locked(X0No,pp,modeNo,optBase,CFG);

    state.I_Dynamic(i)=d.I; state.T_Dynamic(i)=d.T; state.E_Dynamic(i)=d.EEffective;
    state.I_Fixed(i)=f.I;   state.T_Fixed(i)=f.T; state.E_FixedState(i)=f.E; state.E_FixedEffective(i)=f.EEffective;
    state.I_No(i)=n.I;      state.T_No(i)=n.T;
    state.MatchedE(i)=matchedE;

    state.DeltaI_net(i)=d.I-n.I;       state.DeltaT_net(i)=d.T-n.T;
    state.DeltaI_adapt(i)=d.I-f.I;     state.DeltaT_adapt(i)=d.T-f.T;
    state.DeltaI_capacity(i)=f.I-n.I;  state.DeltaT_capacity(i)=f.T-n.T;

    state.DynamicResolved(i)=d.resolved; state.FixedResolved(i)=f.resolved; state.NoResolved(i)=n.resolved;
    state.DynamicClass(i)=d.coarse; state.FixedClass(i)=f.coarse; state.NoClass(i)=n.coarse;
    state.AllThreeResolved(i)=d.resolved && f.resolved && n.resolved;
    state.SameRegimeThree(i)=state.AllThreeResolved(i) && ...
        d.coarse==f.coarse && f.coarse==n.coarse;
    state.M_net(i)=d.resolved && n.resolved && d.coarse==n.coarse;
    state.M_adapt(i)=d.resolved && f.resolved && d.coarse==f.coarse;
    if isfinite(f.EEffective) && isfinite(matchedE), state.CapacityMatchError(i)=abs(f.EEffective-matchedE); else, state.CapacityMatchError(i)=NaN; end
    state.DynamicHorizon(i)=d.horizon; state.FixedHorizon(i)=f.horizon; state.NoHorizon(i)=n.horizon;
    state.done(i)=true;

    if mod(i,10)==0 || i==1 || i==N
        fprintf('  %4d/%4d | resolved3=%d | same3=%d | dI_net=%+.3e | dI_adapt=%+.3e\n', ...
            i,N,state.AllThreeResolved(i),state.SameRegimeThree(i), ...
            state.DeltaI_net(i),state.DeltaI_adapt(i));
    end
    if mod(i,CFG.CHECKPOINT_EVERY)==0 || i==N
        save(checkpointFile,'state','-v7.3');
    end
end

T=design_state_to_table(state,names);
end

function state=initialize_design_state(N,rep,seed,D,ranges) %#ok<INUSD>
state=struct(); state.N=N; state.rep=rep; state.seed=seed; state.Xparam=[]; state.done=false(N,1);
numNames={'I_Dynamic','T_Dynamic','E_Dynamic','I_Fixed','T_Fixed','E_FixedState','E_FixedEffective','I_No','T_No','MatchedE', ...
    'DeltaI_net','DeltaT_net','DeltaI_adapt','DeltaT_adapt','DeltaI_capacity','DeltaT_capacity', ...
    'CapacityMatchError','DynamicHorizon','FixedHorizon','NoHorizon'};
for k=1:numel(numNames), state.(numNames{k})=nan(N,1); end
logNames={'DynamicResolved','FixedResolved','NoResolved','AllThreeResolved','SameRegimeThree','M_net','M_adapt'};
for k=1:numel(logNames), state.(logNames{k})=false(N,1); end
state.DynamicClass=strings(N,1); state.FixedClass=strings(N,1); state.NoClass=strings(N,1);
end

function T=design_state_to_table(S,names)
N=S.N;
T=table(repmat(S.N,N,1),repmat(S.rep,N,1),(1:N)',repmat(S.seed,N,1), ...
    'VariableNames',{'DesignN','DesignRep','Sample','DesignSeed'});
for j=1:numel(names)
    vn=matlab.lang.makeValidName(['P_' names{j}]);
    T.(vn)=S.Xparam(:,j);
end
copyNames={'I_Dynamic','T_Dynamic','E_Dynamic','I_Fixed','T_Fixed','E_FixedState','E_FixedEffective','I_No','T_No','MatchedE', ...
    'DeltaI_net','DeltaT_net','DeltaI_adapt','DeltaT_adapt','DeltaI_capacity','DeltaT_capacity', ...
    'CapacityMatchError','DynamicResolved','FixedResolved','NoResolved','AllThreeResolved', ...
    'SameRegimeThree','M_net','M_adapt','DynamicClass','FixedClass','NoClass', ...
    'DynamicHorizon','FixedHorizon','NoHorizon'};
for k=1:numel(copyNames), T.(copyNames{k})=S.(copyNames{k}); end
end

%% ======================================================================
% BRANCH CERTIFICATION
% =======================================================================
function out=certify_branch_locked(X0,p,mode,optBase,CFG)
out=empty_branch();
lastSol=[]; lastDiag=empty_diag();

for h=CFG.HORIZONS
    opt=optBase;
    opt.t0=0; opt.tEnd=h; opt.allowEarlyStop=false; opt.solver='ode45';
    if isfield(opt,'odeRelTol'), opt.odeRelTol=min(opt.odeRelTol,1e-9); end
    if isfield(opt,'odeAbsTol'), opt.odeAbsTol=min(opt.odeAbsTol,1e-11); end
    try
        sol=aigc.solve_model(X0,p,mode,opt);
    catch ME
        out.detail="solver_error:"+string(ME.identifier); return;
    end
    [t,X]=uniform_resample_solution(sol,CFG.OUTPUT_DT);
    diagNow=classify_tail(t,X,p,mode,CFG);
    lastSol=struct('t',t,'X',X); lastDiag=diagNow;
    out.horizon=h;
    if diagNow.resolved, break; end
end

if isempty(lastSol), return; end
out.I=longrun_cycle_aware_mean(lastSol.t,lastSol.X(:,4),lastDiag,CFG);
out.T=longrun_cycle_aware_mean(lastSol.t,lastSol.X(:,5),lastDiag,CFG);
out.E=longrun_cycle_aware_mean(lastSol.t,lastSol.X(:,10),lastDiag,CFG);
% E state and effective AIGC capacity are not the same object for the fixed
% branch. Audit the value actually used by the V10 RHS via model_terms.
if isfield(mode,'fixedE') && mode.fixedE
    assert(islogical(mode.fixedE) && isscalar(mode.fixedE), ...
        'mode.fixedE must be a logical scalar switch.');
    validateattributes(mode.fixedEValue,{'numeric'}, ...
        {'real','finite','scalar','>=',0,'<=',1});
    auditIds=unique(round(linspace(1,numel(lastSol.t),11)));
    Ea=nan(numel(auditIds),1);
    for ka=1:numel(auditIds)
        ia=auditIds(ka);
        aux=aigc.model_terms(lastSol.t(ia),lastSol.X(ia,:)',p,mode);
        Ea(ka)=aux.E;
    end
    assert(all(isfinite(Ea)), 'Non-finite effective E detected in fixed branch.');
    assert(max(abs(Ea-mode.fixedEValue))<=1e-12, ...
        'The RHS does not use the requested matched E.');
    out.EEffective=mean(Ea);
elseif ~isfield(mode,'useAIGC') || ~logical(mode.useAIGC) || ...
        (isfield(mode,'aigcForm') && strcmpi(mode.aigcForm,'none'))
    out.EEffective=0;
else
    out.EEffective=out.E;
end
out.coarse=lastDiag.coarse; out.detail=lastDiag.detail; out.resolved=lastDiag.resolved;
out.riskAmp=lastDiag.riskAmp; out.activeAmp=lastDiag.activeAmp;
out.period=lastDiag.period; out.periodCV=lastDiag.periodCV; out.ampDrift=lastDiag.ampDrift;
out.derivativeResidual=lastDiag.derivativeResidual;
end

function d=classify_tail(t,X,p,mode,CFG)
d=empty_diag(); active=active_state_indices_locked(mode);
% Require all three tail windows to agree for equilibrium; use primary tail for cycle diagnostics.
eqPass=true; eqResid=0; activeAmp=0;
for frac=CFG.TAIL_FRACTIONS
    idx=tail_index_time(t,frac); Xt=X(idx,active);
    amp=max(max(Xt,[],1)-min(Xt,[],1)); activeAmp=max(activeAmp,amp);
    xm=time_weighted_vector_mean(t(idx),X(idx,:));
    rhs=aigc.model_rhs(t(idx(end)),xm(:),p,mode); rhs=rhs(:);
    resid=max(abs(rhs(active))); eqResid=max(eqResid,resid);
    eqPass=eqPass && amp<=CFG.EQ_ACTIVE_AMP_TOL && resid<=CFG.DERIVATIVE_TOL;
end

d.activeAmp=activeAmp; d.derivativeResidual=eqResid;
if eqPass
    d.coarse="equilibrium"; d.detail="certified_equilibrium"; d.resolved=true;
    return;
end

idx=tail_index_time(t,CFG.PRIMARY_TAIL);
y=X(idx,4); tt=t(idx);
d.riskAmp=max(y)-min(y);
[d.period,d.periodCV,d.nPeriods]=cycle_period_diagnostics(tt,y);
d.ampDrift=amplitude_drift(y);
if d.riskAmp>=CFG.CYCLE_RISK_AMP_MIN && d.nPeriods>=CFG.CYCLE_MIN_PERIODS && ...
        d.periodCV<=CFG.CYCLE_PERIOD_CV_MAX && d.ampDrift<=CFG.CYCLE_AMP_DRIFT_MAX
    d.coarse="cycle"; d.detail="certified_cycle"; d.resolved=true;
else
    d.coarse="unresolved"; d.detail="unresolved_longrun"; d.resolved=false;
end
end

function v=longrun_cycle_aware_mean(t,y,d,CFG)
idx=tail_index_time(t,CFG.PRIMARY_TAIL);
% For certified cycles, use the most recent complete periods when possible.
if d.coarse=="cycle" && isfinite(d.period) && d.period>0
    tEnd=t(end); tStart=max(t(idx(1)),tEnd-max(CFG.CYCLE_MIN_PERIODS,8)*d.period);
    idx=find(t>=tStart);
end
v=time_weighted_mean(t(idx),y(idx));
end

function idx=active_state_indices_locked(mode)
idx=1:9;
if mode_uses_dynamic_aigc(mode), idx=1:10; end
end
function tf=mode_uses_dynamic_aigc(mode)
tf=isfield(mode,'useAIGC') && logical(mode.useAIGC) && isfield(mode,'aigcForm') && strcmpi(mode.aigcForm,'dynamic');
end
function out=empty_branch()
out=struct('I',NaN,'T',NaN,'E',NaN,'EEffective',NaN,'coarse',"unresolved",'detail',"not_run",'resolved',false, ...
    'horizon',NaN,'riskAmp',NaN,'activeAmp',NaN,'period',NaN,'periodCV',NaN, ...
    'ampDrift',NaN,'derivativeResidual',NaN);
end
function d=empty_diag()
d=struct('coarse',"unresolved",'detail',"",'resolved',false,'riskAmp',NaN,'activeAmp',NaN, ...
    'period',NaN,'periodCV',Inf,'nPeriods',0,'ampDrift',Inf,'derivativeResidual',Inf);
end

%% ======================================================================
% PRCC
% =======================================================================
function T=build_prcc_table(Tall,names,responseNames,subsetNames,CFG)
rows=struct([]); Ns=unique(Tall.DesignN)'; reps=unique(Tall.DesignRep)';
paramCols=cellfun(@(s) matlab.lang.makeValidName(['P_' s]),names,'UniformOutput',false);
for N=Ns
    repsN=unique(Tall.DesignRep(Tall.DesignN==N))';
    for rep=repsN
        S=Tall(Tall.DesignN==N & Tall.DesignRep==rep,:);
        X=S{:,paramCols};
        for ir=1:numel(responseNames)
            rn=responseNames{ir}; y=S.(rn);
            for is=1:numel(subsetNames)
                sn=subsetNames{is}; mask=subset_mask(S,sn) & all(isfinite(X),2) & isfinite(y);
                if sum(mask)<=numel(names)+3
                    pr=nan(numel(names),1);
                else
                    pr=prcc_vector_fast(X(mask,:),y(mask));
                end
                rankAbs=rank_desc(abs(pr));
                for j=1:numel(names)
                    r=struct(); r.DesignN=N; r.DesignRep=rep; r.Response=string(rn); r.Subset=string(sn);
                    r.Parameter=string(names{j}); r.NUsed=sum(mask); r.PRCC=pr(j); r.AbsRank=rankAbs(j);
                    rows=append_struct(rows,r);
                end
            end
        end
    end
end
T=struct2table(rows);
% Primary-design marker aids plotting/table filtering.
T.IsPrimary = T.DesignN==CFG.PRIMARY_N & T.DesignRep==CFG.PRIMARY_REP;
end

function T=build_convergence_summary(P,topK)
rows=struct([]); Ns=unique(P.DesignN)'; responses=unique(P.Response,'stable'); subsets=unique(P.Subset,'stable'); params=unique(P.Parameter,'stable');
for N=Ns
    for ir=1:numel(responses)
        for is=1:numel(subsets)
            for ip=1:numel(params)
                q=P.DesignN==N & P.Response==responses(ir) & P.Subset==subsets(is) & P.Parameter==params(ip);
                v=P.PRCC(q); rk=P.AbsRank(q); v=v(isfinite(v)); rk=rk(isfinite(rk));
                if isempty(v), continue; end
                r=struct(); r.DesignN=N; r.Response=responses(ir); r.Subset=subsets(is); r.Parameter=params(ip);
                r.NDesigns=numel(v); r.MeanPRCC=mean(v); r.StdPRCC=std(v,0); r.MeanAbsPRCC=mean(abs(v));
                r.SignConsistency=max(mean(v>0),mean(v<0)); r.MedianAbsRank=median(rk); r.TopKFrequency=mean(rk<=topK);
                rows=append_struct(rows,r);
            end
        end
    end
end
T=struct2table(rows);
end

function T=bootstrap_primary_prcc(S,names,responseNames,subsetNames,B,seed)
rows=struct([]); paramCols=cellfun(@(s) matlab.lang.makeValidName(['P_' s]),names,'UniformOutput',false);
Xall=S{:,paramCols}; rng(seed,'twister');
for ir=1:numel(responseNames)
    rn=responseNames{ir}; yall=S.(rn);
    for is=1:numel(subsetNames)
        sn=subsetNames{is}; mask=subset_mask(S,sn) & all(isfinite(Xall),2) & isfinite(yall);
        X=Xall(mask,:); y=yall(mask); n=size(X,1);
        if n<=numel(names)+3
            point=nan(numel(names),1); lo=point; hi=point;
        else
            point=prcc_vector_fast(X,y);
            BB=nan(B,numel(names));
            for b=1:B
                ids=randi(n,n,1);
                BB(b,:)=prcc_vector_fast(X(ids,:),y(ids,:))';
            end
            lo=column_quantile(BB,0.025); hi=column_quantile(BB,0.975);
        end
        ranks=rank_desc(abs(point));
        for j=1:numel(names)
            r=struct(); r.Response=string(rn); r.Subset=string(sn); r.Parameter=string(names{j});
            r.NUsed=n; r.PRCC=point(j); r.CI_Low=lo(j); r.CI_High=hi(j); r.AbsRank=ranks(j);
            r.CIExcludesZero=isfinite(lo(j)) && isfinite(hi(j)) && (lo(j)>0 || hi(j)<0);
            rows=append_struct(rows,r);
        end
    end
end
T=struct2table(rows);
end

function pr=prcc_vector_fast(X,y)
[n,d]=size(X); pr=nan(d,1);
if n<=d+2 || std(y)<=eps, return; end
R=zeros(n,d+1);
for j=1:d, R(:,j)=rank_average_local(X(:,j)); end
R(:,d+1)=rank_average_local(y);
C=corrcoef(R);
if any(~isfinite(C(:))), return; end
P=pinv(C);
di=diag(P); den=sqrt(max(di(1:d)*di(end),eps));
pr=-P(1:d,end)./den;
pr=max(min(pr,1),-1);
end

function mask=subset_mask(S,name)
switch char(name)
    case 'AllFinite', mask=true(height(S),1);
    case 'AllThreeResolved', mask=logical(S.AllThreeResolved);
    case 'SameRegimeThree', mask=logical(S.SameRegimeThree);
    otherwise, error('Unknown subset: %s',name);
end
end

%% ======================================================================
% EFFECT PROBABILITIES
% =======================================================================
function T=effect_probability_table(S,taus)
responses={'DeltaI_net','DeltaT_net','DeltaI_adapt','DeltaT_adapt'};
subsets={'AllFinite','AllThreeResolved','SameRegimeThree'}; rows=struct([]);
for ir=1:numel(responses)
    rn=responses{ir}; isRisk=contains(rn,'DeltaI');
    for is=1:numel(subsets)
        mask=subset_mask(S,subsets{is}) & isfinite(S.(rn)); v=S.(rn)(mask);
        for tau=taus
            r=struct(); r.Response=string(rn); r.Subset=string(subsets{is}); r.Threshold=tau; r.NUsed=numel(v);
            if isempty(v)
                r.FavorableDirection=NaN; r.AdverseDirection=NaN; r.AbsMaterial=NaN; r.AdverseMaterial=NaN;
            else
                % Here "adverse" means more risk for I, less trust for T.
                if isRisk
                    adverse=v>0; favorable=v<0; adverseMat=v>tau;
                else
                    adverse=v<0; favorable=v>0; adverseMat=v<-tau;
                end
                r.FavorableDirection=mean(favorable); r.AdverseDirection=mean(adverse);
                r.AbsMaterial=mean(abs(v)>tau); r.AdverseMaterial=mean(adverseMat);
            end
            rows=append_struct(rows,r);
        end
    end
end
T=struct2table(rows);
end

%% ======================================================================
% QUALITY GATE / REPORT / FIGURES
% =======================================================================
function T=quality_gate(Tall,Tprcc,Tboot,CFG,primaryNActual)
rows=struct([]);
rows=qc_add(rows,'Independent N designs present',all(ismember(CFG.N_LIST,unique(Tall.DesignN)')),numel(unique(Tall.DesignN)),numel(CFG.N_LIST),'');
for N=CFG.N_LIST
    nrep=numel(unique(Tall.DesignRep(Tall.DesignN==N)));
    rows=qc_add(rows,sprintf('N=%d repetition count',N),nrep==CFG.N_REP,nrep,CFG.N_REP,'independent seeds/designs');
end
rows=qc_add(rows,'Primary design exists',any(Tall.DesignN==primaryNActual & Tall.DesignRep==1),primaryNActual,primaryNActual,'');
P0=Tall(Tall.DesignN==primaryNActual & Tall.DesignRep==1,:);
D0=numel(unique(Tprcc.Parameter));
nSame=sum(P0.SameRegimeThree & isfinite(P0.DeltaI_net) & isfinite(P0.DeltaI_adapt));
rows=qc_add(rows,'Primary same-regime sample supports PRCC',nSame>D0+3,nSame,D0+4,'must exceed number of predictors + 3');
rows=qc_add(rows,'Capacity match numerical error',max(Tall.CapacityMatchError,[],'omitnan')<=1e-10, ...
    max(Tall.CapacityMatchError,[],'omitnan'),1e-10,'fixed-branch E must equal the dynamic long-run matched target');
rows=qc_add(rows,'PRCC table nonempty',~isempty(Tprcc),height(Tprcc),1,'');
rows=qc_add(rows,'Primary bootstrap nonempty',~isempty(Tboot),height(Tboot),1,'');
rows=qc_add(rows,'Primary bootstrap has finite PRCC',any(isfinite(Tboot.PRCC)),sum(isfinite(Tboot.PRCC)),1,'');
T=struct2table(rows);
end

function rows=qc_add(rows,name,pass,value,tol,note)
r=struct('Check',string(name),'Pass',logical(pass),'Value',value,'Tolerance',tol,'Note',string(note)); rows=append_struct(rows,r);
end

function plot_primary_prcc(B,outDir)
responses=["DeltaI_net","DeltaT_net","DeltaI_adapt","DeltaT_adapt"];
S=B(B.Subset=="SameRegimeThree",:);
fig=figure('Visible','off','Color','w','Position',[50 50 1400 900]); tl=tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
for i=1:4
    nexttile; Q=S(S.Response==responses(i),:); [~,ord]=sort(abs(Q.PRCC),'descend'); ord=ord(1:min(10,numel(ord))); Q=Q(ord,:);
    x=1:height(Q); errorbar(x,Q.PRCC,Q.PRCC-Q.CI_Low,Q.CI_High-Q.PRCC,'o','LineWidth',1.1); yline(0,'k--');
    xticks(x); xticklabels(cellstr(Q.Parameter)); xtickangle(45); ylabel('PRCC'); title(strrep(char(responses(i)),'_',' ')); grid on;
end
title(tl,'Primary independent LHS: paired AIGC-effect PRCC (same certified regime)');
save_figure_local(fig,outDir,'fig_exp05_p1_effect_prcc_bootstrap');
end

function plot_convergence(C,outDir,topK)
S=C(C.Subset=="SameRegimeThree" & C.Response=="DeltaI_adapt",:);
maxN=max(S.DesignN); Q=S(S.DesignN==maxN,:); [~,ord]=sort(Q.MeanAbsPRCC,'descend'); top=Q.Parameter(ord(1:min(topK,numel(ord))));
fig=figure('Visible','off','Color','w','Position',[80 80 1100 650]); hold on;
for i=1:numel(top)
    R=S(S.Parameter==top(i),:); R=sortrows(R,'DesignN'); errorbar(R.DesignN,R.MeanPRCC,R.StdPRCC,'-o','LineWidth',1.1,'DisplayName',char(top(i)));
end
yline(0,'k--'); xlabel('Independent LHS sample size N'); ylabel('Mean PRCC across independent designs'); grid on; legend('Location','best');
title('Independent-design stability: adaptation-risk PRCC');
save_figure_local(fig,outDir,'fig_exp05_p1_independent_lhs_convergence');
end

function plot_effect_probabilities(P,outDir)
S=P(P.Subset=="SameRegimeThree",:); responses=unique(S.Response,'stable');
fig=figure('Visible','off','Color','w','Position',[80 80 1200 700]); hold on;
for i=1:numel(responses)
    Q=S(S.Response==responses(i),:); plot(Q.Threshold,Q.AdverseMaterial,'-o','LineWidth',1.2,'DisplayName',char(responses(i)));
end
xlabel('Material-effect threshold |Delta|'); ylabel('Adverse material-effect probability'); ylim([0 1]); grid on; legend('Location','best');
title('Threshold sensitivity of paired AIGC effects');
save_figure_local(fig,outDir,'fig_exp05_p1_effect_threshold_sensitivity');
end

function write_final_report(fileName,Tall,Tconv,Tboot,Tprob,Tqc,CFG,primaryN,names)
fid=fopen(fileName,'w'); if fid<0, return; end; c=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'Exp05-P1 independent LHS + paired AIGC-effect PRCC\n');
fprintf(fid,'===================================================\n\n');
fprintf(fid,'Run mode: %s\n',CFG.RUN_MODE);
fprintf(fid,'Independent sample sizes: %s\n',mat2str(CFG.N_LIST));
fprintf(fid,'Independent repetitions per N: %d\n',CFG.N_REP);
fprintf(fid,'Primary design used in this run: N=%d, rep=1\n',primaryN);
fprintf(fid,'Bootstrap repetitions: %d\n',CFG.BOOTSTRAP);
fprintf(fid,'Sensitivity parameters (%d): %s\n\n',numel(names),strjoin(names,', '));
P=Tall(Tall.DesignN==primaryN & Tall.DesignRep==1,:);
fprintf(fid,'Primary dynamical comparability\n-------------------------------\n');
fprintf(fid,'All-three resolved: %d/%d (%.2f%%)\n',sum(P.AllThreeResolved),height(P),100*mean(P.AllThreeResolved));
fprintf(fid,'Strict same-regime three-branch: %d/%d (%.2f%%)\n\n',sum(P.SameRegimeThree),height(P),100*mean(P.SameRegimeThree));

fprintf(fid,'Primary paired-effect direction probabilities (same-regime; tau=1e-3 row shown when available)\n');
fprintf(fid,'-------------------------------------------------------------------------------------------\n');
Q=Tprob(Tprob.Subset=="SameRegimeThree" & abs(Tprob.Threshold-1e-3)<1e-14,:);
for i=1:height(Q)
    fprintf(fid,'%s: adverse direction %.2f%%; adverse material %.2f%%; N=%d\n',char(Q.Response(i)),100*Q.AdverseDirection(i),100*Q.AdverseMaterial(i),Q.NUsed(i));
end
fprintf(fid,'\nTop effect PRCCs (same-regime, bootstrap point estimate)\n-------------------------------------------------------\n');
for rn=["DeltaI_net","DeltaT_net","DeltaI_adapt","DeltaT_adapt"]
    B=Tboot(Tboot.Response==rn & Tboot.Subset=="SameRegimeThree",:); [~,ord]=sort(abs(B.PRCC),'descend'); ord=ord(1:min(5,numel(ord)));
    fprintf(fid,'[%s]\n',char(rn));
    for j=ord'
        fprintf(fid,'  %-18s PRCC=%+.4f  95%%CI=[%+.4f,%+.4f] rank=%d\n',char(B.Parameter(j)),B.PRCC(j),B.CI_Low(j),B.CI_High(j),B.AbsRank(j));
    end
end
fprintf(fid,'\nQuality gate\n------------\n');
for i=1:height(Tqc), fprintf(fid,'%s : %d\n',char(Tqc.Check(i)),Tqc.Pass(i)); end
fprintf(fid,'\nInterpretation rule: independent repetitions are robustness checks; do not concatenate them into a fictitious larger LHS design.\n');
end

function write_protocol_text(fileName,CFG,root,source,names,ranges,X0)
fid=fopen(fileName,'w'); if fid<0, return; end; c=onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'EXP05-P1 protocol\n=================\n');
fprintf(fid,'Project root: %s\nParameter source: %s\n',root,source);
fprintf(fid,'Run mode: %s\nN list: %s\nRepetitions: %d\nBootstrap: %d\n',CFG.RUN_MODE,mat2str(CFG.N_LIST),CFG.N_REP,CFG.BOOTSTRAP);
fprintf(fid,'Horizons: %s\nTail fractions: %s\nOutput dt: %.6g\n',mat2str(CFG.HORIZONS),mat2str(CFG.TAIL_FRACTIONS),CFG.OUTPUT_DT);
fprintf(fid,'X0: %s\n\nParameters:\n',mat2str(X0(:)',8));
for j=1:numel(names), fprintf(fid,'%-20s [%g,%g]\n',names{j},ranges(j,1),ranges(j,2)); end
end

%% ======================================================================
% V10 / PARAMETER ADAPTERS
% =======================================================================
function [names,ranges,audit]=sensitivity_spec_locked(settings,p)
if isfield(settings,'sensitivityNames') && isfield(settings,'sensitivityRange')
    names=cellstr(string(settings.sensitivityNames)); ranges=settings.sensitivityRange;
else
    names={'s','h','f','c','r','attn','FP','CR','lambda0','beta0','alpha','delta','mu','rhoE','psiE','antiE','etaI','etaC'};
    ranges=[0.55 0.95;0.55 0.95;0.01 0.20;0.50 0.95;0.50 0.95;0.40 0.90;0.30 1.20;0.20 0.65;0.15 0.45;0.30 0.70;0.10 0.35;0.25 0.85;0 0.30;0.05 0.70;0 1.80;0 0.50;0.40 3.00;0.40 4.50];
end
if size(ranges,1)~=numel(names), error('sensitivityNames/range size mismatch.'); end
original=string(names(:)); resolved=original; status=strings(numel(names),1);
for j=1:numel(names)
    nm=names{j};
    if isfield(p,nm)
        status(j)="direct";
    elseif strcmp(nm,'attn') && isfield(p,'chi')
        names{j}='chi'; resolved(j)="chi"; status(j)="alias_attn_to_chi";
    elseif strcmp(nm,'chi') && isfield(p,'attn')
        names{j}='attn'; resolved(j)="attn"; status(j)="alias_chi_to_attn";
    else
        error('Sensitivity parameter "%s" is not a field in active V10 p.',nm);
    end
end
if numel(unique(names))~=numel(names), error('Parameter alias resolution created duplicate names.'); end
audit=table(original,resolved,status,ranges(:,1),ranges(:,2),'VariableNames',{'RequestedName','ResolvedName','Status','Lower','Upper'});
end

function params=set_parameter_vector_locked(p,names,vals)
params=p; for k=1:numel(names), params.(names{k})=vals(k); end
end

function mode=make_dynamic_mode()
mode=aigc.full_mode();
mode.useAIGC=true;
mode.aigcForm='dynamic';
mode.fixedE=false;
mode.fixedEValue=NaN;
mode.exogenousE=false;
mode.activeMask(10)=true;
mode.name='EXP05P1_DynamicAIGC';
end

function mode=make_fixed_mode(E)
validateattributes(E,{'numeric'}, ...
    {'real','finite','scalar','>=',0,'<=',1});
mode=aigc.full_mode();
mode.useAIGC=true;
mode.aigcForm='fixed';   % runner metadata; V10 RHS reads fixedE/fixedEValue
mode.fixedE=true;        % logical switch
mode.fixedEValue=E;      % numerical matched capacity used by model_terms
mode.exogenousE=false;
mode.activeMask(10)=false;
mode.name='EXP05P1_CapacityMatchedFixedAIGC';
end

function mode=make_no_aigc_mode()
mode=aigc.full_mode();
mode.useAIGC=false;
mode.aigcForm='none';
mode.fixedE=false;
mode.fixedEValue=0;
mode.exogenousE=false;
mode.activeMask(10)=false;
mode.name='EXP05P1_NoAIGC';
end

function [p,source]=get_R1_parameters_locked(pBase)
% Use one explicit frozen Exp05-P1 R1 definition.
%
% The original script used the same seven audited R1 modifications as a
% fallback when representative_regimes.m was unavailable.  For the final
% SR package we make that configuration explicit and deterministic rather
% than emitting a "fallback" warning.

p = pBase;
required = {'epsP','epsF','epsU','alpha','delta','etaC','Cstar'};
for k=1:numel(required)
    if ~isfield(p,required{k})
        error('Frozen Exp05-P1 R1 configuration missing field: %s',required{k});
    end
end

p.epsP  = 0.05;
p.epsF  = 0.05;
p.epsU  = 0.05;
p.alpha = 0.30;
p.delta = 0.40;
p.etaC  = 4.00;
p.Cstar = 0.25;

tol=1e-12;
assert(abs(p.epsP-0.05)<tol);
assert(abs(p.epsF-0.05)<tol);
assert(abs(p.epsU-0.05)<tol);
assert(abs(p.alpha-0.30)<tol);
assert(abs(p.delta-0.40)<tol);
assert(abs(p.etaC-4.00)<tol);
assert(abs(p.Cstar-0.25)<tol);

source='frozen Exp05-P1 R1 reference configuration';

fprintf('Exp05-P1 R1 source: %s\n',source);
fprintf('  epsP/epsF/epsU : %.4f / %.4f / %.4f\n',p.epsP,p.epsF,p.epsU);
fprintf('  alpha/delta    : %.4f / %.4f\n',p.alpha,p.delta);
fprintf('  etaC/Cstar     : %.4f / %.4f\n',p.etaC,p.Cstar);
end

%% ======================================================================
% NUMERICAL UTILITIES
% =======================================================================
function U=lhs_unit_local(n,d)
U=zeros(n,d); for j=1:d, q=((0:n-1)'+rand(n,1))/n; U(:,j)=q(randperm(n)); end
end
function r=rank_average_local(x)
x=x(:); [s,ord]=sort(x); r=zeros(size(x)); n=numel(x); i=1;
while i<=n
    j=i; while j<n && s(j+1)==s(i), j=j+1; end
    rv=(i+j)/2; r(ord(i:j))=rv; i=j+1;
end
end
function rk=rank_desc(v)
n=numel(v); rk=nan(n,1); good=isfinite(v); ids=find(good); [~,o]=sort(v(good),'descend'); rk(ids(o))=(1:numel(o))';
end
function q=column_quantile(X,p)
q=nan(1,size(X,2)); for j=1:size(X,2), v=X(:,j); v=v(isfinite(v)); q(j)=quantile_local(v,p); end
end
function q=quantile_local(v,p)
v=sort(v(:)); if isempty(v), q=NaN; return; end; if numel(v)==1, q=v; return; end
h=1+(numel(v)-1)*p; lo=floor(h); hi=ceil(h); if lo==hi, q=v(lo); else, q=v(lo)+(h-lo)*(v(hi)-v(lo)); end
end
function idx=tail_index_time(t,frac)
t=t(:); t0=t(end)-frac*(t(end)-t(1)); idx=find(t>=t0); if numel(idx)<3, idx=max(1,numel(t)-2):numel(t); end
end
function v=time_weighted_mean(t,y)
t=t(:); y=y(:); if numel(t)<2, v=mean(y); else, v=trapz(t,y)/max(t(end)-t(1),eps); end
end
function v=time_weighted_vector_mean(t,X)
t=t(:); if numel(t)<2, v=mean(X,1); else, v=trapz(t,X,1)/max(t(end)-t(1),eps); end
end
function [period,cv,nPeriods]=cycle_period_diagnostics(t,y)
t=t(:); y=y(:); period=NaN; cv=Inf; nPeriods=0; if numel(y)<5, return; end
pk=find(y(2:end-1)>y(1:end-2) & y(2:end-1)>=y(3:end))+1; if numel(pk)<2, return; end
pp=diff(t(pk)); pp=pp(isfinite(pp)&pp>0); if isempty(pp), return; end
period=mean(pp); cv=std(pp)/max(period,eps); nPeriods=numel(pp);
end
function d=amplitude_drift(y)
y=y(:); if numel(y)<6, d=Inf; return; end; m=floor(numel(y)/2); a1=max(y(1:m))-min(y(1:m)); a2=max(y(m+1:end))-min(y(m+1:end)); d=abs(a2-a1)/max([a1,a2,eps]);
end
function [tOut,XOut]=uniform_resample_solution(sol,dt)
tRaw=sol.t(:); XRaw=sol.X; if numel(tRaw)<2 || ~(isfinite(dt)&&dt>0), tOut=tRaw; XOut=XRaw; return; end
tOut=(tRaw(1):dt:tRaw(end))'; if isempty(tOut)||tOut(end)<tRaw(end)-1e-12, tOut=[tOut;tRaw(end)]; else, tOut(end)=tRaw(end); end
if numel(tRaw)==numel(tOut) && max(abs(tRaw-tOut))<1e-12, XOut=XRaw; else, XOut=interp1(tRaw,XRaw,tOut,'pchip'); end
XOut=min(max(XOut,0),1);
end
function rows=append_struct(rows,r)
if isempty(rows), rows=r; else, rows(end+1)=r; end %#ok<AGROW>
end
function save_figure_local(fig,outDir,name)
set(fig,'PaperPositionMode','auto'); savefig(fig,fullfile(outDir,[name '.fig']));
try
    exportgraphics(fig,fullfile(outDir,[name '.png']),'Resolution',300);
    exportgraphics(fig,fullfile(outDir,[name '.pdf']),'ContentType','vector');
catch
    print(fig,fullfile(outDir,[name '.png']),'-dpng','-r300'); print(fig,fullfile(outDir,[name '.pdf']),'-dpdf','-bestfit');
end
close(fig);
end

%% ======================================================================
% PATH UTILITIES
% =======================================================================
function root=locate_v10_root_locked(startDir)
% Locate ORIGINAL V10 only.  Do not accept V10-P0.1 for Exp05-P1.
root='';
candidates={};
bases={startDir,pwd};

for b=1:numel(bases)
    c=bases{b};
    for up=1:8
        if isempty(c), break; end
        candidates{end+1}=c; %#ok<AGROW>
        candidates{end+1}=fullfile(c,'v10_core'); %#ok<AGROW>
        candidates{end+1}=fullfile(c,'code','v10_core'); %#ok<AGROW>
        candidates{end+1}=fullfile(c,'AIGC_Coevolution_V10'); %#ok<AGROW>
        candidates{end+1}=fullfile(c,'v10_core','AIGC_Coevolution_V10'); %#ok<AGROW>
        p=fileparts(c);
        if strcmp(p,c), break; end
        c=p;
    end
end

% Prefer an already-resolved package only if it passes ORIGINAL V10 checks.
probe=which('aigc.default_parameters');
if ~isempty(probe)
    candidates{end+1}=fileparts(fileparts(probe)); %#ok<AGROW>
end

for k=1:numel(candidates)
    if is_valid_v10_root(candidates{k})
        root=candidates{k};
        return;
    end
end
end

function tf=is_valid_v10_root(root)
tf=false;
if isempty(root) || exist(root,'dir')~=7, return; end
pkg=fullfile(root,'+aigc');
if exist(pkg,'dir')~=7, return; end

required={'default_parameters.m','default_options.m','experiment_settings.m', ...
          'full_mode.m','solve_model.m','model_rhs.m'};
for k=1:numel(required)
    if exist(fullfile(pkg,required{k}),'file')~=2, return; end
end

% Reject the P0.1 source lineage for Exp05-P1.
if exist(fullfile(pkg,'exp06_timescale_causal_audit.m'),'file')==2 && ...
   exist(fullfile(pkg,'exp08_nested_policy_comparison.m'),'file')==2
    return;
end

tf=true;
end

function validate_exp05_v10_source_tree(root)
if ~is_valid_v10_root(root)
    error(['Exp05-P1 source-lineage check failed. ', ...
           'Use the original V10 tree, not V10-P0.1.']);
end

pkg=fullfile(root,'+aigc');
expected={{'aigc.default_parameters','default_parameters.m'}, ...
          {'aigc.default_options','default_options.m'}, ...
          {'aigc.experiment_settings','experiment_settings.m'}, ...
          {'aigc.solve_model','solve_model.m'}, ...
          {'aigc.model_rhs','model_rhs.m'}};

for k=1:numel(expected)
    funcName=expected{k}{1};
    fileName=expected{k}{2};
    resolved=which(funcName);
    target=fullfile(pkg,fileName);
    if isempty(resolved) || ~same_path_local(resolved,target)
        error(['MATLAB path conflict for %s.\nResolved: %s\nExpected: %s'], ...
            funcName,resolved,target);
    end
end

fprintf('Exp05-P1 ORIGINAL V10 source-lineage check: PASS\n');
end

function remove_competing_aigc_roots(selectedRoot)
funcs={'aigc.default_parameters','aigc.solve_model','aigc.model_rhs'};
roots={};
for i=1:numel(funcs)
    h=which(funcs{i},'-all');
    if ischar(h), h={h}; end
    for j=1:numel(h)
        roots{end+1}=fileparts(fileparts(h{j})); %#ok<AGROW>
    end
end
if isempty(roots), return; end
roots=unique(roots,'stable');
for k=1:numel(roots)
    r=roots{k};
    if ~strcmpi(normalize_path_local(r),normalize_path_local(selectedRoot))
        try
            rmpath(r);
            fprintf('[PATH] Removed competing AIGC root: %s\n',r);
        catch
        end
    end
end
rehash;
end

function tf=same_path_local(a,b)
tf=strcmpi(normalize_path_local(a),normalize_path_local(b));
end

function p=normalize_path_local(p)
p=char(p);
try, p=char(java.io.File(p).getCanonicalPath()); catch, end
p=strrep(p,'/',filesep);
while numel(p)>1 && p(end)==filesep, p(end)=[]; end
end

function warn_if_multiple_package_versions(funcName)
h=which(funcName,'-all'); if ischar(h), h={h}; end
if numel(h)>1
    fprintf(2,'WARNING: multiple %s versions are on path:\n',funcName); for k=1:numel(h), fprintf(2,'  %s\n',h{k}); end
end
end
