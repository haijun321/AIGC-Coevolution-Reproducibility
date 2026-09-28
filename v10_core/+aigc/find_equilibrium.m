function out = find_equilibrium(Xseed,p,mode,opt)
%FIND_EQUILIBRIUM Toolbox-free damped Newton solve on the active subsystem.
x=aigc.clip01(Xseed(:)); active=find(mode.activeMask(:));
out.success=false; out.X=x; out.residual=Inf; out.iterations=0;
out.spectralAbscissa=NaN; out.dominantReal=NaN; out.dominantImag=NaN;
out.dominantComplexReal=NaN; out.dominantComplexImag=NaN;
out.otherSpectralAbscissa=NaN; out.clipSafetyMargin=NaN;
out.dominantComplexEigenvalue=NaN; out.dominantComplexVector=[];
out.internal=false; out.eigenvalues=[];
if isempty(active), out.success=true; out.residual=0; return; end
for it=1:opt.eqMaxIterations
    f=aigc.model_rhs(0,x,p,mode); fa=f(active); nr=norm(fa,inf);
    out.iterations=it;
    if nr<=opt.eqSolveTol
        out.success=true; break;
    end
    J=aigc.numerical_jacobian(x,p,mode,opt.fdStep);
    Ja=J(active,active);
    if rcond(Ja)>1e-11
        step=-Ja\fa;
    else
        step=-pinv(Ja)*fa;
    end
    if any(~isfinite(step)), break; end
    accepted=false; alpha=1;
    for ls=1:18
        xTry=x; xTry(active)=aigc.clip01(x(active)+alpha*step);
        fTry=aigc.model_rhs(0,xTry,p,mode);
        if norm(fTry(active),inf)<nr
            x=xTry; accepted=true; break;
        end
        alpha=alpha/2;
    end
    if ~accepted
        xTry=x; xTry(active)=aigc.clip01(x(active)-0.05*fa);
        fTry=aigc.model_rhs(0,xTry,p,mode);
        if norm(fTry(active),inf)<nr, x=xTry; else, break; end
    end
end
f=aigc.model_rhs(0,x,p,mode); out.residual=norm(f(active),inf);
out.success=out.success || out.residual<=opt.eqAcceptTol;
out.X=x; key=x(active);
out.internal=all(key>opt.tauBoundary & key<1-opt.tauBoundary);
term=aigc.model_terms(0,x,p,mode); out.clipSafetyMargin=term.clipSafetyMargin;
if out.success
    J=aigc.numerical_jacobian(x,p,mode,opt.fdStep);
    [V,D]=eig(J(active,active)); ev=diag(D); out.eigenvalues=ev;
    if ~isempty(ev)
        [~,ii]=max(real(ev));
        out.spectralAbscissa=real(ev(ii));
        out.dominantReal=real(ev(ii)); out.dominantImag=imag(ev(ii));
        pos=find(imag(ev)>1e-7);
        if ~isempty(pos)
            [~,jj]=max(real(ev(pos))); ip=pos(jj);
            out.dominantComplexReal=real(ev(ip)); out.dominantComplexImag=abs(imag(ev(ip)));
            out.dominantComplexEigenvalue=ev(ip);
            vec=V(:,ip); out.dominantComplexVector=vec/(norm(vec)+eps);
            [~,ic]=min(abs(ev-conj(ev(ip))));
            keep=true(size(ev)); keep([ip ic])=false;
            if any(keep), out.otherSpectralAbscissa=max(real(ev(keep)));
            else, out.otherSpectralAbscissa=-Inf; end
        end
    end
end
end
