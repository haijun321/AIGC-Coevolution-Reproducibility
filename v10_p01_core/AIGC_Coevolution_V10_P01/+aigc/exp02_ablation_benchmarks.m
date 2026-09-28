function exp02_ablation_benchmarks(p,opt,settings,outputRoot)
%EXP02_ABLATION_BENCHMARKS M0-M13, F0-F8, classic reductions, and gates.
outDir=fullfile(outputRoot,'Exp02_ablation_benchmarks'); aigc.ensure_dir(outDir);
X0s=aigc.sample_initial_conditions(opt.X0,settings.commonIC,0.10,2026072312);

nestedRows=run_group('M',0:13,p,opt,X0s,settings.certificationMaxTime);
looRows=run_group('F',0:8,p,opt,X0s,settings.certificationMaxTime);
benchRows=run_benchmarks(p,opt,X0s,settings.certificationMaxTime);

Tn=aigc.struct_rows_to_table(nestedRows); Tf=aigc.struct_rows_to_table(looRows); Tb=aigc.struct_rows_to_table(benchRows);
writetable(Tn,fullfile(outDir,'exp02_M0_M13_raw.csv'));
writetable(Tf,fullfile(outDir,'exp02_F0_F8_raw.csv'));
writetable(Tb,fullfile(outDir,'exp02_BM0_BM4_raw.csv'));
Tna=aggregate_group(Tn,'Model'); Tfa=aggregate_group(Tf,'Model'); Tba=aggregate_group(Tb,'Model');
writetable(Tna,fullfile(outDir,'exp02_M0_M13_summary.csv'));
writetable(Tfa,fullfile(outDir,'exp02_F0_F8_summary.csv'));
writetable(Tba,fullfile(outDir,'exp02_classic_benchmark_summary.csv'));

capability=table( ...
    {'BM0';'BM1';'BM2';'BM3';'BM4';'FULL'}, ...
    [1;1;0;0;1;1], [0;0;1;0;1;1], [0;0;0;0;1;1], ...
    [0;0;0;1;1;1], [0;0;0;0;0;1], [0;0;0;0;0;1], ...
    [0;0;0;0;0;1], [0;0;0;0;0;1], ...
    'VariableNames',{'Model','StrategyDynamics','RiskDynamics','BehaviorRiskFeedback', ...
    'DynamicTrust','TrustMemory','BacklogState','AIGCAdaptation','AuditOscillation'});
writetable(capability,fullfile(outDir,'exp02_classic_benchmark_capabilities.csv'));

% Hard identification gate: M0 and M1 may differ in I but not in strategies.
M0=sortrows(Tn(strcmp(Tn.Model,'M0'),:),'IC');
M1=sortrows(Tn(strcmp(Tn.Model,'M1'),:),'IC');
if height(M0)~=height(M1), error('M0/M1 paired sample sizes differ.'); end
diagT=table(max(abs(M1.x-M0.x)),max(abs(M1.y-M0.y)),max(abs(M1.z-M0.z)), ...
    max(abs(M1.I-M0.I)), ...
    'VariableNames',{'MaxDeltaX','MaxDeltaY','MaxDeltaZ','MaxDeltaI'});
diagT.PassStrategyInvariance=max([diagT.MaxDeltaX,diagT.MaxDeltaY,diagT.MaxDeltaZ])<1e-8;
writetable(diagT,fullfile(outDir,'exp02_M0_M1_strategy_invariance.csv'));
assert(diagT.PassStrategyInvariance,'M0-M1 strategy invariance failed. Check all payoff uses of Ipay.');

% Direct matched contrasts prevent over-interpreting one adjacent M-step.
contrastT=direct_contrasts(p,opt,X0s,settings.certificationMaxTime);
writetable(contrastT,fullfile(outDir,'exp02_direct_mechanism_contrasts.csv'));
writetable(contrast_summary(contrastT),fullfile(outDir,'exp02_direct_mechanism_contrast_summary.csv'));
stageT=stage_probability_contrasts(p,opt,X0s,settings.certificationMaxTime);
writetable(stageT,fullfile(outDir,'exp02_stage_probability_mechanism_contrasts.csv'));

fig=figure('Visible','off','Color','w','Position',[80 80 1200 850]);
subplot(3,1,1); plot_group(Tna,'M models');
subplot(3,1,2); plot_group(Tfa,'F models');
subplot(3,1,3); plot_group(Tba,'Classic benchmarks');
aigc.save_figure(fig,fullfile(outDir,'fig_exp02_ablation_and_benchmarks')); close(fig);
end

function rows=run_group(prefix,ids,p,opt,X0s,maxT)
rows=struct([]);
for id=ids
    if prefix=='M', mode=aigc.nested_mode(id); else, mode=aigc.leave_one_out_mode(id); end
    for ic=1:size(X0s,1)
        fprintf('Exp02 %s%d IC %d/%d...\n',prefix,id,ic,size(X0s,1));
        [sol,cert]=aigc.solve_adaptive_longrun(X0s(ic,:)',p,mode,opt,maxT);
        ss=aigc.summarize_solution(sol,p,mode,opt);
        row=row_from_ss(sprintf('%s%d',prefix,id),ic,ss,cert);
        rows=aigc.append_struct_row(rows,row);
    end
end
end

function rows=run_benchmarks(p,opt,X0s,maxT)
names={'BM0','BM1','BM2','BM3','BM4','FULL'}; rows=struct([]);
for k=1:numel(names)
    if strcmp(names{k},'FULL'), mode=aigc.full_mode(); pp=p;
    else, [mode,pp]=aigc.benchmark_mode(names{k},p); end
    for ic=1:size(X0s,1)
        fprintf('Exp02 %s IC %d/%d...\n',names{k},ic,size(X0s,1));
        [sol,cert]=aigc.solve_adaptive_longrun(X0s(ic,:)',pp,mode,opt,maxT);
        ss=aigc.summarize_solution(sol,pp,mode,opt);
        row=row_from_ss(names{k},ic,ss,cert);
        rows=aigc.append_struct_row(rows,row);
    end
end
end

function row=row_from_ss(model,ic,ss,cert)
row.Model=model; row.IC=ic; row.Dynamics=ss.dynamics;
row.x=ss.x; row.y=ss.y; row.z=ss.z; row.I=ss.I; row.T=ss.T;
row.u=ss.u; row.A=ss.A; row.L=ss.L; row.E=ss.E;
row.Qexp=ss.Qexp; row.pAct=ss.pAct; row.JI=ss.JI; row.JT=ss.JT;
row.JC=ss.JC; row.TotalCost=ss.totalCost; row.AmpI=ss.ampI;
row.Period=ss.period; row.PeriodCV=ss.periodCV; row.SpectralAbscissa=ss.spectralAbscissa;
row.TailStable=ss.tailStable; row.TailMeanDrift=ss.tailMeanDrift;
row.Extended=cert.extended; row.FinalTime=cert.finalTime;
row.TailWindowClassRobust=ss.tailWindowClassRobust;
row.TailWindowMeanSpreadI=ss.tailWindowMeanSpreadI; row.TailWindowAmpSpreadI=ss.tailWindowAmpSpreadI;
end

function Ta=aggregate_group(T,key)
names=unique(T.(key),'stable'); rows=struct([]);
for k=1:numel(names)
    idx=strcmp(T.(key),names{k}); row.Model=names{k};
    row.MeanX=mean(T.x(idx)); row.MeanY=mean(T.y(idx)); row.MeanZ=mean(T.z(idx));
    row.MeanI=mean(T.I(idx)); row.MeanT=mean(T.T(idx)); row.MeanQexp=mean(T.Qexp(idx));
    row.MeanPAct=mean(T.pAct(idx)); row.MeanJC=mean(T.JC(idx));
    row.EquilibriumShare=mean(contains(T.Dynamics(idx),'equilibrium'));
    row.CycleShare=mean(strcmp(T.Dynamics(idx),'stable_cycle'));
    row.UnresolvedShare=1-row.EquilibriumShare-row.CycleShare;
    row.TailStableShare=mean(T.TailStable(idx)); row.MeanAmpI=mean(T.AmpI(idx));
    rows=aigc.append_struct_row(rows,row);
end
Ta=aigc.struct_rows_to_table(rows);
end

function T=direct_contrasts(p,opt,X0s,maxT)
rows=struct([]);
for ic=1:size(X0s,1)
    mFull=aigc.full_mode();
    [sFull,~]=aigc.solve_adaptive_longrun(X0s(ic,:)',p,mFull,opt,maxT);
    qFull=aigc.summarize_solution(sFull,p,mFull,opt);
    mIdeal=mFull; mIdeal.idealGovernance=true;
    [sIdeal,~]=aigc.solve_adaptive_longrun(X0s(ic,:)',p,mIdeal,opt,maxT);
    qIdeal=aigc.summarize_solution(sIdeal,p,mIdeal,opt);
    pNoLabel=p; pNoLabel.c=0; pNoLabel.nu1=0;
    [sNoLabel,~]=aigc.solve_adaptive_longrun(X0s(ic,:)',pNoLabel,mFull,opt,maxT);
    qNoLabel=aigc.summarize_solution(sNoLabel,pNoLabel,mFull,opt);
    mNo=mFull; mNo.useAIGC=false; mNo.exogenousE=true; mNo.activeMask(10)=false;
    [sNo,~]=aigc.solve_adaptive_longrun(X0s(ic,:)',p,mNo,opt,maxT);
    qNo=aigc.summarize_solution(sNo,p,mNo,opt);
    row.IC=ic;
    row.FiniteGovernanceRiskEffect=qFull.I-qIdeal.I;
    row.FiniteGovernanceTrustEffect=qFull.T-qIdeal.T;
    row.LabelRiskReduction=qNoLabel.I-qFull.I;
    row.LabelTrustGain=qFull.T-qNoLabel.T;
    row.AIGCNetRiskEffect=qFull.I-qNo.I;
    row.AIGCNetTrustEffect=qFull.T-qNo.T;
    row.FullDynamics=qFull.dynamics; row.IdealDynamics=qIdeal.dynamics;
    row.NoLabelDynamics=qNoLabel.dynamics; row.NoAIGCDynamics=qNo.dynamics;
    row.ValidFinite=aigc.is_resolved_label(qFull.dynamics)&&aigc.is_resolved_label(qIdeal.dynamics);
    row.ValidLabel=aigc.is_resolved_label(qFull.dynamics)&&aigc.is_resolved_label(qNoLabel.dynamics);
    row.ValidAIGC=aigc.is_resolved_label(qFull.dynamics)&&aigc.is_resolved_label(qNo.dynamics);
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function T=contrast_summary(R)
scopes={'All','Resolved'}; rows=struct([]);
for s=1:numel(scopes)
    row=struct(); row.Scope=scopes{s};
    if strcmp(scopes{s},'Resolved')
        vf=R.ValidFinite; vl=R.ValidLabel; va=R.ValidAIGC;
    else
        vf=true(height(R),1); vl=vf; va=vf;
    end
    row.NFinite=sum(vf); row.FiniteGovernanceRiskEffect=mean(R.FiniteGovernanceRiskEffect(vf),'omitnan');
    row.FiniteGovernanceTrustEffect=mean(R.FiniteGovernanceTrustEffect(vf),'omitnan');
    row.NLabel=sum(vl); row.LabelRiskReduction=mean(R.LabelRiskReduction(vl),'omitnan');
    row.LabelTrustGain=mean(R.LabelTrustGain(vl),'omitnan');
    row.NAIGC=sum(va); row.AIGCNetRiskEffect=mean(R.AIGCNetRiskEffect(va),'omitnan');
    row.AIGCNetTrustEffect=mean(R.AIGCNetTrustEffect(va),'omitnan');
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function T=stage_probability_contrasts(p,opt,X0s,maxT)
names={'baseline','no_entry_blocking','no_spread_suppression','no_stock_removal'};
rows=struct([]); mode=aigc.full_mode();
for ic=1:size(X0s,1)
    summaries=cell(4,1);
    for k=1:4
        pp=p;
        if k==2, pp.kappaIn=0; elseif k==3, pp.kappaSp=0; elseif k==4, pp.kappaRm=0; end
        [sol,~]=aigc.solve_adaptive_longrun(X0s(ic,:)',pp,mode,opt,maxT);
        summaries{k}=aigc.summarize_solution(sol,pp,mode,opt);
    end
    for k=2:4
        row=struct(); row.IC=ic; row.Contrast=names{k};
        row.DeltaI=summaries{k}.I-summaries{1}.I;
        row.DeltaT=summaries{k}.T-summaries{1}.T;
        row.DeltaQexp=summaries{k}.Qexp-summaries{1}.Qexp;
        row.BaselineDynamics=summaries{1}.dynamics; row.AlternativeDynamics=summaries{k}.dynamics;
        row.ResolvedPair=aigc.is_resolved_label(summaries{1}.dynamics)&& ...
            aigc.is_resolved_label(summaries{k}.dynamics);
        rows=aigc.append_struct_row(rows,row);
    end
end
T=aigc.struct_rows_to_table(rows);
end

function plot_group(T,titleText)
xx=1:height(T); yy=[T.MeanI T.MeanT T.MeanQexp];
plot(xx,yy,'-o','LineWidth',1.1,'MarkerSize',4);
set(gca,'XTick',xx,'XTickLabel',T.Model); xlim([0.5 height(T)+0.5]);
ylabel('Tail mean'); title(titleText); legend({'I','T','Qexp'},'Location','best'); grid on;
end
