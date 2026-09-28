function out = mean_struct(S,fields)
%MEAN_STRUCT Mean selected numeric fields across scalar-struct array.
out=struct();
for i=1:numel(fields)
    vals=arrayfun(@(s) s.(fields{i}),S);
    out.(fields{i})=mean(vals,'omitnan');
end
end
