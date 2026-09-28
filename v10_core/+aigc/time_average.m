function m = time_average(t,Y)
%TIME_AVERAGE Time-weighted average for vectors or matrices.
t=t(:);
if isempty(t) || isempty(Y), m=NaN; return; end
if size(Y,1)~=numel(t), error('Y must have one row per time point.'); end
if numel(t)==1 || t(end)<=t(1)
    m=Y(end,:);
else
    m=trapz(t,Y,1)/(t(end)-t(1));
end
end
