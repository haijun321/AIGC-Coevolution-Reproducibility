function write_configuration(outputRoot,runMode,p,opt,settings,experimentList)
save(fullfile(outputRoot,'configuration_V10.mat'),'runMode','p','opt','settings','experimentList');
paramTable=aigc.parameter_dictionary(p);
writetable(paramTable,fullfile(outputRoot,'parameter_dictionary_V10.csv'));
stateNames={'x';'y';'z';'I';'T';'M';'u';'A';'L';'E'};
stateTable=table(stateNames,opt.X0(:),'VariableNames',{'State','InitialValue'});
writetable(stateTable,fullfile(outputRoot,'initial_state_V10.csv'));
fid = fopen(fullfile(outputRoot,'configuration_V10.txt'),'w');
if fid < 0, error('Cannot create configuration file.'); end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'AIGC Coevolution V10\n');
fprintf(fid,'Run mode: %s\n',runMode);
fprintf(fid,'Experiments: %s\n\n',mat2str(experimentList));
fprintf(fid,'Core V10 semantics:\n');
fprintf(fid,'  phiIn = aDet*(1-A) and phiAct = rAct*A are queue flows.\n');
fprintf(fid,'  pHandle converts the action rate to a conditional probability.\n');
fprintf(fid,'  pAct = pDet*pHandle is an end-to-end coverage probability.\n');
fprintf(fid,'  pIn, pSp, and pRm separately govern injection, spread, and removal.\n');
fprintf(fid,'  Q0 = x*qC+(1-x)*qS contains no direct governance quality repair.\n');
fprintf(fid,'  G is anchored to Qexp.\n');
fprintf(fid,'  DeltaPiU = Ipay*nuEff*LU-CV-BD; actual Qexp still uses ecological I.\n');
fprintf(fid,'  Tail summaries are time-weighted.\n');
fprintf(fid,'  Matched AIGC shocks use equal onset capacity and compare cumulative areas.\n');
fprintf(fid,'  Exp06 P0 audit changes only positive time-scale multipliers of A, L, M.\n');
fprintf(fid,'  Exp08 core comparison removes policy-form overhead and embeds fixed u as zero-gain dynamic policy.\n\n');
fn = fieldnames(p);
for i=1:numel(fn), fprintf(fid,'p.%s = %.16g\n',fn{i},p.(fn{i})); end
end
