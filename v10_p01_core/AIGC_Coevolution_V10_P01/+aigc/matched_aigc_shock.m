function out = matched_aigc_shock(Xbase,p,mode,opt,strength)
%MATCHED_AIGC_SHOCK Dynamic adaptation vs onset-capacity-matched fixed E.
% Both counterfactuals start from the same ecological state and the same
% AIGC capacity at t=0.  The fixed comparator freezes E at its onset value;
% the dynamic model is allowed to regenerate after the capacity surge.
if nargin<5, strength=0.5; end
optRun=opt; optRun.allowEarlyStop=false;
modeBase=mode; modeBase.shock=aigc.no_shock();
sol0=aigc.solve_model(Xbase,p,modeBase,optRun);
ev0=aigc.evaluate_solution(sol0,p,modeBase);

pDyn=p; pDyn.rhoE=p.rhoE*(1+strength); pDyn.psiE=p.psiE*(1+strength);
modeDyn=mode; modeDyn.shock=aigc.no_shock(); modeDyn.fixedE=false;
solD=aigc.solve_model(Xbase,pDyn,modeDyn,optRun);
evD=aigc.evaluate_solution(solD,pDyn,modeDyn);

% Freeze the fixed comparator at the common onset E state.  This makes the
% pre-intervention capacity exactly equal while allowing only the dynamic
% branch to regenerate thereafter.
Efix=min(max(Xbase(10),0),1);
modeF=modeDyn; modeF.fixedE=true; modeF.fixedEValue=Efix;
modeF.activeMask(10)=false; modeF.exogenousE=false;
solF=aigc.solve_model(Xbase,pDyn,modeF,optRun);
evF=aigc.evaluate_solution(solF,pDyn,modeF);

% Interpolate onto one common grid before paired integration.
t0=max([ev0.t(1),evD.t(1),evF.t(1)]); t1=min([ev0.t(end),evD.t(end),evF.t(end)]);
tGrid=linspace(t0,t1,1201)';
I0=interp1(ev0.t,ev0.I,tGrid,'pchip'); T0=interp1(ev0.t,ev0.T,tGrid,'pchip');
ID=interp1(evD.t,evD.I,tGrid,'pchip'); TD=interp1(evD.t,evD.T,tGrid,'pchip');
IF=interp1(evF.t,evF.I,tGrid,'pchip'); TF=interp1(evF.t,evF.T,tGrid,'pchip');
MD=interp1(evD.t,evD.mE,tGrid,'pchip'); MF=interp1(evF.t,evF.mE,tGrid,'pchip');

initialDynamicCapacity=MD(1); initialFixedCapacity=MF(1);
dynamicMeanCapacity=aigc.time_average(tGrid,MD); fixedMeanCapacity=aigc.time_average(tGrid,MF);
out.Strength=strength; out.MatchType='onset_capacity';
out.InitialDynamicCapacity=initialDynamicCapacity; out.InitialFixedCapacity=initialFixedCapacity;
out.CapacityMatchError=initialFixedCapacity-initialDynamicCapacity;
out.InitialCapacityDifference=abs(out.CapacityMatchError);
out.DynamicMeanCapacity=dynamicMeanCapacity; out.FixedMeanCapacity=fixedMeanCapacity;
out.MeanCapacityDifference=dynamicMeanCapacity-fixedMeanCapacity;
out.FixedE=Efix; out.MatchSolverError=0;
out.DynamicRiskArea=trapz(tGrid,max(ID-I0,0));
out.FixedRiskArea=trapz(tGrid,max(IF-I0,0));
out.RiskAreaGain=out.DynamicRiskArea-out.FixedRiskArea;
out.RiskAreaGainPct=100*out.RiskAreaGain/(out.FixedRiskArea+eps);
out.DynamicTrustLossArea=trapz(tGrid,max(T0-TD,0));
out.FixedTrustLossArea=trapz(tGrid,max(T0-TF,0));
out.TrustLossAreaGain=out.DynamicTrustLossArea-out.FixedTrustLossArea;
out.TrustLossAreaGainPct=100*out.TrustLossAreaGain/(out.FixedTrustLossArea+eps);
out.DynamicPeakRiskExcess=max(ID-I0); out.FixedPeakRiskExcess=max(IF-I0);
out.DynamicMaxTrustLoss=max(T0-TD); out.FixedMaxTrustLoss=max(T0-TF);
out.DynamicFinalRisk=ID(end); out.FixedFinalRisk=IF(end); out.BaselineFinalRisk=I0(end);
out.DynamicFinalTrust=TD(end); out.FixedFinalTrust=TF(end); out.BaselineFinalTrust=T0(end);
out.t=tGrid; out.I0=I0; out.T0=T0; out.ID=ID; out.TD=TD; out.IF=IF; out.TF=TF;
out.MD=MD; out.MF=MF;
end
