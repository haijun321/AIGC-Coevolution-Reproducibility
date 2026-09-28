function p = default_parameters()
%DEFAULT_PARAMETERS Mechanism-calibration values, not empirical estimates.

% Detection, action queue, and provenance chain
p.s = 0.82;
p.h = 0.84;
p.f = 0.05;
p.c = 0.82;
p.r = 0.86;
p.chi = 0.76;
p.eD0 = 0.12;
p.eL0 = 0.12;
p.eMax = 0.85;
p.rhoAuditD = 0.18;
p.rhoAuditL = 0.10;
p.omegaEvasionE = 0.35;
p.rhoPenalty = 0.10;
p.kDetect = 1.00;
p.kAction = 0.85;
p.handleWindow = 1.00;
p.omegaA = 1.20;
p.deltaA = 0.12;
p.kappaIn = 1.00;
p.kappaSp = 1.00;
p.kappaRm = 1.00;
p.kLabel = 0.42;
p.deltaLabel = 0.15;
p.deltaCross = 0.06;

% Content quality and user identification
p.qC = 0.90;
p.qS = 0.35;
p.nu0 = 0.18;
p.nu1 = 0.72;

% Producer payoffs
p.RC = 1.15;
p.RS = 1.05;
p.thetaT_prod = 0.45;
p.thetaI = 0.55;
p.BC = 0.28;
p.CC = 0.42;
p.CS = 0.18;
p.FP = 0.80;
p.LP = 0.42;
p.Ce = 0.18;
p.Cregen = 0.12;
p.CfpP = 0.22;

% Platform payoffs
p.RF = 1.00;
p.BWF = 0.30;
p.gQ = 0.55;
p.gT = 0.48;
p.CR = 0.34;
p.CW = 0.10;
p.CfpF = 0.24;
p.LF = 0.75;
p.FF = 0.45;

% User payoffs
p.BU = 1.00;
p.CV = 0.06;
p.LU = 1.35;
p.BD = 0.025;

% Risk dynamics
p.lambda0 = 0.26;
p.psiE = 0.80;
p.beta0 = 0.46;
p.gamma0 = 0.10;
p.gammaPlatform = 0.45;
p.gammaUser = 0.30;
p.thetaT_share = 0.24;
p.aigcHillK = 0.35;

% Positive and negative trust experience
p.alpha = 0.18;
p.delta = 0.58;
p.xi = 0.28;
p.mu = 0.14;
p.kappa = 0.05;
p.omegaG = 0.45;
p.omegaD = 0.65;
p.omegaI = 0.35;
p.omegaF = 0.45;
p.omegaM = 0.55;
p.omegaETrust = 0.25;
p.kB = 12.0;
p.thetaB = 0.34;
p.phiL = 0.75;
p.phiH = 1.75;
p.hillN = 4.0;

% Dynamic audit controller
p.auditSpeed = 0.52;
p.etaI = 1.80;
p.etaT = 1.20;
p.etaA = 0.55;
p.etaC = 0.80;
p.Istar = 0.25;
p.Tstar = 0.65;
p.Astar = 0.15;
p.Cstar = 0.32;
p.uRef = 0.70;

% AIGC adaptive regeneration
p.rhoE = 0.32;
p.rhoEPenalty = 0.14;
p.rhoEAnti = 0.35;
p.rhoEDecay = 0.08;
p.antiE = 0.15;

% Governance cost components
p.costLabel = 0.07;
p.costBacklog = 0.08;
p.costProvenance = 0.03;
p.costAntiEvasion = 0.08;
p.costDynamicSystem = 0.10;
p.costFixedSystem = 0.035;
p.costPolicyImplementation = 0.00;

% Symmetric, payoff-independent strategy switching
p.epsP = 0.005;
p.epsF = 0.005;
p.epsU = 0.005;

% Exogenous reference values used by reduced models
p.Iref = 0.30;
p.Tref = 0.60;
p.Mref = 0.60;
p.Aref = 0.12;
p.Lref = 0.40;
p.Eref = 0.10;
end
