function s = experiment_settings(runMode)
%EXPERIMENT_SETTINGS PREVIEW/QUICK/FULL experiment budgets and gates.
s.runMode = lower(runMode);
s.factorNames = {'s','h','f','c','r','chi','eD0','eL0'};
s.factorGood = [0.92,0.92,0.02,0.92,0.92,0.90,0.05,0.05];
s.factorBad  = [0.55,0.55,0.18,0.55,0.55,0.40,0.32,0.32];
s.sensitivityNames = {'s','h','f','c','r','chi','FP','CR','lambda0','beta0', ...
    'alpha','delta','mu','rhoE','psiE','antiE','auditSpeed','etaI','etaC','omegaG'};
s.sensitivityRange = [ ...
    0.50 0.96; 0.50 0.96; 0.01 0.20; 0.45 0.96; 0.45 0.96; 0.35 0.95; ...
    0.25 1.30; 0.18 0.75; 0.12 0.48; 0.25 0.78; 0.08 0.34; 0.20 0.90; ...
    0.00 0.30; 0.04 0.75; 0.00 1.80; 0.00 0.55; 0.10 1.20; 0.35 3.50; ...
    0.20 4.50; 0.00 1.00];

switch lower(runMode)
    case 'preview'
        s.commonIC = 2; s.factorialIC = 1;
        s.phaseN = 7; s.aigcPlaneN = 7;
        s.morrisTrajectories = 3; s.morrisLevels = 6; s.lhsN = 40; s.lhsMatchedN = 12;
        s.prccBootstrap = 20;
        s.policyBudget = 16; s.policyRepeats = 2; s.policyMatchGridN = 40;
        s.shockStrengths = [0.3 0.6];
        s.robustnessMutationScales = [0.5 1.0 2.0];
        s.certificationMaxTime = 600; s.factorialMaxTime = 600; s.phaseMaxTime = 600;
        s.trustWarmupMaxTime = 600; s.trustEvalHorizon = 140; s.trustShockStart = 20;
    case 'quick'
        s.commonIC = 5; s.factorialIC = 2;
        s.phaseN = 15; s.aigcPlaneN = 15;
        s.morrisTrajectories = 8; s.morrisLevels = 6; s.lhsN = 160; s.lhsMatchedN = 40;
        s.prccBootstrap = 60;
        s.policyBudget = 60; s.policyRepeats = 3; s.policyMatchGridN = 60;
        s.shockStrengths = [0.2 0.4 0.7];
        s.robustnessMutationScales = [0.25 0.5 1.0 2.0 4.0];
        s.certificationMaxTime = 1200; s.factorialMaxTime = 1200; s.phaseMaxTime = 1200;
        s.trustWarmupMaxTime = 1200; s.trustEvalHorizon = 260; s.trustShockStart = 35;
    case 'full'
        s.commonIC = 12; s.factorialIC = 6;
        s.phaseN = 31; s.aigcPlaneN = 31;
        s.morrisTrajectories = 20; s.morrisLevels = 6; s.lhsN = 640; s.lhsMatchedN = 160;
        s.prccBootstrap = 2000;
        s.policyBudget = 240; s.policyRepeats = 4; s.policyMatchGridN = 180;
        s.shockStrengths = [0.15 0.30 0.50 0.75];
        s.robustnessMutationScales = [0.10 0.25 0.5 1.0 2.0 4.0 8.0];
        s.certificationMaxTime = 2400; s.factorialMaxTime = 2400; s.phaseMaxTime = 2400;
        s.trustWarmupMaxTime = 2400; s.trustEvalHorizon = 420; s.trustShockStart = 60;
    otherwise
        error('Unknown run mode.');
end

s.policyWeights = [0.50 0.20 0.30];
s.policyWeightSets = [0.60 0.15 0.25; 0.50 0.20 0.30; 0.40 0.25 0.35];
s.riskMatchTol = 0.01;
s.costMatchTol = 0.01;
s.policyEquivalenceTol = 0.01;
s.policyFixedLow = 0.25;
s.policyFixedHigh = 0.80;
s.policyGlobalFraction = 0.70;
s.policyLocalStarts = 6;
s.policyWallClockPoints = 50;
s.prccConvergenceN = unique(min([160 320 640],s.lhsN));
s.jointDenominatorTol = 1e-6;
s.effectAbsoluteTol = 1e-3;
s.effectRelativeTol = 0.01;
s.matchedCapacityTol = 2e-3;
s.robustnessAigcShockStrength = 0.50;
s.factorialSeed = 2026072301;
s.sensitivitySeed = 2026072302;
s.policySeed = 2026072303;
end
