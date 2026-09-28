function s = time_std(t,Y)
%TIME_STD Time-weighted population standard deviation.
t=t(:);
if isempty(t) || isempty(Y), s=NaN; return; end
if size(Y,1)~=numel(t), error('Y must have one row per time point.'); end
m=aigc.time_average(t,Y);
if numel(t)==1 || t(end)<=t(1)
    s=zeros(1,size(Y,2));
else
    s=sqrt(max(aigc.time_average(t,(Y-m).^2),0));
end
end
