function save_figure(fig,pathBase)
%SAVE_FIGURE Save PNG and FIG with compatibility fallback.
try
    exportgraphics(fig,[pathBase '.png'],'Resolution',220);
catch
    saveas(fig,[pathBase '.png']);
end
try, savefig(fig,[pathBase '.fig']); catch, end
end
