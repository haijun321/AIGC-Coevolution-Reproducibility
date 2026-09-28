function out = classify_dynamics(sol,p,mode,opt)
%CLASSIFY_DYNAMICS Equilibrium/cycle/unresolved classification.
tailStart=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1));
idx=find(sol.t>=tailStart); if numel(idx)<8, idx=max(1,size(sol.X,1)-7):size(sol.X,1); end
active=find(mode.activeMask(:)); if isempty(active), active=1:10; end
amps=max(sol.X(idx,active),[],1)-min(sol.X(idx,active),[],1);
dEnd=aigc.model_rhs(sol.t(end),sol.finalState,p,mode);
resid=norm(dEnd(active),inf);
out.ampI=max(sol.X(idx,4))-min(sol.X(idx,4));
out.period=NaN; out.periodCV=NaN; out.residual=resid;
out.amplitudes=amps; out.nPeaks=0; out.amplitudeDrift=NaN;
term=aigc.model_terms(sol.t(end),sol.finalState,p,mode);
out.clipSafetyMargin=term.clipSafetyMargin;
if all(amps<=opt.tauEq) && resid<=opt.tauF
    key=sol.finalState(active);
    if out.clipSafetyMargin<=opt.tauClip
        out.label='boundary_nonsmooth_candidate';
    elseif any(key<=opt.tauBoundary | key>=1-opt.tauBoundary)
        out.label='boundary_equilibrium';
    else
        out.label='interior_equilibrium';
    end
    return;
end

y=sol.X(idx,4); tt=sol.t(idx);
peakIdx=aigc.local_peak_indices(y);
out.nPeaks=numel(peakIdx);
if numel(peakIdx)>=opt.minCycles+1 && out.ampI>=opt.minCycleAmplitude
    periods=diff(tt(peakIdx)); per=mean(periods); cv=std(periods)/(per+eps);
    % One amplitude per peak-to-peak interval. This avoids misaligning
    % independently detected peaks and troughs.
    cycleAmp=nan(numel(peakIdx)-1,1);
    for c=1:numel(peakIdx)-1
        seg=peakIdx(c):peakIdx(c+1);
        trough=min(y(seg));
        cycleAmp(c)=0.5*(y(peakIdx(c))+y(peakIdx(c+1)))-trough;
    end
    cycleAmp=cycleAmp(isfinite(cycleAmp));
    if numel(cycleAmp)>=opt.minCycles
        half=max(2,floor(numel(cycleAmp)/2));
        a1=mean(cycleAmp(1:half)); a2=mean(cycleAmp(end-half+1:end));
        drift=abs(a2-a1)/(max(abs(a1),opt.minCycleAmplitude)+eps);
        out.period=per; out.periodCV=cv; out.amplitudeDrift=drift;
        if cv<=opt.maxPeriodCV && drift<=opt.maxAmplitudeDrift
            out.label='stable_cycle';
        else
            out.label='unresolved_oscillation';
        end
        return;
    end
end

midTime=0.5*(tt(1)+tt(end)); early=y(tt<=midTime); late=y(tt>midTime);
if isempty(early) || isempty(late)
    out.label='unresolved_transient';
else
    ampEarly=max(early)-min(early); ampLate=max(late)-min(late);
    if ampLate < 0.6*max(ampEarly,eps)
        out.label='unresolved_transient';
    else
        out.label='unresolved_oscillation';
    end
end
end
