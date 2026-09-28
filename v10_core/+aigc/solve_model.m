function sol = solve_model(X0,p,mode,opt)
%SOLVE_MODEL Integrate the selected model with a common interface.
X0 = aigc.clip01(X0(:));
if numel(X0)~=10, error('X0 must have length 10.'); end
switch lower(opt.solver)
    case 'rk4'
        sol = aigc.rk4_projected(X0,p,mode,opt);
        sol.rawMinState=min(sol.X,[],'all');
        sol.rawMaxState=max(sol.X,[],'all');
    case 'ode45'
        odeOpt=odeset('RelTol',opt.odeRelTol,'AbsTol',opt.odeAbsTol,'NonNegative',1:10);
        tspan=output_times(opt);
        [t,X]=ode45(@(t,x) aigc.model_rhs(t,x,p,mode),tspan,X0,odeOpt);
        sol.t=t; sol.rawMinState=min(X,[],'all'); sol.rawMaxState=max(X,[],'all');
        sol.X=aigc.clip01(X); sol.status='Completed';
    case 'ode15s'
        odeOpt=odeset('RelTol',opt.odeRelTol,'AbsTol',opt.odeAbsTol,'NonNegative',1:10);
        tspan=output_times(opt);
        [t,X]=ode15s(@(t,x) aigc.model_rhs(t,x,p,mode),tspan,X0,odeOpt);
        sol.t=t; sol.rawMinState=min(X,[],'all'); sol.rawMaxState=max(X,[],'all');
        sol.X=aigc.clip01(X); sol.status='Completed';
    otherwise
        error('Unknown solver: %s',opt.solver);
end
sol.finalState=sol.X(end,:)';
sol.finalTime=sol.t(end);
end

function tspan=output_times(opt)
if isfield(opt,'forceOutputGrid') && opt.forceOutputGrid
    tspan=(opt.t0:opt.outputStep:opt.tEnd)';
    if isempty(tspan) || tspan(end)<opt.tEnd-10*eps(max(1,opt.tEnd))
        tspan=[tspan;opt.tEnd];
    else
        tspan(end)=opt.tEnd;
    end
else
    tspan=[opt.t0 opt.tEnd];
end
end
