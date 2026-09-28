function exp07_trust_shocks(p,opt,settings,outputRoot)
%EXP07_TRUST_SHOCKS Model-specific paired counterfactual trust shocks.
outDir=fullfile(outputRoot,'Exp07_trust_shocks'); aigc.ensure_dir(outDir);
optTrust=opt; optTrust.solver='ode45';
patterns=shock_patterns(settings.trustShockStart,settings.trustEvalHorizon);
rows=struct([]); baseRows=struct([]); representative=[];
for k=0:5
    br=struct(); mode=aigc.trust_mode(k); mode.shock=aigc.no_shock();
    [warmSol,~]=aigc.solve_adaptive_longrun(opt.X0,p,mode,optTrust,settings.trustWarmupMaxTime);
    Xb=warmSol.finalState; warmSS=aigc.summarize_solution(warmSol,p,mode,optTrust);
    br.TrustModel=sprintf('T%d',k); br.WarmupDynamics=warmSS.dynamics; br.BaselineI=warmSS.I;
    br.BaselineT=warmSS.T; br.BaselineM=warmSS.M; br.WarmupFinalTime=warmSol.finalTime;
    baseRows=aigc.append_struct_row(baseRows,br);
    optEval=optTrust; optEval.t0=0; optEval.tEnd=settings.trustEvalHorizon; optEval.allowEarlyStop=false;
    m0=mode; m0.shock=aigc.no_shock(); sol0=aigc.solve_model(Xb,p,m0,optEval);
    for s=1:numel(patterns)
        for q=1:numel(settings.shockStrengths)
            row=struct(); ms=mode; sh=aigc.no_shock(); sh.type='risk_environment';
            sh.windows=patterns(s).windows; sh.strength=settings.shockStrengths(q); ms.shock=sh;
            solS=aigc.solve_model(Xb,p,ms,optEval);
            metric=paired_metrics(sol0,solS,p,m0,ms,optTrust,patterns(s).lastEnd,k,settings.effectAbsoluteTol);
            row.TrustModel=sprintf('T%d',k); row.Shock=patterns(s).name; row.Strength=settings.shockStrengths(q);
            fn=fieldnames(metric); for j=1:numel(fn), row.(fn{j})=metric.(fn{j}); end
            rows=aigc.append_struct_row(rows,row);
            if k==5 && strcmp(patterns(s).name,'periodic') && q==numel(settings.shockStrengths)
                representative=representative_trajectory(sol0,solS,p,m0,ms);
            end
        end
    end
    fprintf('Exp07 T%d completed.\n',k);
end
T=aigc.struct_rows_to_table(rows); writetable(T,fullfile(outDir,'exp07_trust_shock_metrics.csv'));
writetable(aigc.struct_rows_to_table(baseRows),fullfile(outDir,'exp07_model_specific_baselines.csv'));
Trec=recovery_summary(T); writetable(Trec,fullfile(outDir,'exp07_recovery_summary.csv'));
Tkm=km_table(T); writetable(Tkm,fullfile(outDir,'exp07_recovery_kaplan_meier.csv'));

fig=figure('Visible','off','Color','w','Position',[80 80 1250 820]);
subplot(2,2,1); plot_metric(T,'instantaneous','MaxTrustLoss'); title('Instantaneous shock');
subplot(2,2,2); plot_metric(T,'periodic','TrustLossArea'); title('Periodic shocks');
subplot(2,2,3); bar(categorical(Trec.TrustModel),[Trec.RecoveryFraction Trec.CensorFraction]);
ylim([0 1]); ylabel('Proportion among applicable trajectories');
legend({'Recovered','Right-censored'},'Location','best'); grid on; title('Recovery and censoring');
subplot(2,2,4);
if ~isempty(representative)
    plot(representative.t,representative.IS,'LineWidth',1.1); hold on;
    plot(representative.t,representative.TS,'LineWidth',1.1); plot(representative.t,representative.MS,'LineWidth',1.1);
    plot(representative.t,representative.T0,'--','LineWidth',1.0);
    legend({'I shock','T shock','M shock','T no-shock'},'Location','best'); xlabel('Time'); ylabel('State'); grid on;
end
title('Representative T5 periodic response');
aigc.save_figure(fig,fullfile(outDir,'fig_exp07_trust_shocks')); close(fig);

fig2=figure('Visible','off','Color','w','Position',[100 100 950 620]);
plot_km(Tkm); xlabel('Time since last shock'); ylabel('Not-yet-recovered probability');
title('Kaplan-Meier-style recovery curves'); grid on;
aigc.save_figure(fig2,fullfile(outDir,'fig_exp07_recovery_survival')); close(fig2);
end

function patterns=shock_patterns(startT,horizon)
patterns=struct('name',{},'windows',{},'lastEnd',{});
patterns(1).name='instantaneous'; patterns(1).windows=[startT startT+2]; patterns(1).lastEnd=startT+2;
patterns(2).name='sustained'; patterns(2).windows=[startT startT+35]; patterns(2).lastEnd=startT+35;
patterns(3).name='repeated'; patterns(3).windows=[startT startT+5; startT+28 startT+33; startT+56 startT+61]; patterns(3).lastEnd=startT+61;
periodStarts=startT:28:min(horizon-5,startT+112); windows=[periodStarts(:),periodStarts(:)+5];
patterns(4).name='periodic'; patterns(4).windows=windows; patterns(4).lastEnd=windows(end,2);
end

function m=paired_metrics(sol0,solS,p,mode0,modeS,opt,lastShockEnd,k,effectTol)
ev0=aigc.evaluate_solution(sol0,p,mode0); evS=aigc.evaluate_solution(solS,p,modeS);
t0=max(ev0.t(1),evS.t(1)); t1=min(ev0.t(end),evS.t(end)); t=linspace(t0,t1,1501)';
I0=interp1(ev0.t,ev0.I,t,'pchip'); IS=interp1(evS.t,evS.I,t,'pchip');
T0=interp1(ev0.t,ev0.T,t,'pchip'); TS=interp1(evS.t,evS.T,t,'pchip');
dT=max(T0-TS,0); dI=max(IS-I0,0);
m.MaxTrustLoss=max(dT); m.TrustLossArea=trapz(t,dT);
m.MaxRiskExcess=max(dI); m.RiskExcessArea=trapz(t,dI);
m.MeasurableTrustLoss=m.MaxTrustLoss>effectTol;
m.RecoveryApplicable=(k>0) && m.MeasurableTrustLoss;
if m.RecoveryApplicable
    [tau,recovered]=recovery_time(t,abs(TS-T0),lastShockEnd,opt.recoveryTolerance,opt.recoveryHold);
    m.RecoveryTime=tau; m.Recovered=double(recovered); m.RightCensored=double(~recovered);
    m.ObservationAfterShock=t(end)-lastShockEnd;
    if recovered, m.RecoveryOrCensorTime=tau; else, m.RecoveryOrCensorTime=m.ObservationAfterShock; end
else
    m.RecoveryTime=NaN; m.Recovered=NaN; m.RightCensored=NaN;
    m.ObservationAfterShock=NaN; m.RecoveryOrCensorTime=NaN;
end
c0=aigc.classify_dynamics(sol0,p,mode0,opt); cs=aigc.classify_dynamics(solS,p,modeS,opt);
m.BaselineDynamics=c0.label; m.ShockDynamics=cs.label;
m.FinalTrustDifference=TS(end)-T0(end); m.FinalRiskDifference=IS(end)-I0(end);
end

function Trec=recovery_summary(T)
models=unique(T.TrustModel,'stable'); rows=struct([]);
for i=1:numel(models)
    idx=strcmp(T.TrustModel,models{i})&T.RecoveryApplicable;
    row=struct(); row.TrustModel=models{i}; row.NApplicable=sum(idx);
    row.NRecovered=sum(T.Recovered(idx)==1); row.NRightCensored=sum(T.RightCensored(idx)==1);
    if row.NApplicable>0
        row.RecoveryFraction=row.NRecovered/row.NApplicable;
        row.CensorFraction=row.NRightCensored/row.NApplicable;
        row.MedianObservedRecovery=median(T.RecoveryTime(idx),'omitnan');
    else
        row.RecoveryFraction=NaN; row.CensorFraction=NaN; row.MedianObservedRecovery=NaN;
    end
    rows=aigc.append_struct_row(rows,row);
end
Trec=aigc.struct_rows_to_table(rows);
end

function Tkm=km_table(T)
models=unique(T.TrustModel,'stable'); rows=struct([]);
for i=1:numel(models)
    idx=strcmp(T.TrustModel,models{i})&T.RecoveryApplicable;
    time=T.RecoveryOrCensorTime(idx); event=T.Recovered(idx)==1;
    ok=isfinite(time); time=time(ok); event=event(ok);
    if isempty(time), continue; end
    eventTimes=unique(time(event)); survival=1;
    row=struct(); row.TrustModel=models{i}; row.Time=0; row.AtRisk=numel(time);
    row.Events=0; row.Censored=0; row.Survival=1; rows=aigc.append_struct_row(rows,row);
    for q=1:numel(eventTimes)
        tq=eventTimes(q); atRisk=sum(time>=tq); d=sum(event&abs(time-tq)<1e-10);
        c=sum(~event&abs(time-tq)<1e-10); survival=survival*(1-d/max(atRisk,1));
        row=struct(); row.TrustModel=models{i}; row.Time=tq; row.AtRisk=atRisk;
        row.Events=d; row.Censored=c; row.Survival=survival;
        rows=aigc.append_struct_row(rows,row);
    end
end
if isempty(rows)
    Tkm=table({''},NaN,NaN,NaN,NaN,NaN,'VariableNames', ...
        {'TrustModel','Time','AtRisk','Events','Censored','Survival'});
else
    Tkm=aigc.struct_rows_to_table(rows);
end
end

function plot_km(T)
models=unique(T.TrustModel,'stable'); hold on;
for i=1:numel(models)
    S=T(strcmp(T.TrustModel,models{i}),:);
    if isempty(S) || all(~isfinite(S.Time)), continue; end
    stairs(S.Time,S.Survival,'LineWidth',1.2,'DisplayName',models{i});
end
legend('Location','best');
end

function [tau,recovered]=recovery_time(t,d,lastEnd,tol,hold)
tau=NaN; recovered=false; ids=find(t>=lastEnd);
for ii=1:numel(ids)
    i=ids(ii); j=find(t>=t(i)+hold,1);
    if isempty(j), break; end
    if all(d(i:j)<tol), tau=t(i)-lastEnd; recovered=true; return; end
end
end

function out=representative_trajectory(sol0,solS,p,m0,mS)
ev0=aigc.evaluate_solution(sol0,p,m0); evS=aigc.evaluate_solution(solS,p,mS);
t=linspace(max(ev0.t(1),evS.t(1)),min(ev0.t(end),evS.t(end)),1501)';
out.t=t; out.I0=interp1(ev0.t,ev0.I,t,'pchip'); out.T0=interp1(ev0.t,ev0.T,t,'pchip');
out.IS=interp1(evS.t,evS.I,t,'pchip'); out.TS=interp1(evS.t,evS.T,t,'pchip');
out.MS=interp1(solS.t,solS.X(:,6),t,'pchip');
end

function plot_metric(T,shockName,metric)
idx=strcmp(T.Shock,shockName); sub=T(idx,:); models=unique(sub.TrustModel,'stable'); strengths=unique(sub.Strength);
Y=nan(numel(models),numel(strengths));
for i=1:numel(models)
    for j=1:numel(strengths)
        k=strcmp(sub.TrustModel,models{i})&sub.Strength==strengths(j); Y(i,j)=mean(sub.(metric)(k),'omitnan');
    end
end
bar(categorical(models),Y); ylabel(metric,'Interpreter','none'); legend(cellstr(string(strengths)),'Location','best'); grid on;
end
