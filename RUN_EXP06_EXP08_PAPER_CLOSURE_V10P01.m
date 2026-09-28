function outputRoot = RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01(runMode)
%RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01_SR_V4
% Final SR runner for V10-P0.1 Exp06 + Exp08 (fixed archive-relative path).
%
% This runner MUST use the V10-P0.1 source tree, not ordinary v10_core.
% It refuses any +aigc package missing the P0.1-specific files.
%
% Usage:
%   RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01_SR_V4('preview')
%   RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01_SR_V4('quick')
%   RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01_SR_V4('full')

if nargin < 1 || isempty(runMode)
    runMode = 'preview';
end
runMode = lower(char(runMode));
if ~ismember(runMode,{'preview','quick','full'})
    error('runMode must be preview, quick, or full.');
end

clc;
close all force;
rehash;

thisFile = mfilename('fullpath');
if isempty(thisFile)
    startDir = pwd;
else
    startDir = fileparts(thisFile);
end

%% Locate the frozen P0.1 root deterministically -- NO GUI selection.
%
% Expected SR archive layout:
%
% AIGC_Coevolution_SR_Reproducibility/
% |-- RUN_EXP06_EXP08_PAPER_CLOSURE_V10P01_SR_V4.m
% |-- v10_p01_core/
% |   `-- AIGC_Coevolution_V10_P01/
% |       |-- +aigc/
% |       `-- CHECK_PACKAGE_V10.m
% `-- v10_core/
%
% The resolver also accepts v10_p01_core/+aigc directly, but it will never
% fall back to v10_core and it will never open uigetdir.
[root,archiveRoot] = locate_p01_root_fixed(startDir);

if isempty(root)
    error(['Cannot locate the frozen V10-P0.1 source tree automatically.\n', ...
           'Expected one of these layouts below the archive root:\n', ...
           '  v10_p01_core/AIGC_Coevolution_V10_P01/+aigc\n', ...
           '  v10_p01_core/+aigc\n', ...
           'Do not use v10_core for Exp06/Exp08 P0.1.']);
end

fprintf('\nArchive root      : %s\n',archiveRoot);

%% Activate only this P0.1 root
remove_competing_aigc_roots(root);
addpath(root,'-begin');
addpath(startDir,'-begin');
rehash;
clear functions; %#ok<CLFUNC>
addpath(root,'-begin');
addpath(startDir,'-begin');
rehash;

%% Hard P0.1 validation
validate_p01_source_tree(root);

fprintf('\n=== Exp06 + Exp08 P0.1 | %s ===\n',upper(runMode));
fprintf('P0.1 Root        : %s\n',root);
fprintf('aigc.main        : %s\n',which('aigc.main'));
fprintf('RHS              : %s\n',which('aigc.model_rhs'));
fprintf('Exp06 audit      : %s\n',which('aigc.exp06_timescale_causal_audit'));
fprintf('Exp08 audit      : %s\n',which('aigc.exp08_nested_policy_comparison'));

warn_multi('aigc.main');
warn_multi('aigc.model_rhs');
warn_multi('aigc.exp06_timescale_causal_audit');
warn_multi('aigc.exp08_nested_policy_comparison');

cd(root);

%% Optional validator
checkFile = fullfile(root,'CHECK_PACKAGE_V10.m');
if exist(checkFile,'file') == 2
    fprintf('\n--- CHECK_PACKAGE_V10 ---\n');
    % IMPORTANT:
    % CHECK_PACKAGE_V10.m is a script and may contain CLEAR/CLEARVARS.
    % Running it directly here would execute it in this function workspace
    % and can delete runMode/root before the Exp06+Exp08 call.
    % Execute it inside an isolated helper workspace instead.
    run_package_check_isolated(checkFile);
else
    fprintf('\n[INFO] CHECK_PACKAGE_V10.m not found; hard P0.1 checks already passed.\n');
end

%% Run Exp06 + Exp08
fprintf('\n--- RUN Exp06 + Exp08 P0.1 ---\n');
outputRoot = aigc.main(runMode,[6 8]);
fprintf('\nOutput: %s\n',outputRoot);

d6 = fullfile(outputRoot,'Exp06_timescale_causal_audit');
d8 = fullfile(outputRoot,'Exp08_nested_policy_comparison');

if exist(d6,'dir') ~= 7
    error('Exp06 P0.1 output directory was not created: %s',d6);
end
if exist(d8,'dir') ~= 7
    error('Exp08 P0.1 output directory was not created: %s',d8);
end

showcsv(fullfile(d6,'experiment_quality_check.csv'),'EXP06 QUALITY');
showcsv(fullfile(d6,'exp06_critical_shift_summary.csv'),'EXP06 CRITICAL SHIFT');
showcsv(fullfile(d6,'exp06_time_domain_validation.csv'),'EXP06 TIME DOMAIN');
showcsv(fullfile(d6,'exp06_shared_equilibrium_branch_audit.csv'),'EXP06 SHARED-BRANCH AUDIT');

showcsv(fullfile(d8,'experiment_quality_check.csv'),'EXP08 QUALITY');
showcsv(fullfile(d8,'exp08_core_policy_comparison.csv'),'EXP08 CORE');
showcsv(fullfile(d8,'exp08_dynamic_budget_scaling.csv'),'EXP08 B/2B/4B');
showcsv(fullfile(d8,'exp08_total_policy_comparison.csv'),'EXP08 TOTAL');

testFile = fullfile(d8,'exp08_selected_policy_test_total.csv');
matchCandidates = { ...
    fullfile(d8,'exp08_matching_feasibility_total_expanded.csv'), ...
    fullfile(d8,'exp08_matching_feasibility_total.csv')};

matchFile = '';
for k=1:numel(matchCandidates)
    if exist(matchCandidates{k},'file') == 2
        matchFile = matchCandidates{k};
        break;
    end
end

nTest = NaN;
nMatch = NaN;

if exist(testFile,'file') == 2
    T = readtable(testFile,'VariableNamingRule','preserve');
    if ismember('Environment',T.Properties.VariableNames)
        nTest = numel(unique(string(T.Environment)));
    end
end

if ~isempty(matchFile)
    T = readtable(matchFile,'VariableNamingRule','preserve');
    if ismember('Environment',T.Properties.VariableNames)
        nMatch = numel(unique(string(T.Environment)));
    end
end

fprintf('\nExp08 held-out environments = %g\n',nTest);
fprintf('Exp08 matching CSV environments = %g\n',nMatch);

if isfinite(nTest) && isfinite(nMatch) && nTest ~= nMatch
    warning(['Matching denominator differs from held-out-test denominator. ' ...
             'Do not describe all matching rows as independent held-out tests.']);
end

fprintf('\nRecommended order: PREVIEW -> QUICK -> FULL.\n');
fprintf('IMPORTANT: always use v10_p01_core for final Exp06/Exp08 P0.1.\n');

end

%% ========================================================================
function [root,archiveRoot] = locate_p01_root_fixed(startDir)
%LOCATE_P01_ROOT_FIXED Resolve P0.1 source from the SR archive structure.
%
% No path guessing from aigc.* and no GUI interaction is used.  This avoids
% accidentally selecting ordinary v10_core after another experiment has
% modified the MATLAB path.

root = '';
archiveRoot = '';

% Step 1: find the enclosing reproducibility archive.
c = startDir;
for up = 1:12
    if exist(fullfile(c,'v10_p01_core'),'dir') == 7
        archiveRoot = c;
        break;
    end
    p = fileparts(c);
    if strcmp(p,c), break; end
    c = p;
end

% Also allow MATLAB to be launched with pwd at the archive root.
if isempty(archiveRoot)
    c = pwd;
    for up = 1:12
        if exist(fullfile(c,'v10_p01_core'),'dir') == 7
            archiveRoot = c;
            break;
        end
        p = fileparts(c);
        if strcmp(p,c), break; end
        c = p;
    end
end

if isempty(archiveRoot)
    return;
end

container = fullfile(archiveRoot,'v10_p01_core');

% Step 2: test the known frozen layouts first.
candidates = { ...
    fullfile(container,'AIGC_Coevolution_V10_P01'), ...
    container};

for k = 1:numel(candidates)
    if is_valid_p01_root(candidates{k})
        root = candidates{k};
        return;
    end
end

% Step 3: tolerate one extra packaging folder inside v10_p01_core.
D = dir(container);
for k = 1:numel(D)
    if ~D(k).isdir || strcmp(D(k).name,'.') || strcmp(D(k).name,'..')
        continue;
    end
    cand = fullfile(container,D(k).name);
    if is_valid_p01_root(cand)
        root = cand;
        return;
    end
end
end

function tf = is_valid_p01_root(root)
tf = false;
if isempty(root) || exist(root,'dir') ~= 7
    return;
end

required = { ...
    'main.m', ...
    'model_rhs.m', ...
    'default_parameters.m', ...
    'default_options.m', ...
    'experiment_settings.m', ...
    'exp06_timescale_causal_audit.m', ...
    'exp08_nested_policy_comparison.m'};

pkg = fullfile(root,'+aigc');
if exist(pkg,'dir') ~= 7
    return;
end

for k=1:numel(required)
    if exist(fullfile(pkg,required{k}),'file') ~= 2
        return;
    end
end

tf = true;
end

function print_missing_p01_files(root)
fprintf(2,'\nP0.1 source-tree audit for:\n  %s\n',root);

required = { ...
    'main.m', ...
    'model_rhs.m', ...
    'default_parameters.m', ...
    'default_options.m', ...
    'experiment_settings.m', ...
    'exp06_timescale_causal_audit.m', ...
    'exp08_nested_policy_comparison.m'};

for k=1:numel(required)
    f = fullfile(root,'+aigc',required{k});
    if exist(f,'file') == 2
        fprintf('  [OK]      +aigc/%s\n',required{k});
    else
        fprintf(2,'  [MISSING] +aigc/%s\n',required{k});
    end
end
fprintf('\n');
end

function validate_p01_source_tree(root)
if ~is_valid_p01_root(root)
    print_missing_p01_files(root);
    error('Incomplete V10-P0.1 source tree.');
end

pkg = fullfile(root,'+aigc');

mainText = fileread(fullfile(pkg,'main.m'));
if ~contains(mainText,'exp06_timescale_causal_audit')
    error(['Selected +aigc/main.m does not reference ', ...
           'exp06_timescale_causal_audit. This is not final P0.1.']);
end
if ~contains(mainText,'exp08_nested_policy_comparison')
    error(['Selected +aigc/main.m does not reference ', ...
           'exp08_nested_policy_comparison. This is not final P0.1.']);
end

% Validate the P0.1 experiment modules themselves.  These checks are much
% more reliable than demanding implementation-specific token names inside
% model_rhs.m.
exp06Text = fileread(fullfile(pkg,'exp06_timescale_causal_audit.m'));
exp08Text = fileread(fullfile(pkg,'exp08_nested_policy_comparison.m'));

exp06Markers = {'exp06TimeScaleVariants','exp06SharedResidualTol','exp06CriticalDeltas'};
for k=1:numel(exp06Markers)
    if ~contains(exp06Text,exp06Markers{k})
        error(['Selected exp06_timescale_causal_audit.m lacks marker %s. ', ...
               'This does not match the final P0.1 audit module.'],exp06Markers{k});
    end
end

exp08Markers = {'policyBudgetMultipliers','policyNestedTrajectoryTol'};
for k=1:numel(exp08Markers)
    if ~contains(exp08Text,exp08Markers{k})
        error(['Selected exp08_nested_policy_comparison.m lacks marker %s. ', ...
               'This does not match the final P0.1 audit module.'],exp08Markers{k});
    end
end

% Do NOT require literal timeScaleA/timeScaleL/timeScaleM tokens in
% model_rhs.m.  The final P0.1 Exp06 audit applies its time-scale variants
% through the audit/configuration layer; therefore literal token checks in
% the RHS are not a valid source-lineage test.  What matters here is that
% the selected model_rhs.m is resolved from the same frozen P0.1 package.
rhsFile = fullfile(pkg,'model_rhs.m');
if exist(rhsFile,'file') ~= 2
    error('Missing P0.1 model_rhs.m: %s',rhsFile);
end

settingsText = fileread(fullfile(pkg,'experiment_settings.m'));
requiredSettings = { ...
    'exp06TimeScaleVariants', ...
    'exp06SharedResidualTol', ...
    'exp06CriticalDeltas', ...
    'policyBudgetMultipliers', ...
    'policyNestedTrajectoryTol'};

for k=1:numel(requiredSettings)
    if ~contains(settingsText,requiredSettings{k})
        error(['Selected experiment_settings.m lacks %s. ', ...
               'This is not the final V10-P0.1 configuration.'],requiredSettings{k});
    end
end

expected = { ...
    'aigc.main','main.m'; ...
    'aigc.model_rhs','model_rhs.m'; ...
    'aigc.exp06_timescale_causal_audit','exp06_timescale_causal_audit.m'; ...
    'aigc.exp08_nested_policy_comparison','exp08_nested_policy_comparison.m'};

for k=1:size(expected,1)
    resolved = which(expected{k,1});
    target = fullfile(pkg,expected{k,2});
    if isempty(resolved) || ~same_path(resolved,target)
        error(['MATLAB path conflict: %s resolves to\n  %s\nExpected:\n  %s'], ...
            expected{k,1},resolved,target);
    end
end

fprintf('\nP0.1 source-lineage checks: PASS\n');
end

function remove_competing_aigc_roots(selectedRoot)
functionsToCheck = { ...
    'aigc.main', ...
    'aigc.model_rhs', ...
    'aigc.exp06_timescale_causal_audit', ...
    'aigc.exp08_nested_policy_comparison'};

selectedRoot = normalize_path(selectedRoot);
roots = {};

for i=1:numel(functionsToCheck)
    hits = which(functionsToCheck{i},'-all');
    if ischar(hits), hits={hits}; end
    for j=1:numel(hits)
        roots{end+1} = fileparts(fileparts(hits{j})); %#ok<AGROW>
    end
end

if isempty(roots), return; end
roots = unique(roots,'stable');

for k=1:numel(roots)
    r = roots{k};
    if ~strcmpi(normalize_path(r),selectedRoot)
        try
            rmpath(r);
            fprintf('[PATH] Removed competing AIGC root: %s\n',r);
        catch
        end
    end
end
rehash;
end

function tf = same_path(a,b)
tf = strcmpi(normalize_path(a),normalize_path(b));
end

function p = normalize_path(p)
p = char(p);
try
    p = char(java.io.File(p).getCanonicalPath());
catch
end
p = strrep(p,'/',filesep);
while numel(p)>1 && p(end)==filesep
    p(end)=[];
end
end

function run_package_check_isolated(checkFile)
%RUN_PACKAGE_CHECK_ISOLATED Execute a script without exposing caller state.
%
% CHECK_PACKAGE_V10.m is a script. Scripts run with RUN execute in the
% caller's workspace. If the script contains CLEAR or CLEARVARS, executing
% it directly inside the master runner can delete runMode/root and cause:
%
%   "Reference to cleared variable runMode."
%
% Running the script inside this helper confines those workspace side
% effects to this helper function.

if exist(checkFile,'file') ~= 2
    error('Package check file does not exist: %s',checkFile);
end

oldPwd = pwd;
cleanupPwd = onCleanup(@() cd(oldPwd)); %#ok<NASGU>

run(checkFile);

fprintf('[INFO] CHECK_PACKAGE_V10 completed in isolated workspace.\n');
end

function warn_multi(name)
h = which(name,'-all');
if ischar(h), h={h}; end
if numel(h)>1
    fprintf(2,'WARNING: multiple versions of %s on path:\n',name);
    for i=1:numel(h)
        fprintf(2,'  %s\n',h{i});
    end
end
end

function showcsv(f,titleText)
fprintf('\n--- %s ---\n',titleText);
if exist(f,'file') == 2
    disp(readtable(f,'VariableNamingRule','preserve'));
else
    fprintf('Not found: %s\n',f);
end
end
