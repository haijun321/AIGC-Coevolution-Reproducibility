function exp08_fair_policy_comparison(p,opt,settings,outputRoot)
%EXP08_FAIR_POLICY_COMPARISON Dense fixed search, multistart dynamic search,
% equal-evaluation and equal-wall-clock budgets, and held-out environments.
outDir=fullfile(outputRoot,'Exp08_fair_policy_comparison'); aigc.ensure_dir(outDir);
optPolicy=opt; optPolicy.solver='ode45'; optPolicy.allowEarlyStop=false;
calib=calibration_environments(optPolicy); test=test_environments(optPolicy);
N=settings.policyBudget; R=settings.policyRepeats; w=settings.policyWeights;
fixedRows=struct([]); dynRows=struct([]); convRows=struct([]); wallRows=struct([]); dualRows=struct([]);

for rep=1:R
    % Fixed family: dense global grid followed by one-dimensional refinement.
    nGlobal=max(3,min(N,round(settings.policyGlobalFraction*N)));
    uGlobal=linspace(0.05,0.95,nGlobal)';
    repF=struct([]); bestF=Inf; cumF=0;
    for i=1:nGlobal
        cand=fixed_candidate(uGlobal(i));
        [m,elapsed]=timed_evaluation(cand,p,optPolicy,calib,w); cumF=cumF+elapsed;
        row=candidate_row(rep,i,cand,m,elapsed,cumF,'global_grid');
        repF=aigc.append_struct_row(repF,row); fixedRows=aigc.append_struct_row(fixedRows,row);
    end
    if nGlobal<N
        TF=aigc.struct_rows_to_table(repF); [~,ib]=min(TF.J); center=TF.u(ib);
        spacing=0.90/max(nGlobal-1,1); radius=2*spacing;
        uLocal=linspace(max(0.05,center-radius),min(0.95,center+radius),N-nGlobal+2)';
        uLocal=uLocal(2:end-1);
        for q=1:numel(uLocal)
            i=nGlobal+q; cand=fixed_candidate(uLocal(q));
            [m,elapsed]=timed_evaluation(cand,p,optPolicy,calib,w); cumF=cumF+elapsed;
            row=candidate_row(rep,i,cand,m,elapsed,cumF,'local_refinement');
            repF=aigc.append_struct_row(repF,row); fixedRows=aigc.append_struct_row(fixedRows,row);
        end
    end

    % Dynamic family: LHS multistart followed by local refinements around
    % several best initial starts.
    nInitial=nGlobal; Ud=aigc.lhs_unit(nInitial,3,settings.policySeed+100*rep+1);
    repD=struct([]); cumD=0;
    for i=1:nInitial
        cand=dynamic_from_unit(Ud(i,:));
        [m,elapsed]=timed_evaluation(cand,p,optPolicy,calib,w); cumD=cumD+elapsed;
        row=candidate_row(rep,i,cand,m,elapsed,cumD,'lhs_multistart');
        repD=aigc.append_struct_row(repD,row); dynRows=aigc.append_struct_row(dynRows,row);
    end
    if nInitial<N
        TD=aigc.struct_rows_to_table(repD); [~,ord]=sort(TD.J,'ascend');
        nCenters=min(settings.policyLocalStarts,numel(ord)); centers=zeros(nCenters,3);
        for c=1:nCenters, centers(c,:)=candidate_to_unit(row_to_candidate(TD(ord(c),:),'dynamic')); end
        nLocal=N-nInitial; UL=aigc.lhs_unit(nLocal,3,settings.policySeed+100*rep+2);
        for q=1:nLocal
            center=centers(1+mod(q-1,nCenters),:);
            radius=0.25-0.20*(q-1)/max(nLocal-1,1);
            u=min(max(center+2*radius*(UL(q,:)-0.5),0),1);
            cand=dynamic_from_unit(u); i=nInitial+q;
            [m,elapsed]=timed_evaluation(cand,p,optPolicy,calib,w); cumD=cumD+elapsed;
            row=candidate_row(rep,i,cand,m,elapsed,cumD,'local_multistart');
            repD=aigc.append_struct_row(repD,row); dynRows=aigc.append_struct_row(dynRows,row);
        end
    end

    TF=aigc.struct_rows_to_table(repF); TD=aigc.struct_rows_to_table(repD);
    bestF=Inf; bestD=Inf;
    for i=1:N
        bestF=min(bestF,TF.J(i)); bestD=min(bestD,TD.J(i));
        row=struct(); row.Repeat=rep; row.Evaluation=i;
        row.BestFixedJ=bestF; row.BestDynamicJ=bestD;
        row.FixedCumulativeSeconds=TF.CumulativeSeconds(i);
        row.DynamicCumulativeSeconds=TD.CumulativeSeconds(i);
        convRows=aigc.append_struct_row(convRows,row);
    end
    [wr,dual]=wall_clock_comparison(TF,TD,rep,settings);
    for q=1:numel(wr), wallRows=aigc.append_struct_row(wallRows,wr(q)); end
    dualRows=aigc.append_struct_row(dualRows,dual);
    fprintf('Exp08 repeat %d/%d completed.\n',rep,R);
end

Tfixed=aigc.struct_rows_to_table(fixedRows); Tdyn=aigc.struct_rows_to_table(dynRows);
writetable(Tfixed,fullfile(outDir,'exp08_fixed_candidate_frontier.csv'));
writetable(Tdyn,fullfile(outDir,'exp08_dynamic_candidate_frontier.csv'));
TconvRaw=aigc.struct_rows_to_table(convRows); Tconv=aggregate_convergence(TconvRaw,N);
TwallRaw=aigc.struct_rows_to_table(wallRows); Twall=aggregate_wall_convergence(TwallRaw);
Tdual=aigc.struct_rows_to_table(dualRows);
writetable(Tconv,fullfile(outDir,'exp08_evaluation_budget_convergence.csv'));
writetable(Twall,fullfile(outDir,'exp08_wall_clock_budget_convergence.csv'));
writetable(Tdual,fullfile(outDir,'exp08_dual_budget_summary.csv'));

% P0/P1/P2 are prespecified comparators; P3/P4 are best-found policies.
[~,i3]=min(Tfixed.J); P3=row_to_candidate(Tfixed(i3,:),'fixed');
[~,i4]=min(Tdyn.J); P4=row_to_candidate(Tdyn(i4,:),'dynamic');
P0=struct('type','dynamic','u',NaN,'auditSpeed',p.auditSpeed,'gainScale',1,'etaCScale',1);
P1=fixed_candidate(settings.policyFixedLow);
P2=fixed_candidate(settings.policyFixedHigh);
policies={P0,P1,P2,P3,P4};
names={'P0_original_dynamic','P1_low_fixed','P2_high_fixed','P3_best_found_fixed','P4_best_found_dynamic'};
selRows=struct([]);
for k=1:5
    m=evaluate_candidate(policies{k},p,optPolicy,calib,w);
    row=selected_row(names{k},policies{k},m);
    selRows=aigc.append_struct_row(selRows,row);
end
Tsel=aigc.struct_rows_to_table(selRows);
Tsel.EvaluationsPerFamily=repmat(N*R,height(Tsel),1);
writetable(Tsel,fullfile(outDir,'exp08_selected_policy_calibration.csv'));
save(fullfile(outDir,'exp08_selected_policies.mat'),'P0','P1','P2','P3','P4','w','settings');

% Freeze selected policies before held-out tests.
testRows=struct([]);
for k=1:5
    for e=1:numel(test)
        m=evaluate_candidate(policies{k},p,optPolicy,test(e),w);
        row=struct(); row.Policy=names{k}; row.Environment=test(e).name;
        row.JI=m.JI; row.JT=m.JT; row.JC=m.JC; row.J=m.J; row.TotalCost=m.TotalCost;
        row.ResolvedShare=m.ResolvedShare; row.TailWindowRobustShare=m.TailWindowRobustShare;
        testRows=aigc.append_struct_row(testRows,row);
    end
end
Ttest=aigc.struct_rows_to_table(testRows);
writetable(Ttest,fullfile(outDir,'exp08_selected_policy_test.csv'));

% Environment-specific equal-risk and equal-budget feasibility.
matchRows=struct([]); allEnv=[calib(:);test(:)];
uGrid=linspace(0.05,0.95,settings.policyMatchGridN);
for e=1:numel(allEnv)
    md=evaluate_candidate(P4,p,optPolicy,allEnv(e),w); F=nan(numel(uGrid),4);
    for i=1:numel(uGrid)
        mm=evaluate_candidate(fixed_candidate(uGrid(i)),p,optPolicy,allEnv(e),w);
        F(i,:)=[mm.JI,mm.JC,mm.J,mm.ResolvedShare];
    end
    [ir,er]=match_index(F(:,1),md.JI,settings.riskMatchTol,F(:,2),'min');
    [ic,ec]=match_index(F(:,2),md.JC,settings.costMatchTol,F(:,1),'min');
    row=struct(); row.Environment=allEnv(e).name; row.DynamicRisk=md.JI; row.DynamicCost=md.JC;
    row.EqualRiskReachable=er; row.EqualRiskFixedU=uGrid(ir);
    row.EqualRiskRiskError=F(ir,1)-md.JI;
    if er, row.EqualRiskCostDifference=F(ir,2)-md.JC; else, row.EqualRiskCostDifference=NaN; end
    row.EqualBudgetReachable=ec; row.EqualBudgetFixedU=uGrid(ic);
    row.EqualBudgetCostError=F(ic,2)-md.JC;
    if ec, row.EqualBudgetRiskDifference=F(ic,1)-md.JI; else, row.EqualBudgetRiskDifference=NaN; end
    row.DynamicBudgetOutsideFixedRange=md.JC<min(F(:,2))-settings.costMatchTol || ...
        md.JC>max(F(:,2))+settings.costMatchTol;
    row.FixedResolvedShareAtEqualRisk=F(ir,4); row.FixedResolvedShareAtEqualBudget=F(ic,4);
    matchRows=aigc.append_struct_row(matchRows,row);
end
Tmatch=aigc.struct_rows_to_table(matchRows);
writetable(Tmatch,fullfile(outDir,'exp08_matching_feasibility.csv'));

% Objective-weight sensitivity reuses the evaluated candidate set.
weightRows=struct([]);
for q=1:size(settings.policyWeightSets,1)
    ww=settings.policyWeightSets(q,:);
    Jf=ww(1)*Tfixed.JI+ww(2)*Tfixed.JT+ww(3)*Tfixed.JC;
    Jd=ww(1)*Tdyn.JI+ww(2)*Tdyn.JT+ww(3)*Tdyn.JC;
    [bf,ifx]=min(Jf); [bd,idy]=min(Jd);
    row=struct(); row.WeightRisk=ww(1); row.WeightTrust=ww(2); row.WeightCost=ww(3);
    row.BestFixedJ=bf; row.BestDynamicJ=bd; row.DynamicMinusFixed=bd-bf;
    row.BestFixedRisk=Tfixed.JI(ifx); row.BestDynamicRisk=Tdyn.JI(idy);
    row.BestFixedCost=Tfixed.JC(ifx); row.BestDynamicCost=Tdyn.JC(idy);
    weightRows=aigc.append_struct_row(weightRows,row);
end
Tweight=aigc.struct_rows_to_table(weightRows);
writetable(Tweight,fullfile(outDir,'exp08_weight_sensitivity.csv'));

fig=figure('Visible','off','Color','w','Position',[35 35 1500 980]);
subplot(2,3,1); plot(Tfixed.JC,Tfixed.JI,'.'); hold on; plot(Tdyn.JC,Tdyn.JI,'.');
xlabel('Full-window governance cost'); ylabel('Tail risk'); legend({'Fixed','Dynamic'},'Location','best'); grid on;
subplot(2,3,[2 3]); plot(Tconv.Evaluation/max(Tconv.Evaluation),Tconv.MeanBestFixedJ,'-','LineWidth',1.2); hold on;
plot(Tconv.Evaluation/max(Tconv.Evaluation),Tconv.MeanBestDynamicJ,'-','LineWidth',1.2);
plot(Twall.BudgetFraction,Twall.MeanBestFixedJ,'--','LineWidth',1.2);
plot(Twall.BudgetFraction,Twall.MeanBestDynamicJ,'--','LineWidth',1.2);
xlabel('Normalized search budget'); ylabel('Best-found J');
legend({'Fixed: equal evaluations','Dynamic: equal evaluations', ...
    'Fixed: equal wall-clock','Dynamic: equal wall-clock'},'Location','best'); grid on;
subplot(2,3,4); testAgg=aggregate_test(Ttest);
bar(categorical(testAgg.Policy),[testAgg.MeanJI testAgg.MeanJT testAgg.MeanJC]);
legend({'Tail risk','Tail trust loss','Cost'},'Location','best'); grid on; title('Held-out tests');
subplot(2,3,5); plot_matching(Tmatch);
subplot(2,3,6); bar(1:height(Tweight),Tweight.DynamicMinusFixed);
set(gca,'XTick',1:height(Tweight),'XTickLabel',compose('%.2f/%.2f/%.2f', ...
    Tweight.WeightRisk,Tweight.WeightTrust,Tweight.WeightCost));
xtickangle(35); yline(0,'k--'); ylabel('Dynamic minus fixed best-found J'); title('Weight sensitivity'); grid on;
aigc.save_figure(fig,fullfile(outDir,'fig_exp08_fair_policy_comparison')); close(fig);
end

function cand=fixed_candidate(u)
cand=struct('type','fixed','u',min(max(u,0.05),0.95), ...
    'auditSpeed',NaN,'gainScale',NaN,'etaCScale',NaN);
end

function cand=dynamic_from_unit(u)
cand=struct('type','dynamic','u',NaN,'auditSpeed',0.15+u(1)*(1.20-0.15), ...
    'gainScale',0.40+u(2)*(2.80-0.40),'etaCScale',0.40+u(3)*(2.20-0.40));
end

function u=candidate_to_unit(cand)
u=[(cand.auditSpeed-0.15)/(1.20-0.15),(cand.gainScale-0.40)/(2.80-0.40), ...
    (cand.etaCScale-0.40)/(2.20-0.40)];
u=min(max(u,0),1);
end

function [m,elapsed]=timed_evaluation(cand,p,opt,envs,w)
timer=tic; m=evaluate_candidate(cand,p,opt,envs,w); elapsed=toc(timer);
end

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

function m=evaluate_candidate(cand,p,opt,envs,w)
vals=nan(numel(envs),7);
for e=1:numel(envs)
    pp=apply_mods(p,envs(e).pmods);
    if strcmp(cand.type,'fixed')
        mode=aigc.full_mode(); mode.dynamicAudit=false; mode.fixedAudit=true;
        mode.fixedAuditIntensity=cand.u; mode.activeMask(7)=false;
        mode.costDynamic=false; mode.costFixed=true;
    else
        mode=aigc.full_mode(); mode.costDynamic=true; mode.costFixed=false;
        pp.auditSpeed=cand.auditSpeed; pp.etaI=pp.etaI*cand.gainScale;
        pp.etaT=pp.etaT*cand.gainScale; pp.etaA=pp.etaA*cand.gainScale;
        pp.etaC=pp.etaC*cand.etaCScale;
    end
    mode.shock=envs(e).shock;
    sol=aigc.solve_model(envs(e).X0,pp,mode,opt);
    ev=aigc.evaluate_solution(sol,pp,mode); ss=aigc.summarize_solution(sol,pp,mode,opt,ev);
    tailStart=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1));
    idx=find(sol.t>=tailStart);
    jt=aigc.time_average(sol.t(idx),max(pp.Tstar-ev.T(idx),0));
    ji=ss.I; jc=ev.JC; J=w(1)*ji+w(2)*jt+w(3)*jc;
    vals(e,:)=[ji,jt,jc,J,ev.totalCost,double(aigc.is_resolved_label(ss.dynamics)),double(ss.tailWindowClassRobust)];
end
m.JI=mean(vals(:,1)); m.JT=mean(vals(:,2)); m.JC=mean(vals(:,3));
m.J=mean(vals(:,4)); m.TotalCost=mean(vals(:,5));
m.ResolvedShare=mean(vals(:,6)); m.TailWindowRobustShare=mean(vals(:,7));
end

function pp=apply_mods(p,mods)
pp=p; fn=fieldnames(mods); for i=1:numel(fn), pp.(fn{i})=mods.(fn{i}); end
end

function row=candidate_row(rep,id,cand,m,elapsed,cumulative,stage)
row=struct(); row.Repeat=rep; row.Candidate=id; row.SearchStage=stage; row.Type=cand.type;
row.u=cand.u; row.auditSpeed=cand.auditSpeed; row.gainScale=cand.gainScale; row.etaCScale=cand.etaCScale;
row.JI=m.JI; row.JT=m.JT; row.JC=m.JC; row.J=m.J; row.TotalCost=m.TotalCost;
row.ResolvedShare=m.ResolvedShare; row.TailWindowRobustShare=m.TailWindowRobustShare;
row.ElapsedSeconds=elapsed; row.CumulativeSeconds=cumulative;
end

function cand=row_to_candidate(Trow,type)
cand.type=type;
if strcmp(type,'fixed')
    cand.u=Trow.u; cand.auditSpeed=NaN; cand.gainScale=NaN; cand.etaCScale=NaN;
else
    cand.u=NaN; cand.auditSpeed=Trow.auditSpeed;
    cand.gainScale=Trow.gainScale; cand.etaCScale=Trow.etaCScale;
end
end

function row=selected_row(name,cand,m)
row=struct(); row.Policy=name; row.Type=cand.type; row.u=cand.u;
row.auditSpeed=cand.auditSpeed; row.gainScale=cand.gainScale; row.etaCScale=cand.etaCScale;
row.JI=m.JI; row.JT=m.JT; row.JC=m.JC; row.J=m.J; row.TotalCost=m.TotalCost;
row.ResolvedShare=m.ResolvedShare; row.TailWindowRobustShare=m.TailWindowRobustShare;
end

function [idx,reachable]=match_index(values,target,tol,tieValues,tieMode)
ok=abs(values-target)<=tol; reachable=any(ok);
if reachable
    ids=find(ok);
    if strcmp(tieMode,'min'), [~,j]=min(tieValues(ids)); else, [~,j]=max(tieValues(ids)); end
    idx=ids(j);
else
    [~,idx]=min(abs(values-target));
end
end

function [rows,summary]=wall_clock_comparison(F,D,rep,settings)
maxCommon=min(F.CumulativeSeconds(end),D.CumulativeSeconds(end));
minCommon=max(F.CumulativeSeconds(1),D.CumulativeSeconds(1));
times=linspace(minCommon,maxCommon,settings.policyWallClockPoints);
rows=struct([]);
for i=1:numel(times)
    row=struct(); row.Repeat=rep; row.CommonSeconds=times(i);
    row.BestFixedJ=min(F.J(F.CumulativeSeconds<=times(i)));
    row.BestDynamicJ=min(D.J(D.CumulativeSeconds<=times(i)));
    rows=aigc.append_struct_row(rows,row);
end
summary=struct(); summary.Repeat=rep; summary.EvaluationBudget=height(F);
summary.BestFixedEqualEvaluations=min(F.J); summary.BestDynamicEqualEvaluations=min(D.J);
summary.CommonWallClockSeconds=maxCommon;
summary.BestFixedEqualWallClock=min(F.J(F.CumulativeSeconds<=maxCommon));
summary.BestDynamicEqualWallClock=min(D.J(D.CumulativeSeconds<=maxCommon));
summary.FixedTotalSeconds=F.CumulativeSeconds(end); summary.DynamicTotalSeconds=D.CumulativeSeconds(end);
end

function T=aggregate_convergence(R,N)
rows=struct([]);
for i=1:N
    idx=R.Evaluation==i; row=struct(); row.Evaluation=i;
    row.MeanBestFixedJ=mean(R.BestFixedJ(idx)); row.MeanBestDynamicJ=mean(R.BestDynamicJ(idx));
    row.LowFixed=aigc.percentile(R.BestFixedJ(idx),2.5); row.HighFixed=aigc.percentile(R.BestFixedJ(idx),97.5);
    row.LowDynamic=aigc.percentile(R.BestDynamicJ(idx),2.5); row.HighDynamic=aigc.percentile(R.BestDynamicJ(idx),97.5);
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
        vf(r)=S.BestFixedJ(k); vd(r)=S.BestDynamicJ(k); seconds(r)=S.CommonSeconds(k);
    end
    row=struct(); row.BudgetFraction=q(i); row.CommonSeconds=mean(seconds);
    row.MeanBestFixedJ=mean(vf); row.MeanBestDynamicJ=mean(vd);
    row.LowFixed=aigc.percentile(vf,2.5); row.HighFixed=aigc.percentile(vf,97.5);
    row.LowDynamic=aigc.percentile(vd,2.5); row.HighDynamic=aigc.percentile(vd,97.5);
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function Ta=aggregate_test(T)
names=unique(T.Policy,'stable'); rows=struct([]);
for i=1:numel(names)
    idx=strcmp(T.Policy,names{i}); row=struct(); row.Policy=names{i};
    row.MeanJI=mean(T.JI(idx)); row.MeanJT=mean(T.JT(idx));
    row.MeanJC=mean(T.JC(idx)); row.MeanJ=mean(T.J(idx));
    row.ResolvedShare=mean(T.ResolvedShare(idx));
    rows=aigc.append_struct_row(rows,row);
end
Ta=aigc.struct_rows_to_table(rows);
end

function plot_matching(T)
vRisk=T.EqualRiskReachable; vBudget=T.EqualBudgetReachable;
vals=[mean(T.EqualRiskCostDifference(vRisk),'omitnan'),mean(T.EqualBudgetRiskDifference(vBudget),'omitnan')];
bar(categorical({'Equal-risk cost difference','Equal-budget risk difference'}),vals);
yline(0,'k--'); ylabel('Fixed minus dynamic'); grid on;
title(sprintf('Reachable: risk %d/%d, budget %d/%d',sum(vRisk),height(T),sum(vBudget),height(T)));
end
