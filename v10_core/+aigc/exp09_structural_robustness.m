function exp09_structural_robustness(p,opt,settings,outputRoot)
%EXP09_STRUCTURAL_ROBUSTNESS Claim-specific retention with valid denominators.
outDir=fullfile(outputRoot,'Exp09_structural_robustness'); aigc.ensure_dir(outDir);
optRob=opt; optRob.solver='ode45'; optRob.allowEarlyStop=false;
settingsList=build_settings(settings.robustnessMutationScales);
[P3,P4,policySource]=load_policies(outputRoot,p);
rows=struct([]); optShock=optRob; optShock.t0=0;
optShock.tEnd=max(100,opt.tEnd/4); optShock.allowEarlyStop=false;
for k=1:numel(settingsList)
    row=blank_row(settingsList(k),policySource);
    try
        [pp,mode]=apply_setting(p,settingsList(k));
        [solF,~]=aigc.solve_adaptive_longrun(opt.X0,pp,mode,optRob,settings.certificationMaxTime);
        sf=aigc.summarize_solution(solF,pp,mode,optRob);
        mi=mode; mi.idealGovernance=true;
        [solI,~]=aigc.solve_adaptive_longrun(opt.X0,pp,mi,optRob,settings.certificationMaxTime);
        si=aigc.summarize_solution(solI,pp,mi,optRob);
        pNL=pp; pNL.c=0; pNL.nu1=0;
        [solL,~]=aigc.solve_adaptive_longrun(opt.X0,pNL,mode,optRob,settings.certificationMaxTime);
        snl=aigc.summarize_solution(solL,pNL,mode,optRob);
        mNo=mode; mNo.useAIGC=false; mNo.activeMask(10)=false; mNo.exogenousE=true;
        [solN,~]=aigc.solve_adaptive_longrun(opt.X0,pp,mNo,optRob,settings.certificationMaxTime);
        sna=aigc.summarize_solution(solN,pp,mNo,optRob);
        mm=aigc.matched_aigc_shock(solF.finalState,pp,mode,optShock,settings.robustnessAigcShockStrength);
        Jfix=evaluate_policy(P3,pp,mode,optRob,settings.policyWeights);
        Jdyn=evaluate_policy(P4,pp,mode,optRob,settings.policyWeights);
        epsEffect=max(settings.effectAbsoluteTol,settings.effectRelativeTol*max(abs(sf.I),1e-6));

        row.ValidSetting=true; row.FullI=sf.I; row.FullT=sf.T; row.FullQexp=sf.Qexp;
        row.Dynamics=sf.dynamics; row.TailStable=sf.tailStable;
        row.FiniteGovernanceRiskEffect=sf.I-si.I; row.LabelRiskReduction=snl.I-sf.I;
        row.AIGCNetRiskEffect=sf.I-sna.I; row.AIGCNetTrustEffect=sf.T-sna.T;
        row.MatchedRiskAreaGain=mm.RiskAreaGain; row.MatchedTrustLossAreaGain=mm.TrustLossAreaGain;
        row.CapacityMatchError=mm.CapacityMatchError;
        row.PolicyDeltaJ_DynamicMinusFixed=Jdyn-Jfix;
        row.PolicyNearParity=abs(row.PolicyDeltaJ_DynamicMinusFixed)<=settings.policyEquivalenceTol;
        if row.PolicyNearParity, row.PolicyWinner='near_parity';
        elseif row.PolicyDeltaJ_DynamicMinusFixed<0, row.PolicyWinner='dynamic';
        else, row.PolicyWinner='fixed'; end
        row.EffectTolerance=epsEffect;
        row.ValidFiniteGovernance=aigc.is_resolved_label(sf.dynamics)&&aigc.is_resolved_label(si.dynamics);
        row.ValidLabel=aigc.is_resolved_label(sf.dynamics)&&aigc.is_resolved_label(snl.dynamics);
        row.ValidAIGCNet=aigc.is_resolved_label(sf.dynamics)&&aigc.is_resolved_label(sna.dynamics);
        row.ValidMatchedRisk=isfinite(mm.RiskAreaGain)&&abs(mm.CapacityMatchError)<=settings.matchedCapacityTol;
        row.ValidMatchedTrust=isfinite(mm.TrustLossAreaGain)&&abs(mm.CapacityMatchError)<=settings.matchedCapacityTol;
        if row.ValidFiniteGovernance, row.RetainFiniteGovernance=double(row.FiniteGovernanceRiskEffect>epsEffect); end
        if row.ValidLabel, row.RetainLabel=double(row.LabelRiskReduction>epsEffect); end
        if row.ValidMatchedRisk, row.RetainMatchedRiskArea=double(row.MatchedRiskAreaGain>settings.effectAbsoluteTol); end
        if row.ValidMatchedTrust, row.RetainMatchedTrustLoss=double(row.MatchedTrustLossAreaGain>settings.effectAbsoluteTol); end
        row.NearZeroAIGCNet=double(row.ValidAIGCNet&&abs(row.AIGCNetRiskEffect)<=epsEffect);
        vals=[row.RetainFiniteGovernance,row.RetainLabel,row.RetainMatchedRiskArea,row.RetainMatchedTrustLoss];
        row.CoreClaimRetention=mean(vals,'omitnan');
        reasons={};
        if ~row.ValidFiniteGovernance, reasons{end+1}='finite-governance contrast unresolved'; end %#ok<AGROW>
        if ~row.ValidLabel, reasons{end+1}='label contrast unresolved'; end %#ok<AGROW>
        if ~row.ValidAIGCNet, reasons{end+1}='AIGC net contrast unresolved'; end %#ok<AGROW>
        if ~(row.ValidMatchedRisk&&row.ValidMatchedTrust), reasons{end+1}='capacity match invalid'; end %#ok<AGROW>
        row.ExclusionReason=strjoin(reasons,'; ');
    catch ME
        row.ValidSetting=false; row.ExclusionReason=ME.message;
    end
    rows=aigc.append_struct_row(rows,row);
    fprintf('Exp09 structural setting %d/%d completed.\n',k,numel(settingsList));
end
T=aigc.struct_rows_to_table(rows);
writetable(T,fullfile(outDir,'exp09_structural_robustness.csv'));

claims={'RetainFiniteGovernance','RetainLabel','RetainMatchedRiskArea','RetainMatchedTrustLoss'};
labels={'Finite governance raises risk','Label stock reduces risk', ...
    'Dynamic adaptation raises matched risk area','Dynamic adaptation raises matched trust loss'};
summaryRows=struct([]);
for j=1:numel(claims)
    v=T.(claims{j}); valid=isfinite(v);
    row=struct(); row.Claim=labels{j}; row.RetentionRate=mean(v(valid),'omitnan');
    row.NValid=sum(valid); row.NExcluded=height(T)-sum(valid);
    summaryRows=aigc.append_struct_row(summaryRows,row);
end
Tsummary=aigc.struct_rows_to_table(summaryRows);
writetable(Tsummary,fullfile(outDir,'exp09_claim_retention_summary.csv'));
writetable(T(~T.ValidSetting|strlength(string(T.ExclusionReason))>0, ...
    {'Setting','Family','ValidSetting','ExclusionReason'}),fullfile(outDir,'exp09_exclusions.csv'));

fig=figure('Visible','off','Color','w','Position',[60 60 1350 820]);
subplot(2,2,1); valid=T.ValidFiniteGovernance|T.ValidLabel;
bar(categorical(T.Setting(valid)),[T.FiniteGovernanceRiskEffect(valid) T.LabelRiskReduction(valid)]);
ylabel('Signed tail-risk difference'); legend({'Finite governance','Label stock'},'Location','best'); grid on;
subplot(2,2,2); valid=T.ValidMatchedRisk|T.ValidMatchedTrust;
bar(categorical(T.Setting(valid)),[T.MatchedRiskAreaGain(valid) T.MatchedTrustLossAreaGain(valid)]);
ylabel('Signed cumulative-area difference'); legend({'Risk area','Trust-loss area'},'Location','best'); grid on;
subplot(2,2,3); bar(categorical(Tsummary.Claim),Tsummary.RetentionRate);
ylim([0 1]); ylabel('Claim-specific retention rate'); grid on;
subplot(2,2,4); bar(categorical(Tsummary.Claim),[Tsummary.NValid Tsummary.NExcluded]);
legend({'Valid denominator','Excluded'},'Location','best'); ylabel('Structural settings'); grid on;
aigc.save_figure(fig,fullfile(outDir,'fig_exp09_structural_robustness')); close(fig);
end

function row=blank_row(item,policySource)
row=struct('Setting',item.name,'Family',item.family,'PolicySource',policySource, ...
    'ValidSetting',false,'ExclusionReason','','FullI',NaN,'FullT',NaN,'FullQexp',NaN, ...
    'Dynamics','','TailStable',false,'FiniteGovernanceRiskEffect',NaN, ...
    'LabelRiskReduction',NaN,'AIGCNetRiskEffect',NaN,'AIGCNetTrustEffect',NaN, ...
    'MatchedRiskAreaGain',NaN,'MatchedTrustLossAreaGain',NaN,'CapacityMatchError',NaN, ...
    'PolicyDeltaJ_DynamicMinusFixed',NaN,'PolicyNearParity',false,'PolicyWinner','not_evaluated', ...
    'EffectTolerance',NaN,'ValidFiniteGovernance',false,'ValidLabel',false, ...
    'ValidAIGCNet',false,'ValidMatchedRisk',false,'ValidMatchedTrust',false, ...
    'RetainFiniteGovernance',NaN,'RetainLabel',NaN,'RetainMatchedRiskArea',NaN, ...
    'RetainMatchedTrustLoss',NaN,'NearZeroAIGCNet',NaN,'CoreClaimRetention',NaN);
end

function [P3,P4,source]=load_policies(outputRoot,p)
matFile=fullfile(outputRoot,'Exp08_fair_policy_comparison','exp08_selected_policies.mat');
if exist(matFile,'file')
    S=load(matFile,'P3','P4'); P3=S.P3; P4=S.P4; source='Exp08_best_found_frozen_policies';
else
    P3=struct('type','fixed','u',p.uRef,'auditSpeed',NaN,'gainScale',NaN,'etaCScale',NaN);
    P4=struct('type','dynamic','u',NaN,'auditSpeed',p.auditSpeed,'gainScale',1,'etaCScale',1);
    source='fallback_reference_policies';
end
end

function J=evaluate_policy(cand,p,baseMode,opt,w)
pp=p; mode=baseMode;
if strcmp(cand.type,'fixed')
    mode.dynamicAudit=false; mode.fixedAudit=true; mode.fixedAuditIntensity=cand.u;
    mode.activeMask(7)=false; mode.costDynamic=false; mode.costFixed=true;
else
    mode.dynamicAudit=true; mode.fixedAudit=false; mode.activeMask(7)=true;
    mode.costDynamic=true; mode.costFixed=false;
    pp.auditSpeed=cand.auditSpeed; pp.etaI=pp.etaI*cand.gainScale;
    pp.etaT=pp.etaT*cand.gainScale; pp.etaA=pp.etaA*cand.gainScale;
    pp.etaC=pp.etaC*cand.etaCScale;
end
sol=aigc.solve_model(opt.X0,pp,mode,opt); ev=aigc.evaluate_solution(sol,pp,mode);
ss=aigc.summarize_solution(sol,pp,mode,opt,ev);
tailStart=sol.t(1)+(1-opt.tailFraction)*(sol.t(end)-sol.t(1)); idx=find(sol.t>=tailStart);
jt=aigc.time_average(sol.t(idx),max(pp.Tstar-ev.T(idx),0));
J=w(1)*ss.I+w(2)*jt+w(3)*ev.JC;
end

function list=build_settings(switchingScales)
list=struct('name',{},'family',{},'value',{});
add('baseline','baseline','baseline');
% Only genuine alternatives are added below.  Baseline forms are represented
% once by the baseline row and must not receive extra weight in retention rates.
forms={'hill','piecewise'}; for i=1:numel(forms), add(['threshold_' forms{i}],'threshold',forms{i}); end
forms={'sqrt','projected'}; for i=1:numel(forms), add(['audit_' forms{i}],'audit_boundary',forms{i}); end
forms={'hill','saturating'}; for i=1:numel(forms), add(['aigc_' forms{i}],'aigc_form',forms{i}); end
forms={'rational'}; for i=1:numel(forms), add(['handle_' forms{i}],'handle_probability',forms{i}); end
forms={'exponential','rational'}; for i=1:numel(forms), add(['stage_' forms{i}],'stage_probability',forms{i}); end
forms={'in','sp','rm'}; for i=1:numel(forms), add(['stage_half_' forms{i}],'stage_strength',forms{i}); end
forms={'pure_qexp'}; for i=1:numel(forms), add(['G_' forms{i}],'positive_experience',forms{i}); end
for i=1:numel(switchingScales)
    if abs(switchingScales(i)-1)>10*eps
        add(sprintf('switching_x%.3g',switchingScales(i)),'switching',switchingScales(i));
    end
end
    function add(name,family,value)
        n=numel(list)+1; list(n).name=name; list(n).family=family; list(n).value=value;
    end
end

function [pp,mode]=apply_setting(p,item)
pp=p; mode=aigc.full_mode();
switch item.family
    case 'baseline'
    case 'threshold', mode.thresholdForm=item.value;
    case 'audit_boundary', mode.auditBoundaryForm=item.value;
    case 'aigc_form', mode.aigcAmplificationForm=item.value;
    case 'handle_probability', mode.handleProbabilityForm=item.value;
    case 'stage_probability', mode.stageProbabilityForm=item.value;
    case 'stage_strength'
        if strcmp(item.value,'in'), pp.kappaIn=0.5;
        elseif strcmp(item.value,'sp'), pp.kappaSp=0.5;
        else, pp.kappaRm=0.5; end
    case 'positive_experience', mode.positiveExperienceForm=item.value;
    case 'switching'
        pp.epsP=p.epsP*item.value; pp.epsF=p.epsF*item.value; pp.epsU=p.epsU*item.value;
    otherwise, error('Unknown robustness family.');
end
end
