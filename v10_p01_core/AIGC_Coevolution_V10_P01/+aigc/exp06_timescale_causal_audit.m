function exp06_timescale_causal_audit(p,opt,settings,outputRoot)
%EXP06_TIMESCALE_CAUSAL_AUDIT
% P0.1 review-closure experiment for Exp06.
%
% Core principle:
%   1) trace ONE FULL equilibrium branch X*_FULL(rho);
%   2) evaluate FULL/A-fast/L-fast/M-fast/ALL-fast Jacobians on exactly the
%      SAME X*_FULL(rho) states;
%   3) refine every spectral crossing by solving ONLY the FULL equilibrium
%      at the refined rho and then evaluating the variant Jacobian there.
%
% Therefore the comparison changes only response speeds of A, L, M and
% cannot be contaminated by different equilibrium branches selected by
% independent variant-specific Newton continuation.

outDir=fullfile(outputRoot,'Exp06_timescale_causal_audit');
aigc.ensure_dir(outDir);
modeBase=aigc.full_mode();
optLong=opt; optLong.allowEarlyStop=false; optLong.solver='ode45';

rhoGrid=linspace(0.25,1.60,max(21,settings.phaseN));
V=settings.exp06TimeScaleVariants;
names=settings.exp06TimeScaleNames;

% =============================================================
% A. Trace the FULL equilibrium branch ONCE.
% =============================================================
[TfullBranch,fullStates]=shared_full_equilibrium_path( ...
    rhoGrid,p,modeBase,opt,optLong,settings.phaseMaxTime);
writetable(TfullBranch,fullfile(outDir,'exp06_shared_full_equilibrium_branch.csv'));

% =============================================================
% B. Evaluate every time-scale variant on the shared FULL branch.
% =============================================================
pathRows=struct([]); critRows=struct([]); sharedAuditRows=struct([]);
for iv=1:numel(names)
    mode=with_timescales(modeBase,V(iv,1),V(iv,2),V(iv,3));
    Tpath=spectral_path_on_shared_branch(rhoGrid,TfullBranch,fullStates,p,mode,opt,names{iv});
    pathRows=append_table_rows(pathRows,Tpath);

    for iq=1:height(Tpath)
        r=struct();
        r.Variant=names{iv}; r.kA=V(iv,1); r.kL=V(iv,2); r.kM=V(iv,3);
        r.Rho=Tpath.Rho(iq); r.FullEquilibriumFound=Tpath.FullEquilibriumFound(iq);
        r.SharedStateResidual=Tpath.SharedStateResidual(iq);
        r.Pass=Tpath.FullEquilibriumFound(iq) && ...
            isfinite(Tpath.SharedStateResidual(iq)) && ...
            Tpath.SharedStateResidual(iq)<=settings.exp06SharedResidualTol;
        sharedAuditRows=aigc.append_struct_row(sharedAuditRows,r);
    end

    crit=critical_from_shared_path(Tpath,fullStates,p,modeBase,mode,opt,optLong,settings);
    crit.Variant=names{iv}; crit.kA=V(iv,1); crit.kL=V(iv,2); crit.kM=V(iv,3);
    critRows=aigc.append_struct_row(critRows,crit);
    fprintf('Exp06 shared-branch path %s completed. qCrit=%g, status=%s\n', ...
        names{iv},crit.RhoCrit,crit.ScanStatus);
end
TpathAll=aigc.struct_rows_to_table(pathRows);
Tcrit=aigc.struct_rows_to_table(critRows);
Tshared=aigc.struct_rows_to_table(sharedAuditRows);
idxFull=find(strcmp(string(Tcrit.Variant),'FULL'),1);
if isempty(idxFull), rhoBase=NaN; else, rhoBase=Tcrit.RhoCrit(idxFull); end
Tcrit.DeltaRhoCrit=Tcrit.RhoCrit-rhoBase;
writetable(TpathAll,fullfile(outDir,'exp06_timescale_path_spectrum.csv'));
writetable(Tcrit,fullfile(outDir,'exp06_critical_shift_summary.csv'));
writetable(Tshared,fullfile(outDir,'exp06_shared_equilibrium_branch_audit.csv'));

% Backward-compatible summary file: now it audits the entire shared branch.
Teq=shared_equilibrium_summary(Tshared,names,V);
writetable(Teq,fullfile(outDir,'exp06_equilibrium_preservation_audit.csv'));

% =============================================================
% C. Time-domain validation around each shared-branch crossing.
%    Deltas are deliberately farther from the spectral zero than PREVIEW
%    P0.0, reducing extremely slow near-critical transients.
% =============================================================
if isfield(settings,'exp06CriticalDeltas')
    criticalDeltas=settings.exp06CriticalDeltas;
else
    criticalDeltas=settings.exp06CriticalDelta;
end
valRows=struct([]); representative=struct([]);
for iv=1:numel(names)
    crit=Tcrit.RhoCrit(iv);
    if ~isfinite(crit), continue; end
    mode=with_timescales(modeBase,V(iv,1),V(iv,2),V(iv,3));
    for id=1:numel(criticalDeltas)
        delta=criticalDeltas(id);
        for side=[-1 1]
            rho=min(max(crit+side*delta,rhoGrid(1)),rhoGrid(end));
            pp=continuation_parameters(p,rho);
            seed=nearest_state_from_branch(TfullBranch,fullStates,rho,opt.X0);
            eqFull=equilibrium_with_retry(seed,pp,modeBase,opt,optLong,settings.phaseMaxTime);
            if eqFull.success
                metric=shared_state_spectral_metrics(eqFull.X,pp,mode,opt);
                X0=perturb_equilibrium(eqFull.X,mode);
            else
                metric=empty_metric();
                X0=seed;
            end

            [sol,cert]=aigc.solve_adaptive_longrun(X0,pp,mode,optLong,settings.phaseMaxTime);
            ss=aigc.summarize_solution(sol,pp,mode,opt);
            row=struct();
            row.Variant=names{iv}; row.kA=V(iv,1); row.kL=V(iv,2); row.kM=V(iv,3);
            row.Delta=delta; row.Side=side; row.Rho=rho; row.Classification=ss.dynamics;
            row.Resolved=aigc.is_resolved_label(ss.dynamics); row.AmpI=ss.ampI;
            row.MeanI=ss.I; row.MeanT=ss.T; row.Period=ss.period; row.PeriodCV=ss.periodCV;
            row.AmplitudeDrift=ss.amplitudeDrift; row.TailStable=ss.tailStable;
            row.FinalTime=cert.finalTime; row.FullEquilibriumFound=eqFull.success;
            if eqFull.success, row.FullEquilibriumResidual=eqFull.residual; else, row.FullEquilibriumResidual=Inf; end
            row.SharedStateResidual=metric.residual; row.SpectralAbscissa=metric.spectralAbscissa;
            row.DominantComplexReal=metric.dominantComplexReal; row.DominantComplexImag=metric.dominantComplexImag;
            row.OtherSpectralAbscissa=metric.otherSpectralAbscissa; row.ClipSafetyMargin=metric.clipSafetyMargin;
            valRows=aigc.append_struct_row(valRows,row);

            if side>0 && strcmp(ss.dynamics,'stable_cycle') && ...
                    (strcmp(names{iv},'FULL') || strcmp(names{iv},'ALL_fast'))
                rep=struct(); rep.Variant=names{iv}; rep.Delta=delta; rep.sol=sol;
                rep.pp=pp; rep.mode=mode; rep.ss=ss;
                representative=aigc.append_struct_row(representative,rep);
            end
        end
    end
end
if isempty(valRows), Tval=table(); else, Tval=aigc.struct_rows_to_table(valRows); end
writetable(Tval,fullfile(outDir,'exp06_time_domain_validation.csv'));

% =============================================================
% D. Joint time-scale gradient on the SAME FULL equilibrium branch.
% =============================================================
gradRows=struct([]);
for k=settings.exp06JointTimeScaleGrid
    mode=with_timescales(modeBase,k,k,k);
    Tg=spectral_path_on_shared_branch(rhoGrid,TfullBranch,fullStates,p,mode,opt,sprintf('joint_%g',k));
    cg=critical_from_shared_path(Tg,fullStates,p,modeBase,mode,opt,optLong,settings);
    row=struct(); row.JointScale=k; row.RhoCrit=cg.RhoCrit; row.CrossingFound=cg.CrossingFound;
    row.ScanStatus=cg.ScanStatus; row.MinComplexReal=cg.MinComplexReal; row.MaxComplexReal=cg.MaxComplexReal;
    row.ComplexImagAtCrit=cg.ComplexImagAtCrit; row.CrossingSlope=cg.CrossingSlope;
    row.OtherModesStable=cg.OtherModesStable; row.ClipSafe=cg.ClipSafe;
    gradRows=aigc.append_struct_row(gradRows,row);
end
Tgrad=aigc.struct_rows_to_table(gradRows);
baseCrit=Tgrad.RhoCrit(find(Tgrad.JointScale==1,1));
if isempty(baseCrit) || ~isfinite(baseCrit), baseCrit=NaN; end
Tgrad.DeltaRhoCrit=Tgrad.RhoCrit-baseCrit;
writetable(Tgrad,fullfile(outDir,'exp06_joint_timescale_gradient.csv'));

% =============================================================
% E. Toolbox-free phase-lag audit for representative certified cycles.
% =============================================================
if settings.exp06PhaseLagEnabled
    Tlag=phase_lag_table(representative,opt);
else
    Tlag=table();
end
writetable(Tlag,fullfile(outDir,'exp06_phase_lag.csv'));

% =============================================================
% F. Automated quality gate.
% =============================================================
Tqc=quality_check(Tshared,Tcrit,Tval,Tgrad,settings);
writetable(Tqc,fullfile(outDir,'experiment_quality_check.csv'));

% =============================================================
% G. Evidence figure.
% =============================================================
plot_timescale_evidence(TpathAll,Tcrit,Tgrad,Tlag,outDir);
end

% =====================================================================
% Shared equilibrium branch utilities
% =====================================================================
function mode=with_timescales(mode,kA,kL,kM)
mode.timeScaleA=kA; mode.timeScaleL=kL; mode.timeScaleM=kM;
end

function pp=continuation_parameters(p,rho)
% EXACTLY mirrors the V10 Exp06 continuation path.
pp=p;
pp.auditSpeed=p.auditSpeed*rho;
pp.etaI=p.etaI*rho;
pp.etaT=p.etaT*rho;
pp.etaA=p.etaA*rho;
end

function [T,states]=shared_full_equilibrium_path(rhoGrid,p,modeBase,opt,optLong,maxT)
rows=struct([]); states=cell(numel(rhoGrid),1); seed=opt.X0;
for i=1:numel(rhoGrid)
    pp=continuation_parameters(p,rhoGrid(i));
    eq=equilibrium_with_retry(seed,pp,modeBase,opt,optLong,maxT);
    if eq.success
        seed=eq.X; states{i}=eq.X;
    else
        states{i}=[];
    end
    row=struct(); row.Rho=rhoGrid(i); row.AuditSpeed=pp.auditSpeed; row.EtaI=pp.etaI;
    row.EquilibriumFound=eq.success; row.EquilibriumResidual=eq.residual;
    row.SpectralAbscissa=eq.spectralAbscissa; row.DominantComplexReal=eq.dominantComplexReal;
    row.DominantComplexImag=eq.dominantComplexImag; row.OtherSpectralAbscissa=eq.otherSpectralAbscissa;
    row.ClipSafetyMargin=eq.clipSafetyMargin;
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function T=spectral_path_on_shared_branch(rhoGrid,Tfull,fullStates,p,mode,opt,variantName)
rows=struct([]);
for i=1:numel(rhoGrid)
    pp=continuation_parameters(p,rhoGrid(i));
    if Tfull.EquilibriumFound(i) && ~isempty(fullStates{i})
        m=shared_state_spectral_metrics(fullStates{i},pp,mode,opt);
    else
        m=empty_metric();
    end
    row=struct(); row.Variant=variantName; row.kA=mode.timeScaleA; row.kL=mode.timeScaleL; row.kM=mode.timeScaleM;
    row.Rho=rhoGrid(i); row.AuditSpeed=pp.auditSpeed; row.EtaI=pp.etaI;
    row.FullEquilibriumFound=Tfull.EquilibriumFound(i);
    row.FullEquilibriumResidual=Tfull.EquilibriumResidual(i);
    row.SharedStateResidual=m.residual;
    row.SpectralAbscissa=m.spectralAbscissa; row.DominantComplexReal=m.dominantComplexReal;
    row.DominantComplexImag=m.dominantComplexImag; row.OtherSpectralAbscissa=m.otherSpectralAbscissa;
    row.ClipSafetyMargin=m.clipSafetyMargin;
    rows=aigc.append_struct_row(rows,row);
end
T=aigc.struct_rows_to_table(rows);
end

function m=shared_state_spectral_metrics(Xeq,p,mode,opt)
m=empty_metric();
active=find(mode.activeMask(:));
if isempty(active)
    m.residual=0; m.spectralAbscissa=-Inf; m.otherSpectralAbscissa=-Inf;
    term=aigc.model_terms(0,Xeq,p,mode); m.clipSafetyMargin=term.clipSafetyMargin;
    return;
end
f=aigc.model_rhs(0,Xeq,p,mode);
m.residual=norm(f(active),inf);
term=aigc.model_terms(0,Xeq,p,mode); m.clipSafetyMargin=term.clipSafetyMargin;
J=aigc.numerical_jacobian(Xeq,p,mode,opt.fdStep);
ev=eig(J(active,active));
m.eigenvalues=ev;
if isempty(ev), return; end
m.spectralAbscissa=max(real(ev));
pos=find(imag(ev)>1e-7);
if ~isempty(pos)
    [~,jj]=max(real(ev(pos))); ip=pos(jj);
    m.dominantComplexReal=real(ev(ip));
    m.dominantComplexImag=abs(imag(ev(ip)));
    [~,ic]=min(abs(ev-conj(ev(ip))));
    keep=true(size(ev)); keep([ip ic])=false;
    if any(keep), m.otherSpectralAbscissa=max(real(ev(keep))); else, m.otherSpectralAbscissa=-Inf; end
end
end

function m=empty_metric()
m=struct(); m.residual=Inf; m.spectralAbscissa=NaN; m.dominantComplexReal=NaN;
m.dominantComplexImag=NaN; m.otherSpectralAbscissa=NaN; m.clipSafetyMargin=NaN; m.eigenvalues=[];
end

function eq=equilibrium_with_retry(seed,p,mode,opt,optLong,maxT)
eq=aigc.find_equilibrium(seed,p,mode,opt);
if eq.success, return; end
try
    [sol,~]=aigc.solve_adaptive_longrun(seed,p,mode,optLong,maxT);
    eq=aigc.find_equilibrium(sol.finalState,p,mode,opt);
    if eq.success, return; end
    t0=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1));
    idx=find(sol.t>=t0);
    if ~isempty(idx)
        tailSeed=aigc.time_average(sol.t(idx),sol.X(idx,:))';
        eq=aigc.find_equilibrium(tailSeed,p,mode,opt);
    end
catch
    % Caller records the failed FULL equilibrium point.
end
end

% =====================================================================
% Shared-branch crossing identification/refinement
% =====================================================================
function crit=critical_from_shared_path(T,fullStates,p,modeBase,modeVariant,opt,optLong,settings)
crit=empty_critical();
vals=T.DominantComplexReal;
crit.MinComplexReal=min(vals,[],'omitnan');
crit.MaxComplexReal=max(vals,[],'omitnan');
crit.ScanStatus=scan_status(vals,T.DominantComplexImag);
for i=1:height(T)-1
    a=T.DominantComplexReal(i); b=T.DominantComplexReal(i+1);
    imagOk=min(T.DominantComplexImag(i),T.DominantComplexImag(i+1))>1e-4;
    clipOk=min(T.ClipSafetyMargin(i),T.ClipSafetyMargin(i+1))>opt.tauClip;
    residualOk=max(T.SharedStateResidual(i),T.SharedStateResidual(i+1))<=settings.exp06SharedResidualTol;
    if isfinite(a) && isfinite(b) && a<=0 && b>=0 && imagOk && clipOk && residualOk
        left=T.Rho(i); right=T.Rho(i+1);
        seed=fullStates{i}; if isempty(seed), seed=opt.X0; end
        crit=refine_crossing_shared(left,right,seed,p,modeBase,modeVariant,opt,optLong,settings);
        crit.MinComplexReal=min(vals,[],'omitnan');
        crit.MaxComplexReal=max(vals,[],'omitnan');
        crit.ScanStatus='crossing_found';
        return;
    end
end
end

function status=scan_status(vals,imagVals)
finiteVals=vals(isfinite(vals));
if isempty(finiteVals)
    if any(isfinite(imagVals)), status='no_finite_complex_real'; else, status='no_complex_mode_over_scan'; end
elseif all(finiteVals<0)
    status='stable_over_scan';
elseif all(finiteVals>0)
    status='unstable_over_scan';
else
    status='no_qualified_crossing';
end
end

function c=empty_critical()
c=struct(); c.CrossingFound=false; c.RhoLeft=NaN; c.RhoRight=NaN; c.RhoCrit=NaN;
c.ComplexRealAtCrit=NaN; c.ComplexImagAtCrit=NaN; c.CrossingSlope=NaN;
c.OtherSpectralAbscissa=NaN; c.OtherModesStable=false; c.ClipSafetyMargin=NaN; c.ClipSafe=false;
c.EquilibriumResidual=NaN; c.SharedStateResidual=NaN;
c.MinComplexReal=NaN; c.MaxComplexReal=NaN; c.ScanStatus='not_evaluated';
end

function c=refine_crossing_shared(left,right,seed,p,modeBase,modeVariant,opt,optLong,settings)
c=empty_critical();
ppL=continuation_parameters(p,left);
eqL=equilibrium_with_retry(seed,ppL,modeBase,opt,optLong,settings.phaseMaxTime);
if ~eqL.success, return; end
mL=shared_state_spectral_metrics(eqL.X,ppL,modeVariant,opt);
ppR=continuation_parameters(p,right);
eqR=equilibrium_with_retry(eqL.X,ppR,modeBase,opt,optLong,settings.phaseMaxTime);
if ~eqR.success, return; end
mR=shared_state_spectral_metrics(eqR.X,ppR,modeVariant,opt);
fL=mL.dominantComplexReal; fR=mR.dominantComplexReal;
if ~(isfinite(fL)&&isfinite(fR)&&fL<=0&&fR>=0), return; end

rhoCrit=0.5*(left+right); eqCrit=eqL; mCrit=mL;
for it=1:60
    mid=0.5*(left+right); ppM=continuation_parameters(p,mid);
    eqM=equilibrium_with_retry(eqL.X,ppM,modeBase,opt,optLong,settings.phaseMaxTime);
    if ~eqM.success, break; end
    mM=shared_state_spectral_metrics(eqM.X,ppM,modeVariant,opt);
    fM=mM.dominantComplexReal;
    if ~isfinite(fM), break; end
    rhoCrit=mid; eqCrit=eqM; mCrit=mM;
    if abs(fM)<=settings.exp06SpectralZeroTol || (right-left)<=settings.exp06CriticalRhoTol
        break;
    end
    if fM>=0
        right=mid; eqR=eqM; mR=mM; fR=fM;
    else
        left=mid; eqL=eqM; mL=mM; fL=fM;
    end
end

% Centered finite-difference transversality, again using FULL equilibria.
h=max(settings.exp06CriticalRhoTol,0.5*(right-left));
rhoL=max(0.01,rhoCrit-h); rhoR=rhoCrit+h;
e1=equilibrium_with_retry(eqCrit.X,continuation_parameters(p,rhoL),modeBase,opt,optLong,settings.phaseMaxTime);
e2=equilibrium_with_retry(eqCrit.X,continuation_parameters(p,rhoR),modeBase,opt,optLong,settings.phaseMaxTime);
if e1.success && e2.success && rhoR>rhoL
    mm1=shared_state_spectral_metrics(e1.X,continuation_parameters(p,rhoL),modeVariant,opt);
    mm2=shared_state_spectral_metrics(e2.X,continuation_parameters(p,rhoR),modeVariant,opt);
    slope=(mm2.dominantComplexReal-mm1.dominantComplexReal)/(rhoR-rhoL);
else
    slope=NaN;
end

c.CrossingFound=true; c.RhoLeft=left; c.RhoRight=right; c.RhoCrit=rhoCrit;
c.ComplexRealAtCrit=mCrit.dominantComplexReal; c.ComplexImagAtCrit=mCrit.dominantComplexImag;
c.CrossingSlope=slope; c.OtherSpectralAbscissa=mCrit.otherSpectralAbscissa;
c.OtherModesStable=isfinite(mCrit.otherSpectralAbscissa) && mCrit.otherSpectralAbscissa < -opt.spectralTolerance;
c.ClipSafetyMargin=mCrit.clipSafetyMargin; c.ClipSafe=mCrit.clipSafetyMargin>opt.tauClip;
c.EquilibriumResidual=eqCrit.residual; c.SharedStateResidual=mCrit.residual;
c.ScanStatus='crossing_found';
end

% =====================================================================
% Shared-equilibrium audits and time-domain helpers
% =====================================================================
function Teq=shared_equilibrium_summary(Tshared,names,V)
rows=struct([]);
for iv=1:numel(names)
    idx=strcmp(string(Tshared.Variant),names{iv});
    row=struct(); row.Variant=names{iv}; row.kA=V(iv,1); row.kL=V(iv,2); row.kM=V(iv,3);
    if any(idx)
        row.Points=sum(idx); row.MaxSharedStateResidual=max(Tshared.SharedStateResidual(idx),[],'omitnan');
        row.Pass=all(Tshared.Pass(idx));
    else
        row.Points=0; row.MaxSharedStateResidual=Inf; row.Pass=false;
    end
    rows=aigc.append_struct_row(rows,row);
end
Teq=aigc.struct_rows_to_table(rows);
end

function X=nearest_state_from_branch(T,states,rho,fallback)
[~,i]=min(abs(T.Rho-rho)); X=states{i}; if isempty(X), X=fallback; end
end

function Xp=perturb_equilibrium(X,mode)
Xp=X(:); active=find(mode.activeMask(:));
if ~isempty(active), Xp(active)=aigc.clip01(Xp(active)+1e-3*sin((1:numel(active))')); end
end

function rows=append_table_rows(rows,T)
for i=1:height(T)
    rows=aigc.append_struct_row(rows,table2struct(T(i,:)));
end
end

% =====================================================================
% Phase-lag utilities
% =====================================================================
function T=phase_lag_table(reps,opt)
rows=struct([]);
for i=1:numel(reps)
    sol=reps(i).sol; ev=aigc.evaluate_solution(sol,reps(i).pp,reps(i).mode);
    t0=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1)); idx=find(sol.t>=t0);
    if numel(idx)<20, continue; end
    t=sol.t(idx); u=ev.uEff(idx); A=ev.A(idx); L=ev.L(idx); M=sol.X(idx,6);
    dt=median(diff(t)); periodGuess=reps(i).ss.period;
    if ~isfinite(periodGuess) || periodGuess<=0, periodGuess=10; end
    maxLag=min(floor(numel(idx)/4),max(5,round(periodGuess/max(dt,eps))));
    row=struct(); row.Variant=reps(i).Variant; row.Delta=reps(i).Delta; row.Label=sprintf('%s_d%.2f',reps(i).Variant,reps(i).Delta); row.Period=reps(i).ss.period;
    row.Lag_u_A=best_lag(u,A,dt,maxLag); row.Lag_u_L=best_lag(u,L,dt,maxLag);
    row.Lag_u_M=best_lag(u,M,dt,maxLag); row.AbsLagSum=abs(row.Lag_u_A)+abs(row.Lag_u_L)+abs(row.Lag_u_M);
    rows=aigc.append_struct_row(rows,row);
end
if isempty(rows), T=table(); else, T=aigc.struct_rows_to_table(rows); end
end

function lagTime=best_lag(a,b,dt,maxLag)
a=a(:); b=b(:); a=a-mean(a); b=b-mean(b);
sa=std(a); sb=std(b); if sa<eps || sb<eps, lagTime=NaN; return; end
a=a/sa; b=b/sb; best=-Inf; bestLag=0;
for lag=-maxLag:maxLag
    if lag>=0
        if lag>=numel(a), continue; end
        aa=a(1:end-lag); bb=b(1+lag:end);
    else
        q=-lag; if q>=numel(a), continue; end
        aa=a(1+q:end); bb=b(1:end-q);
    end
    if numel(aa)<8, continue; end
    cc=sum(aa.*bb)/numel(aa);
    if cc>best, best=cc; bestLag=lag; end
end
lagTime=bestLag*dt;
end

% =====================================================================
% Quality gate and plotting
% =====================================================================
function Tqc=quality_check(Tshared,Tcrit,Tval,Tgrad,settings)
rows=struct([]);
sharedPass=~isempty(Tshared) && all(Tshared.Pass);
rows=qc_row(rows,'All variants evaluated on one shared FULL equilibrium branch',sharedPass, ...
    max_or_nan(Tshared,'SharedStateResidual'),settings.exp06SharedResidualTol,'max variant residual at shared FULL equilibria');
rows=qc_row(rows,'FULL spectral crossing found',row_pass(Tcrit,'Variant','FULL','CrossingFound'),NaN,NaN,'shared-branch spectral test');
rows=qc_row(rows,'ALL-fast shared spectral path evaluated',any(strcmp(string(Tcrit.Variant),'ALL_fast')),NaN,NaN,'');
if ~isempty(Tval)
    isFull=strcmp(string(Tval.Variant),'FULL');
    pre=isFull & Tval.Side<0; post=isFull & Tval.Side>0;
    prePass=any(pre & contains(string(Tval.Classification),'equilibrium'));
    postPass=any(post & strcmp(string(Tval.Classification),'stable_cycle'));
else
    prePass=false; postPass=false;
end
rows=qc_row(rows,'FULL precritical equilibrium certified',prePass,NaN,NaN,'time-domain cross-check');
rows=qc_row(rows,'FULL postcritical cycle certified',postPass,NaN,NaN,'time-domain cross-check');
rows=qc_row(rows,'Joint scale gradient completed',height(Tgrad)==numel(settings.exp06JointTimeScaleGrid), ...
    height(Tgrad),numel(settings.exp06JointTimeScaleGrid),'shared FULL equilibrium branch');
Tqc=aigc.struct_rows_to_table(rows);
end

function rows=qc_row(rows,name,pass,value,tol,note)
r=struct(); r.Check=name; r.Pass=logical(pass); r.Value=value; r.Tolerance=tol; r.Note=note;
rows=aigc.append_struct_row(rows,r);
end

function v=max_or_nan(T,field)
if isempty(T) || ~ismember(field,T.Properties.VariableNames), v=NaN; else, v=max(T.(field),[],'omitnan'); end
end

function pass=row_pass(T,keyField,keyValue,valueField)
pass=false; if isempty(T), return; end
idx=strcmp(string(T.(keyField)),keyValue); if any(idx), pass=any(T.(valueField)(idx)); end
end

function plot_timescale_evidence(Tpath,Tcrit,Tgrad,Tlag,outDir)
fig=figure('Visible','off','Color','w','Position',[50 50 1450 920]);
subplot(2,2,1); hold on;
names=unique(string(Tpath.Variant),'stable');
for i=1:numel(names)
    S=Tpath(string(Tpath.Variant)==names(i),:);
    plot(S.Rho,S.DominantComplexReal,'-','LineWidth',1.1);
end
yline(0,'k--'); xlabel('Continuation scale \rho'); ylabel('Dominant complex real part'); grid on;
legend(cellstr(names),'Location','best'); title('Shared-branch slow-state time-scale intervention');
subplot(2,2,2);
bar(categorical(string(Tcrit.Variant)),Tcrit.RhoCrit); ylabel('Critical \rho'); grid on; title('Shared-branch spectral crossing location');
subplot(2,2,3);
plot(Tgrad.JointScale,Tgrad.RhoCrit,'-o','LineWidth',1.2); xlabel('Joint speed multiplier k_A=k_L=k_M'); ylabel('Critical \rho'); grid on;
title('Joint time-scale gradient on shared branch');
subplot(2,2,4);
if isempty(Tlag)
    text(0.1,0.5,'No certified-cycle phase-lag record available'); axis off;
else
    bar(categorical(string(Tlag.Label)),[abs(Tlag.Lag_u_A),abs(Tlag.Lag_u_L),abs(Tlag.Lag_u_M)]);
    legend({'|lag(u,A)|','|lag(u,L)|','|lag(u,M)|'},'Location','best'); ylabel('Absolute lag'); grid on;
end
aigc.save_figure(fig,fullfile(outDir,'fig_exp06_timescale_causal_audit')); close(fig);
end
