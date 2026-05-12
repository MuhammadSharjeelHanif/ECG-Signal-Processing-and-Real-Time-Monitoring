clear; clc; close all;
% ========================================================================
% TASK 2 STREAM A - DENOISING / CLASSICAL FILTERING
% Mandatory outputs:
% A.1 raw time-domain plot
% A.2 raw FFT spectrum with noise peaks
% A.3 SNR before filtering
% A.4 HP filter response and phase
% A.5 notch response
% A.6 LP filter response
% A.7 combined before/after time and frequency + SNR after
% A.8 group delay analysis
% A.9 hardware ECG before/after filtering
% ========================================================================

mainsHz = 50;
segmentSec = 30;

sourceChoice = menu('Stream A input source', ...
    'MIT-BIH dataset record 100', ...
    'Realtime/hardware recorded CSV or MAT');
if sourceChoice == 0
    error('No Stream A input source selected.');
end

if sourceChoice == 1
    sourceTag = 'dataset_mitdb';
else
    sourceTag = 'realtime_recorded';
end

outputFolder = fullfile(pwd, 'Task2_StreamA_outputs', sourceTag);
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

%% A.1 Load ECG and plot raw signal
if sourceChoice == 1
    try
        [raw, Fs, meta] = load_mitbih_100_for_A(segmentSec);
    catch ME
        warning('MIT-BIH WFDB loading failed: %s', ME.message);
        [raw, Fs, meta] = ecg_load_signal_interactive(360, segmentSec);
    end
else
    [file,path] = uigetfile({'*.csv;*.mat','Recorded ECG CSV/MAT'}, ...
        'Select realtime/hardware recorded ECG file');
    if isequal(file,0), error('No realtime/hardware ECG file selected.'); end
    [raw, Fs] = load_hardware_file(fullfile(path,file), 250);
    meta = struct('source','Realtime/hardware recorded ECG', ...
        'recordID',file, ...
        'durationSec',numel(raw)/Fs);
end
raw = raw(:); raw = raw(1:min(end, round(segmentSec*Fs)));
t = (0:numel(raw)-1)'/Fs;

figA1 = figure('Name','A.1 Raw ECG Time Domain','Color','w','Position',[80 80 1150 550]);
plot(t, raw, 'LineWidth',1.1); grid on;
xlabel('Time (s)'); ylabel('Amplitude');
title(sprintf('A.1 Raw ECG signal: %s record %s', meta.source, meta.recordID), 'Interpreter','none');
annotation('textbox',[0.14 0.78 0.75 0.1], 'String', 'Inspect for baseline drift, 50 Hz interference, and high-frequency muscle/measurement noise.', ...
    'EdgeColor','none', 'FontWeight','bold');
exportgraphics(figA1, fullfile(outputFolder,'A1_raw_time_domain.png'), 'Resolution',300);

%% A.2 Raw FFT spectrum
featRaw = ecg_fft_features(raw, Fs, mainsHz);
figA2 = figure('Name','A.2 Raw FFT Spectrum','Color','w','Position',[80 80 1150 600]);
keep = featRaw.f <= min(120, Fs/2);
plot(featRaw.f(keep), featRaw.mag(keep), 'LineWidth',1.3); grid on; hold on;
xlabel('Frequency (Hz)'); ylabel('|X(f)| magnitude');
title('A.2 Raw ECG FFT spectrum with identified bands');
xline(0.5,'--','Baseline <0.5 Hz','LabelVerticalAlignment','bottom');
xline(40,'--','ECG signal band 0.5-40 Hz','LabelVerticalAlignment','bottom');
xline(mainsHz,':',sprintf('%d Hz mains',mainsHz),'LabelVerticalAlignment','bottom');
xline(100,'--','EMG/noise >100 Hz','LabelVerticalAlignment','bottom');
exportgraphics(figA2, fullfile(outputFolder,'A2_raw_fft_noise_bands.png'), 'Resolution',300);

%% A.3 Noise power and SNR before filtering
snrBefore = featRaw.snrDb;

%% A.4/A.5/A.6 Filter design and response
F = ecg_design_filters(Fs, mainsHz, 0.5, 40, 35);
filterList = {
    'High-pass IIR, 0.5 Hz', F.bHP, F.aHP;
    sprintf('Notch IIR, %d Hz', mainsHz), F.bNotch, F.aNotch;
    'Low-pass IIR, 40 Hz', F.bLP, F.aLP;
    'High-pass FIR comparison, 0.5 Hz', F.bFIR_HP, F.aFIR_HP;
    'Low-pass FIR comparison, 40 Hz', F.bFIR_LP, F.aFIR_LP
    };

for k = 1:size(filterList,1)
    name = filterList{k,1}; b = filterList{k,2}; a = filterList{k,3};
    [H,w] = freqz(b,a,4096,Fs);
    fig = figure('Name',['Response ' name],'Color','w','Position',[80 80 1150 650]);
    subplot(2,1,1); plot(w, 20*log10(abs(H)+eps), 'LineWidth',1.3); grid on;
    xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)'); title(['Magnitude response: ' name], 'Interpreter','none'); xlim([0 min(120,Fs/2)]);
    subplot(2,1,2); plot(w, unwrap(angle(H)), 'LineWidth',1.3); grid on;
    xlabel('Frequency (Hz)'); ylabel('Phase (rad)'); title(['Phase response: ' name], 'Interpreter','none'); xlim([0 min(120,Fs/2)]);
    safeName = regexprep(name,'[^a-zA-Z0-9]','_');
    exportgraphics(fig, fullfile(outputFolder,['A4_A6_filter_response_' safeName '.png']), 'Resolution',300);
end

%% A.7 Combined filtering pipeline
[clean, stages] = ecg_apply_classical_filters(raw, Fs, F);
featClean = ecg_fft_features(clean, Fs, mainsHz);
snrAfter = featClean.snrDb;
snrImprovement = snrAfter - snrBefore;

figA7a = figure('Name','A.7 Before After Time Domain','Color','w','Position',[80 80 1150 600]);
plot(t, normalize_for_plot(raw), 'DisplayName','Raw ECG'); hold on; grid on;
plot(t, clean, 'LineWidth',1.2, 'DisplayName','Cleaned ECG');
xlabel('Time (s)'); ylabel('Normalized amplitude');
title('A.7 Raw vs cleaned ECG in time domain'); legend('Location','best');
exportgraphics(figA7a, fullfile(outputFolder,'A7_raw_vs_clean_time.png'), 'Resolution',300);
if sourceChoice == 2
    exportgraphics(figA7a, fullfile(outputFolder,'A9_hardware_before_after_filtering.png'), 'Resolution',300);
end

figA7b = figure('Name','A.7 Before After Frequency Domain','Color','w','Position',[80 80 1150 600]);
keep = featRaw.f <= min(120, Fs/2);
plot(featRaw.f(keep), featRaw.mag(keep), 'DisplayName','Raw spectrum'); hold on; grid on;
plot(featClean.f(keep), featClean.mag(keep), 'LineWidth',1.2, 'DisplayName','Cleaned spectrum');
xlabel('Frequency (Hz)'); ylabel('|X(f)| magnitude');
title('A.7 Raw vs cleaned ECG spectrum'); legend('Location','best');
xline(0.5,'--','0.5 Hz'); xline(mainsHz,':','mains'); xline(40,'--','40 Hz');
exportgraphics(figA7b, fullfile(outputFolder,'A7_raw_vs_clean_frequency.png'), 'Resolution',300);

snrTable = table(snrBefore, snrAfter, snrImprovement, featRaw.baselinePower, featClean.baselinePower, ...
    featRaw.noisePower, featClean.noisePower, 'VariableNames', ...
    {'SNR_before_dB','SNR_after_dB','SNR_improvement_dB','BaselinePower_before','BaselinePower_after','NoisePower_before','NoisePower_after'});
writetable(snrTable, fullfile(outputFolder,'A7_SNR_table.csv'));
disp('A.7 SNR table'); disp(snrTable);

figA7c = figure('Name','A.7 SNR Table','Color','w','Position',[100 100 1050 260]);
uitable(figA7c, 'Data', table2cell(snrTable), 'ColumnName', snrTable.Properties.VariableNames, ...
    'Units','normalized','Position',[0.02 0.10 0.96 0.80]);
annotation(figA7c,'textbox',[0.02 0.91 0.96 0.08], 'String','A.7 SNR computation table before and after filtering', ...
    'EdgeColor','none','FontWeight','bold','FontSize',13);
exportgraphics(figA7c, fullfile(outputFolder,'A7_SNR_table.png'), 'Resolution',300);

%% A.8 Group delay analysis
for k = 1:size(filterList,1)
    name = filterList{k,1}; b = filterList{k,2}; a = filterList{k,3};
    [gd,wgd] = grpdelay(b,a,4096,Fs);
    fig = figure('Name',['Group delay ' name],'Color','w','Position',[80 80 1100 550]);
    plot(wgd, gd/Fs*1000, 'LineWidth',1.3); grid on;
    xlabel('Frequency (Hz)'); ylabel('Group delay (ms)');
    title(['A.8 Group delay: ' name], 'Interpreter','none'); xlim([0 min(120,Fs/2)]);
    safeName = regexprep(name,'[^a-zA-Z0-9]','_');
    exportgraphics(fig, fullfile(outputFolder,['A8_group_delay_' safeName '.png']), 'Resolution',300);
end

%% A.9 Hardware implementation: apply pipeline to saved hardware window
if sourceChoice == 1
    choice = questdlg('Do you also want to process a saved hardware ECG window for A.9?', 'A.9 Hardware', 'Yes','No','No');
else
    choice = 'No';
end
if strcmp(choice,'Yes')
    [file,path] = uigetfile({'*.csv;*.mat','Hardware ECG window'}, 'Select saved ECG hardware file');
    if ~isequal(file,0)
        [hw, FsHw] = load_hardware_file(fullfile(path,file), Fs);
        Fhw = ecg_design_filters(FsHw, mainsHz, 0.5, 40, 35);
        [hwClean,~] = ecg_apply_classical_filters(hw, FsHw, Fhw);
        thw = (0:numel(hw)-1)'/FsHw;
        figA9 = figure('Name','A.9 Hardware before after filtering','Color','w','Position',[80 80 1150 600]);
        plot(thw, normalize_for_plot(hw), 'DisplayName','Raw hardware ECG'); hold on; grid on;
        plot(thw, hwClean, 'LineWidth',1.2, 'DisplayName','Filtered hardware ECG');
        xlabel('Time (s)'); ylabel('Normalized amplitude'); title('A.9 Hardware-acquired ECG before/after filtering'); legend;
        exportgraphics(figA9, fullfile(outputFolder,'A9_hardware_before_after_filtering.png'), 'Resolution',300);
    end
end

%% Written justification
justification = sprintf(['Stream A justification:\n' ...
'1. A high-pass cutoff of 0.5 Hz was selected because baseline wander from breathing and electrode drift is mainly below 0.5 Hz.\n' ...
'2. A 50 Hz notch filter was selected because local mains interference appears around 50 Hz.\n' ...
'3. A 40 Hz low-pass cutoff was selected because most diagnostic QRS energy is inside the 1-40 Hz ECG band for this project.\n' ...
'4. IIR Butterworth filters were used in the live dashboard because they need low order and are computationally light.\n' ...
'5. Zero-phase filtfilt processing was used offline/near-real-time to reduce phase distortion.\n' ...
'6. FIR filters were also plotted for comparison because FIR filters can provide nearly linear phase.\n' ...
'7. The FIR filters need a much higher order than IIR filters for the same transition sharpness.\n' ...
'8. Group delay plots show whether the filter delay is constant or frequency-dependent.\n' ...
'9. Frequency-dependent delay can distort ECG morphology such as QRS width and ST-segment timing.\n' ...
'10. The combined pipeline improved estimated SNR from %.2f dB to %.2f dB, an improvement of %.2f dB.\n'], ...
 snrBefore, snrAfter, snrImprovement);
fid = fopen(fullfile(outputFolder,'StreamA_written_justification.txt'),'w'); fprintf(fid,'%s',justification); fclose(fid);
fprintf('\n%s\n', justification);

fprintf('\nStream A outputs saved in: %s\n', outputFolder);

%% ----------------------- LOCAL FUNCTIONS -------------------------------
function [x, Fs, meta] = load_mitbih_100_for_A(segmentSec)
if exist('rdsamp','file') ~= 2, error('rdsamp not found.'); end
recordName = 'mitdb/100';
try
    [sig, Fs, ~] = rdsamp(recordName, [], round(segmentSec*360), 1);
catch
    [sig, Fs, ~] = rdsamp(recordName);
    sig = sig(1:min(end, round(segmentSec*Fs)), :);
end
x = sig(:,1);
meta = struct('source','MIT-BIH Arrhythmia Database','recordID','100');
end

function y = normalize_for_plot(x)
x = double(x(:)); x = x - median(x,'omitnan');
sc = prctile(abs(x),95); if ~isfinite(sc) || sc < eps, sc = max(abs(x)); end
if ~isfinite(sc) || sc < eps, sc = 1; end
y = x/sc;
end

function [x, Fs] = load_hardware_file(filename, defaultFs)
if endsWith(lower(filename),'.mat')
    S = load(filename);
    if isfield(S,'fftSegment'), x = S.fftSegment(:); else
        names = fieldnames(S); x = [];
        for k = 1:numel(names)
            v = S.(names{k}); if isnumeric(v) && isvector(v), x = v(:); break; end
        end
    end
    if isfield(S,'Fs'), Fs = S.Fs; else, Fs = defaultFs; end
else
    M = readmatrix(filename);
    if size(M,2)>=2
        t = M(:,1); x = M(:,2); dt = median(diff(t),'omitnan');
        if isfinite(dt) && dt>0, Fs = 1/dt; else, Fs = defaultFs; end
    else
        x = M(:,1); Fs = defaultFs;
    end
end
x = double(x(:)); x = x(isfinite(x));
end
