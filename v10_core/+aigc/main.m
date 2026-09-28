function outputRoot = main(runMode, experimentList)
%AIGC.MAIN Run the complete AIGC coevolution V10 experiment chain.
if nargin < 1 || isempty(runMode), runMode = 'preview'; end
if nargin < 2 || isempty(experimentList), experimentList = 0:9; end
runMode = lower(char(runMode));
if ~ismember(runMode,{'preview','quick','full'}), error('runMode must be preview, quick, or full.'); end
experimentList = unique(experimentList(:)');
if any(experimentList < 0) || any(experimentList > 9) || any(experimentList ~= round(experimentList))
    error('experimentList must contain integers from 0 to 9.');
end
projectRoot = fileparts(fileparts(mfilename('fullpath'))); addpath(projectRoot); rng(20260723,'twister');
p = aigc.default_parameters(); opt = aigc.default_options(runMode); settings = aigc.experiment_settings(runMode);
aigc.validate_model_configuration(p,opt,settings);
stamp = datestr(now,'yyyymmdd_HHMMSS');
outputRoot = fullfile(projectRoot,'outputs',['V10_' upper(runMode) '_' stamp]); aigc.ensure_dir(outputRoot);
diary(fullfile(outputRoot,'run_log.txt')); cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>
fprintf('============================================================\n');
fprintf('AIGC content-ecology coevolution MATLAB V10\n');
fprintf('Mode: %s\n',runMode); fprintf('Experiments: %s\n',mat2str(experimentList));
fprintf('Output: %s\n',outputRoot); fprintf('============================================================\n');
aigc.write_configuration(outputRoot,runMode,p,opt,settings,experimentList);
for expId = experimentList
    fprintf('\n-------------------- Exp%02d --------------------\n',expId);
    try
        switch expId
            case 0, aigc.exp00_solver_validation(p,opt,settings,outputRoot);
            case 1, aigc.exp01_representative_regimes(p,opt,settings,outputRoot);
            case 2, aigc.exp02_ablation_benchmarks(p,opt,settings,outputRoot);
            case 3, aigc.exp03_governance_factorial(p,opt,settings,outputRoot);
            case 4, aigc.exp04_aigc_specific(p,opt,settings,outputRoot);
            case 5, aigc.exp05_global_sensitivity(p,opt,settings,outputRoot);
            case 6, aigc.exp06_dynamic_instability(p,opt,settings,outputRoot);
            case 7, aigc.exp07_trust_shocks(p,opt,settings,outputRoot);
            case 8, aigc.exp08_fair_policy_comparison(p,opt,settings,outputRoot);
            case 9, aigc.exp09_structural_robustness(p,opt,settings,outputRoot);
        end
    catch ME
        fprintf(2,'[ERROR] Exp%02d failed: %s\n',expId,ME.message);
        fprintf(2,'%s\n',getReport(ME,'extended','hyperlinks','off')); rethrow(ME);
    end
end
fprintf('\n============================================================\n');
fprintf('Selected V10 experiments completed.\nOutput: %s\n',outputRoot);
fprintf('============================================================\n');
end
