function mode = leave_one_out_mode(k)
%LEAVE_ONE_OUT_MODE F0-F8 deletion or scale-matched replacement models.
if k < 0 || k > 8 || k ~= round(k), error('F index must be 0..8.'); end
mode = aigc.full_mode();
mode.name = sprintf('F%d',k);
switch k
    case 0
    case 1
        mode.informationFeedback = false;
    case 2
        mode.trustAsymmetric = false;
    case 3
        mode.useMemory = false; mode.activeMask(6) = false;
    case 4
        mode.useThreshold = false;
    case 5
        mode.useAState = false; mode.activeMask(8) = false;
    case 6
        mode.useLState = false; mode.activeMask(9) = false;
    case 7
        mode.endogenousEvasion = false;
    case 8
        mode.useAIGC = false; mode.activeMask(10) = false; mode.exogenousE = true;
end
end
