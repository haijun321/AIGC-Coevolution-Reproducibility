function rows = append_struct_row(rows,row)
%APPEND_STRUCT_ROW Append one scalar struct to a struct array safely.
%   This helper fixes MATLAB's "Subscripted assignment between dissimilar
%   structures" error when a result container starts as struct([]).
%
%   It also normalizes field order before appending. A true field-name
%   mismatch is reported with the missing/extra fields so that a schema
%   error cannot be silently hidden.

if ~isstruct(rows)
    error('aigc:append_struct_row:ContainerType', ...
        'rows must be a struct array, but received %s.',class(rows));
end
if ~isstruct(row) || ~isscalar(row)
    error('aigc:append_struct_row:RowType', ...
        'row must be a scalar struct.');
end

if isempty(rows)
    rows = row;
    return;
end

containerFields = fieldnames(rows);
rowFields = fieldnames(row);
missingFromRow = setdiff(containerFields,rowFields,'stable');
extraInRow = setdiff(rowFields,containerFields,'stable');
if ~isempty(missingFromRow) || ~isempty(extraInRow)
    error('aigc:append_struct_row:SchemaMismatch', ...
        ['Struct-row schema mismatch. Missing from new row: [%s]. ' ...
         'Extra in new row: [%s].'], ...
        strjoin(missingFromRow,', '),strjoin(extraInRow,', '));
end

% MATLAB requires identical field order for scalar-struct assignment.
row = orderfields(row,rows(1));
rows(end+1,1) = row;
end
