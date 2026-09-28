function out = tail_window_diagnostics(sol,p,mode,opt,res)
%TAIL_WINDOW_DIAGNOSTICS Compare 25%, 40%, and 50% tail summaries.
if nargin<5 || isempty(res), res=aigc.evaluate_solution(sol,p,mode); end
fractions=opt.tailFractions(:)'; n=numel(fractions);
out.fractions=fractions; out.meanI=nan(1,n); out.meanT=nan(1,n);
out.meanQexp=nan(1,n); out.ampI=nan(1,n); out.ampT=nan(1,n);
out.classification=strings(1,n);
for k=1:n
    startT=sol.t(1)+(1-fractions(k))*(sol.t(end)-sol.t(1));
    idx=find(sol.t>=startT);
    if numel(idx)<4, idx=max(1,numel(sol.t)-3):numel(sol.t); end
    tt=sol.t(idx);
    out.meanI(k)=aigc.time_average(tt,res.I(idx));
    out.meanT(k)=aigc.time_average(tt,res.T(idx));
    out.meanQexp(k)=aigc.time_average(tt,res.Qexp(idx));
    out.ampI(k)=max(res.I(idx))-min(res.I(idx));
    out.ampT(k)=max(res.T(idx))-min(res.T(idx));
    oo=opt; oo.tailFraction=fractions(k);
    cc=aigc.classify_dynamics(sol,p,mode,oo);
    out.classification(k)=string(cc.label);
end
out.meanSpreadI=max(out.meanI)-min(out.meanI);
out.meanSpreadT=max(out.meanT)-min(out.meanT);
out.ampSpreadI=max(out.ampI)-min(out.ampI);
out.ampSpreadT=max(out.ampT)-min(out.ampT);
out.classRobust=numel(unique(out.classification))==1;
end
