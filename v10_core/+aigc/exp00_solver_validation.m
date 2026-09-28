function exp00_solver_validation(p,opt,settings,outputRoot) %#ok<INUSD>
%EXP00_SOLVER_VALIDATION Solver agreement and semantic-invariant gates.
outDir=fullfile(outputRoot,'Exp00_solver_validation'); aigc.ensure_dir(outDir);
mode=aigc.full_mode();
solvers={'rk4','ode45','ode15s'}; sols=cell(3,1); evals=cell(3,1);
opt0=opt; opt0.allowEarlyStop=false;
for i=1:3
    oi=opt0; oi.solver=solvers{i};
    fprintf('Exp00 solver %s...\n',solvers{i});
    sols{i}=aigc.solve_model(opt.X0,p,mode,oi);
    evals{i}=aigc.evaluate_solution(sols{i},p,mode);
end

tGrid=linspace(opt.t0,opt.tEnd,1001)'; Xgrid=cell(3,1);
for i=1:3, Xgrid{i}=interp1(sols{i}.t,sols{i}.X,tGrid,'pchip'); end
rows=struct([]);
for i=1:3
    for j=i+1:3
        row=struct(); row.SolverA=solvers{i}; row.SolverB=solvers{j};
        row.MaxTrajectoryError=max(abs(Xgrid{i}-Xgrid{j}),[],'all');
        row.FinalStateError=max(abs(Xgrid{i}(end,:)-Xgrid{j}(end,:)));
        rows=aigc.append_struct_row(rows,row);
    end
end
Tpair=aigc.struct_rows_to_table(rows); writetable(Tpair,fullfile(outDir,'solver_pairwise_errors.csv'));

semRows=struct([]);
for i=1:3
    row=struct(); e=evals{i}; row.Solver=solvers{i};
    % Audit the solver's unprojected output.  The stored state is clipped only
    % after these extrema have been recorded, so this gate cannot hide an ODE
    % overshoot by inspecting the projected trajectory alone.
    row.MinState=sols{i}.rawMinState; row.MaxState=sols{i}.rawMaxState;
    row.MinPhiIn=min(e.phiIn); row.MinPhiAct=min(e.phiAct);
    row.MinPAct=min(e.pAct); row.MaxPAct=max(e.pAct);
    row.MinPHandle=min(e.pHandle); row.MaxPHandle=max(e.pHandle);
    row.MinStageProbability=min([e.pIn;e.pSp;e.pRm]);
    row.MaxStageProbability=max([e.pIn;e.pSp;e.pRm]);
    [row.MaxSemanticError,row.MaxEq26Error]=semantic_error(sols{i},p,mode);
    semRows=aigc.append_struct_row(semRows,row);
end
Tsem=aigc.struct_rows_to_table(semRows); writetable(Tsem,fullfile(outDir,'semantic_invariant_checks.csv'));

% Hard gates: these test numerical reliability, not the substantive claims.
assert(max(Tpair.MaxTrajectoryError)<1e-4,'Solver trajectory disagreement exceeds 1e-4.');
assert(max(Tpair.FinalStateError)<1e-6,'Solver final-state disagreement exceeds 1e-6.');
assert(all(Tsem.MinState>=-1e-10) && all(Tsem.MaxState<=1+1e-10),'State invariance failed.');
assert(all(Tsem.MinPhiIn>=-1e-10) && all(Tsem.MinPhiAct>=-1e-10),'Queue flows must be nonnegative.');
assert(all(Tsem.MinPAct>=-1e-10) && all(Tsem.MaxPAct<=1+1e-10),'pAct must lie in [0,1].');
assert(all(Tsem.MinPHandle>=-1e-10) && all(Tsem.MaxPHandle<=1+1e-10),'pHandle must lie in [0,1].');
assert(all(Tsem.MinStageProbability>=-1e-10) && all(Tsem.MaxStageProbability<=1+1e-10), ...
    'Stage probabilities must lie in [0,1].');
assert(all(Tsem.MaxEq26Error<1e-10),'Equation (26) consistency failed.');
assert(all(Tsem.MaxSemanticError<1e-10),'Independent manuscript-code semantic check failed.');

Tr=table(tGrid,'VariableNames',{'time'});
for i=1:3
    Tr.([solvers{i} '_I'])=Xgrid{i}(:,4);
    Tr.([solvers{i} '_T'])=Xgrid{i}(:,5);
    Tr.([solvers{i} '_u'])=Xgrid{i}(:,7);
end
writetable(Tr,fullfile(outDir,'solver_trajectories_common_grid.csv'));

fig=figure('Visible','off','Color','w','Position',[100 100 1050 720]);
subplot(2,1,1); hold on;
for i=1:3, plot(tGrid,Xgrid{i}(:,4),'LineWidth',1.2); end
xlabel('Time'); ylabel('Risk I'); legend(solvers,'Location','best'); box on;
subplot(2,1,2); hold on;
for i=1:3, plot(tGrid,Xgrid{i}(:,5),'LineWidth',1.2); end
xlabel('Time'); ylabel('Trust T'); legend(solvers,'Location','best'); box on;
aigc.save_figure(fig,fullfile(outDir,'fig_exp00_solver_agreement')); close(fig);
fprintf('Exp00 max trajectory error: %.3e\n',max(Tpair.MaxTrajectoryError));
end

function [maxErr,maxEq26]=semantic_error(sol,p,mode)
fields={'aDet','phiIn','phiAct','pHandle','pAct','pIn','pSp','pRm','Q0','DV','DD','D','Qexp','deltaPiU'};
maxErr=0; maxEq26=0;
for k=1:numel(sol.t)
    [~,a]=aigc.model_rhs(sol.t(k),sol.X(k,:)',p,mode);
    r=aigc.semantic_reference_terms(sol.t(k),sol.X(k,:)',p,mode);
    for j=1:numel(fields), maxErr=max(maxErr,abs(a.(fields{j})-r.(fields{j}))); end
    maxEq26=max(maxEq26,abs((r.piUV-r.piUD)-r.deltaPiU));
end
end
