function mode = trust_mode(k)
%TRUST_MODE T0-T5 trust structures.
if k < 0 || k > 5 || k ~= round(k), error('T index must be 0..5.'); end
mode = aigc.full_mode();
mode.name = sprintf('T%d',k);
switch k
    case 0
        mode.enableTrust = false; mode.exogenousT = true;
        mode.useMemory = false; mode.activeMask([5 6]) = false;
    case 1
        mode.trustAsymmetric = false; mode.useMemory = false;
        mode.useThreshold = false; mode.activeMask(6) = false;
    case 2
        mode.trustAsymmetric = true; mode.useMemory = false;
        mode.useThreshold = false; mode.activeMask(6) = false;
    case 3
        mode.trustAsymmetric = false; mode.useMemory = true;
        mode.useThreshold = false;
    case 4
        mode.trustAsymmetric = true; mode.useMemory = true;
        mode.useThreshold = false;
    case 5
        mode.trustAsymmetric = true; mode.useMemory = true;
        mode.useThreshold = true;
end
end
