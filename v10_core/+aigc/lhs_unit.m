function U = lhs_unit(n,d,seed)
%LHS_UNIT Latin hypercube samples in (0,1), no toolbox.
if nargin<3, seed=20260723; end
state=rng; cleanup=onCleanup(@() rng(state)); %#ok<NASGU>
rng(seed,'twister'); U=zeros(n,d);
for j=1:d
    perm=randperm(n)';
    U(:,j)=(perm-rand(n,1))/n;
end
end
