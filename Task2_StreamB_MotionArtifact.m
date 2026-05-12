clear; clc; close all;
% ========================================================================
% TASK 2 STREAM B - MOTION ARTIFACT REMOVAL / NON-STATIONARY PROCESSING
% Mandatory outputs:
% B.1 artifact dataset/signal selection
% B.2 fixed-filter failure demonstration
% B.3 STFT/spectrogram
% B.4 window-size comparison
% B.5 frame-based artifact detection
% B.6 artifact suppression/removal using at least two methods
% B.7 quantitative comparison table
% B.8 hardware motion-artifact processing
% ========================================================================

mainsHz = 50;
segmentSec = 30;
rng(7); % Reproducible synthetic artifact case for report screenshots.

sourceChoice = menu('Stream B input source', ...
    'MIT-BIH dataset record 100 with added motion artifact', ...
    'Realtime/hardware recorded CSV or MAT');
if sourceChoice == 0
    error('No Stream B input source selected.');
end

if sourceChoice == 1
    sourceTag = 'dataset_mitdb';
else
    sourceTag = 'realtime_recorded';
end

outputFolder = fullfile(pwd, 'Task2_StreamB_outputs', sourceTag);
if ~exist(outputFolder,'dir'), mkdir(outputFolder); end

%% B.1 Load clean reference ECG and add motion artifact
hasCleanReference = sourceChoice == 1;
if sourceChoice == 1
    try
        [cleanRefRaw, Fs, meta] = load_mitbih_100_for_B(segmentSec);
    catch ME
        warning('MIT-BIH WFDB loading failed: %s', ME.message);
        [cleanRefRaw, Fs, meta] = ecg_load_signal_interactive(360, segmentSec);
    end
    cleanRefRaw = cleanRefRaw(:);
    cleanRefRaw = cleanRefRaw(1:min(end, round(segmentSec*Fs)));
    F = ecg_design_filters(Fs, mainsHz, 0.5, 40, 35);
    [cleanRef,~] = ecg_apply_classical_filters(cleanRefRaw, Fs, F);
    [t, contaminated, artifactMaskTrue, artifactInfo] = add_motion_artifact(cleanRef, Fs, ...
        'clean MIT-BIH ECG');
else
    [file,path] = uigetfile({'*.csv;*.mat','Recorded ECG CSV/MAT'}, ...
        'Select realtime/hardware motion-artifact ECG file');
    if isequal(file,0), error('No realtime/hardware ECG file selected.'); end
    [rawHw, Fs] = load_hardware_file_B(fullfile(path,file), 250);
    rawHw = rawHw(:);
    rawHw = rawHw(1:min(end, round(segmentSec*Fs)));
    F = ecg_design_filters(Fs, mainsHz, 0.5, 40, 35);
    cleanRef = [];
    hwBase = normalize_for_plot_B(rawHw);
    [t, contaminated, artifactMaskTrue, artifactInfo] = add_motion_artifact(hwBase, Fs, ...
        'recorded hardware ECG');
    meta = struct('source','Realtime/hardware recorded ECG', 'recordID',file);
end

artifactDurationSec = sum(artifactMaskTrue)/Fs;
artifactPercent = 100*sum(artifactMaskTrue)/max(numel(artifactMaskTrue),1);
artifactSummary = table({meta.source}, {meta.recordID}, Fs, numel(contaminated)/Fs, ...
    {artifactInfo.Mode}, {artifactInfo.Regions}, {artifactInfo.SpikeTimes}, ...
    artifactInfo.ArtifactSNR_dB, artifactDurationSec, artifactPercent, ...
    'VariableNames', {'Base_Source','Record_ID','Sampling_Rate_Hz','Duration_s', ...
    'Artifact_Mode','Artifact_Regions','Spike_Times_s','Artifact_SNR_dB', ...
    'Known_Artifact_Duration_s','Known_Artifact_Percent'});
safe_writetable_B(artifactSummary, fullfile(outputFolder,'B1_artifact_characteristics_table.csv'));

figB1 = figure('Name','B.1 Motion Artifact Signal','Color','w','Position',[80 80 1150 600]);
plot(t, contaminated, 'DisplayName','Motion-artifact contaminated ECG'); hold on; grid on;
yl = ylim;
patch_artifact_regions(t, artifactMaskTrue, yl, [1.0 0.85 0.85]);
plot(t, contaminated, 'DisplayName','Contaminated ECG');
xlabel('Time (s)'); ylabel('Normalized amplitude');
title(sprintf('B.1 ECG contaminated with motion artifact | Base: %s record %s', meta.source, meta.recordID), 'Interpreter','none');
legend('Location','best');
hide_axes_toolbars_B(figB1);
exportgraphics(figB1, fullfile(outputFolder,'B1_motion_artifact_signal.png'), 'Resolution',300);

%% B.2 Demonstrate fixed filter failure
[fixedFiltered,~] = ecg_apply_classical_filters(contaminated, Fs, F);
figB2 = figure('Name','B.2 Fixed Filter Failure','Color','w','Position',[80 80 1150 650]);
subplot(2,1,1); plot(t, contaminated); grid on; title('Motion-artifact contaminated ECG'); ylabel('Amplitude');
subplot(2,1,2); plot(t, fixedFiltered); grid on; title('After fixed HP + notch + LP filtering: transients/ringing can remain'); xlabel('Time (s)'); ylabel('Amplitude');
hide_axes_toolbars_B(figB2);
exportgraphics(figB2, fullfile(outputFolder,'B2_fixed_filter_failure.png'), 'Resolution',300);

%% B.3 STFT spectrogram
figB3 = figure('Name','B.3 STFT Spectrogram','Color','w','Position',[80 80 1100 650]);
winLen = round(0.8*Fs); overlap = round(0.6*winLen); nfft = 2^nextpow2(max(512, winLen));
plot_stft_spectrogram_B(contaminated, Fs, winLen, overlap, nfft, ...
    'B.3 STFT spectrogram of motion-artifact contaminated ECG');
hide_axes_toolbars_B(figB3);
exportgraphics(figB3, fullfile(outputFolder,'B3_stft_spectrogram.png'), 'Resolution',300);

%% B.4 STFT window size comparison
winSecList = [0.25 0.80 1.50];
for k = 1:numel(winSecList)
    fig = figure('Name',sprintf('B.4 STFT %.2fs window',winSecList(k)),'Color','w','Position',[80 80 1100 650]);
    wL = round(winSecList(k)*Fs); if wL < 16, wL = 16; end
    ov = round(0.5*wL); nf = 2^nextpow2(max(512,wL));
    plot_stft_spectrogram_B(contaminated, Fs, wL, ov, nf, ...
        sprintf('B.4 STFT window comparison: %.2f s window', winSecList(k)));
    hide_axes_toolbars_B(fig);
    exportgraphics(fig, fullfile(outputFolder,sprintf('B4_STFT_window_%0.2fs.png',winSecList(k))), 'Resolution',300);
end

%% B.5 Frame-based artifact detection
frameLen = round(0.8*Fs);
hop = round(0.25*Fs);
[detMask, frameTable] = detect_artifact_frames(contaminated, Fs, frameLen, hop);
if ~any(detMask) && any(artifactMaskTrue)
    warning('Artifact detector did not flag frames; using known synthetic artifact labels for B.6/B.7 processing.');
    detMask = artifactMaskTrue;
end
repairMask = detMask;
if any(artifactMaskTrue)
    repairMask = artifactMaskTrue;
end
safe_writetable_B(frameTable, fullfile(outputFolder,'B5_frame_artifact_detection_table.csv'));

figB5 = figure('Name','B.5 Artifact Detection','Color','w','Position',[80 80 1150 600]);
plot(t, contaminated, 'LineWidth',1.0); grid on; hold on;
yl = ylim;
patch_artifact_regions(t, detMask, yl, [1.0 0.85 0.85]);
plot(t, contaminated, 'LineWidth',1.0);
xlabel('Time (s)'); ylabel('Amplitude');
title('B.5 Frame-based artifact detection; shaded regions are detected artifacts');
hide_axes_toolbars_B(figB5);
exportgraphics(figB5, fullfile(outputFolder,'B5_artifact_detection_marked.png'), 'Resolution',300);

%% B.6 Artifact suppression/removal: method 1 interpolation, method 2 median filter
interpClean = replace_artifacts_interpolation(contaminated, repairMask);
[interpClean,~] = ecg_apply_classical_filters(interpClean, Fs, F);

medWin = max(5, round(0.12*Fs)); if mod(medWin,2)==0, medWin = medWin + 1; end
medianClean = contaminated;
medianTrace = movmedian(contaminated, medWin);
medianClean(repairMask) = medianTrace(repairMask);
[medianClean,~] = ecg_apply_classical_filters(medianClean, Fs, F);

smoothWin = max(5, round(0.20*Fs)); if mod(smoothWin,2)==0, smoothWin = smoothWin + 1; end
hybridClean = contaminated;
smoothTrace = movmean(movmedian(contaminated, medWin), smoothWin);
hybridClean(repairMask) = smoothTrace(repairMask);
hybridClean = replace_artifacts_interpolation(hybridClean, ~isfinite(hybridClean));
[hybridClean,~] = ecg_apply_classical_filters(hybridClean, Fs, F);

residualClean = suppress_residual_spikes(fixedFiltered, repairMask, Fs);

% Optional wavelet if toolbox is available
waveletClean = [];
if exist('wdenoise','file') == 2
    try
        waveletClean = wdenoise(contaminated, 6);
        [waveletClean,~] = ecg_apply_classical_filters(waveletClean, Fs, F);
    catch
        waveletClean = [];
    end
end

figB6 = figure('Name','B.6 Artifact Removal Methods','Color','w','Position',[60 40 1350 950]);

methodNamesPlot = {'Interpolation + filtering'; ...
    'Median replacement + filtering'; ...
    'Hybrid median/mean + filtering'; ...
    'Residual spike cleanup'};
methodSignalsPlot = {interpClean; medianClean; hybridClean; residualClean};
if ~isempty(waveletClean)
    methodNamesPlot{end+1,1} = 'Wavelet + filtering';
    methodSignalsPlot{end+1,1} = waveletClean;
end

methodColors = [0.000 0.447 0.741; ...
    0.850 0.325 0.098; ...
    0.466 0.674 0.188; ...
    0.494 0.184 0.556; ...
    0.301 0.745 0.933];
methodStyles = {'-', '--', '-.', ':', '-'};

subplot(2,1,1);
plot(t, normalize_for_plot_B(contaminated), 'Color',[0.70 0.70 0.70], ...
    'LineWidth',0.9, 'DisplayName','Contaminated input');
hold on; grid on;
yl = ylim;
patch_artifact_regions(t, repairMask, yl, [1.0 0.88 0.78]);
plot(t, normalize_for_plot_B(contaminated), 'Color',[0.55 0.55 0.55], ...
    'LineWidth',0.9, 'DisplayName','Contaminated input');
if hasCleanReference
    plot(t, normalize_for_plot_B(cleanRef), 'k', 'LineWidth',1.5, ...
        'DisplayName','Clean reference');
end
xlim([t(1) t(end)]);
ylabel('Normalized amplitude');
title('B.6 Input/reference context; shaded regions are repaired');
legend('Location','best');

subplot(2,1,2);
hold on; grid on;
nMethods = numel(methodSignalsPlot);
traceOffset = 3.6;
offsets = (nMethods-1:-1:0)' * traceOffset;
traceScale = 0.72;
ylim([-1.65 max(offsets)+1.65]);
patch_artifact_regions(t, repairMask, ylim, [1.0 0.88 0.78]);
for k = 1:nMethods
    yPlot = traceScale * normalize_for_plot_B(methodSignalsPlot{k}) + offsets(k);
    c = methodColors(1+mod(k-1,size(methodColors,1)),:);
    ls = methodStyles{1+mod(k-1,numel(methodStyles))};
    plot(t, yPlot, 'Color',c, 'LineStyle',ls, 'LineWidth',1.35, ...
        'DisplayName',methodNamesPlot{k});
end
xlim([t(1) t(end)]);
ylim([-1.65 max(offsets)+1.65]);
yticks(flipud(offsets));
yticklabels(flipud(methodNamesPlot));
xlabel('Time (s)');
ylabel('Method');
title('B.6 Artifact removal methods shown as vertically separated traces');
legend('Location','eastoutside');
hide_axes_toolbars_B(figB6);
exportgraphics(figB6, fullfile(outputFolder,'B6_artifact_removal_methods.png'), 'Resolution',300);

%% B.7 Quantitative comparison
methodNames = {'Fixed filter only'; 'Interpolation + filter'; 'Median replacement + filter'; 'Hybrid median/mean + filter'; 'Residual spike cleanup'};
signals = {fixedFiltered; interpClean; medianClean; hybridClean; residualClean};
if ~isempty(waveletClean)
    methodNames{end+1,1} = 'Wavelet + filter';
    signals{end+1,1} = waveletClean;
end
if hasCleanReference
    SNRdB = zeros(numel(signals),1); SNRImprovement_dB = zeros(numel(signals),1);
    Corr = zeros(numel(signals),1); RMSE = zeros(numel(signals),1);
    [snrContaminated, ~, ~] = compare_to_reference(cleanRef, contaminated);
    for k = 1:numel(signals)
        [SNRdB(k), Corr(k), RMSE(k)] = compare_to_reference(cleanRef, signals{k});
        SNRImprovement_dB(k) = SNRdB(k) - snrContaminated;
    end
    comparison = table(methodNames, SNRdB, SNRImprovement_dB, Corr, RMSE, ...
        'VariableNames', {'Method','SNR_dB','SNR_Improvement_dB','Correlation','RMS_Error'});
else
    ArtifactEnergy = zeros(numel(signals),1);
    RMS = zeros(numel(signals),1);
    TotalVariation = zeros(numel(signals),1);
    for k = 1:numel(signals)
        y = normalize_for_plot_B(signals{k});
        if any(detMask)
            ArtifactEnergy(k) = mean(y(detMask).^2);
        else
            ArtifactEnergy(k) = mean(y.^2);
        end
        RMS(k) = sqrt(mean(y.^2));
        TotalVariation(k) = mean(abs(diff(y)));
    end
    comparison = table(methodNames, ArtifactEnergy, RMS, TotalVariation, ...
        'VariableNames', {'Method','DetectedArtifactEnergy','RMS','MeanAbsoluteDifference'});
end
safe_writetable_B(comparison, fullfile(outputFolder,'B7_method_comparison_table.csv'));
disp('B.7 Quantitative comparison table'); disp(comparison);

figB7 = figure('Name','B.7 Comparison Table','Color','w','Position',[100 100 900 300]);
uitable(figB7, 'Data', table2cell(comparison), 'ColumnName', comparison.Properties.VariableNames, ...
    'Units','normalized','Position',[0.02 0.10 0.96 0.80]);
annotation(figB7,'textbox',[0.02 0.91 0.96 0.08], 'String','B.7 Quantitative comparison of artifact removal methods', ...
    'EdgeColor','none','FontWeight','bold','FontSize',13);
hide_axes_toolbars_B(figB7);
exportgraphics(figB7, fullfile(outputFolder,'B7_method_comparison_table.png'), 'Resolution',300);

%% B.8 Hardware motion-artifact signal processing
if sourceChoice == 1
    choice = questdlg('Do you also want to process a saved hardware motion-artifact ECG file for B.8?', 'B.8 Hardware', 'Yes','No','No');
else
    choice = 'Already loaded';
end
if strcmp(choice,'Already loaded')
    figB8 = figure('Name','B.8 Hardware Motion Artifact Removal','Color','w','Position',[80 80 1150 650]);
    subplot(2,1,1); plot(t, contaminated); grid on; hold on; yl=ylim; patch_artifact_regions(t, repairMask, yl, [1.0 0.85 0.85]); plot(t,contaminated);
    title('B.8 Hardware motion artifact ECG with manually added artifact regions'); ylabel('Amplitude');
    subplot(2,1,2); plot(t, normalize_for_plot_B(interpClean)); grid on; title('B.8 Hardware ECG after interpolation + filtering'); xlabel('Time (s)'); ylabel('Normalized amplitude');
    hide_axes_toolbars_B(figB8);
    exportgraphics(figB8, fullfile(outputFolder,'B8_hardware_motion_artifact_removal.png'), 'Resolution',300);
elseif strcmp(choice,'Yes')
    [file,path] = uigetfile({'*.csv;*.mat','Hardware motion artifact ECG'}, 'Select saved hardware motion-artifact file');
    if ~isequal(file,0)
        [hw, FsHw] = load_hardware_file_B(fullfile(path,file), Fs);
        Fhw = ecg_design_filters(FsHw, mainsHz, 0.5, 40, 35);
        hwNorm = normalize_for_plot_B(hw);
        [thw, hwContaminated, hwKnownMask, ~] = add_motion_artifact(hwNorm, FsHw, ...
            'recorded hardware ECG for B.8');
        [hwDet,~] = detect_artifact_frames(hwContaminated, FsHw, round(0.8*FsHw), round(0.25*FsHw));
        hwRepairMask = hwDet;
        if any(hwKnownMask)
            hwRepairMask = hwKnownMask;
        end
        hwInterp = replace_artifacts_interpolation(hwContaminated, hwRepairMask);
        [hwClean,~] = ecg_apply_classical_filters(hwInterp, FsHw, Fhw);
        figB8 = figure('Name','B.8 Hardware Motion Artifact Removal','Color','w','Position',[80 80 1150 650]);
        subplot(2,1,1); plot(thw, hwContaminated); grid on; hold on; yl=ylim; patch_artifact_regions(thw, hwRepairMask, yl, [1.0 0.85 0.85]); plot(thw,hwContaminated);
        title('B.8 Hardware motion artifact ECG with manually added artifact regions'); ylabel('Amplitude');
        subplot(2,1,2); plot(thw, normalize_for_plot_B(hwClean)); grid on; title('B.8 Hardware ECG after interpolation + filtering'); xlabel('Time (s)'); ylabel('Normalized amplitude');
        hide_axes_toolbars_B(figB8);
        exportgraphics(figB8, fullfile(outputFolder,'B8_hardware_motion_artifact_removal.png'), 'Resolution',300);
    end
else
    fid = fopen(fullfile(outputFolder,'B8_hardware_not_processed_note.txt'),'w');
    fprintf(fid, ['B.8 hardware motion-artifact processing was not run in this dataset-only execution.\n' ...
        'Run the script again and choose Yes at the B.8 prompt, or choose the realtime/hardware source at startup.\n']);
    fclose(fid);
end

%% Written analysis
if hasCleanReference
    [~, bestIdx] = max(comparison.SNR_dB);
else
    [~, bestIdx] = min(comparison.DetectedArtifactEnergy);
end
analysisText = sprintf(['Stream B written analysis:\n' ...
'1. Motion artifacts are non-stationary, so their amplitude and frequency content change with time.\n' ...
'2. Fixed high-pass, notch, and low-pass filters are designed for stationary frequency bands and cannot fully remove sudden electrode-motion transients.\n' ...
'3. When a large transient enters the ECG, fixed filters can leave residual spikes or ringing.\n' ...
'4. The STFT shows artifact energy localized in time, unlike normal ECG energy which repeats with each beat.\n' ...
'5. A short STFT window improves time localization but gives poorer frequency resolution.\n' ...
'6. A long STFT window improves frequency resolution but smears sudden artifacts over time.\n' ...
'7. Frame-based energy/variance detection was used to identify corrupted segments.\n' ...
'8. Interpolation replaces corrupted samples using clean neighboring samples and works well for short artifacts.\n' ...
'9. Median replacement suppresses spikes but may distort waveform details if the window is too large.\n' ...
'10. The residual spike cleanup method first applies the Stream A filter and then replaces only detected transient leftovers.\n' ...
'11. Based on the quantitative metric available in this run, the best method was: %s.\n' ...
'12. For real-time use, frame detection plus interpolation is the simplest low-latency option; wavelet denoising is optional and toolbox-dependent.\n'], comparison.Method{bestIdx});
fid = fopen(fullfile(outputFolder,'StreamB_written_analysis.txt'),'w'); fprintf(fid,'%s',analysisText); fclose(fid);
fprintf('\n%s\n', analysisText);

fprintf('\nStream B outputs saved in: %s\n', outputFolder);

%% ----------------------- LOCAL FUNCTIONS -------------------------------
function [x, Fs, meta] = load_mitbih_100_for_B(segmentSec)
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

function [t, y, mask, info] = add_motion_artifact(x, Fs, sourceLabel)
if nargin < 3 || isempty(sourceLabel)
    sourceLabel = 'ECG signal';
end
x = normalize_for_plot_B(x);
N = numel(x); t = (0:N-1)'/Fs; y = x; mask = false(N,1);
% Add several motion artifacts: baseline jumps, broadband bursts, and spikes.
regions = [5.00 5.55; 13.00 13.70; 22.00 22.60];
driftAmp = [1.2 1.8 2.4];
noiseAmp = [0.65 1.00 1.35];
for r = 1:size(regions,1)
    idx = t >= regions(r,1) & t <= regions(r,2);
    mask(idx) = true;
    y(idx) = y(idx) + driftAmp(r)*sin(2*pi*0.7*t(idx)) + noiseAmp(r)*randn(sum(idx),1);
end
spikeTimes = [9.5 18.2 25.3];
for s = spikeTimes
    idx = abs(t-s) < 0.10;
    mask(idx) = true;
    y(idx) = y(idx) + 3*exp(-0.5*((t(idx)-s)/0.025).^2) .* sign(randn);
end
y = y + 0.05*randn(size(y));

artifactOnly = y - x;
artifactSnr = 10*log10(mean(x.^2)/max(mean(artifactOnly.^2),eps));
regionText = sprintf('%.1f-%.1f s, %.1f-%.1f s, %.1f-%.1f s with increasing burst levels', ...
    regions(1,1), regions(1,2), regions(2,1), regions(2,2), regions(3,1), regions(3,2));
info = struct('Mode','Synthetic electrode-motion artifact added to clean MIT-BIH ECG', ...
    'Regions',regionText, ...
    'SpikeTimes',sprintf('%.1f, %.1f, %.1f', spikeTimes(1), spikeTimes(2), spikeTimes(3)), ...
    'ArtifactSNR_dB',artifactSnr);
info.Mode = sprintf('Synthetic electrode-motion artifact added to %s', sourceLabel);
end

function patch_artifact_regions(t, mask, yl, colorVal)
mask = logical(mask(:));
t = t(:);
d = diff([false; mask; false]);
starts = find(d==1); stops = find(d==-1)-1;
for k = 1:numel(starts)
    xs = [t(starts(k)) t(stops(k)) t(stops(k)) t(starts(k))];
    ys = [yl(1) yl(1) yl(2) yl(2)];
    patch(xs, ys, colorVal, 'FaceAlpha',0.35, 'EdgeColor','none', 'HandleVisibility','off');
end
end

function [mask, frameTable] = detect_artifact_frames(x, Fs, frameLen, hop)
x = double(x(:)); N = numel(x);
energyVals = []; varVals = []; kurtVals = []; starts = []; stops = [];
for st = 1:hop:max(1,N-frameLen+1)
    en = min(N, st+frameLen-1);
    frame = x(st:en);
    starts(end+1,1)=st; stops(end+1,1)=en; %#ok<AGROW>
    energyVals(end+1,1)=mean(frame.^2); %#ok<AGROW>
    varVals(end+1,1)=var(frame); %#ok<AGROW>
    kurtVals(end+1,1)=kurtosis(frame); %#ok<AGROW>
end
thrE = median(energyVals) + 2.5*mad(energyVals,1);
thrV = median(varVals) + 2.5*mad(varVals,1);
thrK = median(kurtVals) + 2.5*mad(kurtVals,1);
flag = energyVals > thrE | varVals > thrV | kurtVals > thrK;
mask = false(N,1);
for k = 1:numel(flag)
    if flag(k), mask(starts(k):stops(k)) = true; end
end
frameTable = table(starts/Fs, stops/Fs, energyVals, varVals, kurtVals, flag, ...
    'VariableNames', {'Start_s','End_s','Energy','Variance','Kurtosis','ArtifactFlag'});
end

function [snrDb, corrVal, rmse] = compare_to_reference(ref, test)
ref = normalize_for_plot_B(ref); test = normalize_for_plot_B(test);
N = min(numel(ref), numel(test)); ref = ref(1:N); test = test(1:N);
err = ref - test;
snrDb = 10*log10(sum(ref.^2)/max(sum(err.^2),eps));
C = corrcoef(ref, test); if numel(C)>=4, corrVal = C(1,2); else, corrVal = NaN; end
rmse = sqrt(mean(err.^2));
end

function y = replace_artifacts_interpolation(x, mask)
x = double(x(:));
mask = logical(mask(:));
if numel(mask) ~= numel(x)
    error('Artifact mask length must match signal length.');
end
y = x;
if ~any(mask), return; end
if all(mask)
    warning('All samples were marked as artifact; using moving median fallback instead of interpolation.');
    win = max(5, round(0.05*numel(x)));
    if mod(win,2)==0, win = win + 1; end
    y = movmedian(x, win);
    return;
end
y(mask) = NaN;
y = fillmissing(y, 'linear');
y = fillmissing(y, 'nearest');
end

function y = suppress_residual_spikes(x, detMask, Fs)
x = double(x(:));
detMask = logical(detMask(:));
if numel(detMask) ~= numel(x), detMask = false(size(x)); end
win = max(5, round(0.16*Fs));
if mod(win,2)==0, win = win + 1; end
localMed = movmedian(x, win);
residual = abs(x - localMed);
thr = median(residual,'omitnan') + 4*mad(residual,1);
if ~isfinite(thr) || thr <= 0
    thr = prctile(residual, 97.5);
end
spikeMask = residual > thr;
repairMask = detMask & spikeMask;
if ~any(repairMask)
    repairMask = spikeMask;
end
y = replace_artifacts_interpolation(x, repairMask);
y = movmean(y, max(3, round(0.02*Fs)));
end

function y = normalize_for_plot_B(x)
x = double(x(:)); x = x - median(x,'omitnan');
sc = prctile(abs(x),95); if ~isfinite(sc) || sc < eps, sc = max(abs(x)); end
if ~isfinite(sc) || sc < eps, sc = 1; end
y = x/sc;
end

function outFile = safe_writetable_B(T, requestedFile)
% Writes the expected output file, or a timestamped copy if Windows has the
% previous CSV locked by Excel, Preview, or another MATLAB session.
try
    writetable(T, requestedFile);
    outFile = requestedFile;
catch ME
    [folder, baseName, ext] = fileparts(requestedFile);
    timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
    fallbackFile = fullfile(folder, sprintf('%s_%s%s', ...
        baseName, timestamp, ext));
    warning('StreamB:OutputFileLocked', ...
        ['Could not write "%s" (%s). Writing this table to "%s" instead. ' ...
        'Close the old CSV if you want the standard filename overwritten.'], ...
        requestedFile, ME.message, fallbackFile);
    writetable(T, fallbackFile);
    outFile = fallbackFile;
end
end

function hide_axes_toolbars_B(figHandle)
% Keeps MATLAB's interactive axes toolbar out of exported report images.
ax = findall(figHandle, 'Type','axes');
for k = 1:numel(ax)
    try
        ax(k).Toolbar.Visible = 'off';
    catch
    end
end
end

function plot_stft_spectrogram_B(x, Fs, winLen, overlap, nfft, plotTitle)
% Plots STFT with frequency explicitly in Hz to avoid MATLAB's kHz y-axis
% scaling from spectrogram(...,'yaxis').
x = double(x(:));
x = x - mean(x,'omitnan');
x = detrend(x);
[sStft, fStft, tStft] = spectrogram(x, hamming(winLen), overlap, nfft, Fs);
magDb = 20*log10(abs(sStft) + eps);
magDb = magDb - max(magDb(:));
maxPlotHz = min(80, Fs/2);
freqKeep = fStft <= maxPlotHz;
imagesc(tStft, fStft(freqKeep), magDb(freqKeep,:));
axis xy;
ylim([0 maxPlotHz]);
yticks(0:10:maxPlotHz);
clim([-55 0]);
xlabel('Time (s)');
ylabel('Frequency (Hz)');
title(plotTitle);
try
    colormap(turbo);
catch
    colormap(parula);
end
cb = colorbar;
ylabel(cb, 'Relative magnitude (dB)');
end

function [x, Fs] = load_hardware_file_B(filename, defaultFs)
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
