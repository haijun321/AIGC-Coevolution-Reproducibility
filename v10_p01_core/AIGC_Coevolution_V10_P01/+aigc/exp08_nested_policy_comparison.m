function exp08_nested_policy_comparison(p,opt,settings,outputRoot)
%EXP08_NESTED_POLICY_COMPARISON
% P0.1 review-closure replacement for Exp08.
%
% Evidence layer 1: equal-budget search efficiency.
%   Fixed and raw dynamic searches use the same NFE / wall-clock budgets.
%   The nested envelope min(best fixed,best raw dynamic) is reported because
%   every fixed policy is an exact zero-gain dynamic-family special case.
%
% Evidence layer 2: expanded-search policy-family potential.
%   Dynamic-only B/2B/4B searches are retained and their candidates are
%   propagated into subsequent core, implementation-aware, hold-out,
%   matching, weight-sensitivity and dynamics evaluations.  Thus a better
%   adaptive candidate discovered at 4B is not discarded after the search-
%   adequacy diagnostic.
%
% Evidence layer 3: implementation-aware policy comparison.
%   The SAME candidate pools are re-evaluated with policy-specific costs.
%   This separates adaptive control gain from implementation overhead.

outDir=fullfile(outputRoot,'Exp08_nested_policy_comparison');
aigc.ensure_dir(outDir);
optPolicy=opt; optPolicy.solver='ode45'; optPolicy.allowEarlyStop=false;
calib=calibration_environments(optPolicy); test=test_environments(optPolicy);
N=settings.policyBudget; R=settings.policyRepeats; w=settings.policyWeights;

% =============================================================
% A. Strict nesting audit BEFORE any optimization.
% =============================================================
Tnest=nested_family_audit(p,optPolicy,settings,calib,w);
writetable(Tnest,fullfile(outDir,'exp08_nested_family_audit.csv'));
if ~all(Tnest.Pass)
    error('Exp08 strict nesting audit failed. Inspect exp08_nested_family_audit.csv before policy optimization.');
end

% =============================================================
% B. Equal-budget mechanism-neutral searches.
% =============================================================
fixedRows=struct([]); dynRows=struct([]); convRows=struct([]); wallRows=struct([]); dualRows=struct([]);
for rep=1:R
    [TFrep,~]=fixed_search(N,rep,p,optPolicy,calib,w,settings,'core');
    [TDrep,~]=dynamic_search(N,N,rep,p,optPolicy,calib,w,settings,'core',0);
    fixedRows=append_table_rows(fixedRows,TFrep); dynRows=append_table_rows(dynRows,TDrep);

    fixedBestFull=min(TFrep.J); bestF=Inf; bestDRaw=Inf;
    for i=1:N
        bestF=min(bestF,TFrep.J(i)); bestDRaw=min(bestDRaw,TDrep.J(i));
        row=struct(); row.Repeat=rep; row.Evaluation=i;
        row.BestFixedRawJ=bestF; row.BestDynamicRawJ=bestDRaw;
        row.EmbeddedFixedBaselineJ=fixedBestFull;
        row.BestDynamicNestedFamilyJ=min(fixedBestFull,bestDRaw);
        row.FixedCumulativeSeconds=TFrep.CumulativeSeconds(i);
        row.DynamicCumulativeSeconds=TDrep.CumulativeSeconds(i);
        convRows=aigc.append_struct_row(convRows,row);
    end
    [wr,dual]=wall_clock_comparison(TFrep,TDrep,rep,settings);
    for q=1:numel(wr), wallRows=aigc.append_struct_row(wallRows,wr(q)); end
    dual.NestedFamilyBest=min(fixedBestFull,min(TDrep.J));
    dual.EmbeddedFixedBaseline=fixedBestFull;
    dualRows=aigc.append_struct_row(dualRows,dual);
    fprintf('Exp08 equal-budget core repeat %d/%d completed. fixed=%g rawDyn=%g nested=%g\n', ...
        rep,R,fixedBestFull,min(TDrep.J),min(fixedBestFull,min(TDrep.J)));
end

TfixedCore=aigc.struct_rows_to_table(fixedRows);
TdynCore=aigc.struct_rows_to_table(dynRows);
writetable(TfixedCore,fullfile(outDir,'exp08_core_fixed_candidate_frontier.csv'));
writetable(TdynCore,fullfile(outDir,'exp08_core_dynamic_raw_candidate_frontier.csv'));

TconvRaw=aigc.struct_rows_to_table(convRows); Tconv=aggregate_convergence(TconvRaw,N);
TwallRaw=aigc.struct_rows_to_table(wallRows); Twall=aggregate_wall_convergence(TwallRaw);
Tdual=aigc.struct_rows_to_table(dualRows);
writetable(Tconv,fullfile(outDir,'exp08_core_evaluation_budget_convergence.csv'));
writetable(Twall,fullfile(outDir,'exp08_core_wall_clock_budget_convergence.csv'));
writetable(Tdual,fullfile(outDir,'exp08_core_dual_budget_summary.csv'));

% Equal-budget selected core policies.
[~,iFcore]=min(TfixedCore.J); PfixCore=row_to_candidate(TfixedCore(iFcore,:),'fixed');
[~,iDrawEq]=min(TdynCore.J); PdynRawEqCore=row_to_candidate(TdynCore(iDrawEq,:),'dynamic');
JfixCore=TfixedCore.J(iFcore); JdynRawEqCore=TdynCore.J(iDrawEq);
if JdynRawEqCore < JfixCore
    PdynEqCore=PdynRawEqCore; dynEqSource='adaptive_dynamic_equal_budget';
else
    PdynEqCore=embedded_dynamic(PfixCore,p); dynEqSource='embedded_fixed_optimum_equal_budget';
end

% =============================================================
% C. Dynamic-only B/2B/4B search and candidate propagation.
% =============================================================
Nmax=max(settings.policyBudgetMultipliers)*N;
budgetRows=struct([]); budgetTraceRows=struct([]); longRows=struct([]);
for rep=1:R
    [Tlong,~]=dynamic_search(Nmax,N,rep,p,optPolicy,calib,w,settings,'core',7000);
    % Mark long-search rows explicitly, then retain every candidate.
    for i=1:height(Tlong)
        r=table2struct(Tlong(i,:));
        r.SearchStage=['expanded_' char(string(Tlong.SearchStage(i)))];
        longRows=aigc.append_struct_row(longRows,r);
    end
    for mult=settings.policyBudgetMultipliers
        nUse=mult*N; bestRaw=min(Tlong.J(1:nUse));
        row=struct(); row.Repeat=rep; row.BudgetMultiplier=mult; row.Evaluations=nUse;
        row.FixedCoreBest=JfixCore; row.RawDynamicBest=bestRaw;
        row.NestedFamilyBest=min(JfixCore,bestRaw); row.AdaptiveGain=max(0,JfixCore-bestRaw);
        row.RawDynamicMinusFixed=bestRaw-JfixCore;
        budgetRows=aigc.append_struct_row(budgetRows,row);
    end
    b=Inf;
    for i=1:height(Tlong)
        b=min(b,Tlong.J(i)); r=struct(); r.Repeat=rep; r.Evaluation=i;
        r.RawBestDynamicJ=b; r.NestedBestDynamicJ=min(JfixCore,b);
        budgetTraceRows=aigc.append_struct_row(budgetTraceRows,r);
    end
end
Tbudget=aigc.struct_rows_to_table(budgetRows);
TbudgetTrace=aigc.struct_rows_to_table(budgetTraceRows);
TdynLongCore=aigc.struct_rows_to_table(longRows);
TdynExpandedCore=[TdynCore;TdynLongCore];
writetable(Tbudget,fullfile(outDir,'exp08_dynamic_budget_scaling.csv'));
writetable(TbudgetTrace,fullfile(outDir,'exp08_dynamic_long_search_trace.csv'));
writetable(TdynLongCore,fullfile(outDir,'exp08_core_dynamic_expanded_search_candidates.csv'));
writetable(TdynExpandedCore,fullfile(outDir,'exp08_core_dynamic_expanded_candidate_pool.csv'));

% Expanded-search selected core policy.
[~,iDrawExp]=min(TdynExpandedCore.J);
PdynRawExpCore=row_to_candidate(TdynExpandedCore(iDrawExp,:),'dynamic');
JdynRawExpCore=TdynExpandedCore.J(iDrawExp);
if JdynRawExpCore < JfixCore
    PdynExpCore=PdynRawExpCore; dynExpSource='adaptive_dynamic_expanded_search';
else
    PdynExpCore=embedded_dynamic(PfixCore,p); dynExpSource='embedded_fixed_optimum_expanded_search';
end

MfixCore=evaluate_candidate(PfixCore,p,optPolicy,calib,w,'core');
MdynRawEqCore=evaluate_candidate(PdynRawEqCore,p,optPolicy,calib,w,'core');
MdynEqCore=evaluate_candidate(PdynEqCore,p,optPolicy,calib,w,'core');
MdynRawExpCore=evaluate_candidate(PdynRawExpCore,p,optPolicy,calib,w,'core');
MdynExpCore=evaluate_candidate(PdynExpCore,p,optPolicy,calib,w,'core');
coreRows=struct([]);
coreRows=aigc.append_struct_row(coreRows,comparison_row('best_fixed_core',PfixCore,MfixCore,'fixed_search'));
coreRows=aigc.append_struct_row(coreRows,comparison_row('best_dynamic_raw_equal_budget_core',PdynRawEqCore,MdynRawEqCore,'raw_dynamic_equal_budget'));
coreRows=aigc.append_struct_row(coreRows,comparison_row('best_dynamic_nested_equal_budget_core',PdynEqCore,MdynEqCore,dynEqSource));
coreRows=aigc.append_struct_row(coreRows,comparison_row('best_dynamic_raw_expanded_core',PdynRawExpCore,MdynRawExpCore,'raw_dynamic_expanded_search'));
coreRows=aigc.append_struct_row(coreRows,comparison_row('best_dynamic_nested_expanded_core',PdynExpCore,MdynExpCore,dynExpSource));
Tcore=aigc.struct_rows_to_table(coreRows);
writetable(Tcore,fullfile(outDir,'exp08_core_policy_comparison.csv'));

if MdynEqCore.J > MfixCore.J + settings.policyNestedObjectiveTol || ...
        MdynExpCore.J > MfixCore.J + settings.policyNestedObjectiveTol
    error('Nested-family theorem violated numerically: a nested dynamic core best is worse than fixed.');
end

% =============================================================
% D. Implementation-aware re-evaluation of BOTH dynamic pools.
% =============================================================
TfixedTotal=revalue_candidate_table(TfixedCore,p,optPolicy,calib,w,'total');

TdynTotalEqRaw=revalue_candidate_table(TdynCore,p,optPolicy,calib,w,'total');
TdynTotalEmbedded=embedded_dynamic_table(TfixedCore,p,optPolicy,calib,w,'total');
TdynTotalEq=[TdynTotalEqRaw;TdynTotalEmbedded];

% Re-rank a prespecified top core subset from the expanded search.  This
% guarantees that 4B candidates propagate into the total layer without
% re-simulating every long-search point under implementation costs.
if isfield(settings,'policyExpandedTotalRerankPerRepeat')
    nRerank=settings.policyExpandedTotalRerankPerRepeat;
else
    nRerank=max(12,round(0.10*height(TdynExpandedCore)/max(R,1)));
end
TdynExpandedRerankCore=select_rerank_pool(TdynExpandedCore,nRerank);
writetable(TdynExpandedRerankCore,fullfile(outDir,'exp08_core_dynamic_expanded_total_rerank_pool.csv'));
TdynTotalExpRaw=revalue_candidate_table(TdynExpandedRerankCore,p,optPolicy,calib,w,'total');
TdynTotalExp=[TdynTotalExpRaw;TdynTotalEmbedded];

writetable(TfixedTotal,fullfile(outDir,'exp08_total_fixed_candidate_frontier.csv'));
writetable(TdynTotalEq,fullfile(outDir,'exp08_total_dynamic_candidate_frontier_equal_budget.csv'));
writetable(TdynTotalExp,fullfile(outDir,'exp08_total_dynamic_candidate_frontier_expanded.csv'));
% Backward-compatible name points to the scientifically richer expanded pool.
writetable(TdynTotalExp,fullfile(outDir,'exp08_total_dynamic_candidate_frontier.csv'));

[~,iFtot]=min(TfixedTotal.J);
[~,iDeqTot]=min(TdynTotalEq.J);
[~,iDexpTot]=min(TdynTotalExp.J);
PfixTotal=row_to_candidate(TfixedTotal(iFtot,:),'fixed');
PdynEqTotal=row_to_candidate(TdynTotalEq(iDeqTot,:),'dynamic');
PdynExpTotal=row_to_candidate(TdynTotalExp(iDexpTot,:),'dynamic');
MfixTotal=evaluate_candidate(PfixTotal,p,optPolicy,calib,w,'total');
MdynEqTotal=evaluate_candidate(PdynEqTotal,p,optPolicy,calib,w,'total');
MdynExpTotal=evaluate_candidate(PdynExpTotal,p,optPolicy,calib,w,'total');
totalRows=struct([]);
totalRows=aigc.append_struct_row(totalRows,comparison_row('best_fixed_total',PfixTotal,MfixTotal,'fixed_candidate_rerank'));
totalRows=aigc.append_struct_row(totalRows,comparison_row('best_dynamic_equal_budget_total',PdynEqTotal,MdynEqTotal,'equal_budget_dynamic_pool_rerank'));
totalRows=aigc.append_struct_row(totalRows,comparison_row('best_dynamic_expanded_total',PdynExpTotal,MdynExpTotal,'expanded_dynamic_pool_rerank'));
Ttotal=aigc.struct_rows_to_table(totalRows);
writetable(Ttotal,fullfile(outDir,'exp08_total_policy_comparison.csv'));

% =============================================================
% E. Prespecified comparators + equal-budget + expanded selections.
% =============================================================
P0=original_dynamic_candidate(p,optPolicy);
P1=fixed_candidate(settings.policyFixedLow);
P2=fixed_candidate(settings.policyFixedHigh);
policiesCore={P0,P1,P2,PfixCore,PdynEqCore,PdynExpCore};
namesCore={'P0_original_dynamic','P1_low_fixed','P2_high_fixed','P3_best_fixed_core', ...
    'P4_equal_budget_nested_dynamic_core','P5_expanded_nested_dynamic_core'};
policiesTotal={P0,P1,P2,PfixTotal,PdynEqTotal,PdynExpTotal};
namesTotal={'P0_original_dynamic','P1_low_fixed','P2_high_fixed','P3_best_fixed_total', ...
    'P4_equal_budget_dynamic_total','P5_expanded_dynamic_total'};
TselCore=selected_policy_table(policiesCore,namesCore,p,optPolicy,calib,w,'core');
TselTotal=selected_policy_table(policiesTotal,namesTotal,p,optPolicy,calib,w,'total');
writetable(TselCore,fullfile(outDir,'exp08_selected_policy_calibration_core.csv'));
writetable(TselTotal,fullfile(outDir,'exp08_selected_policy_calibration_total.csv'));
save(fullfile(outDir,'exp08_selected_policies.mat'),'P0','P1','P2','PfixCore','PdynEqCore','PdynExpCore', ...
    'PfixTotal','PdynEqTotal','PdynExpTotal','w','settings');

% =============================================================
% F. Frozen independent test environments.
% =============================================================
TtestCore=test_policy_table(policiesCore,namesCore,p,optPolicy,test,w,'core');
TtestTotal=test_policy_table(policiesTotal,namesTotal,p,optPolicy,test,w,'total');
writetable(TtestCore,fullfile(outDir,'exp08_selected_policy_test_core.csv'));
writetable(TtestTotal,fullfile(outDir,'exp08_selected_policy_test_total.csv'));

% =============================================================
% G. Equal-risk/equal-budget feasibility for both dynamic selections.
% =============================================================
allEnvs=[calib(:);test(:)];
TmatchEq=matching_feasibility(PdynEqTotal,p,optPolicy,allEnvs,w,settings,'total');
TmatchExp=matching_feasibility(PdynExpTotal,p,optPolicy,allEnvs,w,settings,'total');
writetable(TmatchEq,fullfile(outDir,'exp08_matching_feasibility_total_equal_budget.csv'));
writetable(TmatchExp,fullfile(outDir,'exp08_matching_feasibility_total_expanded.csv'));
writetable(TmatchExp,fullfile(outDir,'exp08_matching_feasibility_total.csv'));

% =============================================================
% H. Objective-weight sensitivity for equal-budget AND expanded pools.
% =============================================================
Tweight=weight_sensitivity(TfixedCore,TdynCore,TdynExpandedCore, ...
    TfixedTotal,TdynTotalEq,TdynTotalExp,settings);
writetable(Tweight,fullfile(outDir,'exp08_weight_sensitivity.csv'));

% =============================================================
% I. Policy dynamics for all selected policy layers.
% =============================================================
TdynSummary=[policy_dynamics_table(PfixCore,'fixed_core',p,optPolicy,allEnvs,'core'); ...
             policy_dynamics_table(PdynEqCore,'dynamic_equal_budget_core',p,optPolicy,allEnvs,'core'); ...
             policy_dynamics_table(PdynExpCore,'dynamic_expanded_core',p,optPolicy,allEnvs,'core'); ...
             policy_dynamics_table(PfixTotal,'fixed_total',p,optPolicy,allEnvs,'total'); ...
             policy_dynamics_table(PdynEqTotal,'dynamic_equal_budget_total',p,optPolicy,allEnvs,'total'); ...
             policy_dynamics_table(PdynExpTotal,'dynamic_expanded_total',p,optPolicy,allEnvs,'total')];
writetable(TdynSummary,fullfile(outDir,'exp08_policy_dynamics.csv'));

% =============================================================
% J. Automated gate + figure.
% =============================================================
Tqc=quality_check(Tnest,Tcore,Tbudget,TtestCore,TtestTotal,TdynExpandedCore,settings);
writetable(Tqc,fullfile(outDir,'experiment_quality_check.csv'));
plot_policy_evidence(TfixedCore,TdynCore,TdynExpandedCore,Tconv,Tbudget,TmatchExp,Tweight,JfixCore,outDir);
end

% =====================================================================
% Search and candidate utilities
% =====================================================================
function [T,bestCand]=fixed_search(N,rep,p,opt,envs,w,settings,costMode)
nGlobal=max(3,min(N,round(settings.policyGlobalFraction*N)));
uGlobal=linspace(settings.policyUmin,settings.policyUmax,nGlobal)';
rows=struct([]); cum=0;
for i=1:nGlobal
    cand=fixed_candidate(uGlobal(i)); [m,elapsed]=timed_evaluation(cand,p,opt,envs,w,costMode); cum=cum+elapsed;
    rows=aigc.append_struct_row(rows,candidate_row(rep,i,cand,m,elapsed,cum,'global_grid',costMode));
end
if nGlobal<N
    T0=aigc.struct_rows_to_table(rows); [~,ib]=min(T0.J); center=T0.u0(ib);
    spacing=(settings.policyUmax-settings.policyUmin)/max(nGlobal-1,1); radius=2*spacing;
    uLocal=linspace(max(settings.policyUmin,center-radius),min(settings.policyUmax,center+radius),N-nGlobal+2)';
    uLocal=uLocal(2:end-1);
    for q=1:numel(uLocal)
        i=nGlobal+q; cand=fixed_candidate(uLocal(q)); [m,elapsed]=timed_evaluation(cand,p,opt,envs,w,costMode); cum=cum+elapsed;
        rows=aigc.append_struct_row(rows,candidate_row(rep,i,cand,m,elapsed,cum,'local_refinement',costMode));
    end
end
T=aigc.struct_rows_to_table(rows); [~,ib]=min(T.J); bestCand=row_to_candidate(T(ib,:),'fixed');
end

function [T,bestCand]=dynamic_search(N,baseBudget,rep,p,opt,envs,w,settings,costMode,seedOffset)
% Independent raw adaptive search.  The fixed optimum is NOT injected here;
% the nested-family envelope is computed separately, preserving raw search
% difficulty evidence.
nInitial=max(4,min(N,round(settings.policyGlobalFraction*baseBudget)));
U=aigc.lhs_unit(nInitial,4,settings.policySeed+seedOffset+100*rep+1);
rows=struct([]); cum=0;
for i=1:nInitial
    cand=dynamic_from_unit(U(i,:),settings); [m,elapsed]=timed_evaluation(cand,p,opt,envs,w,costMode); cum=cum+elapsed;
    rows=aigc.append_struct_row(rows,candidate_row(rep,i,cand,m,elapsed,cum,'lhs_multistart',costMode));
end
if nInitial<N
    T0=aigc.struct_rows_to_table(rows); [~,ord]=sort(T0.J,'ascend');
    nCenters=min(settings.policyLocalStarts,numel(ord)); centers=zeros(nCenters,4);
    for c=1:nCenters, centers(c,:)=candidate_to_unit(row_to_candidate(T0(ord(c),:),'dynamic'),settings); end
    nLocal=N-nInitial; UL=aigc.lhs_unit(nLocal,4,settings.policySeed+seedOffset+100*rep+2);
    for q=1:nLocal
        center=centers(1+mod(q-1,nCenters),:);
        radius=0.25-0.20*(q-1)/max(nLocal-1,1);
        uu=min(max(center+2*radius*(UL(q,:)-0.5),0),1);
        cand=dynamic_from_unit(uu,settings); i=nInitial+q;
        [m,elapsed]=timed_evaluation(cand,p,opt,envs,w,costMode); cum=cum+elapsed;
        rows=aigc.append_struct_row(rows,candidate_row(rep,i,cand,m,elapsed,cum,'local_multistart',costMode));
    end
end
T=aigc.struct_rows_to_table(rows); [~,ib]=min(T.J); bestCand=row_to_candidate(T(ib,:),'dynamic');
end

function cand=fixed_candidate(u)
cand=struct('type','fixed','u0',u,'auditSpeed',NaN,'gainScale',NaN,'etaCScale',NaN);
end

function cand=embedded_dynamic(fixedCand,p)
cand=struct('type','dynamic','u0',fixedCand.u0,'auditSpeed',p.auditSpeed,'gainScale',0,'etaCScale',0);
end

function cand=original_dynamic_candidate(p,opt)
cand=struct('type','dynamic','u0',opt.X0(7),'auditSpeed',p.auditSpeed,'gainScale',1,'etaCScale',1);
end

function cand=dynamic_from_unit(u,settings)
r1=settings.policyAuditSpeedRange; r2=settings.policyGainScaleRange; r3=settings.policyEtaCScaleRange;
cand=struct('type','dynamic', ...
    'u0',settings.policyUmin+u(1)*(settings.policyUmax-settings.policyUmin), ...
    'auditSpeed',r1(1)+u(2)*(r1(2)-r1(1)), ...
    'gainScale',r2(1)+u(3)*(r2(2)-r2(1)), ...
    'etaCScale',r3(1)+u(4)*(r3(2)-r3(1)));
end

function u=candidate_to_unit(cand,settings)
r1=settings.policyAuditSpeedRange; r2=settings.policyGainScaleRange; r3=settings.policyEtaCScaleRange;
u=[(cand.u0-settings.policyUmin)/(settings.policyUmax-settings.policyUmin), ...
   (cand.auditSpeed-r1(1))/(r1(2)-r1(1)), ...
   (cand.gainScale-r2(1))/max(r2(2)-r2(1),eps), ...
   (cand.etaCScale-r3(1))/max(r3(2)-r3(1),eps)];
u=min(max(u,0),1);
end

function [m,elapsed]=timed_evaluation(cand,p,opt,envs,w,costMode)
t=tic; m=evaluate_candidate(cand,p,opt,envs,w,costMode); elapsed=toc(t);
end

% =====================================================================
% Strict nesting audit
% =====================================================================
function T=nested_family_audit(p,opt,settings,envs,w)
uGrid=linspace(settings.policyUmin,settings.policyUmax,settings.policyNestedAuditN);
rows=struct([]);
for iu=1:numel(uGrid)
    cf=fixed_candidate(uGrid(iu)); cd=embedded_dynamic(cf,p);
    for e=1:numel(envs)
        [mf,sf]=evaluate_single_environment(cf,p,opt,envs(e),w,'core',true);
        [md,sd]=evaluate_single_environment(cd,p,opt,envs(e),w,'core',true);
        if numel(sf.t)==numel(sd.t) && max(abs(sf.t-sd.t))<1e-12
            traj=max(abs(sf.X-sd.X),[],'all'); final=max(abs(sf.finalState-sd.finalState));
        else
            traj=Inf; final=Inf;
        end
        row=struct(); row.uFixed=uGrid(iu); row.Environment=envs(e).name;
        row.TrajectoryMaxError=traj; row.FinalStateError=final;
        row.JIError=abs(mf.JI-md.JI); row.JTError=abs(mf.JT-md.JT); row.JCError=abs(mf.JC-md.JC);
        row.JError=abs(mf.J-md.J); row.FixedJ=mf.J; row.EmbeddedDynamicJ=md.J;
        row.Pass=traj<=settings.policyNestedTrajectoryTol && row.JError<=settings.policyNestedObjectiveTol;
        rows=aigc.append_struct_row(rows,row);
    end
end
T=aigc.struct_rows_to_table(rows);
end

% =====================================================================
% Evaluation semantics
% =====================================================================
function m=evaluate_candidate(cand,p,opt,envs,w,costMode)
vals=nan(numel(envs),12);
for e=1:numel(envs)
    [me,~]=evaluate_single_environment(cand,p,opt,envs(e),w,costMode,false);
    vals(e,:)=[me.JI,me.JT,me.JC,me.J,me.TotalCost,me.Resolved,me.TailWindowRobust, ...
        me.AmpI,me.AmpT,me.IsEquilibrium,me.IsCycle,me.FinalTime];
end
m.JI=mean(vals(:,1)); m.JT=mean(vals(:,2)); m.JC=mean(vals(:,3)); m.J=mean(vals(:,4));
m.TotalCost=mean(vals(:,5)); m.ResolvedShare=mean(vals(:,6)); m.TailWindowRobustShare=mean(vals(:,7));
m.MeanAmpI=mean(vals(:,8)); m.MeanAmpT=mean(vals(:,9)); m.EquilibriumShare=mean(vals(:,10));
m.CycleShare=mean(vals(:,11)); m.MeanFinalTime=mean(vals(:,12));
end

function [m,sol]=evaluate_single_environment(cand,p,opt,env,w,costMode,returnSol)
pp=prepare_policy_parameters(cand,p,env.pmods); [mode,X0]=policy_mode_and_state(cand,env.X0,costMode);
mode.shock=env.shock;
sol=aigc.solve_model(X0,pp,mode,opt);
ev=aigc.evaluate_solution(sol,pp,mode); ss=aigc.summarize_solution(sol,pp,mode,opt,ev);
tailStart=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1)); idx=find(sol.t>=tailStart);
jt=aigc.time_average(sol.t(idx),max(pp.Tstar-ev.T(idx),0)); ji=ss.I; jc=ev.JC; J=w(1)*ji+w(2)*jt+w(3)*jc;
ampT=max(ev.T(idx))-min(ev.T(idx));
m=struct(); m.JI=ji; m.JT=jt; m.JC=jc; m.J=J; m.TotalCost=ev.totalCost;
m.Resolved=double(aigc.is_resolved_label(ss.dynamics)); m.TailWindowRobust=double(ss.tailWindowClassRobust);
m.AmpI=ss.ampI; m.AmpT=ampT; m.IsEquilibrium=double(contains(ss.dynamics,'equilibrium'));
m.IsCycle=double(strcmp(ss.dynamics,'stable_cycle')); m.Dynamics=ss.dynamics; m.Period=ss.period; m.PeriodCV=ss.periodCV;
m.FinalTime=sol.finalTime; m.SpectralAbscissa=ss.spectralAbscissa;
if ~returnSol, sol=[]; end
end

function [mode,X0]=policy_mode_and_state(cand,X0,costMode)
mode=aigc.full_mode(); X0=X0(:); X0(7)=cand.u0;
% Cost flags are explicitly set here; no policy-type overhead is present in core mode.
mode.costDynamic=false; mode.costFixed=false; mode.costPolicy=false;
if strcmp(cand.type,'fixed')
    mode.dynamicAudit=false; mode.fixedAudit=true; mode.fixedAuditIntensity=cand.u0; mode.activeMask(7)=false;
    if strcmp(costMode,'total'), mode.costFixed=true; end
else
    mode.dynamicAudit=true; mode.fixedAudit=false; mode.activeMask(7)=true;
    if strcmp(costMode,'total'), mode.costDynamic=true; end
end
end

function pp=apply_dynamic_parameters(cand,pp)
if strcmp(cand.type,'dynamic')
    pp.auditSpeed=cand.auditSpeed;
    pp.etaI=pp.etaI*cand.gainScale;
    pp.etaT=pp.etaT*cand.gainScale;
    pp.etaA=pp.etaA*cand.gainScale;
    pp.etaC=pp.etaC*cand.etaCScale;
end
end

% IMPORTANT: policy_mode_and_state and parameter scaling must both be used.
% This wrapper keeps the single-environment evaluator concise and auditable.
function pp=prepare_policy_parameters(cand,p,mods)
pp=apply_mods(p,mods); pp=apply_dynamic_parameters(cand,pp);
end

% =====================================================================
% Environment definitions
% =====================================================================
function envs=calibration_environments(opt)
H=opt.tEnd;
envs(1)=make_env('steady',opt.X0,aigc.no_shock(),struct());
sh=aigc.no_shock(); sh.type='risk_environment'; sh.windows=[0.68*H 0.70*H]; sh.strength=0.45;
envs(2)=make_env('tail_instant_shock',opt.X0,sh,struct());
X=opt.X0; X(4)=0.72; X(5)=0.32; X(8)=0.30; X(10)=0.35;
envs(3)=make_env('high_risk_initial',X,aigc.no_shock(),struct());
end

function envs=test_environments(opt)
H=opt.tEnd;
sh=aigc.no_shock(); sh.type='risk_environment'; sh.windows=[0.55*H 0.85*H]; sh.strength=0.45;
envs(1)=make_env('tail_sustained_shock',opt.X0,sh,struct());
starts=[0.55 0.70 0.85]*H; width=0.035*H;
sh=aigc.no_shock(); sh.type='risk_environment'; sh.windows=[starts(:),starts(:)+width]; sh.strength=0.45;
envs(2)=make_env('tail_repeated_shock',opt.X0,sh,struct());
envs(3)=make_env('high_AIGC',opt.X0,aigc.no_shock(),struct('rhoE',0.65,'psiE',1.55));
envs(4)=make_env('high_audit_cost',opt.X0,aigc.no_shock(),struct('CR',0.70,'costDynamicSystem',0.18));
envs(5)=make_env('low_user_attention',opt.X0,aigc.no_shock(),struct('chi',0.35));
envs(6)=make_env('high_false_positive',opt.X0,aigc.no_shock(),struct('f',0.18));
end

function env=make_env(name,X0,shock,pmods)
env.name=name; env.X0=X0(:); env.shock=shock; env.pmods=pmods;
end

function pp=apply_mods(p,mods)
pp=p; fn=fieldnames(mods); for i=1:numel(fn), pp.(fn{i})=mods.(fn{i}); end
end

% =====================================================================
% TABLES / post-processing
% =====================================================================
function row=candidate_row(rep,id,cand,m,elapsed,cumulative,stage,costMode)
row=struct(); row.Repeat=rep; row.Candidate=id; row.SearchStage=stage; row.CostMode=costMode; row.Type=cand.type;
row.u0=cand.u0; row.auditSpeed=cand.auditSpeed; row.gainScale=cand.gainScale; row.etaCScale=cand.etaCScale;
row.JI=m.JI; row.JT=m.JT; row.JC=m.JC; row.J=m.J; row.TotalCost=m.TotalCost;
row.ResolvedShare=m.ResolvedShare; row.TailWindowRobustShare=m.TailWindowRobustShare;
row.MeanAmpI=m.MeanAmpI; row.MeanAmpT=m.MeanAmpT; row.EquilibriumShare=m.EquilibriumShare; row.CycleShare=m.CycleShare;
row.ElapsedSeconds=elapsed; row.CumulativeSeconds=cumulative;
end

function cand=row_to_candidate(Trow,type)
cand.type=type; cand.u0=Trow.u0;
if strcmp(type,'fixed')
    cand.auditSpeed=NaN; cand.gainScale=NaN; cand.etaCScale=NaN;
else
    cand.auditSpeed=Trow.auditSpeed; cand.gainScale=Trow.gainScale; cand.etaCScale=Trow.etaCScale;
end
end

function row=comparison_row(name,cand,m,source)
row=struct(); row.Policy=name; row.Source=source; row.Type=cand.type; row.u0=cand.u0;
row.auditSpeed=cand.auditSpeed; row.gainScale=cand.gainScale; row.etaCScale=cand.etaCScale;
row.JI=m.JI; row.JT=m.JT; row.JC=m.JC; row.J=m.J; row.TotalCost=m.TotalCost;
row.ResolvedShare=m.ResolvedShare; row.MeanAmpI=m.MeanAmpI; row.MeanAmpT=m.MeanAmpT;
row.EquilibriumShare=m.EquilibriumShare; row.CycleShare=m.CycleShare;
end

function T=revalue_candidate_table(Tin,p,opt,envs,w,costMode)
rows=struct([]);
for i=1:height(Tin)
    cand=row_to_candidate(Tin(i,:),char(string(Tin.Type(i)))); m=evaluate_candidate(cand,p,opt,envs,w,costMode);
    row=candidate_row(Tin.Repeat(i),Tin.Candidate(i),cand,m,NaN,NaN,char(string(Tin.SearchStage(i))),costMode);
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function T=embedded_dynamic_table(Tfixed,p,opt,envs,w,costMode)
rows=struct([]);
for i=1:height(Tfixed)
    cf=row_to_candidate(Tfixed(i,:),'fixed'); cand=embedded_dynamic(cf,p);
    m=evaluate_candidate(cand,p,opt,envs,w,costMode);
    row=candidate_row(Tfixed.Repeat(i),Tfixed.Candidate(i),cand,m,NaN,NaN,'embedded_fixed_subfamily',costMode);
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function T=select_rerank_pool(Tin,nPerRepeat)
% Select the best core candidates within each repeat for implementation-cost
% re-evaluation.  Search/re-ranking uses calibration data only.
reps=unique(Tin.Repeat); rows=struct([]);
for ir=1:numel(reps)
    S=Tin(Tin.Repeat==reps(ir),:);
    [~,ord]=sort(S.J,'ascend');
    ord=ord(1:min(nPerRepeat,numel(ord)));
    for j=1:numel(ord)
        rows=aigc.append_struct_row(rows,table2struct(S(ord(j),:)));
    end
end
T=aigc.struct_rows_to_table(rows);
end

function T=selected_policy_table(policies,names,p,opt,envs,w,costMode)
rows=struct([]);
for k=1:numel(policies)
    m=evaluate_candidate(policies{k},p,opt,envs,w,costMode);
    rows=aigc.append_struct_row(rows,comparison_row(names{k},policies{k},m,'selected'));
end
T=aigc.struct_rows_to_table(rows);
end

function T=test_policy_table(policies,names,p,opt,envs,w,costMode)
rows=struct([]);
for k=1:numel(policies)
    for e=1:numel(envs)
        [m,~]=evaluate_single_environment(policies{k},p,opt,envs(e),w,costMode,false);
        row=struct(); row.Policy=names{k}; row.Environment=envs(e).name; row.CostMode=costMode;
        row.JI=m.JI; row.JT=m.JT; row.JC=m.JC; row.J=m.J; row.TotalCost=m.TotalCost;
        row.Dynamics=m.Dynamics; row.Resolved=m.Resolved; row.AmpI=m.AmpI; row.AmpT=m.AmpT;
        row.Period=m.Period; row.PeriodCV=m.PeriodCV; row.SpectralAbscissa=m.SpectralAbscissa;
        rows=aigc.append_struct_row(rows,row);
    end
end
T=aigc.struct_rows_to_table(rows);
end

function T=policy_dynamics_table(cand,name,p,opt,envs,costMode)
w=[0.50 0.20 0.30]; rows=struct([]);
for e=1:numel(envs)
    [m,~]=evaluate_single_environment(cand,p,opt,envs(e),w,costMode,false);
    r=struct(); r.Policy=name; r.Environment=envs(e).name; r.CostMode=costMode; r.Dynamics=m.Dynamics;
    r.Resolved=m.Resolved; r.AmpI=m.AmpI; r.AmpT=m.AmpT; r.Period=m.Period; r.PeriodCV=m.PeriodCV;
    r.SpectralAbscissa=m.SpectralAbscissa; rows=aigc.append_struct_row(rows,r);
end
T=aigc.struct_rows_to_table(rows);
end

function T=matching_feasibility(Pdyn,p,opt,envs,w,settings,costMode)
rows=struct([]); uGrid=linspace(settings.policyUmin,settings.policyUmax,settings.policyMatchGridN);
for e=1:numel(envs)
    [md,~]=evaluate_single_environment(Pdyn,p,opt,envs(e),w,costMode,false); F=nan(numel(uGrid),4);
    for i=1:numel(uGrid)
        [mm,~]=evaluate_single_environment(fixed_candidate(uGrid(i)),p,opt,envs(e),w,costMode,false);
        F(i,:)=[mm.JI,mm.JC,mm.J,mm.Resolved];
    end
    [ir,er]=match_index(F(:,1),md.JI,settings.riskMatchTol,F(:,2),'min');
    [ic,ec]=match_index(F(:,2),md.JC,settings.costMatchTol,F(:,1),'min');
    row=struct(); row.Environment=envs(e).name; row.DynamicRisk=md.JI; row.DynamicCost=md.JC;
    row.EqualRiskReachable=er; row.EqualRiskFixedU=uGrid(ir); row.EqualRiskRiskError=F(ir,1)-md.JI;
    if er, row.EqualRiskCostDifference=F(ir,2)-md.JC; else, row.EqualRiskCostDifference=NaN; end
    row.EqualBudgetReachable=ec; row.EqualBudgetFixedU=uGrid(ic); row.EqualBudgetCostError=F(ic,2)-md.JC;
    if ec, row.EqualBudgetRiskDifference=F(ic,1)-md.JI; else, row.EqualBudgetRiskDifference=NaN; end
    row.DynamicBudgetOutsideFixedRange=md.JC<min(F(:,2))-settings.costMatchTol || md.JC>max(F(:,2))+settings.costMatchTol;
    row.FixedResolvedAtEqualRisk=F(ir,4); row.FixedResolvedAtEqualBudget=F(ic,4);
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function [idx,reachable]=match_index(values,target,tol,tieValues,tieMode)
ok=abs(values-target)<=tol; reachable=any(ok);
if reachable
    ids=find(ok); if strcmp(tieMode,'min'), [~,j]=min(tieValues(ids)); else, [~,j]=max(tieValues(ids)); end; idx=ids(j);
else
    [~,idx]=min(abs(values-target));
end
end


function T=weight_sensitivity(Fc,DcEq,DcExp,Ft,DtEq,DtExp,settings)
rows=struct([]);
for q=1:size(settings.policyWeightSets,1)
    ww=settings.policyWeightSets(q,:);
    Jfc=ww(1)*Fc.JI+ww(2)*Fc.JT+ww(3)*Fc.JC;
    JdcEq=ww(1)*DcEq.JI+ww(2)*DcEq.JT+ww(3)*DcEq.JC;
    JdcExp=ww(1)*DcExp.JI+ww(2)*DcExp.JT+ww(3)*DcExp.JC;
    Jft=ww(1)*Ft.JI+ww(2)*Ft.JT+ww(3)*Ft.JC;
    JdtEq=ww(1)*DtEq.JI+ww(2)*DtEq.JT+ww(3)*DtEq.JC;
    JdtExp=ww(1)*DtExp.JI+ww(2)*DtExp.JT+ww(3)*DtExp.JC;

    bf=min(Jfc); bdRawEq=min(JdcEq); bdnEq=min(bf,bdRawEq);
    bdRawExp=min(JdcExp); bdnExp=min(bf,bdRawExp);
    bft=min(Jft); bdtEq=min(JdtEq); bdtExp=min(JdtExp);

    row=struct(); row.WeightRisk=ww(1); row.WeightTrust=ww(2); row.WeightCost=ww(3);
    row.CoreBestFixed=bf;
    row.CoreBestDynamicRawEqualBudget=bdRawEq;
    row.CoreBestDynamicNestedEqualBudget=bdnEq;
    row.CoreAdaptiveGainEqualBudget=bf-bdnEq;
    row.CoreBestDynamicRawExpanded=bdRawExp;
    row.CoreBestDynamicNestedExpanded=bdnExp;
    row.CoreAdaptiveGainExpanded=bf-bdnExp;
    row.TotalBestFixed=bft;
    row.TotalBestDynamicEqualBudget=bdtEq;
    row.TotalDynamicEqualBudgetMinusFixed=bdtEq-bft;
    row.TotalBestDynamicExpanded=bdtExp;
    row.TotalDynamicExpandedMinusFixed=bdtExp-bft;
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function [rows,summary]=wall_clock_comparison(F,D,rep,settings)
maxCommon=min(F.CumulativeSeconds(end),D.CumulativeSeconds(end));
minCommon=max(F.CumulativeSeconds(1),D.CumulativeSeconds(1));
times=linspace(minCommon,maxCommon,settings.policyWallClockPoints); rows=struct([]);
for i=1:numel(times)
    rf=F.J(F.CumulativeSeconds<=times(i)); rd=D.J(D.CumulativeSeconds<=times(i));
    row=struct(); row.Repeat=rep; row.CommonSeconds=times(i);
    row.BestFixedRawJ=min(rf); row.BestDynamicRawJ=min(rd); rows=aigc.append_struct_row(rows,row);
end
summary=struct(); summary.Repeat=rep; summary.EvaluationBudget=height(F);
summary.BestFixedEqualEvaluations=min(F.J); summary.BestDynamicRawEqualEvaluations=min(D.J);
summary.CommonWallClockSeconds=maxCommon;
summary.BestFixedEqualWallClock=min(F.J(F.CumulativeSeconds<=maxCommon));
summary.BestDynamicRawEqualWallClock=min(D.J(D.CumulativeSeconds<=maxCommon));
summary.FixedTotalSeconds=F.CumulativeSeconds(end); summary.DynamicTotalSeconds=D.CumulativeSeconds(end);
end

function T=aggregate_convergence(R,N)
rows=struct([]);
for i=1:N
    idx=R.Evaluation==i; row=struct(); row.Evaluation=i;
    row.MeanBestFixedRawJ=mean(R.BestFixedRawJ(idx)); row.MeanBestDynamicRawJ=mean(R.BestDynamicRawJ(idx));
    row.MeanEmbeddedFixedBaselineJ=mean(R.EmbeddedFixedBaselineJ(idx));
    row.MeanBestDynamicNestedFamilyJ=mean(R.BestDynamicNestedFamilyJ(idx));
    row.LowFixed=aigc.percentile(R.BestFixedRawJ(idx),2.5); row.HighFixed=aigc.percentile(R.BestFixedRawJ(idx),97.5);
    row.LowDynamic=aigc.percentile(R.BestDynamicRawJ(idx),2.5); row.HighDynamic=aigc.percentile(R.BestDynamicRawJ(idx),97.5);
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function T=aggregate_wall_convergence(R)
reps=unique(R.Repeat); q=linspace(0,1,50); rows=struct([]);
for i=1:numel(q)
    vf=nan(numel(reps),1); vd=vf; seconds=nan(numel(reps),1);
    for r=1:numel(reps)
        S=R(R.Repeat==reps(r),:); k=max(1,min(height(S),round(1+q(i)*(height(S)-1))));
        vf(r)=S.BestFixedRawJ(k); vd(r)=S.BestDynamicRawJ(k); seconds(r)=S.CommonSeconds(k);
    end
    row=struct(); row.BudgetFraction=q(i); row.CommonSeconds=mean(seconds);
    row.MeanBestFixedRawJ=mean(vf); row.MeanBestDynamicRawJ=mean(vd);
    row.LowFixed=aigc.percentile(vf,2.5); row.HighFixed=aigc.percentile(vf,97.5);
    row.LowDynamic=aigc.percentile(vd,2.5); row.HighDynamic=aigc.percentile(vd,97.5);
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function rows=append_table_rows(rows,T)
for i=1:height(T), rows=aigc.append_struct_row(rows,table2struct(T(i,:))); end
end


% =====================================================================
% Quality gate and plotting
% =====================================================================
function T=quality_check(Tnest,Tcore,Tbudget,TtestCore,TtestTotal,TdynExpandedCore,settings)
rows=struct([]);
rows=qc(rows,'Strict nested trajectory/objective audit',all(Tnest.Pass), ...
    max(Tnest.TrajectoryMaxError),settings.policyNestedTrajectoryTol,'core mode');
fixedJ=Tcore.J(strcmp(string(Tcore.Policy),'best_fixed_core'));
eqNestedJ=Tcore.J(strcmp(string(Tcore.Policy),'best_dynamic_nested_equal_budget_core'));
expNestedJ=Tcore.J(strcmp(string(Tcore.Policy),'best_dynamic_nested_expanded_core'));
rows=qc(rows,'Equal-budget nested core not worse than fixed', ...
    eqNestedJ<=fixedJ+settings.policyNestedObjectiveTol,eqNestedJ-fixedJ,settings.policyNestedObjectiveTol,'mathematical nesting');
rows=qc(rows,'Expanded-search nested core not worse than fixed', ...
    expNestedJ<=fixedJ+settings.policyNestedObjectiveTol,expNestedJ-fixedJ,settings.policyNestedObjectiveTol,'mathematical nesting');
rawExpanded=min(TdynExpandedCore.J); expectedExpanded=min(fixedJ,rawExpanded);
rows=qc(rows,'Expanded-search candidate propagated into selected core policy', ...
    abs(expNestedJ-expectedExpanded)<=settings.policyNestedObjectiveTol,expNestedJ-expectedExpanded,settings.policyNestedObjectiveTol,'4B candidate pool is not discarded');
rows=qc(rows,'Zero dynamic gains allowed',settings.policyGainScaleRange(1)==0 && settings.policyEtaCScaleRange(1)==0,0,0,'policy family contains fixed subfamily');
rows=qc(rows,'Dynamic u0 spans fixed interval',true,settings.policyUmax-settings.policyUmin,0,'u0 is an explicit dynamic policy variable');
rows=qc(rows,'B/2B/4B long-search prefixes completed', ...
    numel(unique(Tbudget.BudgetMultiplier))==numel(settings.policyBudgetMultipliers),height(Tbudget),numel(settings.policyBudgetMultipliers),'');
rows=qc(rows,'Held-out core tests produced',~isempty(TtestCore),height(TtestCore),1,'tests are not used for tuning');
rows=qc(rows,'Expanded core policy reaches held-out tests', ...
    any(contains(string(TtestCore.Policy),'expanded_nested_dynamic_core')),height(TtestCore),1,'expanded candidate must be externally evaluated');
rows=qc(rows,'Held-out total tests produced',~isempty(TtestTotal),height(TtestTotal),1,'implementation-aware layer');
rows=qc(rows,'Expanded total policy reaches held-out tests', ...
    any(contains(string(TtestTotal.Policy),'expanded_dynamic_total')),height(TtestTotal),1,'expanded candidate must be externally evaluated');
T=aigc.struct_rows_to_table(rows);
end

function rows=qc(rows,name,pass,value,tol,note)
r=struct(); r.Check=name; r.Pass=logical(pass); r.Value=value; r.Tolerance=tol; r.Note=note;
rows=aigc.append_struct_row(rows,r);
end

function plot_policy_evidence(F,Deq,Dexp,C,B,Tmatch,Tweight,Jfixed,outDir)
fig=figure('Visible','off','Color','w','Position',[35 35 1500 980]);
subplot(2,3,1);
plot(F.JC,F.JI,'.'); hold on; plot(Deq.JC,Deq.JI,'.'); plot(Dexp.JC,Dexp.JI,'.');
xlabel('Core governance cost'); ylabel('Tail risk');
legend({'Fixed','Equal-budget raw dynamic','Expanded-search raw dynamic'},'Location','best');
grid on; title('Mechanism-neutral candidate pools');

subplot(2,3,[2 3]);
plot(C.Evaluation/max(C.Evaluation),C.MeanBestFixedRawJ,'-','LineWidth',1.1); hold on;
plot(C.Evaluation/max(C.Evaluation),C.MeanBestDynamicRawJ,'-','LineWidth',1.1);
plot(C.Evaluation/max(C.Evaluation),C.MeanBestDynamicNestedFamilyJ,'--','LineWidth',1.3);
yline(Jfixed,'k:'); xlabel('Normalized equal-evaluation budget'); ylabel('Best J'); grid on;
legend({'Fixed raw search','Dynamic raw search','Nested equal-budget envelope','Embedded fixed optimum'},'Location','best');

subplot(2,3,4);
mult=unique(B.BudgetMultiplier); raw=zeros(numel(mult),1); nested=raw;
for ii=1:numel(mult)
    idx=B.BudgetMultiplier==mult(ii);
    raw(ii)=mean(B.RawDynamicBest(idx)); nested(ii)=mean(B.NestedFamilyBest(idx));
end
plot(mult,raw,'-o','LineWidth',1.1); hold on;
plot(mult,nested,'-s','LineWidth',1.1); yline(Jfixed,'k:');
xlabel('Dynamic search budget multiplier'); ylabel('Best core J'); grid on; title('Expanded-search adequacy');

subplot(2,3,5); plot_matching(Tmatch);

subplot(2,3,6);
vals=[Tweight.TotalDynamicEqualBudgetMinusFixed,Tweight.TotalDynamicExpandedMinusFixed];
bar(1:height(Tweight),vals);
set(gca,'XTick',1:height(Tweight),'XTickLabel',compose('%.2f/%.2f/%.2f',Tweight.WeightRisk,Tweight.WeightTrust,Tweight.WeightCost));
xtickangle(35); yline(0,'k--'); ylabel('Dynamic minus fixed total J'); grid on;
legend({'Equal-budget dynamic','Expanded-search dynamic'},'Location','best');
title('Implementation-aware weight sensitivity');
aigc.save_figure(fig,fullfile(outDir,'fig_exp08_nested_policy_comparison')); close(fig);
end

function plot_matching(T)
vRisk=T.EqualRiskReachable; vBudget=T.EqualBudgetReachable;
vals=[mean(T.EqualRiskCostDifference(vRisk),'omitnan'),mean(T.EqualBudgetRiskDifference(vBudget),'omitnan')];
bar(categorical({'Equal-risk cost difference','Equal-budget risk difference'}),vals);
yline(0,'k--'); ylabel('Fixed minus dynamic'); grid on;
title(sprintf('Expanded dynamic reachable: risk %d/%d, budget %d/%d',sum(vRisk),height(T),sum(vBudget),height(T)));
end

