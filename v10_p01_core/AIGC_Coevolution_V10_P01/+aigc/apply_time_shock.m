function [pOut,modeOut] = apply_time_shock(t,p,mode)
%APPLY_TIME_SHOCK Apply a piecewise-constant exogenous shock.
pOut = p;
modeOut = mode;
if ~isfield(mode,'shock') || strcmpi(mode.shock.type,'none'), return; end
sh = mode.shock;
active = false;
for i=1:size(sh.windows,1)
    if t >= sh.windows(i,1) && t <= sh.windows(i,2)
        active = true; break;
    end
end
if ~active, return; end
s = sh.strength;
switch lower(sh.type)
    case 'risk_environment'
        pOut.lambda0 = p.lambda0*(1+s);
        pOut.beta0 = p.beta0*(1+0.60*s);
    case 'detection_failure'
        pOut.s = max(0.01,p.s*(1-s));
    case 'label_failure'
        pOut.c = max(0.01,p.c*(1-s));
        pOut.r = max(0.01,p.r*(1-s));
    case 'false_positive'
        pOut.f = min(0.60,p.f+0.45*s);
    case 'aigc_surge'
        pOut.rhoE = p.rhoE*(1+s);
        pOut.psiE = p.psiE*(1+s);
    case 'combined_governance_failure'
        pOut.s = max(0.01,p.s*(1-0.60*s));
        pOut.h = max(0.01,p.h*(1-0.60*s));
        pOut.c = max(0.01,p.c*(1-0.60*s));
        pOut.r = max(0.01,p.r*(1-0.60*s));
        pOut.chi = max(0.01,p.chi*(1-0.60*s));
    otherwise
        error('Unknown shock type: %s',sh.type);
end
end
