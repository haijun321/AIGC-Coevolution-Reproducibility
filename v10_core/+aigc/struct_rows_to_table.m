function T = struct_rows_to_table(rows)
%STRUCT_ROWS_TO_TABLE Convert scalar-struct array to table robustly.
if isempty(rows), T=table(); return; end
T=struct2table(rows,'AsArray',true);
end
