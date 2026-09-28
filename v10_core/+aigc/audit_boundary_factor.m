function f = audit_boundary_factor(u,mode)
switch lower(mode.auditBoundaryForm)
    case 'logistic'
        f = u*(1-u);
    case 'sqrt'
        f = sqrt(max(u*(1-u),0));
    case 'projected'
        % Directional projection is applied in model_terms after the raw
        % control direction is known.
        f = 1;
    otherwise
        error('Unknown audit boundary form: %s',mode.auditBoundaryForm);
end
end
