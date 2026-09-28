function opt = default_options(runMode)
%DEFAULT_OPTIONS Numerical integration, certification, and recovery settings.
opt.t0 = 0;
opt.solver = 'ode45';
opt.project = true;
opt.allowEarlyStop = true;
opt.steadyTol = 1e-9;
opt.derivativeTol = 1e-8;
opt.tailFraction = 0.25;
opt.odeRelTol = 1e-9;
opt.odeAbsTol = 1e-11;
opt.fdStep = 1e-6;
opt.forceOutputGrid = true;
opt.tailFractions = [0.25 0.40 0.50];

% Equilibrium/cycle certification.
opt.tauEq = 1e-4;
opt.tauF = 1e-6;
opt.tauBoundary = 1e-4;
opt.tauClip = 1e-4;
opt.minCycleAmplitude = 2e-3;
opt.minCycles = 8;
opt.maxPeriodCV = 0.02;
opt.maxAmplitudeDrift = 0.05;
opt.tailMeanDriftTol = 1e-3;

% Toolbox-free equilibrium solver.
opt.eqMaxIterations = 80;
opt.eqSolveTol = 1e-9;
opt.eqAcceptTol = 1e-6;
opt.spectralTolerance = 1e-4;

% Shock recovery.
opt.recoveryTolerance = 0.015;
opt.recoveryHold = 15;
opt.X0 = [0.40;0.45;0.40;0.35;0.60;0.60;0.65;0.12;0.40;0.10];

switch lower(runMode)
    case 'preview'
        opt.tEnd = 180; opt.h = 0.10; opt.outputStep = 0.10; opt.stableK = 40;
        opt.longRunSchedule = [180 360 600];
    case 'quick'
        opt.tEnd = 360; opt.h = 0.05; opt.outputStep = 0.05; opt.stableK = 100;
        opt.longRunSchedule = [360 720 1200];
    case 'full'
        opt.tEnd = 600; opt.h = 0.025; opt.outputStep = 0.025; opt.stableK = 240;
        opt.longRunSchedule = [600 1200 2400];
    otherwise
        error('Unknown run mode.');
end
end
