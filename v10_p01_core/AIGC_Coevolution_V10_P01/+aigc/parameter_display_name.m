function label = parameter_display_name(name)
%PARAMETER_DISPLAY_NAME Manuscript-consistent LaTeX label for code fields.
switch char(name)
    case 's', label='$s$';
    case 'h', label='$h$';
    case 'f', label='$f$';
    case 'c', label='$c$';
    case 'r', label='$r$';
    case 'chi', label='$\chi$';
    case 'eD0', label='$e_{D0}$';
    case 'eL0', label='$e_{L0}$';
    case 'FP', label='$F_P$';
    case 'CR', label='$C_R$';
    case 'lambda0', label='$\lambda_0$';
    case 'beta0', label='$\beta_0$';
    case 'alpha', label='$\alpha$';
    case 'delta', label='$\delta$';
    case 'mu', label='$\mu$';
    case 'rhoE', label='$\rho_E$';
    case 'psiE', label='$\psi_E$';
    case 'antiE', label='$a_E$';
    case 'auditSpeed', label='$\sigma_u$';
    case 'etaI', label='$\eta_I$';
    case 'etaC', label='$\eta_C$';
    case 'omegaG', label='$\omega_G$';
    otherwise, label=['$\mathrm{' strrep(char(name),'_','\_') '}$'];
end
end
