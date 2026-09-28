function [mode,pOut] = benchmark_mode(name,pIn)
%BENCHMARK_MODE BM0-BM4 classic/reduced benchmark models.
name = upper(char(name));
pOut = pIn;
mode = aigc.full_mode();
mode.name = name;
switch name
    case 'BM0'
        % Standard three-population replicator dynamics with exogenous ecology.
        pOut.epsP = 0; pOut.epsF = 0; pOut.epsU = 0;
        mode.enableInformation = false; mode.exogenousI = true; mode.informationFeedback = false;
        mode.enableTrust = false; mode.exogenousT = true; mode.trustFeedback = false;
        mode.useMemory = false; mode.useAState = false; mode.useLState = false;
        mode.exogenousA = true; mode.exogenousL = true; mode.exogenousE = true;
        mode.useAIGC = false; mode.endogenousEvasion = false;
        mode.dynamicAudit = false; mode.fixedAudit = true;
        mode.costDynamic = false; mode.costFixed = true;
        mode.activeMask = false(10,1); mode.activeMask(1:3) = true;
    case 'BM1'
        % Replicator selection plus symmetric switching, exogenous ecology.
        mode.enableInformation = false; mode.exogenousI = true; mode.informationFeedback = false;
        mode.enableTrust = false; mode.exogenousT = true; mode.trustFeedback = false;
        mode.useMemory = false; mode.useAState = false; mode.useLState = false;
        mode.exogenousA = true; mode.exogenousL = true; mode.exogenousE = true;
        mode.useAIGC = false; mode.endogenousEvasion = false;
        mode.dynamicAudit = false; mode.fixedAudit = true;
        mode.costDynamic = false; mode.costFixed = true;
        mode.activeMask = false(10,1); mode.activeMask(1:3) = true;
    case 'BM2'
        % Exogenous-parameter injection-diffusion-removal model.
        mode.informationFeedback = false;
        mode.enableTrust = false; mode.exogenousT = true;
        mode.useMemory = false; mode.useAState = false; mode.useLState = false;
        mode.exogenousA = true; mode.exogenousL = true; mode.exogenousE = true;
        mode.useAIGC = false; mode.endogenousEvasion = false;
        mode.dynamicAudit = false; mode.fixedAudit = true;
        mode.activeMask = false(10,1); mode.activeMask(4) = true;
    case 'BM3'
        % First-order trust model without memory or threshold.
        mode.enableInformation = false; mode.exogenousI = true; mode.informationFeedback = false;
        mode.enableTrust = true; mode.trustAsymmetric = false;
        mode.useMemory = false; mode.useThreshold = false;
        mode.useAState = false; mode.useLState = false; mode.useAIGC = false;
        mode.exogenousA = true; mode.exogenousL = true; mode.exogenousE = true;
        mode.endogenousEvasion = false;
        mode.dynamicAudit = false; mode.fixedAudit = true;
        mode.activeMask = false(10,1); mode.activeMask(5) = true;
    case 'BM4'
        % Static-governance coevolution: x,y,z,I,T evolve; u,A,L,E fixed.
        mode.useMemory = false;
        mode.useAState = true; mode.useLState = true;
        mode.useAIGC = false; mode.endogenousEvasion = false;
        mode.dynamicAudit = false; mode.fixedAudit = true;
        mode.activeMask = false(10,1); mode.activeMask([1:5]) = true;
        mode.exogenousA = true; mode.exogenousL = true; mode.exogenousE = true;
        mode.costDynamic = false; mode.costFixed = true;
    otherwise
        error('Unknown benchmark %s.',name);
end
end
