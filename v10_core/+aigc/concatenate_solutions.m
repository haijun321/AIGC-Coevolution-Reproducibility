function sol = concatenate_solutions(solA,solB)
%CONCATENATE_SOLUTIONS Join two solution segments with one shared endpoint.
if isempty(solA) || ~isfield(solA,'t') || isempty(solA.t), sol=solB; return; end
if isempty(solB) || ~isfield(solB,'t') || isempty(solB.t), sol=solA; return; end
startIdx=1;
if abs(solB.t(1)-solA.t(end))<=100*eps(max(1,abs(solA.t(end))))
    startIdx=2;
end
sol.t=[solA.t;solB.t(startIdx:end)];
sol.X=[solA.X;solB.X(startIdx:end,:)];
sol.finalState=sol.X(end,:)';
sol.finalTime=sol.t(end);
sol.status=solB.status;
if isfield(solA,'rawMinState') && isfield(solB,'rawMinState')
    sol.rawMinState=min(solA.rawMinState,solB.rawMinState);
    sol.rawMaxState=max(solA.rawMaxState,solB.rawMaxState);
end
end
