function [sol,cert] = solve_adaptive_longrun(X0,p,mode,opt,maxTEnd)
%SOLVE_ADAPTIVE_LONGRUN Extend unresolved trajectories until stationary or capped.
if nargin<5 || isempty(maxTEnd), maxTEnd=opt.tEnd; end
optSeg=opt; optSeg.allowEarlyStop=false;
sol=aigc.solve_model(X0,p,mode,optSeg);
classOut=aigc.classify_dynamics(sol,p,mode,opt);
stab=aigc.tail_stability(sol,p,mode,opt);
extended=false; nSegments=1;
schedule=opt.longRunSchedule(:)';
schedule=schedule(schedule>sol.finalTime+eps & schedule<=maxTEnd+eps);
if sol.finalTime<maxTEnd && (isempty(schedule) || schedule(end)<maxTEnd-eps)
    schedule=[schedule,maxTEnd];
end
for nextEnd=schedule
    if stab.stable && aigc.is_resolved_label(classOut.label), break; end
    nextEnd=min(maxTEnd,nextEnd);
    optNext=optSeg; optNext.t0=sol.finalTime; optNext.tEnd=nextEnd;
    seg=aigc.solve_model(sol.finalState,p,mode,optNext);
    sol=aigc.concatenate_solutions(sol,seg);
    classOut=aigc.classify_dynamics(sol,p,mode,opt);
    stab=aigc.tail_stability(sol,p,mode,opt);
    extended=true; nSegments=nSegments+1;
end
cert.classification=classOut.label;
cert.period=classOut.period; cert.periodCV=classOut.periodCV;
cert.ampI=classOut.ampI; cert.residual=classOut.residual;
cert.tailStable=stab.stable; cert.tailMeanDrift=stab.maxMeanDrift;
cert.tailAmplitudeDrift=stab.ampDrift; cert.extended=extended;
cert.nSegments=nSegments; cert.finalTime=sol.finalTime;
end
