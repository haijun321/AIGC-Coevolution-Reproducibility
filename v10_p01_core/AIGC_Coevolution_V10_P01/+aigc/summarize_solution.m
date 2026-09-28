function ss = summarize_solution(sol,p,mode,opt,res)
%SUMMARIZE_SOLUTION Time-weighted tail metrics and certified dynamics.
if nargin<5 || isempty(res), res=aigc.evaluate_solution(sol,p,mode); end
classOut=aigc.classify_dynamics(sol,p,mode,opt);
tStart=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1));
if strcmp(classOut.label,'stable_cycle') && isfinite(classOut.period) && classOut.period>0
    available=sol.t(end)-tStart;
    nWhole=max(opt.minCycles,floor(available/classOut.period));
    if nWhole*classOut.period<=sol.t(end)-sol.t(1)
        tStart=sol.t(end)-nWhole*classOut.period;
    end
end
idx=find(sol.t>=tStart); if numel(idx)<4, idx=max(1,size(sol.X,1)-3):size(sol.X,1); end
tt=sol.t(idx); mu=aigc.time_average(tt,sol.X(idx,:)); sd=aigc.time_std(tt,sol.X(idx,:));
ss.x=mu(1); ss.y=mu(2); ss.z=mu(3); ss.I=aigc.time_average(tt,res.I(idx));
ss.T=aigc.time_average(tt,res.T(idx)); ss.M=mu(6); ss.u=aigc.time_average(tt,res.uEff(idx));
ss.A=aigc.time_average(tt,res.A(idx)); ss.L=aigc.time_average(tt,res.L(idx));
ss.E=aigc.time_average(tt,res.E(idx)); ss.Q0=aigc.time_average(tt,res.Q0(idx));
ss.D=aigc.time_average(tt,res.D(idx)); ss.Qexp=aigc.time_average(tt,res.Qexp(idx));
ss.pAct=aigc.time_average(tt,res.pAct(idx)); ss.pDet=aigc.time_average(tt,res.pDet(idx));
ss.pHandle=aigc.time_average(tt,res.pHandle(idx)); ss.phiIn=aigc.time_average(tt,res.phiIn(idx));
ss.phiAct=aigc.time_average(tt,res.phiAct(idx)); ss.pIn=aigc.time_average(tt,res.pIn(idx));
ss.pSp=aigc.time_average(tt,res.pSp(idx)); ss.pRm=aigc.time_average(tt,res.pRm(idx));
ss.nuEff=aigc.time_average(tt,res.nuEff(idx)); ss.G=aigc.time_average(tt,res.G(idx));
ss.B=aigc.time_average(tt,res.B(idx)); ss.mE=aigc.time_average(tt,res.mE(idx)); ss.Ecal=aigc.time_average(tt,res.Ecal(idx));
ss.JI=ss.I; ss.JT=aigc.time_average(tt,max(p.Tstar-res.T(idx),0));
ss.JIFull=res.JI; ss.JTFull=res.JT; ss.JC=res.JC; ss.totalCost=res.totalCost;
ss.sdI=aigc.time_std(tt,res.I(idx)); ss.sdT=aigc.time_std(tt,res.T(idx));
ss.sdu=aigc.time_std(tt,res.uEff(idx)); ss.status=sol.status;
ss.dynamics=classOut.label; ss.period=classOut.period; ss.periodCV=classOut.periodCV;
ss.ampI=classOut.ampI; ss.residual=classOut.residual; ss.nPeaks=classOut.nPeaks;
ss.amplitudeDrift=classOut.amplitudeDrift;
ss.clipSafetyMargin=classOut.clipSafetyMargin;
stab=aigc.tail_stability(sol,p,mode,opt,res);
ss.tailStable=stab.stable; ss.tailMeanDrift=stab.maxMeanDrift; ss.tailAmplitudeDrift=stab.ampDrift;
ss.spectralAbscissa=NaN; ss.dominantImag=NaN;
if contains(classOut.label,'equilibrium')
    J=aigc.numerical_jacobian(sol.finalState,p,mode,opt.fdStep);
    ev=eig(J(logical(mode.activeMask),logical(mode.activeMask)));
    if ~isempty(ev), [~,ii]=max(real(ev)); ss.spectralAbscissa=real(ev(ii)); ss.dominantImag=imag(ev(ii)); end
end
ss.tailStateSD=mean(sd);
tw=aigc.tail_window_diagnostics(sol,p,mode,opt,res);
ss.tailWindowMeanSpreadI=tw.meanSpreadI; ss.tailWindowMeanSpreadT=tw.meanSpreadT;
ss.tailWindowAmpSpreadI=tw.ampSpreadI; ss.tailWindowAmpSpreadT=tw.ampSpreadT;
ss.tailWindowClassRobust=tw.classRobust;
for k=1:numel(tw.fractions)
    tag=sprintf('%02d',round(100*tw.fractions(k)));
    ss.(['I' tag])=tw.meanI(k); ss.(['T' tag])=tw.meanT(k);
    ss.(['AmpI' tag])=tw.ampI(k); ss.(['Class' tag])=char(tw.classification(k));
end
end
