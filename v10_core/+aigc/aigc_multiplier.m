function mE = aigc_multiplier(E,p,mode)
%AIGC_MULTIPLIER Evaluate the selected AIGC capacity-amplification form.
E = min(max(E,0),1);
switch lower(mode.aigcAmplificationForm)
    case 'linear'
        mE = 1+p.psiE*E;
    case 'hill'
        num = E.^p.hillN;
        den = num+p.aigcHillK.^p.hillN+eps;
        mE = 1+p.psiE*num./den;
    case 'saturating'
        mE = 1+p.psiE*E./(1+E);
    otherwise
        error('Unknown AIGC amplification form: %s',mode.aigcAmplificationForm);
end
end
