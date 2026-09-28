function [U,order,step] = morris_trajectory(d,levels,seed)
%MORRIS_TRAJECTORY Generate one standard one-factor-at-a-time Morris path.
if mod(levels,2)~=0 || levels<4, error('levels must be even and >=4.'); end
state=rng; cleanup=onCleanup(@() rng(state)); %#ok<NASGU>
rng(seed,'twister'); delta=levels/(2*(levels-1)); grid=linspace(0,1,levels);
direction=2*(rand(1,d)>0.5)-1; start=zeros(1,d);
low=grid(grid<=1-delta+10*eps); high=grid(grid>=delta-10*eps);
for j=1:d
    if direction(j)>0, start(j)=low(randi(numel(low)));
    else, start(j)=high(randi(numel(high))); end
end
order=randperm(d); U=zeros(d+1,d); U(1,:)=start; step=zeros(d,1);
for k=1:d
    j=order(k); U(k+1,:)=U(k,:); step(k)=direction(j)*delta;
    U(k+1,j)=U(k,j)+step(k);
end
U=min(max(U,0),1);
end
