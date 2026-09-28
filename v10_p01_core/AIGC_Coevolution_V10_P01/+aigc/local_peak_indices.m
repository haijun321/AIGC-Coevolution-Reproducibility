function idx = local_peak_indices(y)
%LOCAL_PEAK_INDICES Basic local maxima finder without Signal Toolbox.
y=y(:);
if numel(y)<3, idx=[]; return; end
d1=diff(y);
idx=find([false; d1(1:end-1)>0 & d1(2:end)<=0; false]);
% Remove numerically flat/duplicate peaks.
if numel(idx)>1
    keep=[true; diff(idx)>1]; idx=idx(keep);
end
end
