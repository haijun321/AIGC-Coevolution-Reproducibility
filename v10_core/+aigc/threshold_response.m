function [gB,phi] = threshold_response(B,p,mode)
%THRESHOLD_RESPONSE Threshold gate and asymmetric loss multiplier.
if ~mode.useThreshold
    gB = 0;
    phi = 1;
    return;
end
switch lower(mode.thresholdForm)
    case 'logistic'
        gB = 1./(1+exp(-p.kB*(B-p.thetaB)));
    case 'hill'
        Bp = max(B,0).^p.hillN;
        gB = Bp./(Bp+p.thetaB^p.hillN+eps);
    case 'piecewise'
        gB = min(max(0.5+(B-p.thetaB)/0.20,0),1);
    otherwise
        error('Unknown threshold form: %s',mode.thresholdForm);
end
phi = p.phiL + (p.phiH-p.phiL).*gB;
end
