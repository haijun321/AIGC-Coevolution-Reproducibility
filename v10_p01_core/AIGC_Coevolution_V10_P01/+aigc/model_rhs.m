function [dX,aux] = model_rhs(t,X,p,mode)
%MODEL_RHS V10 right-hand side with invariant-boundary protection.
terms = aigc.model_terms(t,X,p,mode);
dX = terms.dX;
mask = logical(mode.activeMask(:));
if numel(mask) ~= 10, error('mode.activeMask must have length 10.'); end
dX(~mask) = 0;
Xc = aigc.clip01(X(:));
for i=1:10
    if Xc(i)<=0 && dX(i)<0, dX(i)=0; end
    if Xc(i)>=1 && dX(i)>0, dX(i)=0; end
end
if nargout > 1
    aux = rmfield(terms,'dX');
end
end
