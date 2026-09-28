function report = check_package()
%CHECK_PACKAGE Static, formula, and branch checks before long V10 runs.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
required={ ...
    'RUN_ALL_PREVIEW_V10.m','RUN_ALL_QUICK_V10.m','RUN_ALL_FULL_V10.m', ...
    'RUN_SELECTED_V10.m','RUN_GATE_QUICK_V10.m','CHECK_PACKAGE_V10.m', ...
    'RUN_EXP06_EXP08_PREVIEW_V10P0.m','RUN_EXP06_EXP08_QUICK_V10P0.m','RUN_EXP06_EXP08_FULL_V10P0.m', ...
    'RUN_EXP06_EXP08_PREVIEW_V10P01.m','RUN_EXP06_EXP08_QUICK_V10P01.m','RUN_EXP06_EXP08_FULL_V10P01.m', ...
    '+aigc/main.m','+aigc/model_rhs.m','+aigc/model_terms.m', ...
    '+aigc/semantic_reference_terms.m','+aigc/stage_probability.m', ...
    '+aigc/parameter_display_name.m', ...
    '+aigc/default_parameters.m','+aigc/default_options.m','+aigc/experiment_settings.m', ...
    '+aigc/append_struct_row.m','+aigc/solve_adaptive_longrun.m', ...
    '+aigc/find_equilibrium.m','+aigc/matched_aigc_shock.m', ...
    '+aigc/tail_window_diagnostics.m','+aigc/is_resolved_label.m', ...
    '+aigc/morris_trajectory.m','+aigc/exp00_solver_validation.m', ...
    '+aigc/exp01_representative_regimes.m','+aigc/exp02_ablation_benchmarks.m', ...
    '+aigc/exp03_governance_factorial.m','+aigc/exp04_aigc_specific.m', ...
    '+aigc/exp05_global_sensitivity.m','+aigc/exp06_dynamic_instability.m', ...
    '+aigc/exp06_timescale_causal_audit.m', ...
    '+aigc/exp07_trust_shocks.m','+aigc/exp08_fair_policy_comparison.m', ...
    '+aigc/exp08_nested_policy_comparison.m', ...
    '+aigc/exp09_structural_robustness.m'};
missing={};
for i=1:numel(required)
    if ~exist(fullfile(projectRoot,required{i}),'file'), missing{end+1}=required{i}; end %#ok<AGROW>
end
if ~isempty(missing), error('Missing V10 files: %s',strjoin(missing,', ')); end

rows=struct([]); rows=aigc.append_struct_row(rows,struct('A',1,'B','first'));
rows=aigc.append_struct_row(rows,struct('B','second','A',2));
assert(numel(rows)==2 && rows(2).A==2,'append_struct_row unit test failed.');
p=aigc.default_parameters(); opt=aigc.default_options('preview');
s=aigc.experiment_settings('preview'); aigc.validate_model_configuration(p,opt,s);
mode=aigc.full_mode(); [dX,a]=aigc.model_rhs(0,opt.X0,p,mode);
assert(numel(dX)==10 && all(isfinite(dX)),'RHS is not finite.');
assert(a.phiIn>=0 && a.phiAct>=0,'Queue flows must be nonnegative.');
assert(all([a.pHandle,a.pAct,a.pIn,a.pSp,a.pRm]>=0) && ...
    all([a.pHandle,a.pAct,a.pIn,a.pSp,a.pRm]<=1),'Probability semantics failed.');
assert(isfield(a,'Q0') && ~isfield(a,'Q'),'Only Q0 may represent supply quality.');
assert(abs(a.Q0-(opt.X0(1)*p.qC+(1-opt.X0(1))*p.qS))<1e-12,'Q0 formula mismatch.');
assert(abs((a.piUV-a.piUD)-a.deltaPiU)<1e-10,'User-payoff identity mismatch.');
ref=aigc.semantic_reference_terms(0,opt.X0,p,mode);
fields={'aDet','phiIn','phiAct','pHandle','pAct','pIn','pSp','pRm','Q0','D','Qexp','deltaPiU'};
semanticError=0;
for j=1:numel(fields), semanticError=max(semanticError,abs(a.(fields{j})-ref.(fields{j}))); end
assert(semanticError<1e-12,'Independent formula transcription mismatch.');

% Stage mappings must be legal and structurally distinct.
forms={'linear','exponential','rational'}; stageValues=nan(1,numel(forms));
for j=1:numel(forms)
    [stageValues(j),~]=aigc.stage_probability(0.6,1,forms{j});
    assert(stageValues(j)>=0 && stageValues(j)<=1,'Stage mapping out of range.');
end
assert(numel(unique(round(stageValues*1e10)))==numel(forms),'Stage mappings are not distinct.');

% Exact M0-M1 strategy-derivative invariance at common states.
m0=aigc.nested_mode(0); m1=aigc.nested_mode(1); rng(2026072399,'twister');
for q=1:6
    Xq=aigc.clip01(opt.X0+0.15*(2*rand(10,1)-1));
    d0=aigc.model_rhs(0,Xq,p,m0); d1=aigc.model_rhs(0,Xq,p,m1);
    assert(max(abs(d0(1:3)-d1(1:3)))<1e-12,'M0-M1 strategy invariance failed.');
end

% P0 Exp06: positive time-scale multipliers must preserve zero sets.
modeFast=mode; modeFast.timeScaleA=10; modeFast.timeScaleL=10; modeFast.timeScaleM=10;
[dBase,~]=aigc.model_rhs(0,opt.X0,p,mode); [dFast,~]=aigc.model_rhs(0,opt.X0,p,modeFast);
keep=[1:5 7 10];
assert(max(abs(dBase(keep)-dFast(keep)))<1e-12,'Exp06 time-scale intervention changed non-target derivatives.');
assert(abs(dFast(6)-10*dBase(6))<1e-10 && abs(dFast(8)-10*dBase(8))<1e-10 && abs(dFast(9)-10*dBase(9))<1e-10, ...
    'Exp06 time-scale multipliers are not applied only to M/A/L equations.');

% P0 Exp08: a zero-gain dynamic controller must reproduce an arbitrary fixed u.
ubar=0.37; Xnest=opt.X0; Xnest(7)=ubar;
modeF=aigc.full_mode(); modeF.dynamicAudit=false; modeF.fixedAudit=true; modeF.fixedAuditIntensity=ubar;
modeF.activeMask(7)=false; modeF.costDynamic=false; modeF.costFixed=false; modeF.costPolicy=false;
modeD=aigc.full_mode(); modeD.dynamicAudit=true; modeD.fixedAudit=false;
modeD.costDynamic=false; modeD.costFixed=false; modeD.costPolicy=false;
pD=p; pD.etaI=0; pD.etaT=0; pD.etaA=0; pD.etaC=0;
optNest=opt; optNest.tEnd=2; optNest.outputStep=0.1; optNest.allowEarlyStop=false;
solF=aigc.solve_model(Xnest,p,modeF,optNest); solD=aigc.solve_model(Xnest,pD,modeD,optNest);
assert(max(abs(solF.X-solD.X),[],'all')<1e-9,'Exp08 fixed-in-dynamic nesting smoke test failed.');

% Smoke-test model variants and numerical helpers.
optSmoke=opt; optSmoke.tEnd=2; optSmoke.h=0.1; optSmoke.outputStep=0.1;
optSmoke.allowEarlyStop=false; branchCount=0;
for k=0:13, aigc.solve_model(opt.X0,p,aigc.nested_mode(k),optSmoke); branchCount=branchCount+1; end
for k=0:8, aigc.solve_model(opt.X0,p,aigc.leave_one_out_mode(k),optSmoke); branchCount=branchCount+1; end
for k=0:5, aigc.solve_model(opt.X0,p,aigc.trust_mode(k),optSmoke); branchCount=branchCount+1; end
for k=0:4
    [mb,pb]=aigc.benchmark_mode(sprintf('BM%d',k),p);
    aigc.solve_model(opt.X0,pb,mb,optSmoke); branchCount=branchCount+1;
end
[U,order,step]=aigc.morris_trajectory(numel(s.sensitivityNames),s.morrisLevels,20260731);
assert(size(U,1)==numel(order)+1 && all(abs(step)>0),'Morris trajectory construction failed.');
[aSol,~]=aigc.solve_adaptive_longrun(opt.X0,p,mode,optSmoke,4);
eq=aigc.find_equilibrium(aSol.finalState,p,mode,opt); %#ok<NASGU>
mm=aigc.matched_aigc_shock(aSol.finalState,p,mode,optSmoke,0.2);
assert(isfinite(mm.CapacityMatchError) && mm.InitialCapacityDifference<1e-10, ...
    'Onset-capacity matching failed.');
report=table(string(projectRoot),numel(required),numel(missing),semanticError, ...
    a.pDet,a.pHandle,a.pAct,a.pIn,a.pSp,a.pRm,a.phiIn,a.phiAct,a.Q0,a.Qexp,branchCount, ...
    'VariableNames',{'ProjectRoot','RequiredFiles','MissingFiles','SemanticError', ...
    'pDet','pHandle','pAct','pIn','pSp','pRm','phiIn','phiAct','Q0','Qexp','SmokeTestBranches'});
fprintf('V10 package check passed.\n');
end
