function outputRoot = RUN_CORE_SR(runMode)
% Reproduce the V10 core evidence (Exp00-03, Exp07 and main Exp08).
% Run final Exp04, Exp05, Exp06/08 P0.1 and Exp09 from their separate runners.
if nargin < 1 || isempty(runMode), runMode = 'preview'; end
archiveRoot = fileparts(mfilename('fullpath'));
coreRoot = fullfile(archiveRoot, 'v10_core');
restoredefaultpath; rehash toolboxcache;
addpath(archiveRoot); addpath(coreRoot, '-begin');
outputRoot = aigc.main(runMode, [0 1 2 3 7 8]);
end
