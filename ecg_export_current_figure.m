function ecg_export_current_figure(filename)
%ECG_EXPORT_CURRENT_FIGURE Save current figure at 300 dpi.
if nargin < 1 || isempty(filename)
    filename = ['figure_' datestr(now,'yyyymmdd_HHMMSS') '.png'];
end
try
    exportgraphics(gcf, filename, 'Resolution', 300);
catch
    print(gcf, filename, '-dpng', '-r300');
end
fprintf('Saved figure: %s\n', filename);
end
