function exp01_representative_regimes(p,opt,settings,outputRoot)
%EXP01_REPRESENTATIVE_REGIMES Re-certify four targeted dynamical regimes.
outDir=fullfile(outputRoot,'Exp01_representative_regimes'); aigc.ensure_dir(outDir);
regimes=aigc.representative_regimes(p); mode=aigc.full_mode();
raw=struct([]); repSols=cell(numel(regimes),1); repEval=cell(numel(regimes),1);
for g=1:numel(regimes)
    X0s=aigc.sample_initial_conditions(regimes(g).X0,settings.commonIC,0.12,2026072300+g);
    for ic=1:size(X0s,1)
        fprintf('Exp01 %s IC %d/%d...\n',regimes(g).name,ic,size(X0s,1));
        [sol,cert]=aigc.solve_adaptive_longrun(X0s(ic,:)',regimes(g).p,mode,opt,settings.certificationMaxTime);
        ss=aigc.summarize_solution(sol,regimes(g).p,mode,opt);
        row=make_row(regimes(g),ic,ss,cert);
        raw=aigc.append_struct_row(raw,row);
        if ic==1, repSols{g}=sol; repEval{g}=aigc.evaluate_solution(sol,regimes(g).p,mode); end
    end
end
Traw=aigc.struct_rows_to_table(raw); writetable(Traw,fullfile(outDir,'exp01_regime_raw.csv'));

agg=struct([]);
for g=1:numel(regimes)
    row=struct(); idx=strcmp(Traw.Regime,regimes(g).name); labels=Traw.Dynamics(idx);
    row.Regime=regimes(g).name; row.ExpectedClass=regimes(g).expectedClass;
    row.MeanI=mean(Traw.I(idx)); row.MeanT=mean(Traw.T(idx)); row.MeanQexp=mean(Traw.Qexp(idx));
    row.MeanU=mean(Traw.u(idx)); row.MeanPAct=mean(Traw.pAct(idx)); row.MeanA=mean(Traw.A(idx));
    row.MeanL=mean(Traw.L(idx)); row.MeanE=mean(Traw.E(idx));
    row.EquilibriumShare=mean(contains(labels,'equilibrium'));
    row.CycleShare=mean(strcmp(labels,'stable_cycle'));
    row.UnresolvedShare=1-row.EquilibriumShare-row.CycleShare;
    row.TailStableShare=mean(Traw.TailStable(idx));
    row.MeanPeriod=mean(Traw.Period(idx),'omitnan');
    row.MeanSpectralAbscissa=mean(Traw.SpectralAbscissa(idx),'omitnan');
    row.ExpectedClassShare=mean(strcmp(labels,regimes(g).expectedClass));
    row.PassTarget=target_pass(regimes(g).name,row,Traw(idx,:));
    agg=aigc.append_struct_row(agg,row);
end
Tagg=aigc.struct_rows_to_table(agg); writetable(Tagg,fullfile(outDir,'exp01_regime_summary.csv'));

fig=figure('Visible','off','Color','w','Position',[40 40 1500 980]);
columnNames={'Risk $I$','Trust $T$','Audit $u$','Coverage $p_{act}$','Backlog $A$','Label $L$'};
for g=1:numel(regimes)
    sol=repSols{g}; ev=repEval{g};
    series={ev.I,ev.T,ev.uEff,ev.pAct,ev.A,ev.L};
    cert=aigc.classify_dynamics(sol,regimes(g).p,mode,opt);
    for c=1:6
        subplot(4,6,(g-1)*6+c); plot(sol.t,series{c},'LineWidth',1.05); box on;
        ylim([0 1]); if g==4, xlabel('Time'); end
        if g==1, title(columnNames{c},'Interpreter','latex'); end
        if c==1
            ylabel(sprintf('%s\n%s',regimes(g).name,cert.label),'Interpreter','none');
        end
    end
end
aigc.save_figure(fig,fullfile(outDir,'fig_exp01_representative_regimes')); close(fig);
end

function row=make_row(regime,ic,ss,cert)
row.Regime=regime.name; row.ExpectedClass=regime.expectedClass; row.IC=ic; row.Dynamics=ss.dynamics;
row.x=ss.x; row.y=ss.y; row.z=ss.z; row.I=ss.I; row.T=ss.T; row.M=ss.M;
row.u=ss.u; row.A=ss.A; row.L=ss.L; row.E=ss.E; row.Q0=ss.Q0; row.D=ss.D;
row.Qexp=ss.Qexp; row.pAct=ss.pAct; row.pIn=ss.pIn; row.pSp=ss.pSp; row.pRm=ss.pRm;
row.phiIn=ss.phiIn; row.phiAct=ss.phiAct; row.nuEff=ss.nuEff; row.JC=ss.JC;
row.Period=ss.period; row.PeriodCV=ss.periodCV; row.AmpI=ss.ampI;
row.Residual=ss.residual; row.SpectralAbscissa=ss.spectralAbscissa;
row.TailStable=ss.tailStable; row.TailMeanDrift=ss.tailMeanDrift;
row.Extended=cert.extended; row.FinalTime=cert.finalTime;
row.ClipSafetyMargin=ss.clipSafetyMargin; row.TailWindowClassRobust=ss.tailWindowClassRobust;
row.TailWindowMeanSpreadI=ss.tailWindowMeanSpreadI; row.TailWindowAmpSpreadI=ss.tailWindowAmpSpreadI;
end

function pass=target_pass(name,row,T)
switch name
    case 'R1_BalancedInterior'
        pass=row.EquilibriumShare>=0.8 && row.TailStableShare>=0.8 && row.MeanI>0.05 && row.MeanI<0.55;
    case 'R2_LowRiskHighTrust'
        pass=row.EquilibriumShare>=0.8 && row.MeanI<0.20 && row.MeanT>0.65;
    case 'R3_PeriodicCandidate'
        pass=row.CycleShare>=0.8 && mean(T.PeriodCV,'omitnan')<0.02;
    case 'R4_RiskDominantBoundary'
        pass=row.EquilibriumShare>=0.8 && row.MeanI>0.70 && row.MeanT<0.10;
    otherwise
        pass=false;
end
end
