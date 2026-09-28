function [rho,bootLo,bootHi] = prcc(X,Y,nBoot,seed)
%PRCC Partial rank correlation coefficients with bootstrap intervals.
if nargin<3, nBoot=0; end
if nargin<4, seed=20260723; end
valid=all(isfinite(X),2)&isfinite(Y);
X=X(valid,:); Y=Y(valid,:); [n,d]=size(X);
RX=zeros(n,d); for j=1:d, RX(:,j)=aigc.local_rank(X(:,j)); end
RY=aigc.local_rank(Y);
rho=zeros(d,1);
for j=1:d
    Z=[ones(n,1),RX(:,setdiff(1:d,j))];
    rx=RX(:,j)-Z*(Z\RX(:,j));
    ry=RY-Z*(Z\RY);
    C=corrcoef(rx,ry); if numel(C)<4, rho(j)=NaN; else, rho(j)=C(1,2); end
end
bootLo=nan(d,1); bootHi=nan(d,1);
if nBoot<=0 || n<8, return; end
state=rng; cleanup=onCleanup(@() rng(state)); %#ok<NASGU>
rng(seed,'twister'); B=nan(nBoot,d);
for b=1:nBoot
    ind=randi(n,n,1); xb=X(ind,:); yb=Y(ind);
    rxb=zeros(n,d); for j=1:d, rxb(:,j)=aigc.local_rank(xb(:,j)); end
    ryb=aigc.local_rank(yb);
    for j=1:d
        Z=[ones(n,1),rxb(:,setdiff(1:d,j))];
        ex=rxb(:,j)-Z*(Z\rxb(:,j)); ey=ryb-Z*(Z\ryb);
        C=corrcoef(ex,ey); if numel(C)>=4, B(b,j)=C(1,2); end
    end
end
for j=1:d
    v=sort(B(isfinite(B(:,j)),j));
    if ~isempty(v)
        bootLo(j)=v(max(1,round(0.025*numel(v))));
        bootHi(j)=v(min(numel(v),round(0.975*numel(v))));
    end
end
end
