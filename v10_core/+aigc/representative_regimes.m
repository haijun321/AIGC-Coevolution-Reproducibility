function regimes = representative_regimes(pBase)
%REPRESENTATIVE_REGIMES Four targeted parameter regions for re-certification.
template = struct('name','','description','','expectedClass','','p',pBase,'X0',[]);
regimes = repmat(template,4,1);

p1 = pBase;
p1.epsP = 0.025; p1.epsF = 0.025; p1.epsU = 0.025;
p1.alpha = 0.22; p1.delta = 0.48; p1.etaC = 1.20;
p1.auditSpeed=0.32; p1.etaI=1.25; p1.etaT=0.85; p1.etaA=0.35;
regimes(1).name = 'R1_BalancedInterior';
regimes(1).description = 'Balanced interior-equilibrium candidate';
regimes(1).expectedClass = 'interior_equilibrium';
regimes(1).p = p1;
regimes(1).X0 = [0.42;0.46;0.42;0.36;0.58;0.58;0.62;0.15;0.38;0.12];

% R2 is intentionally calibrated as a slow-feedback, high-capacity regime.
% The lower controller speed/gain separates it from the R3 oscillatory case.
p2 = pBase;
p2.s=0.95; p2.h=0.95; p2.c=0.95; p2.r=0.95; p2.chi=0.92;
p2.FP=1.15; p2.BC=0.45; p2.CR=0.22; p2.lambda0=0.13;
p2.beta0=0.27; p2.antiE=0.40; p2.rhoE=0.10; p2.psiE=0.25;
p2.auditSpeed=0.14; p2.etaI=0.70; p2.etaT=0.45; p2.etaA=0.18; p2.etaC=1.45;
p2.Istar=0.18; p2.Tstar=0.72; p2.Cstar=0.30;
regimes(2).name = 'R2_LowRiskHighTrust';
regimes(2).description = 'Low-risk high-trust stable-governance candidate';
regimes(2).expectedClass = 'interior_equilibrium';
regimes(2).p = p2;
regimes(2).X0 = [0.58;0.68;0.60;0.18;0.72;0.70;0.72;0.06;0.62;0.03];

p3 = pBase;
p3.auditSpeed=0.95; p3.etaI=3.0; p3.etaT=2.2; p3.etaA=1.0;
p3.etaC=0.35; p3.lambda0=0.30; p3.beta0=0.52;
p3.mu=0.20; p3.kappa=0.035;
regimes(3).name = 'R3_PeriodicCandidate';
regimes(3).description = 'High-speed high-gain audit-cycle candidate';
regimes(3).expectedClass = 'stable_cycle';
regimes(3).p = p3;
regimes(3).X0 = [0.40;0.46;0.40;0.42;0.52;0.60;0.45;0.20;0.35;0.15];

p4 = pBase;
p4.RC=0.92; p4.CC=0.58; p4.BC=0.06; p4.FP=0.22;
p4.CR=0.72; p4.gQ=0.30; p4.gT=0.22;
p4.lambda0=0.46; p4.beta0=0.72; p4.s=0.50; p4.h=0.50;
p4.c=0.50; p4.r=0.50; p4.chi=0.42; p4.antiE=0.03;
p4.rhoE=0.62; p4.psiE=1.55; p4.epsP=0.015; p4.epsF=0.015; p4.epsU=0.015;
p4.etaC=2.8; p4.Cstar=0.25;
regimes(4).name = 'R4_RiskDominantBoundary';
regimes(4).description = 'High-risk governance-capacity-limited candidate';
regimes(4).expectedClass = 'boundary_equilibrium';
regimes(4).p = p4;
regimes(4).X0 = [0.25;0.25;0.28;0.62;0.35;0.45;0.72;0.30;0.20;0.35];
end
