function [p,source] = exp04_reference_parameters(pBase)
%EXP04_REFERENCE_PARAMETERS Frozen Exp04 R1 reference configuration.
% ========================================================================
% This helper is the single source of truth for the parameter regime used
% by the final SR Exp04 reproduction workflow.
%
% It intentionally does NOT depend on aigc.representative_regimes.m.
% The seven modifications below are the documented Exp04 R1 modifications
% used by the V10 experiment family and by the later three-branch
% comparability audit.
%
% Usage:
%       pBase = aigc.default_parameters();
%       [p,source] = aigc.exp04_reference_parameters(pBase);
%
% Frozen R1 modifications:
%       epsP  = 0.05
%       epsF  = 0.05
%       epsU  = 0.05
%       alpha = 0.30
%       delta = 0.40
%       etaC  = 4.00
%       Cstar = 0.25
%
% All remaining parameters are inherited unchanged from pBase.
% ========================================================================

if nargin < 1 || isempty(pBase)
    pBase = aigc.default_parameters();
end

required = {'epsP','epsF','epsU','alpha','delta','etaC','Cstar'};
for k = 1:numel(required)
    if ~isfield(pBase,required{k})
        error('Exp04 frozen R1 configuration: missing parameter field %s.', ...
            required{k});
    end
end

p = pBase;

% Frozen Exp04 R1 modifications.
p.epsP  = 0.05;
p.epsF  = 0.05;
p.epsU  = 0.05;
p.alpha = 0.30;
p.delta = 0.40;
p.etaC  = 4.00;
p.Cstar = 0.25;

% Hard validation: fail rather than silently drifting from the frozen setup.
tol = 1e-12;
assert(abs(p.epsP  - 0.05) < tol,'Frozen Exp04 parameter mismatch: epsP');
assert(abs(p.epsF  - 0.05) < tol,'Frozen Exp04 parameter mismatch: epsF');
assert(abs(p.epsU  - 0.05) < tol,'Frozen Exp04 parameter mismatch: epsU');
assert(abs(p.alpha - 0.30) < tol,'Frozen Exp04 parameter mismatch: alpha');
assert(abs(p.delta - 0.40) < tol,'Frozen Exp04 parameter mismatch: delta');
assert(abs(p.etaC  - 4.00) < tol,'Frozen Exp04 parameter mismatch: etaC');
assert(abs(p.Cstar - 0.25) < tol,'Frozen Exp04 parameter mismatch: Cstar');

source = 'frozen Exp04 R1 reference configuration';

end
