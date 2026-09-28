function T = parameter_dictionary(p)
%PARAMETER_DICTIONARY Machine-readable baseline parameter dictionary.
groups = struct();
groups.Governance = {'s','h','f','c','r','chi','eD0','eL0','eMax','rhoAuditD','rhoAuditL', ...
    'omegaEvasionE','rhoPenalty','kDetect','kAction','handleWindow','omegaA','deltaA', ...
    'kappaIn','kappaSp','kappaRm','kLabel','deltaLabel','deltaCross'};
groups.QualityIdentification = {'qC','qS','nu0','nu1'};
groups.ProducerPayoff = {'RC','RS','thetaT_prod','thetaI','BC','CC','CS','FP','LP','Ce','Cregen','CfpP'};
groups.PlatformPayoff = {'RF','BWF','gQ','gT','CR','CW','CfpF','LF','FF'};
groups.UserPayoff = {'BU','CV','LU','BD'};
groups.Risk = {'lambda0','psiE','beta0','gamma0','gammaPlatform','gammaUser','thetaT_share','aigcHillK'};
groups.Trust = {'alpha','delta','xi','mu','kappa','omegaG','omegaD','omegaI','omegaF','omegaM', ...
    'omegaETrust','kB','thetaB','phiL','phiH','hillN'};
groups.AuditControl = {'auditSpeed','etaI','etaT','etaA','etaC','Istar','Tstar','Astar','Cstar','uRef'};
groups.AIGCAdaptation = {'rhoE','rhoEPenalty','rhoEAnti','rhoEDecay','antiE'};
groups.Cost = {'costLabel','costBacklog','costProvenance','costAntiEvasion','costDynamicSystem','costFixedSystem','costPolicyImplementation'};
groups.SymmetricSwitching = {'epsP','epsF','epsU'};
groups.Reference = {'Iref','Tref','Mref','Aref','Lref','Eref'};
fn=fieldnames(p); rows=repmat(struct('CodeField','','Baseline',NaN,'Group','','Scale','','UsedIn',''),numel(fn),1);
gn=fieldnames(groups);
for i=1:numel(fn)
    rows(i).CodeField=fn{i}; rows(i).Baseline=p.(fn{i}); rows(i).Group='Other';
    for g=1:numel(gn)
        if ismember(fn{i},groups.(gn{g})), rows(i).Group=gn{g}; break; end
    end
    if ismember(fn{i},{'s','h','f','c','r','chi','eD0','eL0','eMax','qC','qS','nu0','nu1', ...
            'omegaG','Istar','Tstar','Astar','uRef','antiE','Iref','Tref','Mref','Aref','Lref','Eref'})
        rows(i).Scale='[0,1]';
    else
        rows(i).Scale='dimensionless';
    end
    rows(i).UsedIn='model and/or Exp00-Exp09';
end
T=struct2table(rows);
end
