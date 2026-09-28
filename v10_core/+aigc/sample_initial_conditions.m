function X0s = sample_initial_conditions(baseX,n,spread,seed)
%SAMPLE_INITIAL_CONDITIONS Common bounded initial conditions.
if nargin<4, seed=20260723; end
state=rng; cleanup=onCleanup(@() rng(state)); %#ok<NASGU>
rng(seed,'twister');
baseX=baseX(:)';
X0s=repmat(baseX,n,1)+spread*(2*rand(n,10)-1);
X0s=min(max(X0s,0.02),0.98);
if n>=1, X0s(1,:)=baseX; end
end
