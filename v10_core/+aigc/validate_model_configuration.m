function validate_model_configuration(p,opt,settings)
%VALIDATE_MODEL_CONFIGURATION Fail early on invalid settings.
probFields = {'s','h','f','c','r','chi','eD0','eL0','eMax','qC','qS','nu0','nu1', ...
    'omegaG','phiL','Istar','Tstar','Astar','Cstar','uRef','antiE', ...
    'Iref','Tref','Mref','Aref','Lref','Eref'};
for k = 1:numel(probFields)
    name = probFields{k};
    v = p.(name);
    if ~isfinite(v) || v < 0 || v > 1.75
        error('Parameter %s=%.6g is outside its admissible calibration range.',name,v);
    end
end
unitFields = {'s','h','f','c','r','chi','eD0','eL0','eMax','qC','qS','nu0','nu1', ...
    'omegaG','Istar','Tstar','Astar','uRef','antiE','Iref','Tref','Mref','Aref','Lref','Eref'};
for k = 1:numel(unitFields)
    v = p.(unitFields{k});
    if v < 0 || v > 1, error('%s must be in [0,1].',unitFields{k}); end
end
if p.qC <= p.qS, error('qC must exceed qS.'); end
if p.handleWindow<=0 || ~isfinite(p.handleWindow), error('handleWindow must be positive.'); end
stageFields={'kappaIn','kappaSp','kappaRm'};
for k=1:numel(stageFields)
    if ~isfinite(p.(stageFields{k})) || p.(stageFields{k})<0
        error('%s must be finite and nonnegative.',stageFields{k});
    end
end
if p.phiH <= p.phiL || p.phiL <= 0, error('Require 0 < phiL < phiH.'); end
if numel(opt.X0) ~= 10 || any(opt.X0 < 0) || any(opt.X0 > 1)
    error('X0 must be ten-dimensional and inside [0,1]^10.');
end
if opt.outputStep<=0 || opt.h<=0, error('Integration/output steps must be positive.'); end
if any(diff(opt.longRunSchedule)<=0) || opt.longRunSchedule(1)<opt.tEnd
    error('longRunSchedule must be increasing and start at or after tEnd.');
end
if settings.policyBudget < 4, error('policyBudget is too small.'); end
if settings.policyRepeats < 1, error('policyRepeats must be positive.'); end
if settings.policyGlobalFraction<=0 || settings.policyGlobalFraction>1
    error('policyGlobalFraction must lie in (0,1].');
end
if settings.certificationMaxTime < opt.tEnd, error('certificationMaxTime must be >= opt.tEnd.'); end
if settings.phaseMaxTime < opt.tEnd, error('phaseMaxTime must be >= opt.tEnd.'); end
if settings.trustEvalHorizon <= settings.trustShockStart, error('Trust evaluation horizon must exceed shock start.'); end
if settings.morrisLevels<4 || mod(settings.morrisLevels,2)~=0
    error('Morris levels must be an even integer of at least four.');
end
if settings.lhsN<max(settings.prccConvergenceN)
    error('lhsN must cover every requested PRCC convergence sample size.');
end
end
