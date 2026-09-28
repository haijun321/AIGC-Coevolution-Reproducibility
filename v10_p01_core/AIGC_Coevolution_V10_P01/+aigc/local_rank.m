function r = local_rank(x)
%LOCAL_RANK Average ranks with ties, no Statistics Toolbox.
x=x(:); [xs,ord]=sort(x); r=zeros(size(x));
i=1; n=numel(x);
while i<=n
    j=i;
    while j<n && xs(j+1)==xs(i), j=j+1; end
    rr=(i+j)/2; r(ord(i:j))=rr; i=j+1;
end
end
