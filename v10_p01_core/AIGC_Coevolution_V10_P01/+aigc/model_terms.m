function out = model_terms(t,X,p,mode)
%MODEL_TERMS Single authoritative implementation of the V10 equations.
X = aigc.clip01(X(:));
[pNow,modeNow] = aigc.apply_time_shock(t,p,mode);

x=X(1); y=X(2); z=X(3); Istate=X(4); Tstate=X(5); M=X(6);
uState=X(7); Astate=X(8); Lstate=X(9); Estate=X(10);

% Experiment-only time-scale multipliers (Exp06).  They default to one,
% so all pre-existing experiments are unchanged.
kTimeA = mode_scale(modeNow,'timeScaleA');
kTimeL = mode_scale(modeNow,'timeScaleL');
kTimeM = mode_scale(modeNow,'timeScaleM');

if modeNow.exogenousI || ~modeNow.enableInformation, I = pNow.Iref; else, I = Istate; end
if modeNow.exogenousT || ~modeNow.enableTrust, T = pNow.Tref; else, T = Tstate; end
if modeNow.fixedE
    E = min(max(modeNow.fixedEValue,0),1);
elseif modeNow.exogenousE || ~modeNow.useAIGC
    E = pNow.Eref*(modeNow.useAIGC);
else
    E = Estate;
end

if modeNow.fixedAudit
    uEff = modeNow.fixedAuditIntensity;
else
    uEff = uState;
end
yEff = y*uEff;

% Endogenous evasion.
eDraw = pNow.eD0;
eLraw = pNow.eL0;
if modeNow.endogenousEvasion
    eDraw = eDraw + pNow.rhoAuditD*yEff + pNow.omegaEvasionE*E - pNow.rhoPenalty*pNow.FP;
    eLraw = eLraw + pNow.rhoAuditL*yEff + 0.50*pNow.omegaEvasionE*E - pNow.rhoPenalty*pNow.FP;
end
eD = min(max(eDraw,0),pNow.eMax);
eL = min(max(eLraw,0),pNow.eMax);

% Detection probability and queue inflow.
pDetRaw = pNow.s*(1-eD);
pDet = min(max(pDetRaw,0),1);
if modeNow.idealGovernance, pDet=1; end
aDet = pNow.kDetect*pDet*I;

% Backlog state or scale-matched quasi-steady backlog.
if modeNow.exogenousA
    A = pNow.Aref;
elseif modeNow.useAState
    A = Astate;
else
    A = pNow.Aref;
    for it=1:30
        hTmp = pNow.h/(1+pNow.omegaA*A);
        rTmp = yEff*pNow.kAction*hTmp;
        Anew = aDet/(aDet+rTmp+pNow.deltaA+eps);
        if abs(Anew-A)<1e-12, break; end
        A = min(max(Anew,0),1);
    end
end

% Queue-flow and event-probability separation.
hEff = pNow.h/(1+pNow.omegaA*A);
rAct = yEff*pNow.kAction*hEff;       % conditional action rate per queued clue
phiIn = aDet*(1-A);                  % admitted queue inflow
phiAct = rAct*A;                     % completed-action queue outflow
switch lower(modeNow.handleProbabilityForm)
    case 'exponential'
        pHandle = 1-exp(-max(rAct,0)*pNow.handleWindow);
    case 'rational'
        pHandle = max(rAct,0)*pNow.handleWindow/(1+max(rAct,0)*pNow.handleWindow);
    otherwise
        error('Unknown handle-probability form: %s',modeNow.handleProbabilityForm);
end
pAct = min(max(pDet*pHandle,0),1);   % end-to-end action coverage probability
if modeNow.idealGovernance
    pHandle=1; pAct=1;
end

% Lifecycle-stage governance probabilities.
[pIn,pInRaw] = aigc.stage_probability(pAct,pNow.kappaIn,modeNow.stageProbabilityForm);
[pSp,pSpRaw] = aigc.stage_probability(pAct,pNow.kappaSp,modeNow.stageProbabilityForm);
[pRm,pRmRaw] = aigc.stage_probability(pAct,pNow.kappaRm,modeNow.stageProbabilityForm);
if modeNow.idealGovernance, pIn=1; pSp=1; pRm=1; end

if modeNow.useAState && ~modeNow.exogenousA
    dA = kTimeA*(phiIn-phiAct-pNow.deltaA*A);
else
    dA = 0;
end

% Provenance-label stock or quasi-steady value.
labelInRate = pNow.kLabel*pNow.c*(1-eL)*yEff;
labelOutRate = pNow.deltaLabel*(1-pNow.r)+pNow.deltaCross*I;
if modeNow.exogenousL
    L = pNow.Lref;
elseif modeNow.useLState
    L = Lstate;
else
    L = labelInRate/(labelInRate+labelOutRate+eps);
end
if modeNow.useLState && ~modeNow.exogenousL
    dL = kTimeL*(labelInRate*(1-L)-labelOutRate*L);
else
    dL = 0;
end
nuRaw = pNow.nu0+pNow.nu1*pNow.chi*L;
nuEff = min(max(nuRaw,0),1);

% Content quality, strategy-conditional exposure, and experienced quality.
Q0 = x*pNow.qC + (1-x)*pNow.qS;
DV = I*(1-nuEff);
DD = I;
D = z*DV+(1-z)*DD;
Qexp = Q0*(1-D);

% Payoff feedback switches.
if modeNow.informationFeedback, Ipay=I; else, Ipay=pNow.Iref; end
if modeNow.trustFeedback, Tpay=T; else, Tpay=pNow.Tref; end

% Producer payoffs.
piPC = pNow.RC*(1+pNow.thetaT_prod*Tpay)+yEff*pNow.BC-pNow.CC-yEff*pNow.f*pNow.CfpP;
piPS = pNow.RS*(1+pNow.thetaI*Ipay)-pNow.CS-pAct*(pNow.FP+pNow.LP)-pNow.Ce*eD-pNow.Cregen*E;

% Platform payoffs.
C = aigc.instantaneous_cost(x,yEff,uEff,A,L,pNow,modeNow);
piFR = pNow.RF+pNow.gQ*Q0+pNow.gT*Tpay ...
    -pNow.CR*(0.5+0.5*uEff^2)-pNow.f*x*pNow.CfpF ...
    -(1-pAct)*(1-x)*Ipay*pNow.LF;
piFW = pNow.RF+pNow.BWF-pNow.CW-(1-x)*Ipay*(pNow.LF+pNow.FF);

% User payoffs and exact Eq. (26).  The exposure used by payoffs
% follows the information-feedback switch, whereas Qexp continues to use
% the actual ecological exposure I.
DVpay = Ipay*(1-nuEff);
DDpay = Ipay;
piUV = pNow.BU+Tpay*Q0-pNow.CV-DVpay*pNow.LU;
piUD = pNow.BU+Tpay*Q0-DDpay*pNow.LU+pNow.BD;
deltaPiU_formula = Ipay*nuEff*pNow.LU-pNow.CV-pNow.BD;
deltaPiU_payoff = piUV-piUD;
if abs(deltaPiU_formula-deltaPiU_payoff) > 5e-10
    error('Eq. (26) consistency check failed.');
end

% Replicator selection with symmetric payoff-independent switching.
dx = x*(1-x)*(piPC-piPS)+pNow.epsP*(1-2*x);
dy = y*(1-y)*(piFR-piFW)+pNow.epsF*(1-2*y);
dz = z*(1-z)*deltaPiU_formula+pNow.epsU*(1-2*z);

% AIGC amplification of risk injection.
mE = aigc.aigc_multiplier(E,pNow,modeNow);

% Risk dynamics.
if modeNow.enableInformation && ~modeNow.exogenousI
    lambdaEff = pNow.lambda0*mE;
    injection = lambdaEff*(1-x)*(1-pIn)*(1-Istate);
    betaEff = pNow.beta0*(1-pSp)*(1-z*nuEff)*(1+pNow.thetaT_share*Tpay);
    gammaEff = pNow.gamma0+pNow.gammaPlatform*pRm+pNow.gammaUser*z*nuEff;
    dI = injection+betaEff*Istate*(1-Istate)-gammaEff*Istate;
else
    lambdaEff=0; injection=0; betaEff=0; gammaEff=0; dI=0;
end

% Positive trust experience anchored to Qexp.
governanceSignal = pAct*(1-x);
switch lower(modeNow.positiveExperienceForm)
    case 'integrated'
        G = Qexp+pNow.omegaG*governanceSignal*(1-Qexp);
    case 'pure_qexp'
        G = Qexp;
    otherwise
        error('Unknown positive-experience form: %s',modeNow.positiveExperienceForm);
end

% Negative experience: personal exposure plus public ecosystem signal.
B = pNow.omegaD*D+pNow.omegaI*I ...
    +pNow.omegaF*yEff*pNow.f*x ...
    +pNow.omegaM*(1-pAct)*(1-x)*I ...
    +pNow.omegaETrust*E*I;
[gB,phi] = aigc.threshold_response(B,pNow,modeNow);
if modeNow.enableTrust && ~modeNow.exogenousT
    if modeNow.trustAsymmetric
        lossCoefficient = pNow.delta*phi;
    else
        lossCoefficient = pNow.alpha;
    end
    memoryPull = 0;
    if modeNow.useMemory, memoryPull = pNow.mu*(M-Tstate); end
    dT = pNow.alpha*G*(1-Tstate)-lossCoefficient*B*Tstate ...
        -pNow.xi*yEff*pNow.f*x*Tstate+memoryPull;
    if modeNow.useMemory, dM=kTimeM*pNow.kappa*(Tstate-M); else, dM=0; end
else
    dT=0; dM=0;
end

% Dynamic audit feedback.
if modeNow.dynamicAudit
    controlSignal = pNow.etaI*(Istate-pNow.Istar)+pNow.etaT*(pNow.Tstar-Tstate) ...
        +pNow.etaA*(A-pNow.Astar)-pNow.etaC*(C-pNow.Cstar);
    du = pNow.auditSpeed*aigc.audit_boundary_factor(uState,modeNow)*controlSignal;
    if strcmpi(modeNow.auditBoundaryForm,'projected')
        % Project the vector field onto the tangent cone of [0,1].
        % Merely clipping the stored trajectory would not define the intended
        % projected dynamics and could conceal an outward boundary field.
        if (uState<=0 && du<0) || (uState>=1 && du>0), du=0; end
    end
else
    controlSignal=0; du=0;
end

% AIGC adaptive regeneration.
if modeNow.useAIGC && ~modeNow.exogenousE && ~modeNow.fixedE
    dE = pNow.rhoE*yEff*pNow.s*(1-x)*I*(1-Estate) ...
        -(pNow.rhoEPenalty*pNow.FP+pNow.rhoEAnti*pNow.antiE+pNow.rhoEDecay)*Estate;
else
    dE=0;
end

out.dX = [dx;dy;dz;dI;dT;dM;du;dA;dL;dE];
out.x=x; out.y=y; out.z=z; out.I=I; out.T=T; out.M=M; out.uEff=uEff;
out.A=A; out.L=L; out.E=E; out.yEff=yEff;
out.eD=eD; out.eL=eL; out.eDraw=eDraw; out.eLraw=eLraw;
out.pDet=pDet; out.pDetRaw=pDetRaw; out.aDet=aDet; out.hEff=hEff;
out.rAct=rAct; out.phiIn=phiIn; out.phiAct=phiAct; out.pHandle=pHandle; out.pAct=pAct;
out.pIn=pIn; out.pSp=pSp; out.pRm=pRm;
out.labelInRate=labelInRate; out.labelOutRate=labelOutRate; out.nuEff=nuEff;
out.Q0=Q0; out.DV=DV; out.DD=DD; out.D=D; out.Qexp=Qexp;
out.Ipay=Ipay; out.DVpay=DVpay; out.DDpay=DDpay;
out.piPC=piPC; out.piPS=piPS; out.piFR=piFR; out.piFW=piFW;
out.piUV=piUV; out.piUD=piUD; out.deltaPiU=deltaPiU_formula;
out.mE=mE; out.lambdaEff=lambdaEff; out.injection=injection;
out.betaEff=betaEff; out.gammaEff=gammaEff;
out.G=G; out.B=B; out.gB=gB; out.phi=phi;
out.governanceSignal=governanceSignal; out.cost=C; out.controlSignal=controlSignal;
out.Ecal=abs(T-Qexp);
auditSwitchMargin=Inf;
if strcmpi(modeNow.auditBoundaryForm,'projected')
    auditSwitchMargin=switch_margin(uState,0,1);
end
out.clipSafetyMargin=min([switch_margin(eDraw,0,pNow.eMax), ...
    switch_margin(eLraw,0,pNow.eMax),switch_margin(pDetRaw,0,1), ...
    switch_margin(nuRaw,0,1),stage_margin(pInRaw,modeNow.stageProbabilityForm), ...
    stage_margin(pSpRaw,modeNow.stageProbabilityForm),stage_margin(pRmRaw,modeNow.stageProbabilityForm), ...
    auditSwitchMargin]);
end

function k=mode_scale(mode,fieldName)
k=1.0;
if isfield(mode,fieldName)
    v=mode.(fieldName);
    if isfinite(v) && v>0, k=v; end
end
end

function m=switch_margin(raw,lowerBound,upperBound)
m=min(abs(raw-lowerBound),abs(raw-upperBound));
end

function m=stage_margin(raw,form)
if strcmpi(form,'linear'), m=min(abs(raw),abs(raw-1)); else, m=abs(raw); end
end
