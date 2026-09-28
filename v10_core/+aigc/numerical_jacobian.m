function J = numerical_jacobian(X,p,mode,h)
%NUMERICAL_JACOBIAN Central finite-difference Jacobian.
X=X(:); n=numel(X); J=zeros(n);
for j=1:n
    step=h*max(1,abs(X(j)));
    xp=X; xm=X; xp(j)=min(1,X(j)+step); xm(j)=max(0,X(j)-step);
    fp=aigc.model_rhs(0,xp,p,mode); fm=aigc.model_rhs(0,xm,p,mode);
    den=xp(j)-xm(j);
    if den==0, J(:,j)=0; else, J(:,j)=(fp-fm)/den; end
end
end
