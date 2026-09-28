function ref = semantic_reference_terms(t,X,p,mode)
%SEMANTIC_REFERENCE_TERMS Independent transcription of manuscript algebra.
% This function intentionally does not call model_terms. Exp00 compares the
% two implementations to catch code-manuscript semantic drift.
X=min(max(X(:),0),1);
[pp,mm]=aigc.apply_time_shock(t,p,mode);
x=X(1); y=X(2); z=X(3); Istate=X(4); Tstate=X(5); Astate=X(8); Lstate=X(9); Estate=X(10);
if mm.exogenousI || ~mm.enableInformation, I=pp.Iref; else, I=Istate; end
if mm.exogenousT || ~mm.enableTrust, T=pp.Tref; else, T=Tstate; end
if mm.fixedE, E=min(max(mm.fixedEValue,0),1);
elseif mm.exogenousE || ~mm.useAIGC, E=pp.Eref*double(mm.useAIGC);
else, E=Estate; end
if mm.fixedAudit, uEff=mm.fixedAuditIntensity; else, uEff=X(7); end
yEff=y*uEff;
eDraw=pp.eD0; eLraw=pp.eL0;
if mm.endogenousEvasion
    eDraw=eDraw+pp.rhoAuditD*yEff+pp.omegaEvasionE*E-pp.rhoPenalty*pp.FP;
    eLraw=eLraw+pp.rhoAuditL*yEff+0.5*pp.omegaEvasionE*E-pp.rhoPenalty*pp.FP;
end
eD=min(max(eDraw,0),pp.eMax); eL=min(max(eLraw,0),pp.eMax);
pDet=min(max(pp.s*(1-eD),0),1); if mm.idealGovernance, pDet=1; end
aDet=pp.kDetect*pDet*I;
if mm.exogenousA, A=pp.Aref;
elseif mm.useAState, A=Astate;
else
    A=pp.Aref;
    for it=1:30
        rTmp=yEff*pp.kAction*pp.h/(1+pp.omegaA*A);
        nextA=aDet/(aDet+rTmp+pp.deltaA+eps);
        if abs(nextA-A)<1e-12, break; end
        A=min(max(nextA,0),1);
    end
end
hEff=pp.h/(1+pp.omegaA*A); rAct=yEff*pp.kAction*hEff;
phiIn=aDet*(1-A); phiAct=rAct*A;
switch lower(mm.handleProbabilityForm)
    case 'exponential', pHandle=1-exp(-max(rAct,0)*pp.handleWindow);
    case 'rational', q=max(rAct,0)*pp.handleWindow; pHandle=q/(1+q);
    otherwise, error('Unknown handle-probability form.');
end
pAct=min(max(pDet*pHandle,0),1);
if mm.idealGovernance, pHandle=1; pAct=1; end
pIn=reference_stage_probability(pAct,pp.kappaIn,mm.stageProbabilityForm);
pSp=reference_stage_probability(pAct,pp.kappaSp,mm.stageProbabilityForm);
pRm=reference_stage_probability(pAct,pp.kappaRm,mm.stageProbabilityForm);
if mm.idealGovernance, pIn=1; pSp=1; pRm=1; end
ellIn=pp.kLabel*pp.c*(1-eL)*yEff; ellOut=pp.deltaLabel*(1-pp.r)+pp.deltaCross*I;
if mm.exogenousL, L=pp.Lref;
elseif mm.useLState, L=Lstate;
else, L=ellIn/(ellIn+ellOut+eps); end
nuEff=min(max(pp.nu0+pp.nu1*pp.chi*L,0),1);
Q0=x*pp.qC+(1-x)*pp.qS;
DV=I*(1-nuEff); DD=I; D=z*DV+(1-z)*DD; Qexp=Q0*(1-D);
if mm.informationFeedback, Ipay=I; else, Ipay=pp.Iref; end
if mm.trustFeedback, Tpay=T; else, Tpay=pp.Tref; end
DVpay=Ipay*(1-nuEff); DDpay=Ipay;
piUV=pp.BU+Tpay*Q0-pp.CV-DVpay*pp.LU;
piUD=pp.BU+Tpay*Q0-DDpay*pp.LU+pp.BD;
deltaPiU=Ipay*nuEff*pp.LU-pp.CV-pp.BD;
ref=struct('aDet',aDet,'phiIn',phiIn,'phiAct',phiAct,'pHandle',pHandle, ...
    'pAct',pAct,'pIn',pIn,'pSp',pSp,'pRm',pRm,'Q0',Q0,'DV',DV,'DD',DD, ...
    'D',D,'Qexp',Qexp,'piUV',piUV,'piUD',piUD,'deltaPiU',deltaPiU);
end

function value=reference_stage_probability(pAct,kappa,form)
q=max(kappa,0)*min(max(pAct,0),1);
switch lower(form)
    case 'linear', value=min(max(q,0),1);
    case 'exponential', value=1-exp(-q);
    case 'rational', value=q/(1+q);
    otherwise, error('Unknown stage-probability form.');
end
end
