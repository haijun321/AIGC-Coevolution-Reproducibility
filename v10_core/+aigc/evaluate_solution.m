function res = evaluate_solution(sol,p,mode)
%EVALUATE_SOLUTION Reconstruct all algebraic quantities from one source.
fields={'I','T','uEff','A','L','E','yEff','eD','eL','pDet','aDet','hEff','rAct', ...
    'phiIn','phiAct','pHandle','pAct','pIn','pSp','pRm','nuEff','Q0','DV','DD','D', ...
    'Qexp','Ipay','DVpay','DDpay','deltaPiU','mE','lambdaEff','injection', ...
    'betaEff','gammaEff','G','B','gB','phi','governanceSignal','cost', ...
    'controlSignal','Ecal','clipSafetyMargin'};
n=numel(sol.t);
for j=1:numel(fields), res.(fields{j})=zeros(n,1); end
for i=1:n
    [~,a]=aigc.model_rhs(sol.t(i),sol.X(i,:)',p,mode);
    for j=1:numel(fields), res.(fields{j})(i)=a.(fields{j}); end
end
res.t=sol.t; res.X=sol.X; res.sol=sol;
duration=max(sol.t(end)-sol.t(1),eps);
res.JI=trapz(sol.t,res.I)/duration;       % full-window risk mean
res.JT=trapz(sol.t,max(p.Tstar-res.T,0))/duration; % full-window trust loss
res.JC=trapz(sol.t,res.cost)/duration;
res.totalCost=trapz(sol.t,res.cost);
res.minState=min(sol.X,[],'all');
res.maxState=max(sol.X,[],'all');
res.minPhiIn=min(res.phiIn); res.minPhiAct=min(res.phiAct);
res.minPAct=min(res.pAct); res.maxPAct=max(res.pAct);
res.minPHandle=min(res.pHandle); res.maxPHandle=max(res.pHandle);
res.minStageProbability=min([res.pIn;res.pSp;res.pRm]);
res.maxStageProbability=max([res.pIn;res.pSp;res.pRm]);
end
