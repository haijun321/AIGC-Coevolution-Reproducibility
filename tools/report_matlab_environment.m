function report_matlab_environment(outputFile)
%REPORT_MATLAB_ENVIRONMENT Print or save the local MATLAB environment.
%   report_matlab_environment() prints the report to the Command Window.
%   report_matlab_environment('file.txt') also saves the report to a file.

if nargin < 1
    outputFile = '';
end

lines = {};
lines{end+1} = sprintf('MATLAB version: %s', version); %#ok<AGROW>
try
    lines{end+1} = sprintf('MATLAB release: %s', version('-release')); %#ok<AGROW>
catch
    lines{end+1} = 'MATLAB release: unavailable'; %#ok<AGROW>
end
lines{end+1} = sprintf('Architecture: %s', computer); %#ok<AGROW>
try
    lines{end+1} = sprintf('Computer detail: %s', computer('arch')); %#ok<AGROW>
catch
end
try
    lines{end+1} = sprintf('Operating system: %s', system_dependent('getos')); %#ok<AGROW>
catch
    lines{end+1} = 'Operating system: unavailable via system_dependent'; %#ok<AGROW>
end
lines{end+1} = '';
lines{end+1} = 'Installed products (ver):'; %#ok<AGROW>

v = ver;
for k = 1:numel(v)
    if isfield(v, 'Release') && ~isempty(v(k).Release)
        lines{end+1} = sprintf('- %s | Version %s | %s', v(k).Name, v(k).Version, v(k).Release); %#ok<AGROW>
    else
        lines{end+1} = sprintf('- %s | Version %s', v(k).Name, v(k).Version); %#ok<AGROW>
    end
end

report = strjoin(lines, newline);
fprintf('%s\n', report);

if ~isempty(outputFile)
    fid = fopen(outputFile, 'w');
    if fid < 0
        error('Could not open output file: %s', outputFile);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', report);
end
end
