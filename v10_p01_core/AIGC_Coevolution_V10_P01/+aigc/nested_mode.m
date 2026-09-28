function mode = nested_mode(k)
%NESTED_MODE M0-M13 progressive mechanism construction.
if k < 0 || k > 13 || k ~= round(k), error('M index must be 0..13.'); end
mode = aigc.full_mode();
mode.name = sprintf('M%d',k);

% M0: strategies only; risk and trust are exogenous references.
mode.enableInformation = false;
mode.informationFeedback = false;
mode.enableTrust = false;
mode.trustFeedback = false;
mode.trustAsymmetric = false;
mode.useMemory = false;
mode.useThreshold = false;
mode.useAState = false;
mode.useLState = false;
mode.useAIGC = false;
mode.dynamicAudit = false;
mode.fixedAudit = true;
mode.fixedAuditIntensity = 0.70;
mode.endogenousEvasion = false;
mode.costDynamic = false;
mode.costFixed = true;
mode.activeMask = false(10,1);
mode.activeMask(1:3) = true;
mode.exogenousI = true;
mode.exogenousT = true;
mode.exogenousA = true;
mode.exogenousL = true;
mode.exogenousE = true;

if k >= 1
    mode.enableInformation = true;
    mode.activeMask(4) = true;
    mode.exogenousI = false;
end
if k >= 2, mode.informationFeedback = true; end
if k >= 3
    mode.enableTrust = true;
    mode.trustFeedback = true;
    mode.activeMask(5) = true;
    mode.exogenousT = false;
end
if k >= 4, mode.trustAsymmetric = true; end
if k >= 5
    mode.useMemory = true;
    mode.activeMask(6) = true;
end
if k >= 6, mode.useThreshold = true; end
% M7: finite detection-action chain in quasi-steady form.
if k >= 7
    mode.useAState = false;
    mode.exogenousA = false;
end
% M8: finite label chain in quasi-steady form.
if k >= 8
    mode.useLState = false;
    mode.exogenousL = false;
end
% M9: dynamic action backlog.
if k >= 9
    mode.useAState = true;
    mode.activeMask(8) = true;
end
% M10: dynamic label stock.
if k >= 10
    mode.useLState = true;
    mode.activeMask(9) = true;
end
if k >= 11, mode.endogenousEvasion = true; end
if k >= 12
    mode.useAIGC = true;
    mode.activeMask(10) = true;
    mode.exogenousE = false;
end
if k >= 13
    mode.dynamicAudit = true;
    mode.fixedAudit = false;
    mode.activeMask(7) = true;
    mode.costDynamic = true;
    mode.costFixed = false;
end
end
