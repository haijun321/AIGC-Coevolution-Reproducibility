function exp03_governance_factorial(p,opt,settings,outputRoot)
%EXP03_GOVERNANCE_FACTORIAL 2^8 design, interactions, and resolved strata.
outDir=fullfile(outputRoot,'Exp03_governance_factorial'); aigc.ensure_dir(outDir);
optBulk=opt; optBulk.solver='ode45';
rng(settings.factorialSeed,'twister');
K=numel(settings.factorNames); nComb=2^K; codes=-ones(nComb,K);
for i=0:nComb-1, bits=dec2bin(i,K)-'0'; codes(i+1,:)=2*bits-1; end
X0s=aigc.sample_initial_conditions(opt.X0,settings.factorialIC,0.08,settings.factorialSeed+1);
raw=struct([]); auditNames={'Fixed','Dynamic'};
for a=1:2
    if a==1
        mode=aigc.full_mode(); mode.name='Fixed'; mode.dynamicAudit=false; mode.fixedAudit=true;
        mode.fixedAuditIntensity=p.uRef; mode.activeMask(7)=false; mode.costDynamic=false; mode.costFixed=true;
    else
        mode=aigc.full_mode(); mode.name='Dynamic'; mode.costDynamic=true; mode.costFixed=false;
    end
    for cidx=1:nComb
        pp=apply_factor_levels(p,settings,codes(cidx,:));
        for ic=1:size(X0s,1)
            if mod(cidx,32)==1 && ic==1
                fprintf('Exp03 %s combination %d/%d...\n',auditNames{a},cidx,nComb);
            end
            [sol,cert]=aigc.solve_adaptive_longrun(X0s(ic,:)',pp,mode,optBulk,settings.factorialMaxTime);
            ss=aigc.summarize_solution(sol,pp,mode,optBulk);
            row=struct(); row.Audit=auditNames{a}; row.Combination=cidx; row.IC=ic;
            for j=1:K, row.(['Code_' settings.factorNames{j}])=codes(cidx,j); end
            row.I=ss.I; row.T=ss.T; row.Qexp=ss.Qexp; row.JC=ss.JC; row.pAct=ss.pAct;
            row.pIn=ss.pIn; row.pSp=ss.pSp; row.pRm=ss.pRm;
            row.Dynamics=ss.dynamics; row.Resolved=aigc.is_resolved_label(ss.dynamics);
            row.AmpI=ss.ampI; row.TailStable=ss.tailStable;
            row.TailMeanDrift=ss.tailMeanDrift; row.FinalTime=cert.finalTime;
            row.TailWindowClassRobust=ss.tailWindowClassRobust;
            row.TailWindowMeanSpreadI=ss.tailWindowMeanSpreadI;
            raw=aigc.append_struct_row(raw,row);
        end
    end
end
Traw=aigc.struct_rows_to_table(raw);
writetable(Traw,fullfile(outDir,'exp03_factorial_raw.csv'));
Tagg=[aggregate_combinations(Traw,settings.factorNames,'All'); ...
      aggregate_combinations(Traw,settings.factorNames,'Resolved')];
writetable(Tagg,fullfile(outDir,'exp03_factorial_combination_means.csv'));
[mainT,intT]=effect_tables(Tagg,settings.factorNames);
jointT=joint_failure_table(Traw,settings.factorNames,settings);
medT=control_mediation(mainT);
writetable(mainT,fullfile(outDir,'exp03_main_effects_all_and_resolved.csv'));
writetable(intT,fullfile(outDir,'exp03_two_way_interactions_all_and_resolved.csv'));
writetable(jointT,fullfile(outDir,'exp03_joint_failure_all_and_resolved.csv'));
writetable(medT,fullfile(outDir,'exp03_control_mediation.csv'));

fig=figure('Visible','off','Color','w','Position',[50 50 1400 900]);
subplot(2,2,1); plot_main_comparison(mainT,'All');
title('Fixed and dynamic audit: signed main effects');
subplot(2,2,2); plot_interaction_heatmap(intT,settings.factorNames,'Fixed','All','InteractionI');
title('Fixed audit: risk interactions');
subplot(2,2,3); plot_resolved_comparison(mainT);
title('All trajectories versus resolved subset');
subplot(2,2,4); plot_joint(jointT);
title('Joint excess (positive = super-additive loss)');
aigc.save_figure(fig,fullfile(outDir,'fig_exp03_governance_main_effects')); close(fig);
end

function pp=apply_factor_levels(p,s,codes)
pp=p;
for j=1:numel(s.factorNames)
    if codes(j)==1, v=s.factorGood(j); else, v=s.factorBad(j); end
    pp.(s.factorNames{j})=v;
end
end

function Tagg=aggregate_combinations(Traw,factorNames,scope)
audits=unique(Traw.Audit,'stable'); rows=struct([]);
for a=1:numel(audits)
    for c=1:max(Traw.Combination)
        allIdx=strcmp(Traw.Audit,audits{a}) & Traw.Combination==c;
        idx=allIdx;
        if strcmp(scope,'Resolved'), idx=idx&Traw.Resolved; end
        row=struct(); row.Scope=scope; row.Audit=audits{a}; row.Combination=c;
        first=find(allIdx,1);
        for j=1:numel(factorNames)
            row.(['Code_' factorNames{j}])=Traw.(['Code_' factorNames{j}])(first);
        end
        row.N=sum(idx);
        row.I=safe_mean(Traw.I(idx)); row.T=safe_mean(Traw.T(idx));
        row.Qexp=safe_mean(Traw.Qexp(idx)); row.JC=safe_mean(Traw.JC(idx));
        row.pAct=safe_mean(Traw.pAct(idx));
        row.TailStableShare=safe_mean(double(Traw.TailStable(idx)));
        row.UnresolvedShare=safe_mean(double(contains(Traw.Dynamics(idx),'unresolved')));
        rows=aigc.append_struct_row(rows,row);
    end
end
Tagg=aigc.struct_rows_to_table(rows);
end

function [mainT,intT]=effect_tables(T,factorNames)
audits=unique(T.Audit,'stable'); scopes=unique(T.Scope,'stable'); metrics={'I','T','Qexp'};
mainRows=struct([]); intRows=struct([]);
for s=1:numel(scopes)
    for a=1:numel(audits)
        ia=strcmp(T.Audit,audits{a})&strcmp(T.Scope,scopes{s});
        for j=1:numel(factorNames)
            code=T.(['Code_' factorNames{j}]); row=struct();
            row.Scope=scopes{s}; row.Audit=audits{a}; row.Factor=factorNames{j};
            for m=1:numel(metrics)
                y=T.(metrics{m});
                row.(['Effect' metrics{m}])=safe_mean(y(ia&code==1))-safe_mean(y(ia&code==-1));
            end
            row.MeanTailStableShare=safe_mean(T.TailStableShare(ia));
            row.CompleteCombinationShare=mean(T.N(ia)>0);
            mainRows=aigc.append_struct_row(mainRows,row);
        end
        for j=1:numel(factorNames)-1
            cj=T.(['Code_' factorNames{j}]);
            for k=j+1:numel(factorNames)
                ck=T.(['Code_' factorNames{k}]); row=struct();
                row.Scope=scopes{s}; row.Audit=audits{a};
                row.Factor1=factorNames{j}; row.Factor2=factorNames{k};
                for m=1:numel(metrics)
                    y=T.(metrics{m});
                    ypp=safe_mean(y(ia&cj==1&ck==1)); ypm=safe_mean(y(ia&cj==1&ck==-1));
                    ymp=safe_mean(y(ia&cj==-1&ck==1)); ymm=safe_mean(y(ia&cj==-1&ck==-1));
                    row.(['Interaction' metrics{m}])=0.5*(ypp-ypm-ymp+ymm);
                end
                intRows=aigc.append_struct_row(intRows,row);
            end
        end
    end
end
mainT=aigc.struct_rows_to_table(mainRows); intT=aigc.struct_rows_to_table(intRows);
end

function T=joint_failure_table(R,factorNames,settings)
audits=unique(R.Audit,'stable'); metrics={'I','T','Qexp'}; scopes={'All','Resolved'};
rows=struct([]); rng(settings.factorialSeed+71,'twister');
for s=1:numel(scopes)
    for a=1:numel(audits)
        ics=unique(R.IC(strcmp(R.Audit,audits{a})));
        for m=1:numel(metrics)
            perIC=nan(numel(ics),4);
            for q=1:numel(ics)
                base=strcmp(R.Audit,audits{a})&R.IC==ics(q);
                if strcmp(scopes{s},'Resolved'), base=base&R.Resolved; end
                allGood=base; allBad=base;
                for j=1:numel(factorNames)
                    code=R.(['Code_' factorNames{j}]);
                    allGood=allGood&(code==1); allBad=allBad&(code==-1);
                end
                y=R.(metrics{m}); if strcmp(metrics{m},'I'), Z=y; else, Z=-y; end
                zg=safe_mean(Z(allGood)); zb=safe_mean(Z(allBad));
                singles=nan(1,numel(factorNames));
                for j=1:numel(factorNames)
                    oneBad=base;
                    for k=1:numel(factorNames)
                        code=R.(['Code_' factorNames{k}]);
                        if k==j, oneBad=oneBad&(code==-1); else, oneBad=oneBad&(code==1); end
                    end
                    singles(j)=safe_mean(Z(oneBad))-zg;
                end
                joint=zb-zg; rawSum=sum(singles,'omitnan'); posSum=sum(max(singles,0),'omitnan');
                perIC(q,:)=[joint,rawSum,posSum,joint-posSum];
            end
            valid=all(isfinite(perIC),2); v=perIC(valid,:);
            row=struct(); row.Scope=scopes{s}; row.Audit=audits{a}; row.Metric=metrics{m};
            row.NIC=sum(valid); row.AllBadMinusGood=safe_mean(v(:,1));
            row.SumSingleFailuresRaw=safe_mean(v(:,2));
            row.SumSingleFailuresPositive=safe_mean(v(:,3));
            row.SynergyExcess=safe_mean(v(:,4));
            if row.SumSingleFailuresPositive>settings.jointDenominatorTol
                row.JointFailureRatio=row.AllBadMinusGood/row.SumSingleFailuresPositive;
            else
                row.JointFailureRatio=NaN;
            end
            boot=nan(max(100,settings.prccBootstrap),1);
            if ~isempty(v)
                for b=1:numel(boot), boot(b)=mean(v(randi(size(v,1),size(v,1),1),4)); end
            end
            row.SynergyCI_Low=aigc.percentile(boot,2.5);
            row.SynergyCI_High=aigc.percentile(boot,97.5);
            row.SuperAdditive=isfinite(row.SynergyCI_Low)&&row.SynergyCI_Low>0;
            rows=aigc.append_struct_row(rows,row);
        end
    end
end
T=aigc.struct_rows_to_table(rows);
end

function T=control_mediation(mainT)
factors=unique(mainT.Factor,'stable'); scopes=unique(mainT.Scope,'stable'); rows=struct([]);
for s=1:numel(scopes)
    for i=1:numel(factors)
        f=strcmp(mainT.Factor,factors{i})&strcmp(mainT.Scope,scopes{s});
        fx=f&strcmp(mainT.Audit,'Fixed'); dy=f&strcmp(mainT.Audit,'Dynamic');
        row=struct(); row.Scope=scopes{s}; row.Factor=factors{i};
        row.FixedEffectI=mainT.EffectI(fx); row.DynamicEffectI=mainT.EffectI(dy);
        row.AbsoluteCompressionI=abs(row.FixedEffectI)-abs(row.DynamicEffectI);
        row.RelativeCompressionI=1-abs(row.DynamicEffectI)/(abs(row.FixedEffectI)+eps);
        rows=aigc.append_struct_row(rows,row);
    end
end
T=aigc.struct_rows_to_table(rows);
end

function plot_main_comparison(T,scope)
names=unique(T.Factor,'stable'); audits={'Fixed','Dynamic'}; metrics={'EffectI','EffectT','EffectQexp'};
Y=nan(numel(names),numel(audits)*numel(metrics)); legends=cell(1,size(Y,2)); col=0;
for m=1:numel(metrics)
    for a=1:numel(audits)
        col=col+1; legends{col}=[audits{a} ' ' strrep(metrics{m},'Effect','')];
        for j=1:numel(names)
            idx=strcmp(T.Scope,scope)&strcmp(T.Audit,audits{a})&strcmp(T.Factor,names{j});
            if any(idx), Y(j,col)=T.(metrics{m})(find(idx,1)); end
        end
    end
end
plot(1:numel(names),Y,'-o','LineWidth',0.9,'MarkerSize',3);
labels=cellfun(@aigc.parameter_display_name,names,'UniformOutput',false);
set(gca,'XTick',1:numel(names),'XTickLabel',labels,'TickLabelInterpreter','latex');
yline(0,'k--'); ylabel('Good level minus bad level (dimensionless)');
legend(legends,'Location','best','NumColumns',2); grid on;
end

function plot_interaction_heatmap(T,names,audit,scope,metric)
M=zeros(numel(names)); idx=strcmp(T.Audit,audit)&strcmp(T.Scope,scope);
S=T(idx,:);
for i=1:height(S)
    a=find(strcmp(names,S.Factor1{i}),1); b=find(strcmp(names,S.Factor2{i}),1);
    M(a,b)=S.(metric)(i); M(b,a)=M(a,b);
end
imagesc(M); axis square; cb=colorbar;
cb.Label.String='Signed interaction (positive = joint good levels raise the plotted outcome; dimensionless)';
lim=max(abs(M(:))); if lim>0, caxis([-lim lim]); end
labels=cellfun(@aigc.parameter_display_name,names,'UniformOutput',false);
set(gca,'XTick',1:numel(names),'XTickLabel',labels,'YTick',1:numel(names), ...
    'YTickLabel',labels,'TickLabelInterpreter','latex');
xtickangle(45);
end

function plot_joint(T)
S=T(strcmp(T.Scope,'All'),:); R=T(strcmp(T.Scope,'Resolved'),:);
labels=strcat(S.Audit,'-',S.Metric); Y=nan(height(S),2); Y(:,1)=S.SynergyExcess;
for i=1:height(S)
    q=strcmp(R.Audit,S.Audit{i})&strcmp(R.Metric,S.Metric{i});
    if any(q), Y(i,2)=R.SynergyExcess(find(q,1)); end
end
bar(1:height(S),Y); set(gca,'XTick',1:height(S),'XTickLabel',labels); xtickangle(35);
ylabel('Signed joint excess (dimensionless)'); legend({'All','Resolved'},'Location','best');
yline(0,'k--'); grid on;
end

function plot_resolved_comparison(T)
audits={'Fixed','Dynamic'}; markers={'o','s'}; hold on; allValues=[];
for a=1:numel(audits)
    A=T(strcmp(T.Scope,'All')&strcmp(T.Audit,audits{a}),:);
    R=T(strcmp(T.Scope,'Resolved')&strcmp(T.Audit,audits{a}),:);
    x=nan(height(A),1); y=x;
    for i=1:height(A)
        q=strcmp(R.Factor,A.Factor{i}); x(i)=A.EffectI(i);
        if any(q), y(i)=R.EffectI(find(q,1)); end
    end
    scatter(x,y,45,'filled','Marker',markers{a},'DisplayName',audits{a});
    allValues=[allValues;x;y]; %#ok<AGROW>
end
v=allValues(isfinite(allValues));
if ~isempty(v), lo=min(v); hi=max(v); plot([lo hi],[lo hi],'k--','DisplayName','Equality'); end
xlabel('Risk main effect: all trajectories'); ylabel('Risk main effect: resolved subset');
legend('Location','best'); grid on;
end

function m=safe_mean(x)
if isempty(x), m=NaN; else, m=mean(x,'omitnan'); end
end
