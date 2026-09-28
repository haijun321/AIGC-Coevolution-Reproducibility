function summary = BUILD_SR_FIGURE5_FINAL_REPAIRED_V1(outFull)
% BUILD_SR_FIGURE5_FINAL_REPAIRED_V1
% Final audit + publication Figure 5 builder for repaired Exp05-P1.
%
% Usage:
%   outFull = fullfile(pwd,'results','exp05_independent_aigc_prcc');
%   summary = BUILD_SR_FIGURE5_FINAL_REPAIRED_V1(outFull);
%
% Required output files:
%   exp05_p1_raw_all_independent_designs.csv
%   exp05_p1_raw_N640_rep01.csv
%   exp05_p1_primary_effect_prcc_bootstrap.csv
%   exp05_p1_primary_effect_probabilities.csv
%   experiment_quality_check.csv
%
% Figure panels:
%   (a) PRCC for I_Dynamic, primary N=640 rep=1, AllFinite
%   (b) PRCC for DeltaI_net, primary N=640 rep=1, SameRegimeThree
%   (c) DeltaI_capacity versus DeltaI_net, SameRegimeThree
%   (d) Directional versus material adverse-effect probabilities
%
% The script intentionally does NOT use DeltaI_adapt PRCC as a main panel,
% because the repaired experiment shows that this response is near-zero in
% long-run mean risk after capacity matching.

if nargin < 1 || strlength(string(outFull)) == 0
    error('Please supply the repaired FULL output directory.');
end
outFull = char(outFull);
assert(isfolder(outFull), 'Output directory does not exist:\n%s', outFull);

fAll  = fullfile(outFull,'exp05_p1_raw_all_independent_designs.csv');
fP    = fullfile(outFull,'exp05_p1_raw_N640_rep01.csv');
fBoot = fullfile(outFull,'exp05_p1_primary_effect_prcc_bootstrap.csv');
fProb = fullfile(outFull,'exp05_p1_primary_effect_probabilities.csv');
fQC   = fullfile(outFull,'experiment_quality_check.csv');

req = {fAll,fP,fBoot,fProb,fQC};
for k = 1:numel(req)
    assert(isfile(req{k}), 'Missing required file:\n%s', req{k});
end

Tall = readtable(fAll,'VariableNamingRule','preserve');
P    = readtable(fP,'VariableNamingRule','preserve');
B    = readtable(fBoot,'VariableNamingRule','preserve');
Prob = readtable(fProb,'VariableNamingRule','preserve');
QC   = readtable(fQC,'VariableNamingRule','preserve');

%% ----------------------------------------------------------------------
% 1. HARD AUDIT
% -----------------------------------------------------------------------
fprintf('\n============================================================\n');
fprintf(' SR FIGURE 5 FINAL AUDIT — REPAIRED Exp05-P1\n');
fprintf('============================================================\n');

% Expected FULL design size
expectedN = [160 320 640];
expectedReps = 5;
expectedTotal = expectedReps * sum(expectedN);
assert(height(Tall)==expectedTotal, ...
    'Unexpected total row count: %d (expected %d).',height(Tall),expectedTotal);

for N = expectedN
    for rep = 1:expectedReps
        nHere = sum(Tall.DesignN==N & Tall.DesignRep==rep);
        assert(nHere==N, ...
            'Design N=%d rep=%d has %d rows (expected %d).',N,rep,nHere,N);
    end
end

% Core repaired-interface audits
capErr = max(abs(Tall.CapacityMatchError),[],'omitnan');
eErr   = max(abs(Tall.E_FixedEffective - Tall.MatchedE),[],'omitnan');
decErr = max(abs(Tall.DeltaI_net - Tall.DeltaI_capacity - Tall.DeltaI_adapt),[],'omitnan');

assert(capErr <= 1e-10, ...
    'CapacityMatchError failed: %.4e > 1e-10.',capErr);
assert(eErr <= 1e-10, ...
    'Effective-E audit failed: %.4e > 1e-10.',eErr);
assert(decErr <= 1e-12, ...
    'Risk decomposition identity failed: %.4e > 1e-12.',decErr);

% Runner quality-gate table
if ismember('Pass',QC.Properties.VariableNames)
    assert(all(logical(QC.Pass)), ...
        'At least one experiment_quality_check.csv gate failed.');
end

% Primary design
assert(height(P)==640,'Primary N=640 rep01 file does not contain 640 rows.');
same = logical(P.SameRegimeThree) & ...
       isfinite(P.DeltaI_net) & ...
       isfinite(P.DeltaI_capacity) & ...
       isfinite(P.DeltaI_adapt);

nSame = sum(same);
assert(nSame > 23, ...
    'SameRegimeThree primary subset too small for 20-predictor PRCC.');

% Near-zero adaptation audit (descriptive, NOT a pass/fail assertion)
den = abs(P.DeltaI_net(same));
ada = abs(P.DeltaI_adapt(same));
cap = abs(P.DeltaI_capacity(same));
ratioMask = den > 1e-10;

medianCapNet = median(cap(ratioMask)./den(ratioMask),'omitnan');
medianAdaNet = median(ada(ratioMask)./den(ratioMask),'omitnan');
maxAdaNet    = max(ada(ratioMask)./den(ratioMask),[],'omitnan');
maxAdaAbs    = max(ada,[],'omitnan');

fprintf('FULL design rows                      : %d / %d [PASS]\n',height(Tall),expectedTotal);
fprintf('Max CapacityMatchError                : %.4e [PASS]\n',capErr);
fprintf('Max |E_FixedEffective - MatchedE|     : %.4e [PASS]\n',eErr);
fprintf('Max decomposition error               : %.4e [PASS]\n',decErr);
fprintf('Primary SameRegimeThree               : %d / 640\n',nSame);
fprintf('Median |DeltaI_capacity/DeltaI_net|   : %.12g\n',medianCapNet);
fprintf('Median |DeltaI_adapt/DeltaI_net|      : %.12g\n',medianAdaNet);
fprintf('Max |DeltaI_adapt/DeltaI_net|         : %.12g\n',maxAdaNet);
fprintf('Max |DeltaI_adapt|                    : %.12g\n',maxAdaAbs);
fprintf('============================================================\n\n');

%% ----------------------------------------------------------------------
% 2. SELECT DATA FOR PANELS
% -----------------------------------------------------------------------
% Panel A: state-level long-run risk, all-finite primary design
A = B(string(B.Response)=="I_Dynamic" & string(B.Subset)=="AllFinite",:);
assert(~isempty(A),'No bootstrap rows for I_Dynamic / AllFinite.');
A = sortrows(A,'PRCC','descend'); %#ok<NASGU>
[~,ordA] = sort(abs(A.PRCC),'descend');
A = A(ordA(1:min(8,height(A))),:);

% Panel B: net AIGC risk effect, strict three-branch subset
D = B(string(B.Response)=="DeltaI_net" & string(B.Subset)=="SameRegimeThree",:);
assert(~isempty(D),'No bootstrap rows for DeltaI_net / SameRegimeThree.');
[~,ordD] = sort(abs(D.PRCC),'descend');
D = D(ordD(1:min(8,height(D))),:);

% Panel C: repaired effect decomposition
C = P(same,:);

% Panel D: net risk / net trust at tau = 1e-3 in SameRegimeThree
tau = 1e-3;
Q = Prob(string(Prob.Subset)=="SameRegimeThree" & ...
         abs(Prob.Threshold-tau)<1e-14,:);
Qr = Q(string(Q.Response)=="DeltaI_net",:);
Qt = Q(string(Q.Response)=="DeltaT_net",:);
assert(height(Qr)==1 && height(Qt)==1, ...
    'Could not identify unique DeltaI_net / DeltaT_net probability rows at tau=1e-3.');

barData = [Qr.AdverseDirection Qr.AdverseMaterial; ...
           Qt.AdverseDirection Qt.AdverseMaterial];

%% ----------------------------------------------------------------------
% 3. BUILD PUBLICATION FIGURE
% -----------------------------------------------------------------------
figDir = fullfile(outFull,'Figure5_FINAL_REPAIRED_V1');
if ~isfolder(figDir), mkdir(figDir); end

fig = figure('Color','w','Units','centimeters', ...
    'Position',[2 2 18.0 14.2], ...
    'PaperPositionMode','auto');

tl = tiledlayout(fig,2,2,'TileSpacing','compact','Padding','compact');

% ---- (a)
ax1 = nexttile(tl,1);
hold(ax1,'on');
x = 1:height(A);
errorbar(ax1,x,A.PRCC,A.PRCC-A.CI_Low,A.CI_High-A.PRCC, ...
    'o','LineWidth',1.05,'MarkerSize',4.5,'CapSize',5);
yline(ax1,0,'--','LineWidth',0.8);
ylim(ax1,[-1 1]);
xlim(ax1,[0.4 height(A)+0.6]);
xticks(ax1,x);
xticklabels(ax1,pretty_parameters(A.Parameter));
xtickangle(ax1,35);
ylabel(ax1,'PRCC');
title(ax1,sprintf('(a) Long-run risk sensitivity, N = %d',A.NUsed(1)));
grid(ax1,'on');
box(ax1,'on');

% ---- (b)
ax2 = nexttile(tl,2);
hold(ax2,'on');
x = 1:height(D);
errorbar(ax2,x,D.PRCC,D.PRCC-D.CI_Low,D.CI_High-D.PRCC, ...
    'o','LineWidth',1.05,'MarkerSize',4.5,'CapSize',5);
yline(ax2,0,'--','LineWidth',0.8);
ylim(ax2,[-1 1]);
xlim(ax2,[0.4 height(D)+0.6]);
xticks(ax2,x);
xticklabels(ax2,pretty_parameters(D.Parameter));
xtickangle(ax2,35);
ylabel(ax2,'PRCC');
title(ax2,sprintf('(b) Net AIGC risk-effect sensitivity, N = %d',D.NUsed(1)));
grid(ax2,'on');
box(ax2,'on');

% ---- (c)
ax3 = nexttile(tl,3);
hold(ax3,'on');
scatter(ax3,C.DeltaI_net,C.DeltaI_capacity,18,'filled', ...
    'MarkerFaceAlpha',0.55,'MarkerEdgeAlpha',0.55);

allv = [C.DeltaI_net; C.DeltaI_capacity];
lo = min(allv,[],'omitnan');
hi = max(allv,[],'omitnan');
span = max(hi-lo,1e-8);
lims = [lo-0.04*span, hi+0.04*span];
plot(ax3,lims,lims,'--','LineWidth',0.9);
xlim(ax3,lims);
ylim(ax3,lims);
axis(ax3,'square');
xlabel(ax3,'Net risk effect, \DeltaI_{net}');
ylabel(ax3,'Capacity effect, \DeltaI_{cap}');
title(ax3,'(c) Repaired three-branch decomposition');
grid(ax3,'on');
box(ax3,'on');

txt = sprintf(['N = %d\n' ...
               'median |cap/net| = %.6g\n' ...
               'median |adapt/net| = %.2e'], ...
               nSame,medianCapNet,medianAdaNet);
text(ax3,0.04,0.96,txt,'Units','normalized', ...
    'VerticalAlignment','top','BackgroundColor','w','Margin',4);

% ---- (d)
ax4 = nexttile(tl,4);
bh = bar(ax4,barData,'grouped');
ylim(ax4,[0 1]);
yticks(ax4,0:0.2:1);
xticks(ax4,1:2);
xticklabels(ax4,{'Net risk','Net trust'});
ylabel(ax4,'Probability');
title(ax4,'(d) Direction versus material-effect prevalence');
legend(ax4,bh,{'Adverse direction','Adverse and |\Delta| > 10^{-3}'}, ...
    'Location','southoutside','Orientation','horizontal');
grid(ax4,'on');
box(ax4,'on');

% Consistent typography
set(findall(fig,'-property','FontName'),'FontName','Arial');
set(findall(fig,'-property','FontSize'),'FontSize',9);
set(findall(fig,'-property','LineWidth'),'LineWidth',0.8);

% Keep key plotting lines slightly thicker after global formatting
set(findall(fig,'Type','ErrorBar'),'LineWidth',1.05);

% Global title intentionally omitted for journal layout.
drawnow;

base = fullfile(figDir,'Figure5_SR_FINAL_REPAIRED_V1');
exportgraphics(fig,[base '.pdf'],'ContentType','vector');
exportgraphics(fig,[base '.png'],'Resolution',600);
savefig(fig,[base '.fig']);
try
    print(fig,[base '.eps'],'-depsc','-painters');
catch ME
    warning('EPS export failed: %s',ME.message);
end

%% ----------------------------------------------------------------------
% 4. SAVE MACHINE-READABLE FIGURE SUMMARY
% -----------------------------------------------------------------------
summary = table( ...
    height(Tall),nSame,capErr,eErr,decErr, ...
    medianCapNet,medianAdaNet,maxAdaNet,maxAdaAbs, ...
    Qr.AdverseDirection,Qr.AdverseMaterial, ...
    Qt.AdverseDirection,Qt.AdverseMaterial, ...
    'VariableNames',{ ...
    'FullRows','PrimarySameRegimeN','MaxCapacityMatchError', ...
    'MaxEffectiveEError','MaxDecompositionError', ...
    'MedianAbsCapacityToNet','MedianAbsAdaptToNet', ...
    'MaxAbsAdaptToNet','MaxAbsDeltaIAdapt', ...
    'RiskAdverseDirection','RiskAdverseMaterialTau1e3', ...
    'TrustAdverseDirection','TrustAdverseMaterialTau1e3'});

writetable(summary,fullfile(figDir,'Figure5_SR_FINAL_REPAIRED_V1_summary.csv'));

writetable(A,fullfile(figDir,'Figure5_panelA_PRCC.csv'));
writetable(D,fullfile(figDir,'Figure5_panelB_PRCC.csv'));
writetable(C(:,{'DesignN','DesignRep','Sample','DeltaI_net', ...
    'DeltaI_capacity','DeltaI_adapt','DeltaT_net', ...
    'DeltaT_capacity','DeltaT_adapt','SameRegimeThree'}), ...
    fullfile(figDir,'Figure5_panelC_effect_decomposition.csv'));
writetable(Q,fullfile(figDir,'Figure5_panelD_probabilities.csv'));

fprintf('Figure 5 files written to:\n%s\n',figDir);
fprintf('PDF : %s.pdf\n',base);
fprintf('PNG : %s.png\n',base);
fprintf('EPS : %s.eps\n',base);
fprintf('FIG : %s.fig\n',base);

end

function labels = pretty_parameters(p)
p = string(p);
labels = strings(size(p));
for i = 1:numel(p)
    s = p(i);
    switch s
        case "CR",      labels(i) = "C_R";
        case "lambda0", labels(i) = "\lambda_0";
        case "beta0",   labels(i) = "\beta_0";
        case "alpha",   labels(i) = "\alpha";
        case "delta",   labels(i) = "\delta";
        case "mu",      labels(i) = "\mu";
        case "rhoE",    labels(i) = "\rho_E";
        case "psiE",    labels(i) = "\psi_E";
        case "etaI",    labels(i) = "\eta_I";
        case "etaC",    labels(i) = "\eta_C";
        case "chi",     labels(i) = "\chi";
        case "attn",    labels(i) = "\chi";
        case "antiE",   labels(i) = "a_E";
        case "FP",      labels(i) = "F_P";
        otherwise
            labels(i) = replace(s,"_","\_");
    end
end
labels = cellstr(labels);
end
