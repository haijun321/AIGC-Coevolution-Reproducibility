function exp06_dynamic_instability(p,opt,settings,outputRoot)
%EXP06_DYNAMIC_INSTABILITY Spectrum crossing, clip safety, and long-run classes.
outDir=fullfile(outputRoot,'Exp06_dynamic_instability'); aigc.ensure_dir(outDir);
mode=aigc.full_mode(); optLong=opt; optLong.allowEarlyStop=false; optLong.solver='ode45';
N=settings.phaseN; speedGrid=linspace(0.15,1.10,N); gainGrid=linspace(0.40,2.60,N);
rows=struct([]); classCode=3*ones(N,N); eqStates=cell(N,N);
for i=1:N
    for j=1:N
        pp=scaled_parameters(p,speedGrid(i),gainGrid(j));
        if j>1 && ~isempty(eqStates{i,j-1}), seed=eqStates{i,j-1};
        elseif i>1 && ~isempty(eqStates{i-1,j}), seed=eqStates{i-1,j};
        else, seed=opt.X0; end
        eq=aigc.find_equilibrium(seed,pp,mode,opt);
        Xrun=opt.X0; if eq.success, Xrun=perturb_equilibrium(eq.X,mode); end
        [sol,cert]=aigc.solve_adaptive_longrun(Xrun,pp,mode,optLong,settings.phaseMaxTime);
        ss=aigc.summarize_solution(sol,pp,mode,opt);
        if ~eq.success, eq=retry_equilibrium(sol,pp,mode,opt); end
        if eq.success, eqStates{i,j}=eq.X; else, eqStates{i,j}=[]; end
        dyn=resolve_label(eq,ss,opt);
        row=struct(); row.AuditSpeed=speedGrid(i); row.GainScale=gainGrid(j); row.Dynamics=dyn;
        row.AmpI=ss.ampI; row.Period=ss.period; row.PeriodCV=ss.periodCV;
        row.MeanI=ss.I; row.MeanT=ss.T; row.TailStable=ss.tailStable;
        row.EquilibriumFound=eq.success; row.EquilibriumInternal=eq.internal;
        row.EquilibriumResidual=eq.residual; row.SpectralAbscissa=eq.spectralAbscissa;
        row.DominantComplexReal=eq.dominantComplexReal;
        row.DominantComplexImag=eq.dominantComplexImag;
        row.OtherSpectralAbscissa=eq.otherSpectralAbscissa;
        row.ClipSafetyMargin=eq.clipSafetyMargin; row.FinalTime=cert.finalTime;
        row.TailWindowClassRobust=ss.tailWindowClassRobust;
        row.TailWindowMeanSpreadI=ss.tailWindowMeanSpreadI;
        rows=aigc.append_struct_row(rows,row);
        classCode(i,j)=class_to_code(dyn);
    end
    fprintf('Exp06 phase row %d/%d completed.\n',i,N);
end
T=aigc.struct_rows_to_table(rows);
writetable(T,fullfile(outDir,'exp06_audit_speed_gain_phase.csv'));
write_class_counts(T,fullfile(outDir,'exp06_classification_counts.csv'));

rho=linspace(0.25,1.60,max(21,N));
forward=continuation(rho,p,optLong,mode,opt.X0,'forward',settings.phaseMaxTime,opt);
reverse=continuation(fliplr(rho),p,optLong,mode,forward(end).FinalState','reverse',settings.phaseMaxTime,opt);
Tf=struct2table(rmfield(forward,'FinalState')); Tr=struct2table(rmfield(reverse,'FinalState'));
writetable(Tf,fullfile(outDir,'exp06_continuation_forward.csv'));
writetable(Tr,fullfile(outDir,'exp06_continuation_reverse.csv'));
pathT=path_difference_table(Tf,Tr);
writetable(pathT,fullfile(outDir,'exp06_forward_reverse_path_difference.csv'));

hopfRows=struct([]); robustRows=struct([]); representative=[];
for k=1:height(Tf)-1
    if isfinite(Tf.DominantComplexReal(k)) && isfinite(Tf.DominantComplexReal(k+1)) && ...
            Tf.DominantComplexReal(k)*Tf.DominantComplexReal(k+1)<=0 && ...
            min([Tf.DominantComplexImag(k),Tf.DominantComplexImag(k+1)])>1e-4
        diag=hopf_diagnostic(Tf.Rho(k),Tf.Rho(k+1),forward(k).FinalState,p,mode,opt);
        hopfRows=aigc.append_struct_row(hopfRows,diag);
        [rr,rep]=horizon_window_checks(diag.RhoMid,diag.EquilibriumState,p,mode,opt);
        for q=1:numel(rr), robustRows=aigc.append_struct_row(robustRows,rr(q)); end
        if isempty(representative), representative=rep; end
    end
end
if isempty(hopfRows)
    Th=table(NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,NaN,false,false,NaN,false,false,false, ...
        'VariableNames',{'RhoLeft','RhoRight','RhoMid','ComplexRealLeft','ComplexRealRight', ...
        'ComplexImagLeft','ComplexImagMid','ComplexImagRight','Transversality', ...
        'MinEigenvectorOverlap','MaxPairEigenvalueStep','PairContinuous','OtherModesStable', ...
        'ClipSafetyMargin','ClipSafe','SimpleComplexPair','HopfCandidate'});
else
    Th=aigc.struct_rows_to_table(rmfield(hopfRows,'EquilibriumState'));
end
writetable(Th,fullfile(outDir,'exp06_spectral_crossing_candidates.csv'));
if isempty(robustRows)
    Trob=table(NaN,NaN,NaN,{''},false,NaN,NaN,NaN,NaN,'VariableNames', ...
        {'Rho','Horizon','TailFraction','Classification','Resolved','AmpI', ...
        'Period','PeriodCV','ClipSafetyMargin'});
else
    Trob=aigc.struct_rows_to_table(robustRows);
end
writetable(Trob,fullfile(outDir,'exp06_horizon_tail_window_robustness.csv'));

fig=figure('Visible','off','Color','w','Position',[50 50 1400 900]);
subplot(2,2,1); imagesc(gainGrid,speedGrid,classCode); axis xy; caxis([0.5 4.5]);
cb=colorbar; cb.Ticks=1:4;
cb.TickLabels={'equilibrium','certified cycle','unresolved','boundary/non-smooth'};
xlabel('Feedback gain scale'); ylabel('Audit speed'); title('Long-run classification');
subplot(2,2,2); yyaxis left;
plot(Tf.Rho,Tf.DominantComplexReal,'-o','LineWidth',1.0); hold on; yline(0,'k--');
ylabel('Real part of dominant complex pair');
yyaxis right; plot(Tf.Rho,Tf.DominantComplexImag,'-^','LineWidth',1.0); hold on;
plot(Tf.Rho,Tf.ClipSafetyMargin,'-s','LineWidth',1.0);
yline(opt.tauClip,'r--'); ylabel('Imaginary part / clip safety margin');
xlabel('Continuation scale'); legend({'Complex-pair real part','Zero line', ...
    'Complex-pair imaginary part','Clip safety margin','Clip threshold'},'Location','best'); grid on;
subplot(2,2,3);
if ~isempty(representative)
    plot(representative.tLeft,representative.ILeft,'LineWidth',1.1); hold on;
    plot(representative.tRight,representative.IRight,'LineWidth',1.1);
    legend({'Left of crossing','Right of crossing'},'Location','best');
    xlabel('Time'); ylabel('Risk I'); grid on;
else
    text(0.1,0.5,'No complex-pair crossing candidate found'); axis off;
end
title('Time-domain trajectories around first candidate');
subplot(2,2,4); plot_robustness(Trob);
aigc.save_figure(fig,fullfile(outDir,'fig_exp06_dynamic_instability')); close(fig);
end

function pp=scaled_parameters(p,speed,gain)
pp=p; pp.auditSpeed=speed; pp.etaI=p.etaI*gain; pp.etaT=p.etaT*gain; pp.etaA=p.etaA*gain;
end

function pp=continuation_parameters(p,rho)
pp=p; pp.auditSpeed=p.auditSpeed*rho; pp.etaI=p.etaI*rho;
pp.etaT=p.etaT*rho; pp.etaA=p.etaA*rho;
end

function Xp=perturb_equilibrium(X,mode)
Xp=X(:); active=find(mode.activeMask(:));
if ~isempty(active), Xp(active)=aigc.clip01(Xp(active)+1e-3*sin((1:numel(active))')); end
end

function eq=retry_equilibrium(sol,p,mode,opt)
eq=aigc.find_equilibrium(sol.finalState,p,mode,opt);
if eq.success, return; end
tStart=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1)); idx=find(sol.t>=tStart);
if isempty(idx), return; end
seed=aigc.time_average(sol.t(idx),sol.X(idx,:))';
eq=aigc.find_equilibrium(seed,p,mode,opt);
end

function label=resolve_label(eq,ss,opt)
if eq.success && eq.clipSafetyMargin<=opt.tauClip
    label='boundary_nonsmooth_candidate';
elseif strcmp(ss.dynamics,'stable_cycle')
    label='stable_cycle';
elseif eq.success && eq.spectralAbscissa < -opt.spectralTolerance
    if eq.internal, label='interior_equilibrium'; else, label='boundary_equilibrium'; end
else
    label=ss.dynamics;
end
end

function rows=continuation(rho,p,optLong,mode,Xstart,direction,maxT,optClass)
template=struct('Direction','','Rho',NaN,'Dynamics','','AmpI',NaN,'Period',NaN, ...
    'PeriodCV',NaN,'MeanI',NaN,'MeanT',NaN,'TailStable',false, ...
    'EquilibriumFound',false,'EquilibriumResidual',NaN,'SpectralAbscissa',NaN, ...
    'DominantComplexReal',NaN,'DominantComplexImag',NaN,'OtherSpectralAbscissa',NaN, ...
    'ClipSafetyMargin',NaN,'FinalState',nan(10,1));
rows=repmat(template,numel(rho),1); X=Xstart(:); eqSeed=X;
for k=1:numel(rho)
    pp=continuation_parameters(p,rho(k));
    eq=aigc.find_equilibrium(eqSeed,pp,mode,optClass);
    [sol,~]=aigc.solve_adaptive_longrun(X,pp,mode,optLong,maxT);
    ss=aigc.summarize_solution(sol,pp,mode,optClass);
    if ~eq.success, eq=retry_equilibrium(sol,pp,mode,optClass); end
    if eq.success, eqSeed=eq.X; end
    rows(k).Direction=direction; rows(k).Rho=rho(k); rows(k).Dynamics=resolve_label(eq,ss,optClass);
    rows(k).AmpI=ss.ampI; rows(k).Period=ss.period; rows(k).PeriodCV=ss.periodCV;
    rows(k).MeanI=ss.I; rows(k).MeanT=ss.T; rows(k).TailStable=ss.tailStable;
    rows(k).EquilibriumFound=eq.success; rows(k).EquilibriumResidual=eq.residual;
    rows(k).SpectralAbscissa=eq.spectralAbscissa;
    rows(k).DominantComplexReal=eq.dominantComplexReal;
    rows(k).DominantComplexImag=eq.dominantComplexImag;
    rows(k).OtherSpectralAbscissa=eq.otherSpectralAbscissa;
    rows(k).ClipSafetyMargin=eq.clipSafetyMargin;
    rows(k).FinalState=sol.finalState; X=sol.finalState;
end
end

function row=hopf_diagnostic(left,right,seed,p,mode,opt)
mid=0.5*(left+right); h=max(1e-4,0.25*(right-left));
rhoL=mid-h; rhoR=mid+h;
eqL=aigc.find_equilibrium(seed,continuation_parameters(p,rhoL),mode,opt);
eqM=aigc.find_equilibrium(eqL.X,continuation_parameters(p,mid),mode,opt);
eqR=aigc.find_equilibrium(eqM.X,continuation_parameters(p,rhoR),mode,opt);
row=struct(); row.RhoLeft=left; row.RhoRight=right; row.RhoMid=mid;
row.ComplexRealLeft=eqL.dominantComplexReal; row.ComplexRealRight=eqR.dominantComplexReal;
row.ComplexImagLeft=eqL.dominantComplexImag; row.ComplexImagMid=eqM.dominantComplexImag;
row.ComplexImagRight=eqR.dominantComplexImag;
row.Transversality=(eqR.dominantComplexReal-eqL.dominantComplexReal)/(rhoR-rhoL);
scale=max([eqL.dominantComplexImag,eqR.dominantComplexImag,1e-6]);
overlapLM=eigenvector_overlap(eqL.dominantComplexVector,eqM.dominantComplexVector);
overlapMR=eigenvector_overlap(eqM.dominantComplexVector,eqR.dominantComplexVector);
row.MinEigenvectorOverlap=min(overlapLM,overlapMR);
lambdaStepLM=abs(eqM.dominantComplexEigenvalue-eqL.dominantComplexEigenvalue);
lambdaStepMR=abs(eqR.dominantComplexEigenvalue-eqM.dominantComplexEigenvalue);
row.MaxPairEigenvalueStep=max(lambdaStepLM,lambdaStepMR);
row.PairContinuous=eqL.success&&eqM.success&&eqR.success&& ...
    abs(eqR.dominantComplexImag-eqL.dominantComplexImag)<=0.25*scale&& ...
    row.MinEigenvectorOverlap>=0.80;
row.OtherModesStable=max([eqL.otherSpectralAbscissa,eqM.otherSpectralAbscissa,eqR.otherSpectralAbscissa])<-opt.spectralTolerance;
row.ClipSafetyMargin=min([eqL.clipSafetyMargin,eqM.clipSafetyMargin,eqR.clipSafetyMargin]);
row.ClipSafe=row.ClipSafetyMargin>opt.tauClip;
row.SimpleComplexPair=row.OtherModesStable;
row.HopfCandidate=eqL.success&&eqM.success&&eqR.success&&row.PairContinuous&& ...
    row.OtherModesStable&&row.ClipSafe&&abs(row.Transversality)>opt.spectralTolerance&& ...
    eqL.dominantComplexReal*eqR.dominantComplexReal<=0;
row.EquilibriumState=eqM.X;
end

function value=eigenvector_overlap(v1,v2)
if isempty(v1) || isempty(v2) || numel(v1)~=numel(v2)
    value=NaN; return;
end
den=max(norm(v1)*norm(v2),eps);
% The absolute inner product is phase invariant.  The conjugated comparison
% also makes the diagnostic insensitive to which member of the pair is
% returned by the eigensolver.
value=max(abs(v1'*v2),abs(v1'*conj(v2)))/den;
value=min(max(real(value),0),1);
end

function [rows,rep]=horizon_window_checks(rho,Xeq,p,mode,opt)
pp=continuation_parameters(p,rho); horizons=opt.longRunSchedule; fractions=opt.tailFractions;
rows=struct([]); rep=struct();
for h=1:numel(horizons)
    oo=opt; oo.t0=0; oo.tEnd=horizons(h); oo.allowEarlyStop=false;
    sol=aigc.solve_model(perturb_equilibrium(Xeq,mode),pp,mode,oo);
    for f=1:numel(fractions)
        of=oo; of.tailFraction=fractions(f); c=aigc.classify_dynamics(sol,pp,mode,of);
        row=struct(); row.Rho=rho; row.Horizon=horizons(h); row.TailFraction=fractions(f);
        row.Classification=c.label; row.Resolved=aigc.is_resolved_label(c.label);
        row.AmpI=c.ampI; row.Period=c.period; row.PeriodCV=c.periodCV;
        row.ClipSafetyMargin=c.clipSafetyMargin;
        rows=aigc.append_struct_row(rows,row);
    end
end
halfStep=max(1e-3,0.02*rho);
ppL=continuation_parameters(p,max(rho-halfStep,eps));
ppR=continuation_parameters(p,rho+halfStep);
oo=opt; oo.t0=0; oo.tEnd=opt.longRunSchedule(end); oo.allowEarlyStop=false;
sL=aigc.solve_model(perturb_equilibrium(Xeq,mode),ppL,mode,oo);
sR=aigc.solve_model(perturb_equilibrium(Xeq,mode),ppR,mode,oo);
rep.tLeft=sL.t; rep.ILeft=sL.X(:,4); rep.tRight=sR.t; rep.IRight=sR.X(:,4);
end

function T=path_difference_table(Tf,Tr)
[common,ia,ib]=intersect(Tf.Rho,Tr.Rho); rows=struct([]);
for k=1:numel(common)
    row=struct(); row.Rho=common(k); row.AmpDifference=Tf.AmpI(ia(k))-Tr.AmpI(ib(k));
    row.MeanIDifference=Tf.MeanI(ia(k))-Tr.MeanI(ib(k));
    row.ForwardClass=char(string(Tf.Dynamics(ia(k))));
    row.ReverseClass=char(string(Tr.Dynamics(ib(k))));
    row.PossiblePathDependence=abs(row.AmpDifference)>0.02 || abs(row.MeanIDifference)>0.02;
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function write_class_counts(T,path)
labels={'equilibrium','certified_cycle','unresolved','boundary_nonsmooth'};
counts=[sum(contains(T.Dynamics,'equilibrium')&~contains(T.Dynamics,'boundary')), ...
    sum(strcmp(T.Dynamics,'stable_cycle')),sum(contains(T.Dynamics,'unresolved')), ...
    sum(contains(T.Dynamics,'boundary'))]';
writetable(table(labels',counts,'VariableNames',{'Class','Count'}),path);
end

function plot_robustness(T)
if isempty(T) || all(~isfinite(T.Horizon)), text(0.1,0.5,'No candidate robustness runs'); axis off; return; end
h=unique(T.Horizon); counts=zeros(numel(h),4);
for i=1:numel(h)
    S=T(T.Horizon==h(i)&abs(T.TailFraction-0.25)<1e-12,:);
    counts(i,:)=[sum(contains(S.Classification,'equilibrium')&~contains(S.Classification,'boundary')), ...
        sum(strcmp(S.Classification,'stable_cycle')),sum(contains(S.Classification,'unresolved')), ...
        sum(contains(S.Classification,'boundary'))];
end
bar(categorical(string(h)),counts,'stacked'); xlabel('Horizon'); ylabel('Candidate count');
legend({'equilibrium','cycle','unresolved','boundary/non-smooth'},'Location','best'); grid on;
title('Horizon robustness at 25% tail');
end

function c=class_to_code(label)
if contains(label,'interior_equilibrium'), c=1;
elseif strcmp(label,'stable_cycle'), c=2;
elseif contains(label,'boundary'), c=4;
else, c=3;
end
end
