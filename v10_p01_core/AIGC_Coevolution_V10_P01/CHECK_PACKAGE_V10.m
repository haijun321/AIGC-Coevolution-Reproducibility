projectRoot = fileparts(mfilename('fullpath'));
addpath(projectRoot);
clear; clc; close all;
report = aigc.check_package();
disp(report);
