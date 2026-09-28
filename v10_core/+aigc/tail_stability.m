function out = tail_stability(sol,p,mode,opt,res) %#ok<INUSD>
%TAIL_STABILITY Compare adjacent time windows for long-run stationarity.
if nargin<5 || isempty(res), res=aigc.evaluate_solution(sol,p,mode); end
tStart=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1));
tMid=0.5*(tStart+sol.t(end));
i1=find(sol.t>=tStart & sol.t<=tMid); i2=find(sol.t>tMid);
if numel(i1)<4 || numel(i2)<4
    out.stable=false; out.maxMeanDrift=Inf; out.ampDrift=Inf;
    out.meanDriftI=Inf; out.meanDriftT=Inf; out.meanDriftQexp=Inf; return;
end
m1=[aigc.time_average(sol.t(i1),res.I(i1)),aigc.time_average(sol.t(i1),res.T(i1)), ...
    aigc.time_average(sol.t(i1),res.Qexp(i1))];
m2=[aigc.time_average(sol.t(i2),res.I(i2)),aigc.time_average(sol.t(i2),res.T(i2)), ...
    aigc.time_average(sol.t(i2),res.Qexp(i2))];
d=abs(m2-m1);
a1=max(res.I(i1))-min(res.I(i1)); a2=max(res.I(i2))-min(res.I(i2));
ampDrift=abs(a2-a1)/(max([a1,a2,opt.minCycleAmplitude])+eps);
out.meanDriftI=d(1); out.meanDriftT=d(2); out.meanDriftQexp=d(3);
out.maxMeanDrift=max(d); out.ampDrift=ampDrift;
out.stable=out.maxMeanDrift<=opt.tailMeanDriftTol && ...
    (max(a1,a2)<=opt.tauEq || ampDrift<=opt.maxAmplitudeDrift);
end
