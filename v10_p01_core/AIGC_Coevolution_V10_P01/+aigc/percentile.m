function qv = percentile(x,q)
%PERCENTILE Toolbox-free linear-interpolation percentiles.
x=x(isfinite(x)); x=sort(x(:)); q=q(:)';
qv=nan(size(q)); n=numel(x);
if n==0, return; end
if n==1, qv(:)=x; return; end
for k=1:numel(q)
    qq=min(max(q(k),0),100)/100;
    pos=1+(n-1)*qq; lo=floor(pos); hi=ceil(pos);
    if lo==hi, qv(k)=x(lo);
    else, qv(k)=x(lo)+(pos-lo)*(x(hi)-x(lo)); end
end
end
