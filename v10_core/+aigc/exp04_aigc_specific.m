function exp04_aigc_specific(p,opt,settings,outputRoot)
%EXP04_AIGC_SPECIFIC Separate capacity, adaptation, and net-system effects.
outDir=fullfile(outputRoot,'Exp04_aigc_specific'); aigc.ensure_dir(outDir);
N=settings.aigcPlaneN; modeFull=aigc.full_mode(); modeNo=aigc.leave_one_out_mode(8);
optPlane=opt; optPlane.allowEarlyStop=false; optPlane.solver='ode45';

rhoGrid=linspace(0.04,0.72,N); sGrid=linspace(0.50,0.96,N);
T1=run_plane(p,optPlane,modeFull,modeNo,'rhoE',rhoGrid,'s',sGrid,settings.certificationMaxTime);
writetable(T1,fullfile(outDir,'exp04_plane_rhoE_s.csv'));
psiGrid=linspace(0,1.8,N); fpGrid=linspace(0.25,1.30,N);
T2=run_plane(p,optPlane,modeFull,modeNo,'psiE',psiGrid,'FP',fpGrid,settings.certificationMaxTime);
writetable(T2,fullfile(outDir,'exp04_plane_psiE_FP.csv'));

% Common pre-surge state under the complete system.
[baseSol,~]=aigc.solve_adaptive_longrun(opt.X0,p,modeFull,optPlane,settings.certificationMaxTime);
Xb=baseSol.finalState;
optShock=optPlane; optShock.t0=0; optShock.tEnd=max(120,opt.tEnd/3); optShock.allowEarlyStop=false;
shockRows=struct([]); rep=[];
for k=1:numel(settings.shockStrengths)
    m=aigc.matched_aigc_shock(Xb,p,modeFull,optShock,settings.shockStrengths(k));
    row=rmfield(m,{'t','I0','T0','ID','TD','IF','TF','MD','MF'});
    row.CapacityMatched=abs(row.CapacityMatchError)<=settings.matchedCapacityTol;
    shockRows=aigc.append_struct_row(shockRows,row);
    if k==numel(settings.shockStrengths), rep=m; end
end
Tshock=aigc.struct_rows_to_table(shockRows);
writetable(Tshock,fullfile(outDir,'exp04_matched_capacity_shocks.csv'));

summaryT=[direction_summary(T1,'All',settings);direction_summary(T1,'Resolved',settings)];
writetable(summaryT,fullfile(outDir,'exp04_effect_direction_summary.csv'));

fig=figure('Visible','off','Color','w','Position',[40 40 1500 900]);
subplot(2,3,1); signed_map(sGrid,rhoGrid,plane_matrix(T1,'NetDeltaI',N,N));
xlabel('$s$','Interpreter','latex'); ylabel('$\rho_E$','Interpreter','latex');
title('Dynamic minus no AIGC: risk');
subplot(2,3,2); signed_map(sGrid,rhoGrid,plane_matrix(T1,'NetDeltaT',N,N));
xlabel('$s$','Interpreter','latex'); ylabel('$\rho_E$','Interpreter','latex');
title('Dynamic minus no AIGC: trust');
subplot(2,3,3); class_map(sGrid,rhoGrid,plane_matrix(T1,'DynamicClassCode',N,N));
xlabel('$s$','Interpreter','latex'); ylabel('$\rho_E$','Interpreter','latex');
title('Dynamic-model classification');
subplot(2,3,4); signed_map(fpGrid,psiGrid,plane_matrix(T2,'NetDeltaI',N,N));
xlabel('$F_P$','Interpreter','latex'); ylabel('$\psi_E$','Interpreter','latex');
title('Dynamic minus no AIGC: risk');
subplot(2,3,5); signed_map(sGrid,rhoGrid,plane_matrix(T1,'AdaptationDeltaI',N,N));
xlabel('$s$','Interpreter','latex'); ylabel('$\rho_E$','Interpreter','latex');
title('Dynamic minus capacity-matched fixed');
subplot(2,3,6);
bar(categorical(string(Tshock.Strength)),[Tshock.RiskAreaGain Tshock.TrustLossAreaGain]);
ylabel('Absolute cumulative-area difference');
legend({'Risk area','Trust-loss area'},'Location','best'); grid on;
aigc.save_figure(fig,fullfile(outDir,'fig_exp04_aigc_specific')); close(fig);

if ~isempty(rep)
    fig2=figure('Visible','off','Color','w','Position',[100 100 1000 650]);
    subplot(2,1,1); plot(rep.t,rep.I0,'LineWidth',1.1); hold on;
    plot(rep.t,rep.ID,'LineWidth',1.1); plot(rep.t,rep.IF,'LineWidth',1.1);
    ylabel('Risk I'); legend({'No surge','Dynamic adaptation','Onset-matched fixed'},'Location','best'); grid on;
    subplot(2,1,2); plot(rep.t,rep.T0,'LineWidth',1.1); hold on;
    plot(rep.t,rep.TD,'LineWidth',1.1); plot(rep.t,rep.TF,'LineWidth',1.1);
    xlabel('Time'); ylabel('Trust T'); grid on;
    aigc.save_figure(fig2,fullfile(outDir,'fig_exp04_matched_shock_trajectory')); close(fig2);
end
end

function T=run_plane(p,opt,modeFull,modeNo,name1,grid1,name2,grid2,maxT)
rows=struct([]); N1=numel(grid1); N2=numel(grid2);
for i=1:N1
    for j=1:N2
        pp=p; pp.(name1)=grid1(i); pp.(name2)=grid2(j);
        [solF,certF]=aigc.solve_adaptive_longrun(opt.X0,pp,modeFull,opt,maxT);
        sf=aigc.summarize_solution(solF,pp,modeFull,opt);
        [solN,certN]=aigc.solve_adaptive_longrun(opt.X0,pp,modeNo,opt,maxT);
        sn=aigc.summarize_solution(solN,pp,modeNo,opt);
        targetCap=sf.mE; [Efix,~]=aigc.match_fixed_E(targetCap,pp,modeFull);
        mf=modeFull; mf.fixedE=true; mf.fixedEValue=Efix; mf.activeMask(10)=false;
        [solX,certX]=aigc.solve_adaptive_longrun(opt.X0,pp,mf,opt,maxT);
        sx=aigc.summarize_solution(solX,pp,mf,opt);
        row=struct(); row.(name1)=grid1(i); row.(name2)=grid2(j);
        row.DynamicE=sf.E; row.FixedE=Efix; row.TargetTailCapacity=targetCap;
        row.FixedTailCapacity=sx.mE; row.CapacityMatchError=sx.mE-targetCap;
        row.DynamicI=sf.I; row.FixedI=sx.I; row.NoAIGCI=sn.I;
        row.DynamicT=sf.T; row.FixedT=sx.T; row.NoAIGCT=sn.T;
        row.CapacityDeltaI=sx.I-sn.I; row.CapacityDeltaT=sx.T-sn.T;
        row.AdaptationDeltaI=sf.I-sx.I; row.AdaptationDeltaT=sf.T-sx.T;
        row.NetDeltaI=sf.I-sn.I; row.NetDeltaT=sf.T-sn.T;
        row.DynamicDynamics=sf.dynamics; row.FixedDynamics=sx.dynamics; row.NoAIGCDynamics=sn.dynamics;
        row.DynamicResolved=aigc.is_resolved_label(sf.dynamics);
        row.FixedResolved=aigc.is_resolved_label(sx.dynamics);
        row.NoAIGCResolved=aigc.is_resolved_label(sn.dynamics);
        row.AllResolved=row.DynamicResolved&&row.FixedResolved&&row.NoAIGCResolved;
        row.DynamicClassCode=class_code(sf.dynamics);
        row.DynamicFinalTime=certF.finalTime; row.FixedFinalTime=certX.finalTime; row.NoAIGCFinalTime=certN.finalTime;
        row.DynamicTailWindowRobust=sf.tailWindowClassRobust;
        row.DynamicTailMeanSpreadI=sf.tailWindowMeanSpreadI;
        rows=aigc.append_struct_row(rows,row);
    end
    fprintf('Exp04 plane %s row %d/%d completed.\n',name1,i,N1);
end
T=aigc.struct_rows_to_table(rows);
end

function row=direction_summary(T,scope,settings)
if strcmp(scope,'Resolved'), idx=T.AllResolved; else, idx=true(height(T),1); end
row=table({scope},sum(idx),mean(T.NetDeltaI(idx)>0),mean(T.NetDeltaT(idx)<0), ...
    mean(T.AdaptationDeltaI(idx)>0),mean(T.AdaptationDeltaT(idx)<0), ...
    mean(T.NetDeltaI(idx)>settings.effectAbsoluteTol), ...
    mean(T.NetDeltaT(idx)<-settings.effectAbsoluteTol), ...
    'VariableNames',{'Scope','N','PrNetRiskIncrease','PrNetTrustDecrease', ...
    'PrAdaptationRiskIncrease','PrAdaptationTrustDecrease', ...
    'PrSubstantiveNetRiskIncrease','PrSubstantiveNetTrustDecrease'});
end

function M=plane_matrix(T,field,n1,n2)
M=reshape(T.(field),n2,n1)';
end

function signed_map(x,y,M)
imagesc(x,y,M); axis xy; cb=colorbar;
cb.Label.String='Signed difference (positive = first-named model higher; dimensionless)';
lim=max(abs(M(:)),[],'omitnan'); if isfinite(lim)&&lim>0, caxis([-lim lim]); end
end

function class_map(x,y,M)
imagesc(x,y,M); axis xy; caxis([0.5 4.5]); cb=colorbar;
cb.Ticks=1:4; cb.TickLabels={'equilibrium','certified cycle','unresolved','boundary/non-smooth'};
end

function c=class_code(label)
if contains(label,'interior_equilibrium'), c=1;
elseif strcmp(label,'stable_cycle'), c=2;
elseif contains(label,'boundary'), c=4;
else, c=3;
end
end
