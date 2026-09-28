function output = RUN_EXP04_FINAL_SR_V4()
%RUN_EXP04_FINAL_SR_V4
% ========================================================================
% Direct, archive-relative SR Exp04 reproduction runner.
%
% NO MANUAL FOLDER SELECTION IS REQUIRED.
%
% Expected archive layout:
%
% AIGC_Coevolution_SR_Reproducibility/
% |-- exp04_final_code/
% |   |-- RUN_EXP04_FINAL_SR_V4.m
% |   |-- exp04_aigc_specific.m
% |   |-- exp04_reference_parameters.m
% |   `-- EXP04_THREE_BRANCH_DYNAMICAL_COMPARABILITY_V10_SR.m
% |
% |-- v10_core/
% |   `-- +aigc/
% |
% `-- results/
%
% The resolver also tolerates one extra project folder inside v10_core,
% e.g. v10_core/AIGC_Coevolution_V10/+aigc.
%
% SCIENTIFIC WORKFLOW
%   Stage 1: recompute the two 31x31 primary Exp04 planes from source.
%   Stage 2: run the strict three-branch dynamical-comparability audit on
%            those newly generated plane CSVs.
%   Stage 3: verify the manuscript checkpoints and write a compact summary.
%
% DIRECT RUN
%       output = RUN_EXP04_FINAL_SR_V4;
% ========================================================================

clc;
close all force;
rehash;

RUN_MODE = 'full';
RNG_SEED = 20260715;
EXPECTED_N = 31*31;
EXPECTED_TOL_PCT = 0.25;

EXPECTED = struct( ...
    'rhoNetRiskPct',   11.3, ...
    'rhoAdaptRiskPct', 94.9, ...
    'psiNetRiskPct',   34.3, ...
    'psiAdaptRiskPct', 93.8);

fprintf('\n====================================================================\n');
fprintf(' SR | EXP04 FINAL DIRECT REPRODUCTION WORKFLOW V4\n');
fprintf('====================================================================\n');

%% 1. Resolve archive and original V10 core deterministically.
thisFile = mfilename('fullpath');
if isempty(thisFile)
    runnerDir = pwd;
else
    runnerDir = fileparts(thisFile);
end

[archiveRoot,projectRoot] = locate_archive_and_v10(runnerDir);
if isempty(archiveRoot) || isempty(projectRoot)
    error(['Cannot resolve the SR archive-relative V10 source tree.\n', ...
           'Expected sibling structure:\n', ...
           '  exp04_final_code/RUN_EXP04_FINAL_SR_V4.m\n', ...
           '  v10_core/+aigc\n', ...
           'or v10_core/AIGC_Coevolution_V10/+aigc']);
end

% Exp04-specific final files are ordinary functions in runnerDir.
addpath(runnerDir,'-begin');

% Activate only the original V10 core package.
remove_competing_aigc_roots(projectRoot);
addpath(projectRoot,'-begin');
rehash;

validate_required_files(runnerDir,projectRoot);

fprintf('Archive root      : %s\n',archiveRoot);
fprintf('Frozen V10 root   : %s\n',projectRoot);
fprintf('Primary engine    : %s\n',which('exp04_aigc_specific'));
fprintf('Reference helper  : %s\n',which('exp04_reference_parameters'));
fprintf('Solver            : %s\n',which('aigc.solve_model'));
fprintf('RHS               : %s\n',which('aigc.model_rhs'));

%% 2. Load frozen V10 model configuration and frozen Exp04 R1 regime.
pBase = aigc.default_parameters();
opt = aigc.default_options(RUN_MODE);
settings = aigc.experiment_settings(RUN_MODE);

if ~isfield(settings,'aigcPlaneN') || settings.aigcPlaneN ~= 31
    error('Final FULL Exp04 requires settings.aigcPlaneN = 31.');
end
if ~isfield(opt,'X0') || numel(opt.X0) ~= 10
    error('The frozen V10 default_options must provide a 10-state opt.X0.');
end

[pExp04,parameterSource] = exp04_reference_parameters(pBase);
rng(RNG_SEED,'twister');

fprintf('Parameter source  : %s\n',parameterSource);
fprintf('Run mode          : %s\n',RUN_MODE);
fprintf('Plane size        : %d x %d\n',settings.aigcPlaneN,settings.aigcPlaneN);

%% 3. Stage 1: recompute PRIMARY Exp04. No historical output is required.
fprintf('\n====================================================================\n');
fprintf(' STAGE 1 | RECOMPUTE PRIMARY EXP04 FROM SOURCE\n');
fprintf('====================================================================\n');

stamp = datestr(now,'yyyymmdd_HHMMSS');
generatedRoot = fullfile(archiveRoot,'generated_outputs');
ensure_dir_local(generatedRoot);
finalRoot = fullfile(generatedRoot,['SR_Exp04_FINAL_' stamp]);
ensure_dir_local(finalRoot);

% Ordinary final engine beside this runner; it calls frozen aigc.* core code.
exp04_aigc_specific(pExp04,opt,settings,finalRoot);
primaryDir = fullfile(finalRoot,'Exp04_aigc_specific');

[rhoFile,psiFile] = validate_primary_results(primaryDir,EXPECTED_N);
Trho = readtable(rhoFile,'VariableNamingRule','preserve');
Tpsi = readtable(psiFile,'VariableNamingRule','preserve');

P = calculate_primary_stats(Trho,Tpsi);
validate_locked_percentages(P,EXPECTED,EXPECTED_TOL_PCT);

fprintf('\nPrimary Exp04 checkpoints:\n');
fprintf('  rho net risk positive        : %.4f%%\n',100*P.RhoNetRiskPositive);
fprintf('  rho adaptation risk positive : %.4f%%\n',100*P.RhoAdaptRiskPositive);
fprintf('  psi net risk positive        : %.4f%%\n',100*P.PsiNetRiskPositive);
fprintf('  psi adaptation risk positive : %.4f%%\n',100*P.PsiAdaptRiskPositive);

%% 4. Stage 2: strict three-branch audit on EXACTLY these new CSVs.
fprintf('\n====================================================================\n');
fprintf(' STAGE 2 | STRICT THREE-BRANCH DYNAMICAL COMPARABILITY AUDIT\n');
fprintf('====================================================================\n');

oldPwd = pwd;
cleanupPwd = onCleanup(@() cd(oldPwd)); %#ok<NASGU>
cd(primaryDir);

auditOutput = EXP04_THREE_BRANCH_DYNAMICAL_COMPARABILITY_V10_SR();

if isempty(auditOutput) || exist(auditOutput,'dir') ~= 7
    error('The Exp04 three-branch audit did not return a valid output directory.');
end

auditFinalDir = fullfile(finalRoot,'Exp04_three_branch_comparability');
if exist(auditFinalDir,'dir') == 7
    rmdir(auditFinalDir,'s');
end
[ok,msg] = copyfile(auditOutput,auditFinalDir);
if ~ok
    error('Could not collect Exp04 audit outputs: %s',msg);
end

summaryFile = fullfile(auditFinalDir,'exp04_three_branch_comparability_summary.csv');
if exist(summaryFile,'file') ~= 2
    error('Missing Exp04 three-branch audit summary: %s',summaryFile);
end

S = readtable(summaryFile,'VariableNamingRule','preserve');
requiredAudit = {'Plane','N','N_Mthree','PthreeStrict','NetRiskPositiveAll','AdaptRiskPositiveAll'};
assert_table_vars(S,requiredAudit,'three-branch audit summary');

[rhoRow,psiRow] = identify_plane_rows(S);
validate_three_branch_result(S,rhoRow,psiRow,EXPECTED_N);
validate_primary_vs_audit(P,S,rhoRow,psiRow);

%% 5. Stage 3: write compact final SR summary.
fprintf('\n====================================================================\n');
fprintf(' STAGE 3 | FINAL EXP04 SUMMARY\n');
fprintf('====================================================================\n');

Plane = ["rho_E x s"; "psi_E x F_P"];
N = [height(Trho);height(Tpsi)];
NetRiskPositive = [P.RhoNetRiskPositive;P.PsiNetRiskPositive];
AdaptationRiskPositive = [P.RhoAdaptRiskPositive;P.PsiAdaptRiskPositive];
NetTrustNegative = [P.RhoNetTrustNegative;P.PsiNetTrustNegative];
AdaptationTrustNegative = [P.RhoAdaptTrustNegative;P.PsiAdaptTrustNegative];
NThreeBranchComparable = [S.N_Mthree(rhoRow);S.N_Mthree(psiRow)];
ThreeBranchComparable = [S.PthreeStrict(rhoRow);S.PthreeStrict(psiRow)];

Final = table(Plane,N,NetRiskPositive,AdaptationRiskPositive, ...
    NetTrustNegative,AdaptationTrustNegative, ...
    NThreeBranchComparable,ThreeBranchComparable);

finalCsv = fullfile(finalRoot,'exp04_final_key_results.csv');
writetable(Final,finalCsv);

fprintf('\n');
disp(Final);
fprintf('====================================================================\n');
fprintf(' EXP04 FINAL WORKFLOW PASSED\n');
fprintf('====================================================================\n');
fprintf('Final root        : %s\n',finalRoot);
fprintf('Primary results   : %s\n',primaryDir);
fprintf('Audit results     : %s\n',auditFinalDir);
fprintf('Final key results : %s\n',finalCsv);

output = struct();
output.archiveRoot = archiveRoot;
output.projectRoot = projectRoot;
output.finalRoot = finalRoot;
output.primaryDir = primaryDir;
output.auditDir = auditFinalDir;
output.finalSummary = finalCsv;

end

%% ========================================================================
% LOCAL HELPERS
% ========================================================================

function [archiveRoot,projectRoot] = locate_archive_and_v10(runnerDir)
archiveRoot='';
projectRoot='';

% Find nearest ancestor containing v10_core.
c=runnerDir;
for up=1:10
    if exist(fullfile(c,'v10_core'),'dir')==7
        archiveRoot=c;
        break;
    end
    p=fileparts(c);
    if strcmp(p,c), break; end
    c=p;
end
if isempty(archiveRoot), return; end

container=fullfile(archiveRoot,'v10_core');

% Current archive usually has v10_core/+aigc directly.
candidates={container,fullfile(container,'AIGC_Coevolution_V10')};

% Tolerate one additional packaging directory.
D=dir(container);
for k=1:numel(D)
    if D(k).isdir && ~strcmp(D(k).name,'.') && ~strcmp(D(k).name,'..')
        candidates{end+1}=fullfile(container,D(k).name); %#ok<AGROW>
    end
end

for k=1:numel(candidates)
    if is_valid_v10_core(candidates{k})
        projectRoot=candidates{k};
        return;
    end
end
end

function tf = is_valid_v10_core(root)
tf=false;
if isempty(root) || exist(root,'dir')~=7, return; end
pkg=fullfile(root,'+aigc');
if exist(pkg,'dir')~=7, return; end
req={'default_parameters.m','default_options.m','experiment_settings.m', ...
     'full_mode.m','leave_one_out_mode.m','solve_model.m','model_rhs.m'};
for k=1:numel(req)
    if exist(fullfile(pkg,req{k}),'file')~=2, return; end
end
tf=true;
end

function validate_required_files(runnerDir,projectRoot)
localReq={'exp04_aigc_specific.m','exp04_reference_parameters.m', ...
          'EXP04_THREE_BRANCH_DYNAMICAL_COMPARABILITY_V10_SR.m'};
for k=1:numel(localReq)
    f=fullfile(runnerDir,localReq{k});
    if exist(f,'file')~=2, error('Missing final Exp04 file: %s',f); end
end
if ~is_valid_v10_core(projectRoot)
    error('The resolved v10_core is incomplete.');
end
end

function remove_competing_aigc_roots(selectedRoot)
funcs={'aigc.default_parameters','aigc.solve_model','aigc.model_rhs'};
roots={};
for i=1:numel(funcs)
    h=which(funcs{i},'-all');
    if ischar(h), h={h}; end
    for j=1:numel(h)
        roots{end+1}=fileparts(fileparts(h{j})); %#ok<AGROW>
    end
end
if isempty(roots), return; end
roots=unique(roots,'stable');
for k=1:numel(roots)
    r=roots{k};
    if ~strcmpi(normalize_path(r),normalize_path(selectedRoot))
        try
            rmpath(r);
            fprintf('[PATH] Removed competing AIGC root: %s\n',r);
        catch
        end
    end
end
rehash;
end

function p=normalize_path(p)
p=char(p);
try, p=char(java.io.File(p).getCanonicalPath()); catch, end
p=strrep(p,'/',filesep);
while numel(p)>1 && p(end)==filesep, p(end)=[]; end
end

function [rhoFile,psiFile] = validate_primary_results(primaryDir,expectedN)
rhoFile=fullfile(primaryDir,'exp04_plane_rhoE_s.csv');
psiFile=fullfile(primaryDir,'exp04_plane_psiE_FP.csv');
if exist(rhoFile,'file')~=2, error('Missing primary file: %s',rhoFile); end
if exist(psiFile,'file')~=2, error('Missing primary file: %s',psiFile); end
Trho=readtable(rhoFile,'VariableNamingRule','preserve');
Tpsi=readtable(psiFile,'VariableNamingRule','preserve');
req={'NetDeltaI','NetDeltaT','AdaptationDeltaI','AdaptationDeltaT', ...
     'DynamicDynamics','DynamicResolved','CapacityMatchError'};
assert_table_vars(Trho,req,'rho_E x s primary plane');
assert_table_vars(Tpsi,req,'psi_E x F_P primary plane');
if height(Trho)~=expectedN || height(Tpsi)~=expectedN
    error('Each FULL Exp04 primary plane must contain %d rows.',expectedN);
end
end

function P=calculate_primary_stats(Trho,Tpsi)
P.RhoNetRiskPositive=rate_signed(Trho.NetDeltaI,+1);
P.RhoAdaptRiskPositive=rate_signed(Trho.AdaptationDeltaI,+1);
P.RhoNetTrustNegative=rate_signed(Trho.NetDeltaT,-1);
P.RhoAdaptTrustNegative=rate_signed(Trho.AdaptationDeltaT,-1);
P.PsiNetRiskPositive=rate_signed(Tpsi.NetDeltaI,+1);
P.PsiAdaptRiskPositive=rate_signed(Tpsi.AdaptationDeltaI,+1);
P.PsiNetTrustNegative=rate_signed(Tpsi.NetDeltaT,-1);
P.PsiAdaptTrustNegative=rate_signed(Tpsi.AdaptationDeltaT,-1);
end

function r=rate_signed(v,sgn)
v=double(v(:)); good=isfinite(v);
if ~any(good), error('No finite values in required Exp04 effect column.'); end
if sgn>0, r=mean(v(good)>0); else, r=mean(v(good)<0); end
end

function validate_locked_percentages(P,E,tol)
check_pct('rho net risk',100*P.RhoNetRiskPositive,E.rhoNetRiskPct,tol);
check_pct('rho adaptation risk',100*P.RhoAdaptRiskPositive,E.rhoAdaptRiskPct,tol);
check_pct('psi net risk',100*P.PsiNetRiskPositive,E.psiNetRiskPct,tol);
check_pct('psi adaptation risk',100*P.PsiAdaptRiskPositive,E.psiAdaptRiskPct,tol);
end

function check_pct(label,value,target,tol)
fprintf('  %-26s = %8.4f%% | expected ~ %.2f%%\n',label,value,target);
if abs(value-target)>tol
    error('Locked manuscript checkpoint failed for %s.',label);
end
end

function assert_table_vars(T,names,label)
missing=setdiff(names,T.Properties.VariableNames,'stable');
if ~isempty(missing)
    error('%s is missing required variables: %s',label,strjoin(missing,', '));
end
end

function [rhoRow,psiRow]=identify_plane_rows(S)
plane=lower(string(S.Plane));
rhoRow=find(contains(plane,'rho'),1);
psiRow=find(contains(plane,'psi'),1);
if isempty(rhoRow)||isempty(psiRow)
    if height(S)==2
        rhoRow=1; psiRow=2;
    else
        error('Cannot identify the two Exp04 audit planes.');
    end
end
end

function validate_three_branch_result(S,rhoRow,psiRow,expectedN)
for row=[rhoRow psiRow]
    if S.N(row)~=expectedN || S.N_Mthree(row)~=expectedN || abs(S.PthreeStrict(row)-1)>1e-12
        error('Three-branch comparability is not %d/%d for plane %s.', ...
            expectedN,expectedN,char(string(S.Plane(row))));
    end
end
fprintf('  rho_E x s   three-branch comparability: %d/%d (100%%)\n',expectedN,expectedN);
fprintf('  psi_E x F_P three-branch comparability: %d/%d (100%%)\n',expectedN,expectedN);
end

function validate_primary_vs_audit(P,S,rhoRow,psiRow)
tol=1e-12;
a=[P.RhoNetRiskPositive;P.RhoAdaptRiskPositive;P.PsiNetRiskPositive;P.PsiAdaptRiskPositive];
b=[S.NetRiskPositiveAll(rhoRow);S.AdaptRiskPositiveAll(rhoRow); ...
   S.NetRiskPositiveAll(psiRow);S.AdaptRiskPositiveAll(psiRow)];
if any(abs(a-b)>tol)
    error('Audit effect shares differ from the newly generated primary Exp04 effect shares.');
end
end

function ensure_dir_local(d)
if exist(d,'dir')~=7
    [ok,msg]=mkdir(d);
    if ~ok, error('Could not create directory: %s',msg); end
end
end
