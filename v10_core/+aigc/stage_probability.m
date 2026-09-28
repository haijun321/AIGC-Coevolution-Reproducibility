function [pStage,raw] = stage_probability(pAct,kappa,form)
%STAGE_PROBABILITY Map end-to-end coverage to a lifecycle-stage effect.
pAct = min(max(pAct,0),1);
kappa = max(kappa,0);
switch lower(form)
    case 'linear'
        raw = kappa*pAct;
        pStage = min(max(raw,0),1);
    case 'exponential'
        raw = kappa*pAct;
        pStage = 1-exp(-raw);
    case 'rational'
        raw = kappa*pAct;
        pStage = raw/(1+raw);
    otherwise
        error('Unknown stage-probability form: %s',form);
end
end
