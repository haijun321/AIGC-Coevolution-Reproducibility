function exp05_global_sensitivity(p,opt,settings,outputRoot)
%EXP05_GLOBAL_SENSITIVITY Standard Morris, LHS-PRCC, QA, and effect probabilities.
outDir=fullfile(outputRoot,'Exp05_global_sensitivity'); aigc.ensure_dir(outDir);
mode=aigc.full_mode(); modeNo=aigc.leave_one_out_mode(8);
names=settings.sensitivityNames; ranges=settings.sensitivityRange; d=numel(names);
optS=opt; optS.allowEarlyStop=false; optS.solver='ode45';

% Standard Morris trajectories: each path changes every factor exactly once.
R=settings.morrisTrajectories; EEI=nan(R,d); EET=nan(R,d); pairResolved=false(R,d);
for r=1:R
    [U,order,step]=aigc.morris_trajectory(d,settings.morrisLevels,settings.sensitivitySeed+r);
    yI=nan(d+1,1); yT=nan(d+1,1); resolved=false(d+1,1);
    for k=1:d+1
        pp=apply_sample(p,names,ranges,U(k,:));
        [sol,~]=aigc.solve_adaptive_longrun(opt.X0,pp,mode,optS,settings.certificationMaxTime);
        ss=aigc.summarize_solution(sol,pp,mode,optS);
        yI(k)=ss.I; yT(k)=ss.T; resolved(k)=aigc.is_resolved_label(ss.dynamics);
    end
    for k=1:d
        j=order(k); EEI(r,j)=(yI(k+1)-yI(k))/step(k);
        EET(r,j)=(yT(k+1)-yT(k))/step(k);
        pairResolved(r,j)=resolved(k)&&resolved(k+1);
    end
    fprintf('Exp05 Morris trajectory %d/%d completed.\n',r,R);
end
mRows=struct([]);
for j=1:d
    row=struct(); row.Parameter=names{j}; row.NEffects=sum(isfinite(EEI(:,j)));
    row.ResolvedPairShare=mean(pairResolved(:,j));
    row.MuStarI=mean(abs(EEI(:,j)),'omitnan'); row.SigmaI=std(EEI(:,j),'omitnan');
    row.MuStarT=mean(abs(EET(:,j)),'omitnan'); row.SigmaT=std(EET(:,j),'omitnan');
    mRows=aigc.append_struct_row(mRows,row);
end
Tm=aigc.struct_rows_to_table(mRows);
writetable(Tm,fullfile(outDir,'exp05_morris_screening.csv'));

% One nested LHS design supports N=160,320,640 convergence checks.
N=settings.lhsN; U=aigc.lhs_unit(N,d,settings.sensitivitySeed+10);
Xpar=zeros(N,d); YI=nan(N,1); YT=nan(N,1); YQ=nan(N,1);
dI=nan(N,1); dT=nan(N,1); dynClass=strings(N,1); noClass=strings(N,1);
matchedRisk=nan(N,1); matchedTrust=nan(N,1); valid=false(N,1);
fullResolved=false(N,1); noResolved=false(N,1); tailRobust=false(N,1);
extremeRows=struct([]);
for n=1:N
    pp=apply_sample(p,names,ranges,U(n,:));
    for j=1:d, Xpar(n,j)=pp.(names{j}); end
    try
        [solF,~]=aigc.solve_adaptive_longrun(opt.X0,pp,mode,optS,settings.certificationMaxTime);
        sf=aigc.summarize_solution(solF,pp,mode,optS);
        [solN,~]=aigc.solve_adaptive_longrun(opt.X0,pp,modeNo,optS,settings.certificationMaxTime);
        sn=aigc.summarize_solution(solN,pp,modeNo,optS);
        YI(n)=sf.I; YT(n)=sf.T; YQ(n)=sf.Qexp; dI(n)=sf.I-sn.I; dT(n)=sf.T-sn.T;
        dynClass(n)=string(sf.dynamics); noClass(n)=string(sn.dynamics); valid(n)=true;
        fullResolved(n)=aigc.is_resolved_label(sf.dynamics);
        noResolved(n)=aigc.is_resolved_label(sn.dynamics);
        tailRobust(n)=sf.tailWindowClassRobust;
        if n<=settings.lhsMatchedN
            optShock=optS; optShock.t0=0; optShock.tEnd=max(100,opt.tEnd/4); optShock.allowEarlyStop=false;
            mm=aigc.matched_aigc_shock(solF.finalState,pp,mode,optShock,settings.robustnessAigcShockStrength);
            matchedRisk(n)=mm.RiskAreaGain; matchedTrust(n)=mm.TrustLossAreaGain;
        end
        if abs(dI(n))>0.05 || abs(dT(n))>0.05
            row=struct(); row.Sample=n; row.DeltaI=dI(n); row.DeltaT=dT(n);
            row.FullDynamics=char(dynClass(n)); row.NoAIGCDynamics=char(noClass(n));
            for j=1:d, row.(names{j})=Xpar(n,j); end
            extremeRows=aigc.append_struct_row(extremeRows,row);
        end
    catch ME
        fprintf(2,'Exp05 LHS sample %d failed: %s\n',n,ME.message);
    end
    if mod(n,max(1,round(N/10)))==0, fprintf('Exp05 LHS %d/%d completed.\n',n,N); end
end

Tv=array2table(Xpar,'VariableNames',names);
Tv.I=YI; Tv.T=YT; Tv.Qexp=YQ; Tv.DeltaIAIGCNet=dI; Tv.DeltaTAIGCNet=dT;
Tv.MatchedRiskAreaGain=matchedRisk; Tv.MatchedTrustLossAreaGain=matchedTrust;
Tv.FullDynamics=dynClass; Tv.NoAIGCDynamics=noClass; Tv.Valid=valid;
Tv.FullResolved=fullResolved; Tv.NoAIGCResolved=noResolved; Tv.TailWindowClassRobust=tailRobust;
writetable(Tv,fullfile(outDir,'exp05_lhs_samples.csv'));
if ~isempty(extremeRows)
    writetable(aigc.struct_rows_to_table(extremeRows),fullfile(outDir,'exp05_extreme_counterexamples.csv'));
end

% PRCC convergence and final bootstrap intervals for all and resolved strata.
convRows=struct([]); finalRows=struct([]);
scopes={'All','Resolved'};
for s=1:numel(scopes)
    for q=1:numel(settings.prccConvergenceN)
        nReq=settings.prccConvergenceN(q); base=(1:N)'<=nReq & valid;
        if strcmp(scopes{s},'Resolved'), base=base&fullResolved; end
        nBoot=0; if nReq==max(settings.prccConvergenceN), nBoot=settings.prccBootstrap; end
        [rI,loI,hiI]=aigc.prcc(Xpar(base,:),YI(base),nBoot,settings.sensitivitySeed+20+100*s+q);
        [rT,loT,hiT]=aigc.prcc(Xpar(base,:),YT(base),nBoot,settings.sensitivitySeed+30+100*s+q);
        for j=1:d
            row=struct(); row.Scope=scopes{s}; row.NRequested=nReq; row.NUsed=sum(base);
            row.Parameter=names{j}; row.PRCC_I=rI(j); row.CI_L_I=loI(j); row.CI_U_I=hiI(j);
            row.PRCC_T=rT(j); row.CI_L_T=loT(j); row.CI_U_T=hiT(j);
            convRows=aigc.append_struct_row(convRows,row);
            if nReq==max(settings.prccConvergenceN), finalRows=aigc.append_struct_row(finalRows,row); end
        end
    end
end
Tconv=aigc.struct_rows_to_table(convRows); Tpr=aigc.struct_rows_to_table(finalRows);
writetable(Tconv,fullfile(outDir,'exp05_prcc_convergence.csv'));
writetable(Tpr,fullfile(outDir,'exp05_prcc_all_and_resolved.csv'));

% Monotonicity and collinearity diagnostics.
qaRows=struct([]);
for j=1:d
    base=valid;
    row=struct(); row.Parameter=names{j};
    row.SpearmanI=rank_correlation(Xpar(base,j),YI(base));
    row.SpearmanT=rank_correlation(Xpar(base,j),YT(base));
    row.BinnedSignChangesI=binned_sign_changes(Xpar(base,j),YI(base),5);
    row.BinnedSignChangesT=binned_sign_changes(Xpar(base,j),YT(base),5);
    row.VIF=vif_value(Xpar(base,:),j);
    qaRows=aigc.append_struct_row(qaRows,row);
end
Tqa=aigc.struct_rows_to_table(qaRows);
writetable(Tqa,fullfile(outDir,'exp05_monotonicity_vif.csv'));
C=corrcoef(Xpar(valid,:)); Tc=array2table(C,'VariableNames',names); Tc.Parameter=names';
Tc=movevars(Tc,'Parameter','Before',1);
writetable(Tc,fullfile(outDir,'exp05_parameter_correlation.csv'));

probT=[probability_row('All',valid,dI,dT,matchedRisk,matchedTrust,settings); ...
       probability_row('Resolved',valid&fullResolved&noResolved,dI,dT,matchedRisk,matchedTrust,settings)];
writetable(probT,fullfile(outDir,'exp05_direction_probabilities.csv'));
v=valid; q=[5 25 50 75 95];
Tq=table(q',aigc.percentile(dI(v),q)',aigc.percentile(dT(v),q)', ...
    'VariableNames',{'Percentile','DeltaINet','DeltaTNet'});
writetable(Tq,fullfile(outDir,'exp05_aigc_effect_quantiles.csv'));

% Four-panel figure matching the reported evidence.
fig=figure('Visible','off','Color','w','Position',[60 60 1400 900]);
subplot(2,2,1); scatter(Tm.MuStarI,Tm.SigmaI,45,'filled');
for j=1:d
    text(Tm.MuStarI(j),Tm.SigmaI(j),[' ' aigc.parameter_display_name(Tm.Parameter{j})], ...
        'Interpreter','latex','FontSize',7);
end
xlabel('Morris \mu^* for risk'); ylabel('Morris \sigma for risk'); grid on;
subplot(2,2,2); idx=strcmp(Tpr.Scope,'All'); S=Tpr(idx,:);
[~,ord]=sort(abs(S.PRCC_I),'descend'); ord=ord(1:min(10,numel(ord)));
errorbar(1:numel(ord),S.PRCC_I(ord),S.PRCC_I(ord)-S.CI_L_I(ord),S.CI_U_I(ord)-S.PRCC_I(ord),'o');
labels=cellfun(@aigc.parameter_display_name,S.Parameter(ord),'UniformOutput',false);
set(gca,'XTick',1:numel(ord),'XTickLabel',labels,'TickLabelInterpreter','latex'); xtickangle(45);
yline(0,'k--'); ylabel('PRCC for risk (95% bootstrap CI)'); grid on;
subplot(2,2,3); plot_convergence(Tconv);
subplot(2,2,4); bar(categorical(probT.Scope),[probT.PrNetDeltaI_Positive probT.PrMeaningfulNetRiskIncrease ...
    probT.PrMatchedRiskAreaIncrease probT.PrMatchedTrustLossIncrease]);
ylim([0 1]); ylabel('Estimated probability');
legend({'Net risk direction','Net risk substantive','Matched risk area','Matched trust-loss area'},'Location','best'); grid on;
aigc.save_figure(fig,fullfile(outDir,'fig_exp05_global_sensitivity')); close(fig);
end

function pp=apply_sample(p,names,ranges,u)
pp=p;
for j=1:numel(names), pp.(names{j})=ranges(j,1)+u(j)*(ranges(j,2)-ranges(j,1)); end
end

function row=probability_row(scope,mask,dI,dT,mr,mt,s)
v=mask&isfinite(dI)&isfinite(dT); vm=mask&isfinite(mr)&isfinite(mt);
row=table({scope},sum(v),mean(dI(v)>0),mean(dT(v)<0), ...
    mean(dI(v)>s.effectAbsoluteTol),mean(dT(v)<-s.effectAbsoluteTol), ...
    sum(vm),mean(mr(vm)>0),mean(mt(vm)>0), ...
    mean(mr(vm)>s.effectAbsoluteTol),mean(mt(vm)>s.effectAbsoluteTol), ...
    'VariableNames',{'Scope','NValid','PrNetDeltaI_Positive','PrNetDeltaT_Negative', ...
    'PrMeaningfulNetRiskIncrease','PrMeaningfulNetTrustDecrease','NMatched', ...
    'PrMatchedRiskAreaDirection','PrMatchedTrustLossDirection', ...
    'PrMatchedRiskAreaIncrease','PrMatchedTrustLossIncrease'});
end

function rho=rank_correlation(x,y)
rx=aigc.local_rank(x); ry=aigc.local_rank(y); C=corrcoef(rx,ry);
if numel(C)<4, rho=NaN; else, rho=C(1,2); end
end

function n=binned_sign_changes(x,y,k)
[~,ord]=sort(x); y=y(ord); edges=round(linspace(1,numel(y)+1,k+1)); m=nan(k,1);
for b=1:k
    ids=edges(b):edges(b+1)-1;
    if ~isempty(ids), m(b)=mean(y(ids),'omitnan'); end
end
d=diff(m); d=d(abs(d)>1e-12); if numel(d)<2, n=0; else, n=sum(sign(d(1:end-1))~=sign(d(2:end))); end
end

function v=vif_value(X,j)
ok=all(isfinite(X),2); X=X(ok,:);
y=X(:,j); Z=[ones(size(X,1),1),X(:,setdiff(1:size(X,2),j))];
fit=Z*(Z\y); sst=sum((y-mean(y)).^2); r2=1-sum((y-fit).^2)/(sst+eps);
v=1/max(1-r2,eps);
end

function plot_convergence(T)
S=T(strcmp(T.Scope,'All'),:); nMax=max(S.NRequested);
F=S(S.NRequested==nMax,:); [~,ord]=sort(abs(F.PRCC_I),'descend');
top=F.Parameter(ord(1:min(5,numel(ord)))); hold on;
for j=1:numel(top)
    q=strcmp(S.Parameter,top{j});
    plot(S.NRequested(q),S.PRCC_I(q),'-o','DisplayName',aigc.parameter_display_name(top{j}));
end
xlabel('LHS sample size'); ylabel('PRCC for risk'); yline(0,'k--');
legend('Location','best','Interpreter','latex'); grid on;
end
