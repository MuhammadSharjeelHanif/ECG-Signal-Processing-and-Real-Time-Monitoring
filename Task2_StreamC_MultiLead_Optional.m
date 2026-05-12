clear; clc; close all;
% ========================================================================
% TASK 2 STREAM C - MULTI-LEAD PHASE CONSISTENCY (ADVANCED)
% Uses a real PTB Diagnostic ECG Database record from PhysioNet by default.
% The PTB record contains 15 simultaneous leads; this script uses the first
% 12 standard ECG leads for the required multi-lead phase analysis.
% ========================================================================

outputFolder = fullfile(pwd, 'Task2_StreamC_outputs');
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

mainsHz = 50;
defaultFs = 1000;
segmentSec = 10;
leadNames = {'I','II','III','aVR','aVL','aVF','V1','V2','V3','V4','V5','V6'};

%% C.1 Load multi-lead ECG
if usejava('desktop')
    choice = menu('Multi-lead ECG source', ...
        'Download/load PTB Diagnostic DB patient001/s0010_re', ...
        'Load MAT file with ECG matrix');
else
    choice = 1;
end
if choice == 1
    dataFolder = fullfile(pwd, 'ptbdb_patient001');
    [X, Fs, meta] = load_ptb_patient001_s0010(dataFolder, segmentSec);
elseif choice == 2
    [file,path] = uigetfile({'*.mat','MAT files'}, 'Select MAT file with samples x leads ECG matrix');
    if isequal(file,0), error('No MAT file selected.'); end
    S = load(fullfile(path,file));
    names = fieldnames(S); X = [];
    for k = 1:numel(names)
        v = S.(names{k});
        if isnumeric(v) && ismatrix(v) && min(size(v)) >= 8 && max(size(v)) > 1000
            X = v; break;
        end
    end
    if isempty(X), error('No suitable ECG matrix found.'); end
    if size(X,1) < size(X,2), X = X.'; end
    if isfield(S,'Fs'), Fs = S.Fs; else, Fs = defaultFs; end
    meta = struct('source','User-selected MAT file', 'recordID',file, ...
        'age','User supplied', 'sex','User supplied', ...
        'diagnosis','User supplied', 'url','Local MAT file');
else
    error('No Stream C input source selected.');
end
X = double(X);
numLeads = min(12, size(X,2));
X = X(:,1:numLeads);
leadNames = leadNames(1:numLeads);
t = (0:size(X,1)-1)'/Fs;

infoTable = table({meta.source}, {meta.recordID}, Fs, size(X,1)/Fs, ...
    numLeads, {strjoin(leadNames, ', ')}, {meta.age}, {meta.sex}, ...
    {meta.diagnosis}, {meta.url}, ...
    'VariableNames', {'Dataset','Record_ID','Sampling_Rate_Hz', ...
    'Duration_Used_s','Number_of_Leads_Used','Lead_Names','Age','Sex', ...
    'Diagnosis','Source_URL'});
writetable(infoTable, fullfile(outputFolder,'C1_dataset_information_table.csv'));

figC1 = figure('Name','C.1 Raw 12-lead ECG stacked','Color','w','Position',[80 60 1150 750]);
plot_stacked(t, X, leadNames, sprintf('C.1 Raw multi-lead ECG: %s %s', meta.source, meta.recordID));
exportgraphics(figC1, fullfile(outputFolder,'C1_raw_12lead_stacked.png'), 'Resolution',300);

figC1b = figure('Name','C.1 Dataset Information','Color','w','Position',[100 100 1200 320]);
draw_table_as_text(infoTable, 'C.1 Dataset information for Stream C multi-lead record');
exportgraphics(figC1b, fullfile(outputFolder,'C1_dataset_information_table.png'), 'Resolution',300);

%% C.2 Phase and group delay of Stream A filters
F = ecg_design_filters(Fs, mainsHz, 0.5, 40, 35);
filters = {'HP IIR',F.bHP,F.aHP; 'Notch IIR',F.bNotch,F.aNotch; 'LP IIR',F.bLP,F.aLP; 'LP FIR',F.bFIR_LP,F.aFIR_LP};
for k = 1:size(filters,1)
    name = filters{k,1}; b = filters{k,2}; a = filters{k,3};
    [H,w] = freqz(b,a,4096,Fs); [gd,wgd] = grpdelay(b,a,4096,Fs);
    fig = figure('Name',['C.2 Phase/group delay ' name],'Color','w','Position',[80 80 1100 650]);
    subplot(2,1,1); plot(w, unwrap(angle(H)), 'LineWidth',1.2); grid on; xlim([0 min(100,Fs/2)]);
    xlabel('Frequency (Hz)'); ylabel('Phase (rad)'); title(['Phase response: ' name]);
    subplot(2,1,2); plot(wgd, gd/Fs*1000, 'LineWidth',1.2); grid on; xlim([0 min(100,Fs/2)]);
    xlabel('Frequency (Hz)'); ylabel('Group delay (ms)'); title(['Group delay: ' name]);
    exportgraphics(fig, fullfile(outputFolder,['C2_phase_group_delay_' regexprep(name,'[^a-zA-Z0-9]','_') '.png']), 'Resolution',300);
end

%% C.3 Demonstrate phase distortion using causal IIR filtering
Y_iir_causal = zeros(size(X));
for lead = 1:numLeads
    y = X(:,lead);
    y = filter(F.bHP,F.aHP,y);
    y = filter(F.bNotch,F.aNotch,y);
    y = filter(F.bLP,F.aLP,y);
    Y_iir_causal(:,lead) = y;
end

figC3 = figure('Name','C.3 Phase distortion demonstration','Color','w','Position',[80 80 1150 600]);
leadA = 1; leadB = min(2,numLeads);
plot(t, normalize_lead(X(:,leadA)), 'DisplayName',['Raw ' leadNames{leadA}]); hold on; grid on;
plot(t, normalize_lead(X(:,leadB))+2, 'DisplayName',['Raw ' leadNames{leadB} ' offset']);
plot(t, normalize_lead(Y_iir_causal(:,leadA))-2, 'DisplayName',['Causal IIR ' leadNames{leadA} ' offset']);
plot(t, normalize_lead(Y_iir_causal(:,leadB))-4, 'DisplayName',['Causal IIR ' leadNames{leadB} ' offset']);
xlabel('Time (s)'); ylabel('Normalized amplitude + offsets'); title('C.3 Causal IIR filtering can shift waveform timing'); legend('Location','best');
exportgraphics(figC3, fullfile(outputFolder,'C3_phase_distortion_overlay.png'), 'Resolution',300);

%% C.4 Correct using zero-phase filtering
Y_zero = zeros(size(X));
for lead = 1:numLeads
    [Y_zero(:,lead),~] = ecg_apply_classical_filters(X(:,lead), Fs, F);
end
figC4 = figure('Name','C.4 Corrected zero-phase 12-lead','Color','w','Position',[80 60 1150 750]);
plot_stacked(t, Y_zero, leadNames, 'C.4 Corrected multi-lead ECG using zero-phase filtering');
exportgraphics(figC4, fullfile(outputFolder,'C4_corrected_12lead_zero_phase.png'), 'Resolution',300);

%% C.5 Cross-correlation alignment before/after
pairs = [1 2; 1 min(6,numLeads); 2 min(7,numLeads); min(7,numLeads) min(8,numLeads)];
pairs = unique(pairs(all(pairs<=numLeads,2),:),'rows');
rows = [];
for k = 1:size(pairs,1)
    a = pairs(k,1); b = pairs(k,2);
    lagRaw = best_lag_ms(X(:,a), X(:,b), Fs);
    lagIIR = best_lag_ms(Y_iir_causal(:,a), Y_iir_causal(:,b), Fs);
    lagZero = best_lag_ms(Y_zero(:,a), Y_zero(:,b), Fs);
    rows = [rows; {leadNames{a}, leadNames{b}, lagRaw, lagIIR, lagZero}]; %#ok<AGROW>
end
lagTable = cell2table(rows, 'VariableNames', {'Lead_A','Lead_B','Raw_Lag_ms','Causal_IIR_Lag_ms','ZeroPhase_Lag_ms'});
writetable(lagTable, fullfile(outputFolder,'C5_cross_correlation_lag_table.csv'));
disp('C.5 Cross-correlation lag table'); disp(lagTable);

figC5 = figure('Name','C.5 Lead alignment table','Color','w','Position',[100 100 900 300]);
draw_table_as_text(lagTable, 'C.5 Cross-correlation alignment before/after filtering');
exportgraphics(figC5, fullfile(outputFolder,'C5_cross_correlation_lag_table.png'), 'Resolution',300);

figC5b = figure('Name','C.5 Cross-correlation functions','Color','w','Position',[80 60 1150 760]);
for k = 1:size(pairs,1)
    a = pairs(k,1); b = pairs(k,2);
    subplot(size(pairs,1),1,k);
    plot_xcorr_overlay(X(:,a), X(:,b), Y_iir_causal(:,a), Y_iir_causal(:,b), ...
        Y_zero(:,a), Y_zero(:,b), Fs);
    title(sprintf('C.5 Cross-correlation: %s vs %s', leadNames{a}, leadNames{b}));
end
exportgraphics(figC5b, fullfile(outputFolder,'C5_cross_correlation_functions.png'), 'Resolution',300);

%% C.6 Maximum timing error
maxPairErrIIR = max(abs(lagTable.Causal_IIR_Lag_ms - lagTable.Raw_Lag_ms));
maxPairErrZero = max(abs(lagTable.ZeroPhase_Lag_ms - lagTable.Raw_Lag_ms));

sameLeadRows = cell(numLeads, 3);
for lead = 1:numLeads
    sameLeadRows{lead,1} = leadNames{lead};
    sameLeadRows{lead,2} = best_lag_ms(X(:,lead), Y_iir_causal(:,lead), Fs);
    sameLeadRows{lead,3} = best_lag_ms(X(:,lead), Y_zero(:,lead), Fs);
end
sameLeadTimingTable = cell2table(sameLeadRows, ...
    'VariableNames', {'Lead','Causal_IIR_vs_Raw_Lag_ms','ZeroPhase_vs_Raw_Lag_ms'});
writetable(sameLeadTimingTable, fullfile(outputFolder,'C6_same_lead_processing_delay_table.csv'));

maxSameLeadErrIIR = max(abs(sameLeadTimingTable.Causal_IIR_vs_Raw_Lag_ms));
maxSameLeadErrZero = max(abs(sameLeadTimingTable.ZeroPhase_vs_Raw_Lag_ms));
maxErrorTable = table(maxPairErrIIR, maxPairErrZero, maxSameLeadErrIIR, maxSameLeadErrZero, ...
    'VariableNames', {'MaxCrossLeadLagChange_CausalIIR_ms', ...
    'MaxCrossLeadLagChange_ZeroPhase_ms', ...
    'MaxSameLeadProcessingDelay_CausalIIR_ms', ...
    'MaxSameLeadProcessingDelay_ZeroPhase_ms'});
writetable(maxErrorTable, fullfile(outputFolder,'C6_max_timing_error_table.csv'));
disp('C.6 Maximum timing error table'); disp(maxErrorTable);

figC6 = figure('Name','C.6 Maximum Timing Error Table','Color','w','Position',[100 100 720 260]);
draw_table_as_text(maxErrorTable, 'C.6 Maximum timing error summary');
exportgraphics(figC6, fullfile(outputFolder,'C6_max_timing_error_table.png'), 'Resolution',300);

figC6b = figure('Name','C.6 Same Lead Processing Delay Table','Color','w','Position',[100 100 900 420]);
draw_table_as_text(sameLeadTimingTable, 'C.6 Same-lead processing delay before/after correction');
exportgraphics(figC6b, fullfile(outputFolder,'C6_same_lead_processing_delay_table.png'), 'Resolution',300);

%% C.7 Clinical impact analysis
analysisText = sprintf(['Stream C clinical impact analysis:\n' ...
'1. Multi-lead ECG diagnosis depends on comparing timing and shape across different leads.\n' ...
'2. If filtering delays one lead differently from another, the ECG may look clean but become system-level incorrect.\n' ...
'3. The selected PTB record is a myocardial-infarction case, so preserving inter-lead timing is clinically important.\n' ...
'4. Phase distortion can shift QRS onset or ST-segment timing and may confuse morphology-based interpretation.\n' ...
'5. The causal IIR pipeline changed selected cross-lead correlation lags by as much as %.2f ms.\n' ...
'6. Same-lead processing delay after zero-phase filtering was %.2f ms, showing timing preservation relative to the raw lead.\n' ...
'7. This shows why magnitude-only filter design is not enough for multi-channel biomedical systems.\n' ...
'8. For multi-lead ECG, group delay consistency must be verified along with noise reduction.\n'], maxPairErrIIR, maxSameLeadErrZero);
fid = fopen(fullfile(outputFolder,'C7_clinical_impact_analysis.txt'),'w'); fprintf(fid,'%s',analysisText); fclose(fid);
fprintf('\n%s\n', analysisText);

fprintf('\nStream C outputs saved in: %s\n', outputFolder);

%% ----------------------- LOCAL FUNCTIONS -------------------------------
function [X, Fs, meta] = load_ptb_patient001_s0010(dataFolder, segmentSec)
if ~exist(dataFolder, 'dir'), mkdir(dataFolder); end
baseUrl = 'https://physionet.org/files/ptbdb/1.0.0/patient001/';
files = {'s0010_re.hea','s0010_re.dat','s0010_re.xyz'};
for k = 1:numel(files)
    localFile = fullfile(dataFolder, files{k});
    if ~exist(localFile, 'file')
        fprintf('Downloading %s from PhysioNet...\n', files{k});
        websave(localFile, [baseUrl files{k}]);
    end
end

heaFile = fullfile(dataFolder, 's0010_re.hea');
datFile = fullfile(dataFolder, 's0010_re.dat');
headerText = fileread(heaFile);
headerLines = regexp(headerText, '\r\n|\n|\r', 'split');
first = strsplit(strtrim(headerLines{1}));
numSignals = str2double(first{2});
Fs = str2double(first{3});
numSamples = str2double(first{4});

gains = ones(1, numSignals);
for k = 1:numSignals
    parts = strsplit(strtrim(headerLines{1+k}));
    gains(k) = str2double(parts{3});
end

fid = fopen(datFile, 'r');
if fid < 0, error('Could not open PTB DAT file: %s', datFile); end
raw = fread(fid, [numSignals, numSamples], 'int16=>double').';
fclose(fid);

maxSamples = min(numSamples, round(segmentSec * Fs));
raw = raw(1:maxSamples, :);
X = raw(:,1:12) ./ gains(1:12);

meta = struct();
meta.source = 'PTB Diagnostic ECG Database';
meta.recordID = 'patient001/s0010_re';
meta.age = extract_header_value(headerText, 'age');
meta.sex = extract_header_value(headerText, 'sex');
meta.diagnosis = extract_header_value(headerText, 'Reason for admission');
meta.url = 'https://physionet.org/content/ptbdb/1.0.0/patient001/';
end

function plot_stacked(t, X, leadNames, ttl)
numLeads = size(X,2); hold on; grid on;
offset = 3;
for k = 1:numLeads
    y = normalize_lead(X(:,k)) + (numLeads-k)*offset;
    plot(t, y, 'LineWidth',1.0);
    text(t(1), (numLeads-k)*offset, leadNames{k}, 'FontWeight','bold', 'HorizontalAlignment','right');
end
xlabel('Time (s)'); ylabel('Leads with vertical offsets'); title(ttl, 'Interpreter','none');
yticks([]); xlim([t(1) min(t(end), 10)]);
end

function y = normalize_lead(x)
x = double(x(:)); x = x - median(x,'omitnan');
sc = prctile(abs(x),95); if ~isfinite(sc) || sc<eps, sc = max(abs(x)); end
if ~isfinite(sc) || sc<eps, sc = 1; end
y = x/sc;
end

function lagMs = best_lag_ms(x, y, Fs)
x = normalize_lead(x); y = normalize_lead(y);
maxLag = round(0.2*Fs);
[c,lags] = xcorr(x, y, maxLag, 'coeff');
[~,idx] = max(abs(c));
lagMs = lags(idx)/Fs*1000;
end

function plot_xcorr_overlay(rawA, rawB, iirA, iirB, zeroA, zeroB, Fs)
maxLag = round(0.2*Fs);
[cRaw,lags] = xcorr(normalize_lead(rawA), normalize_lead(rawB), maxLag, 'coeff');
[cIIR,~] = xcorr(normalize_lead(iirA), normalize_lead(iirB), maxLag, 'coeff');
[cZero,~] = xcorr(normalize_lead(zeroA), normalize_lead(zeroB), maxLag, 'coeff');
lagMs = lags/Fs*1000;
plot(lagMs, cRaw, 'DisplayName','Raw'); hold on; grid on;
plot(lagMs, cIIR, 'DisplayName','Causal IIR');
plot(lagMs, cZero, 'DisplayName','Zero-phase');
xlabel('Lag (ms)'); ylabel('Correlation coefficient');
legend('Location','best');
end

function val = extract_header_value(headerText, key)
expr = ['#\s*' regexptranslate('escape', key) ':\s*([^\r\n]+)'];
tok = regexp(headerText, expr, 'tokens', 'once');
if isempty(tok)
    val = 'Not documented';
else
    val = strtrim(tok{1});
end
end

function draw_table_as_text(T, ttl)
axis off;
title(ttl, 'FontWeight','bold', 'Interpreter','none');
rows = format_table_rows(T);
y = 0.90;
for k = 1:numel(rows)
    text(0.02, y, rows{k}, 'Units','normalized', ...
        'FontName','Consolas', 'FontSize', 8.5, ...
        'Interpreter','none', 'VerticalAlignment','top');
    y = y - 0.055;
    if y < 0.05, break; end
end
end

function rows = format_table_rows(T)
names = T.Properties.VariableNames;
C = table2cell(T);
allRows = [names; cellfun(@value_to_text, C, 'UniformOutput', false)];
widths = zeros(1, size(allRows,2));
for c = 1:size(allRows,2)
    widths(c) = min(max(cellfun(@numel, allRows(:,c))), 30);
end
rows = cell(size(allRows,1),1);
for r = 1:size(allRows,1)
    parts = cell(1, size(allRows,2));
    for c = 1:size(allRows,2)
        s = allRows{r,c};
        if numel(s) > widths(c), s = [s(1:max(1,widths(c)-3)) '...']; end
        parts{c} = sprintf(['%-' num2str(widths(c)) 's'], s);
    end
    rows{r} = strjoin(parts, '  ');
end
end

function s = value_to_text(v)
if isnumeric(v)
    if isscalar(v), s = sprintf('%.4g', v); else, s = mat2str(v); end
elseif isstring(v) || ischar(v)
    s = char(v);
elseif iscell(v) && numel(v) == 1
    s = value_to_text(v{1});
else
    s = char(string(v));
end
end
