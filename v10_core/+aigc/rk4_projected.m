function sol = rk4_projected(X0,p,mode,opt)
%RK4_PROJECTED Fixed-step projected fourth-order Runge-Kutta.
t=(opt.t0:opt.h:opt.tEnd)';
if t(end)<opt.tEnd, t=[t;opt.tEnd]; end
N=numel(t); X=zeros(N,10); X(1,:)=X0';
last=1; stableCount=0;
for k=1:N-1
    hk=t(k+1)-t(k); x=X(k,:)';
    k1=aigc.model_rhs(t(k),x,p,mode);
    k2=aigc.model_rhs(t(k)+hk/2,aigc.clip01(x+hk*k1/2),p,mode);
    k3=aigc.model_rhs(t(k)+hk/2,aigc.clip01(x+hk*k2/2),p,mode);
    k4=aigc.model_rhs(t(k)+hk,aigc.clip01(x+hk*k3),p,mode);
    xNew=x+hk*(k1+2*k2+2*k3+k4)/6;
    if opt.project, xNew=aigc.clip01(xNew); end
    X(k+1,:)=xNew'; last=k+1;
    if opt.allowEarlyStop
        dNow=aigc.model_rhs(t(k+1),xNew,p,mode);
        if norm(xNew-x,inf)<opt.steadyTol && norm(dNow,inf)<opt.derivativeTol
            stableCount=stableCount+1;
        else
            stableCount=0;
        end
        if stableCount>=opt.stableK, break; end
    end
end
sol.t=t(1:last); sol.X=X(1:last,:);
if last<N, sol.status='SteadyEarlyStop'; else, sol.status='Completed'; end
end
