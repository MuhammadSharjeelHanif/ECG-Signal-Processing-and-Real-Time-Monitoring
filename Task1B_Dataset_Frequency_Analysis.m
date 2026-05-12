clear; clc; close all;

% ========================================================================
% TASK 1B - DATASET ECG FREQUENCY DOMAIN ANALYSIS
%
% Required outputs:
% Output 4  : magnitude spectrum FFT
% Output 5  : zoomed spectrum 0-50 Hz
% Output 6  : annotated spectrum with P/T, QRS, noise bands
% Output 7  : comparison table, RR BPM vs frequency-domain BPM
% Output 8  : written commentary
% Output 9  : dataset information table
%
% Replace your old Task1B_Dataset_Frequency_Analysis.m with this file.
% ========================================================================

%% ----------------------- SETTINGS --------------------------------------
outputFolder = fullfile(pwd, 'Task1B_outputs');
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

mainsHz    = 50;      % Pakistan mains frequency
segmentSec = 30;      % ECG duration used for analysis

fprintf('\n============================================================\n');
fprintf('TASK 1B - DATASET ECG FREQUENCY DOMAIN ANALYSIS\n');
fprintf('============================================================\n');

%% ----------------------- LOAD DATASET ECG ------------------------------
% First tries MIT-BIH record 100 using WFDB Toolbox.
% If WFDB/rdsamp is not available, it asks you to select CSV/MAT manually.

try
    [ecgRaw, Fs, meta] = load_mitbih_100(segmentSec);
    fprintf('Loaded MIT-BIH record 100 successfully.\n');
catch ME
    warning('MIT-BIH WFDB loading failed: %s', ME.message);
    fprintf('\nWFDB rdsamp() was not found or record could not be loaded.\n');
    fprintf('You can now select a CSV or MAT ECG file manually.\n');
    [ecgRaw, Fs, meta] = ecg_load_signal_interactive(360, segmentSec);
end

ecgRaw = double(ecgRaw(:));
N = min(numel(ecgRaw), round(segmentSec * Fs));
ecgRaw = ecgRaw(1:N);
time = (0:N-1)' / Fs;
meta.durationSec = N / Fs;

fprintf('Sampling rate: %.1f Hz\n', Fs);
fprintf('Segment duration: %.2f seconds\n', meta.durationSec);

%% ----------------------- FILTER / PRE-PROCESS --------------------------
F = ecg_design_filters(Fs, mainsHz, 0.5, 40, 35);
[ecgClean, stages] = ecg_apply_classical_filters(ecgRaw, Fs, F); 

%% ----------------------- R-PEAK BPM + HRV ------------------------------
[rLocs, rAmps] = ecg_detect_rpeaks(ecgClean, Fs);
[bpmRR, rmssd, sdnn, rrMs] = ecg_bpm_hrv(rLocs, Fs); 

fig1 = figure('Name','Dataset ECG with R-peaks', ...
    'Color','w', ...
    'Position',[80 80 1100 550]);

plot(time, ecgClean, 'LineWidth', 1.2);
hold on; grid on;

if ~isempty(rLocs)
    plot(time(rLocs), rAmps, 'rv', 'MarkerFaceColor','r');
end

xlabel('Time (s)');
ylabel('Normalized amplitude');
title(sprintf('Dataset ECG after preprocessing: %s | Record %s', ...
    meta.source, meta.recordID), 'Interpreter','none');

if ~isempty(rLocs)
    legend('Clean ECG','Detected R-peaks');
else
    legend('Clean ECG');
end

save_figure(fig1, fullfile(outputFolder,'Output3_dataset_Rpeaks_HR_HRV.png'));

%% ----------------------- FFT FEATURES ----------------------------------
featRaw   = ecg_fft_features(ecgRaw, Fs, mainsHz);
featClean = ecg_fft_features(ecgClean, Fs, mainsHz);

f   = featClean.f;
mag = featClean.mag;

bpmFreq = featClean.hrBpm;

if isnan(bpmRR) || isnan(bpmFreq)
    percentError = NaN;
else
    percentError = abs(bpmRR - bpmFreq) / max(abs(bpmRR), eps) * 100;
end

%% ----------------------- OUTPUT 4: FULL FFT ----------------------------
fig2 = figure('Name','Output 4 Dataset FFT Magnitude Spectrum', ...
    'Color','w', ...
    'Position',[80 80 1100 600]);

plot(f, mag, 'LineWidth', 1.3);
grid on;
xlabel('Frequency (Hz)');
ylabel('|X(f)| Magnitude');
title('Output 4: Dataset ECG Single-Sided FFT Magnitude Spectrum');
xlim([0 Fs/2]);

save_figure(fig2, fullfile(outputFolder,'Output4_dataset_full_fft.png'));

%% ----------------------- OUTPUT 5: 0-50 Hz FFT -------------------------
fig3 = figure('Name','Output 5 Dataset Zoomed FFT 0-50 Hz', ...
    'Color','w', ...
    'Position',[80 80 1100 600]);

keep50 = f <= 50;
plot(f(keep50), mag(keep50), 'LineWidth', 1.4);
grid on;
xlabel('Frequency (Hz)');
ylabel('|X(f)| Magnitude');
title('Output 5: Dataset ECG Zoomed FFT Spectrum, 0-50 Hz');
xlim([0 50]);

save_figure(fig3, fullfile(outputFolder,'Output5_dataset_zoom_0_50Hz.png'));

%% ----------------------- OUTPUT 6: ANNOTATED FFT -----------------------
fig4 = figure('Name','Output 6 Dataset Annotated Spectrum', ...
    'Color','w', ...
    'Position',[80 80 1150 650]);

hold on;
xlabel('Frequency (Hz)');
ylabel('|X(f)| Magnitude');
title('Output 6: Annotated Frequency Spectrum of Dataset ECG');
xlim([0 50.5]);

yMax = max(mag(keep50)) * 1.18;
if ~isfinite(yMax) || yMax <= 0
    yMax = 1;
end
ylim([0 yMax]);

add_band_patch(gca, [0 0.5],  [0.90 0.95 1.00], 'Baseline wander');
add_band_patch(gca, [0.5 10], [0.92 1.00 0.92], 'P/T morphology band');
add_band_patch(gca, [10 40],  [1.00 0.96 0.86], 'QRS high-frequency band');
add_band_patch(gca, [40 50],  [1.00 0.90 0.90], 'High-frequency/noise band');

plot(f(keep50), mag(keep50), 'LineWidth', 1.4, ...
    'Color',[0.000 0.447 0.741], ...
    'DisplayName','Clean ECG FFT');
grid on;

add_vline_label(gca, 0.5,  'Baseline <0.5 Hz', '--');
add_vline_label(gca, 10,   'P/T to QRS boundary', '--');
add_vline_label(gca, 40,   'QRS/noise boundary', '--');
add_vline_label(gca, mainsHz, sprintf('%d Hz power-line', mainsHz), ':');

offset_hr  = 0.05 * max(featClean.hrPeakMag, featClean.qrsPeakMag);
offset_qrs = 0.10 * max(featClean.hrPeakMag, featClean.qrsPeakMag);
offset_pt  = 0.07 * max(featClean.hrPeakMag, featClean.qrsPeakMag);

if isfinite(featClean.hrPeakHz) && featClean.hrPeakHz <= 50
    plot(featClean.hrPeakHz, featClean.hrPeakMag, 'rv', ...
        'MarkerFaceColor','r', ...
        'MarkerSize',8, ...
        'DisplayName','HR fundamental peak');

    text(featClean.hrPeakHz, featClean.hrPeakMag + offset_hr, ...
        sprintf(' HR peak %.2f Hz = %.1f BPM', featClean.hrPeakHz, bpmFreq), ...
        'FontWeight','bold', ...
        'Color','r');
end

if isfinite(featClean.ptPeakHz) && featClean.ptPeakHz <= 50
    plot(featClean.ptPeakHz, featClean.ptPeakMag, 'md', ...
        'MarkerFaceColor','m', ...
        'MarkerSize',7, ...
        'DisplayName','P/T band peak');

    text(featClean.ptPeakHz, featClean.ptPeakMag + offset_pt, ...
        sprintf(' P/T peak %.2f Hz', featClean.ptPeakHz), ...
        'FontWeight','bold', ...
        'Color',[0.55 0.00 0.55]);
end

if isfinite(featClean.qrsPeakHz) && featClean.qrsPeakHz <= 50
    plot(featClean.qrsPeakHz, featClean.qrsPeakMag, 'ko', ...
        'MarkerFaceColor','y', ...
        'MarkerSize',7, ...
        'DisplayName','QRS band peak');

    text(featClean.qrsPeakHz, featClean.qrsPeakMag + offset_qrs, ...
        sprintf(' QRS peak %.2f Hz', featClean.qrsPeakHz), ...
        'FontWeight','bold', ...
        'Color','k');
end

legend('Location','northeast');

save_figure(fig4, fullfile(outputFolder,'Output6_dataset_annotated_fft.png'));

%% ----------------------- OUTPUT 7: COMPARISON TABLE --------------------
comparisonTable = table( ...
    bpmRR, ...
    featClean.hrPeakHz, ...
    bpmFreq, ...
    percentError, ...
    rmssd, ...
    sdnn, ...
    'VariableNames', { ...
    'HeartRate_RR_BPM', ...
    'Dominant_HR_Peak_Hz', ...
    'HeartRate_Frequency_BPM', ...
    'Percentage_Error', ...
    'RMSSD_ms', ...
    'SDNN_ms'});

writetable(comparisonTable, fullfile(outputFolder,'Output7_dataset_hr_comparison.csv'));

disp('Output 7: Heart-rate comparison table');
disp(comparisonTable);

fig5 = figure('Name','Output 7 Comparison Table', ...
    'Color','w', ...
    'Position',[120 120 950 280]);

annotation(fig5,'textbox',[0.02 0.91 0.96 0.08], ...
    'String','Output 7: HR Comparison, Time Domain vs Frequency Domain', ...
    'EdgeColor','none', ...
    'FontWeight','bold', ...
    'FontSize',13, ...
    'HorizontalAlignment','center');

uitable('Parent', fig5, ...
    'Data', safeCellForUitable(comparisonTable), ...
    'ColumnName', cellstr(comparisonTable.Properties.VariableNames), ...
    'Units', 'normalized', ...
    'Position', [0.03 0.12 0.94 0.72]);

save_figure(fig5, fullfile(outputFolder,'Output7_dataset_hr_comparison_table.png'));

%% ----------------------- OUTPUT 8: COMMENTARY --------------------------
commentary = generate_commentary(meta, featRaw, featClean, bpmRR, bpmFreq, percentError);

fid = fopen(fullfile(outputFolder,'Output8_dataset_frequency_commentary.txt'), 'w');
fprintf(fid, '%s\n', commentary);
fclose(fid);

fprintf('\nOutput 8 commentary:\n%s\n', commentary);

%% ----------------------- OUTPUT 9: DATASET INFO TABLE ------------------
infoTable = table( ...
    {char(meta.source)}, ...
    {char(meta.recordID)}, ...
    Fs, ...
    meta.durationSec, ...
    {char(num2str(getfield_safe(meta,'patientAge','69')))}, ...
    {char(getfield_safe(meta,'patientGender','Male'))}, ...
    {char(getfield_safe(meta,'classification','Abnormal conduction noted; NSR episodes'))}, ...
    {char(getfield_safe(meta,'url','https://physionet.org/content/mitdb/1.0.0/'))}, ...
    'VariableNames', { ...
    'Dataset', ...
    'Record_ID', ...
    'Sampling_Rate_Hz', ...
    'Segment_Duration_s', ...
    'Age', ...
    'Gender', ...
    'Classification', ...
    'Source_URL'});

writetable(infoTable, fullfile(outputFolder,'Output9_dataset_information_table.csv'));

disp('Output 9: Dataset information table');
disp(infoTable);

fig6 = figure('Name','Output 9 Dataset Information', ...
    'Color','w', ...
    'Position',[100 100 1200 300]);

annotation(fig6,'textbox',[0.02 0.91 0.96 0.08], ...
    'String','Output 9: Dataset Information Table', ...
    'EdgeColor','none', ...
    'FontWeight','bold', ...
    'FontSize',13, ...
    'HorizontalAlignment','center');

uitable('Parent', fig6, ...
    'Data', safeCellForUitable(infoTable), ...
    'ColumnName', cellstr(infoTable.Properties.VariableNames), ...
    'Units', 'normalized', ...
    'Position', [0.02 0.10 0.96 0.78]);

save_figure(fig6, fullfile(outputFolder,'Output9_dataset_information_table.png'));

fprintf('\nAll Task 1B outputs saved in folder:\n%s\n', outputFolder);

%% ========================================================================
% LOCAL FUNCTIONS
% ========================================================================

function [x, Fs, meta] = load_mitbih_100(segmentSec)
% Loads MIT-BIH Arrhythmia Database record 100 using WFDB rdsamp().
% Requires WFDB Toolbox.

recordName = 'mitdb/100';

if exist('rdsamp','file') ~= 2
    error('WFDB Toolbox rdsamp() not found. Install/add WFDB Toolbox first.');
end

try
    % Many WFDB Toolbox versions accept this format:
    [sig, Fs, ~] = rdsamp(recordName, [], round(segmentSec * 360), 1);
catch
    % Fallback for toolbox versions with fewer arguments:
    [sig, Fs, ~] = rdsamp(recordName);
    sig = sig(1:min(size(sig,1), round(segmentSec * Fs)), :);
end

x = sig(:,1);

meta = struct();
meta.source         = 'MIT-BIH Arrhythmia Database';
meta.recordID       = '100';
meta.patientAge     = 69;
meta.patientGender  = 'Male';
meta.classification = 'Abnormal conduction noted; record includes normal sinus rhythm episodes';
meta.url            = 'https://physionet.org/content/mitdb/1.0.0/';
meta.durationSec    = segmentSec;
end

function [x, Fs, meta] = ecg_load_signal_interactive(defaultFs, segmentSec)
% Manual fallback loader for CSV or MAT.
% CSV format supported:
%   one column: ECG values only
%   two columns: time and ECG OR ECG and another column
%
% MAT format supported:
%   picks the first numeric vector or first numeric matrix column found.

[fn, fp] = uigetfile({'*.csv;*.txt;*.mat','ECG files (*.csv, *.txt, *.mat)'}, ...
    'Select ECG dataset file');

if isequal(fn,0)
    error('No file selected. Cannot continue without ECG data.');
end

filePath = fullfile(fp, fn);
[~,~,ext] = fileparts(filePath);

Fs = input(sprintf('Enter sampling frequency Fs in Hz [default %.0f]: ', defaultFs));
if isempty(Fs) || ~isfinite(Fs) || Fs <= 0
    Fs = defaultFs;
end

switch lower(ext)
    case {'.csv','.txt'}
        try
            data = readmatrix(filePath);
        catch
            data = csvread(filePath);
        end

        data = data(:, any(isfinite(data),1));

        if isempty(data)
            error('Selected CSV/TXT file contains no numeric ECG data.');
        end

        if size(data,2) == 1
            x = data(:,1);
        else
            % If first column looks like time, use second column.
            col1 = data(:,1);
            dcol1 = diff(col1);
            if all(isfinite(dcol1)) && median(dcol1) > 0 && max(abs(diff(dcol1))) < 0.1*max(abs(median(dcol1)),eps)
                x = data(:,2);
            else
                x = data(:,1);
            end
        end

    case '.mat'
        S = load(filePath);
        names = fieldnames(S);
        x = [];

        for k = 1:numel(names)
            val = S.(names{k});
            if isnumeric(val) && isvector(val)
                x = val(:);
                break;
            elseif isnumeric(val) && ismatrix(val) && ~isempty(val)
                x = val(:,1);
                break;
            end
        end

        if isempty(x)
            error('No numeric ECG vector/matrix found inside MAT file.');
        end

    otherwise
        error('Unsupported file extension: %s', ext);
end

x = double(x(:));
N = min(numel(x), round(segmentSec * Fs));
x = x(1:N);

meta = struct();
meta.source         = 'User-selected ECG dataset file';
meta.recordID       = fn;
meta.patientAge     = 'Unknown';
meta.patientGender  = 'Unknown';
meta.classification = 'Unknown';
meta.url            = filePath;
meta.durationSec    = N / Fs;
end

function F = ecg_design_filters(Fs, mainsHz, hpCut, lpCut, notchQ)
% Designs high-pass, low-pass, and notch filters.

if hpCut <= 0
    hpCut = 0.5;
end
if lpCut >= Fs/2
    lpCut = 0.8 * (Fs/2);
end

[bHP, aHP] = butter(2, hpCut/(Fs/2), 'high');
[bLP, aLP] = butter(2, lpCut/(Fs/2), 'low');
[bN,  aN]  = local_notch_coeffs(mainsHz, Fs, notchQ);

F = struct();
F.bHP = bHP; F.aHP = aHP;
F.bLP = bLP; F.aLP = aLP;
F.bN  = bN;  F.aN  = aN;
F.hpCut = hpCut;
F.lpCut = lpCut;
F.mainsHz = mainsHz;
F.notchQ = notchQ;
end

function [clean, stages] = ecg_apply_classical_filters(raw, Fs, F)
% Baseline removal + HP + LP + notch + normalization.

x = double(raw(:));

% Remove slow median baseline first.
baseWin = max(5, round(0.8 * Fs));
if mod(baseWin,2) == 0
    baseWin = baseWin + 1;
end

if exist('movmedian','file') || exist('movmedian','builtin')
    baseline = movmedian(x, baseWin);
else
    baseline = moving_mean(x, baseWin);
end

x0 = x - baseline;
x1 = filtfilt(F.bHP, F.aHP, x0);
x2 = filtfilt(F.bLP, F.aLP, x1);
x3 = filtfilt(F.bN,  F.aN,  x2);

x3 = x3 - median(x3);
scale = prctile_local(abs(x3), 95);
if ~isfinite(scale) || scale < eps
    scale = max(abs(x3));
end
if ~isfinite(scale) || scale < eps
    scale = 1;
end

clean = x3 / scale;

% Auto polarity: make R-peaks upward.
pol = estimate_r_polarity(clean, Fs);
clean = pol * clean;

stages = struct();
stages.raw = x;
stages.baselineRemoved = x0;
stages.highPass = x1;
stages.lowPass = x2;
stages.notch = x3;
stages.clean = clean;
end

function y = moving_mean(x, win)
win = max(1, round(win));
if win <= 1
    y = x;
else
    kernel = ones(win,1) / win;
    y = conv(x, kernel, 'same');
end
end

function polarity = estimate_r_polarity(x, Fs)
x = x(:);
minDist = round(0.40 * Fs);

try
    [~, posLoc] = findpeaks(x,  'MinPeakDistance', minDist);
    [~, negLoc] = findpeaks(-x, 'MinPeakDistance', minDist);
catch
    posLoc = simple_peak_locs(x, minDist);
    negLoc = simple_peak_locs(-x, minDist);
end

if isempty(posLoc)
    posScore = 0;
else
    posVals = sort(x(posLoc), 'descend');
    posScore = mean(posVals(1:min(5,numel(posVals))));
end

if isempty(negLoc)
    negScore = 0;
else
    negVals = sort(-x(negLoc), 'descend');
    negScore = mean(negVals(1:min(5,numel(negVals))));
end

polarity = 1;
if negScore > posScore
    polarity = -1;
end
end

function [rLocs, rAmps] = ecg_detect_rpeaks(ecg, Fs)
x = double(ecg(:));
rLocs = [];
rAmps = [];

if numel(x) < round(2 * Fs)
    return;
end

p25 = prctile_local(x, 25);
p75 = prctile_local(x, 75);
p90 = prctile_local(x, 90);
medx = median(x);
iqrVal = max(p75 - p25, 0.05);

minPeakHeight   = max(medx + 1.1 * iqrVal, p90);
minPeakDistance = round(0.35 * Fs);
minProm         = max(0.30, 0.45 * iqrVal);

try
    [pks, locs] = findpeaks(x, ...
        'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance, ...
        'MinPeakProminence', minProm);
catch
    try
        [pks, locs] = findpeaks(x, ...
            'MinPeakHeight', minPeakHeight, ...
            'MinPeakDistance', minPeakDistance);
    catch
        locs = simple_peak_locs(x, minPeakDistance);
        pks = x(locs);
        keep = pks >= minPeakHeight;
        locs = locs(keep);
        pks = pks(keep);
    end
end

% Remove edge detections.
edge = round(0.20 * Fs);
keep = locs > edge & locs < (numel(x) - edge);
locs = locs(keep);
pks  = pks(keep);

% Keep physiological RR intervals.
if numel(locs) >= 3
    rr = diff(locs) / Fs;
    validPair = rr >= 0.35 & rr <= 1.60;
    keepLoc = [true; validPair(:)];
    locs = locs(keepLoc);
    pks  = pks(keepLoc);
end

rLocs = locs(:);
rAmps = pks(:);
end

function locs = simple_peak_locs(x, minDist)
x = x(:);
cand = find(x(2:end-1) > x(1:end-2) & x(2:end-1) >= x(3:end)) + 1;

if isempty(cand)
    locs = [];
    return;
end

[~, order] = sort(x(cand), 'descend');
cand = cand(order);

chosen = [];
for k = 1:numel(cand)
    if isempty(chosen) || all(abs(cand(k) - chosen) >= minDist)
        chosen(end+1,1) = cand(k); %#ok<AGROW>
    end
end

locs = sort(chosen);
end

function [bpm, rmssd, sdnn, rrMs] = ecg_bpm_hrv(rLocs, Fs)
bpm = NaN;
rmssd = NaN;
sdnn = NaN;
rrMs = [];

if numel(rLocs) < 2
    return;
end

rr = diff(rLocs(:)) / Fs;
rr = rr(rr >= 0.35 & rr <= 1.60);

if isempty(rr)
    return;
end

medRR = median(rr);
rr = rr(abs(rr - medRR) <= 0.25 * medRR);

if isempty(rr)
    return;
end

bpm = 60 / median(rr);
rrMs = rr * 1000;

if numel(rrMs) >= 3
    rmssd = sqrt(mean(diff(rrMs).^2));
    sdnn = std(rrMs);
end
end

function feat = ecg_fft_features(x, Fs, mainsHz)
x = double(x(:));
x = x - mean(x);

N = numel(x);

% Hann window without requiring hann().
if N > 1
    w = 0.5 - 0.5*cos(2*pi*(0:N-1)'/(N-1));
else
    w = ones(N,1);
end

xw = x .* w;
Y = fft(xw);

P2 = abs(Y) / sum(w);
P1 = P2(1:floor(N/2)+1);

if numel(P1) > 2
    P1(2:end-1) = 2 * P1(2:end-1);
end

f = Fs * (0:floor(N/2))' / N;
mag = P1(:);

% Frequency bands. The display peaks use non-overlapping masks so the
% heart-rate fundamental does not get reported again as P/T or QRS energy.
hrBand       = f >= 0.70 & f <= 2.50;     % 42-150 BPM
ptBand       = f >= 0.50 & f <= 10.00 & ~hrBand;
qrsBand      = f >= 10.00 & f <= 40.00;
baselineBand = f >= 0.00 & f < 0.50;
signalBand   = f >= 0.50 & f <= 40.00;
noiseBand    = (f >= 0.00 & f < 0.50) | (f > 40.00 & f <= min(Fs/2,100.00));

[hrPeakHz, hrPeakMag]   = band_peak(f, mag, hrBand);
[ptPeakHz, ptPeakMag]   = band_peak(f, mag, ptBand);
[qrsPeakHz, qrsPeakMag] = band_peak(f, mag, qrsBand);

signalPower   = band_power(f, mag, signalBand);
noisePower    = band_power(f, mag, noiseBand);
baselinePower = band_power(f, mag, baselineBand);

snrDb = 10 * log10(signalPower / max(noisePower, eps));

feat = struct();
feat.f = f;
feat.mag = mag;
feat.hrPeakHz = hrPeakHz;
feat.hrPeakMag = hrPeakMag;
feat.hrBpm = hrPeakHz * 60;
feat.ptPeakHz = ptPeakHz;
feat.ptPeakMag = ptPeakMag;
feat.qrsPeakHz = qrsPeakHz;
feat.qrsPeakMag = qrsPeakMag;
feat.signalPower = signalPower;
feat.noisePower = noisePower;
feat.baselinePower = baselinePower;
feat.snrDb = snrDb;
feat.mainsHz = mainsHz;
end

function [pkHz, pkMag] = band_peak(f, mag, mask)
pkHz = NaN;
pkMag = NaN;

idx = find(mask & isfinite(mag));
if isempty(idx)
    return;
end

[pkMag, rel] = max(mag(idx));
pkHz = f(idx(rel));
end

function P = band_power(f, mag, mask)
idx = mask & isfinite(mag);
if nnz(idx) < 2
    P = 0;
    return;
end

% Approximate spectral power from magnitude squared.
P = trapz(f(idx), mag(idx).^2);
end

function [b, a] = local_notch_coeffs(f0, Fs, Q)
w0 = 2*pi*f0/Fs;
alpha = sin(w0)/(2*Q);

b0 = 1;
b1 = -2*cos(w0);
b2 = 1;

a0 = 1 + alpha;
a1 = -2*cos(w0);
a2 = 1 - alpha;

b = [b0 b1 b2] / a0;
a = [1 a1/a0 a2/a0];
end

function p = prctile_local(x, pct)
x = sort(x(:));
x = x(isfinite(x));

if isempty(x)
    p = NaN;
    return;
end

pct = max(0, min(100, pct));
idx = 1 + (numel(x)-1) * pct / 100;

lo = floor(idx);
hi = ceil(idx);

if lo == hi
    p = x(lo);
else
    p = x(lo) + (idx-lo) * (x(hi)-x(lo));
end
end

function val = getfield_safe(S, fieldName, defaultVal)
if isfield(S, fieldName)
    val = S.(fieldName);
else
    val = defaultVal;
end
end

function txt = generate_commentary(meta, featRaw, featClean, bpmRR, bpmFreq, percentError)
lines = cell(10,1);

lines{1} = sprintf('1. The ECG segment was taken from %s, record %s, and sampled at the documented sampling frequency.', ...
    meta.source, meta.recordID);

lines{2} = sprintf('2. The dominant heart-rate frequency peak was %.3f Hz, corresponding to %.1f BPM.', ...
    featClean.hrPeakHz, bpmFreq);

lines{3} = sprintf('3. The time-domain R-R interval method gave %.1f BPM, so the percentage difference was %.2f%%.', ...
    bpmRR, percentError);

lines{4} = sprintf('4. The P-wave and T-wave components are expected mainly in the lower ECG band around 0.5-10 Hz; after excluding the heart-rate fundamental, the measured low-band peak was %.2f Hz.', ...
    featClean.ptPeakHz);

lines{5} = sprintf('5. The QRS complex has sharper transitions, so its higher-frequency energy was summarized in the 10-40 Hz band; the measured QRS high-frequency peak was %.2f Hz.', ...
    featClean.qrsPeakHz);

lines{6} = sprintf('6. The baseline-wander power below 0.5 Hz was reduced after preprocessing from %.4g to %.4g.', ...
    featRaw.baselinePower, featClean.baselinePower);

lines{7} = sprintf('7. The %.0f Hz mains region was checked to identify possible power-line interference.', ...
    featClean.mainsHz);

lines{8} = sprintf('8. The computed SNR estimate after filtering was %.2f dB, based on signal-band power versus noise-band power.', ...
    featClean.snrDb);

lines{9} = '9. Small differences between RR-based BPM and FFT-based BPM can occur because the FFT uses a finite window and its frequency resolution depends on the segment length.';

lines{10} = '10. Overall, the frequency-domain result supports the time-domain heart-rate estimate and helps verify the ECG signal quality.';

txt = sprintf('%s\n', lines{:});
end

function out = safeCellForUitable(T)
% Converts table/cell values so older MATLAB uitable can display them.
% Older uitable accepts only numeric, logical, or char values inside cells.

if istable(T)
    out = table2cell(T);
else
    out = T;
end

for r = 1:size(out,1)
    for c = 1:size(out,2)
        x = out{r,c};

        if ischar(x)
            out{r,c} = x;

        elseif isnumeric(x)
            if isempty(x)
                out{r,c} = '';
            elseif isscalar(x)
                out{r,c} = num2str(x);
            else
                out{r,c} = mat2str(x);
            end

        elseif islogical(x)
            if x
                out{r,c} = 'true';
            else
                out{r,c} = 'false';
            end

        elseif iscell(x)
            if isempty(x)
                out{r,c} = '';
            else
                y = x{1};
                if isnumeric(y)
                    out{r,c} = num2str(y);
                elseif ischar(y)
                    out{r,c} = y;
                else
                    try
                        out{r,c} = char(y);
                    catch
                        out{r,c} = '';
                    end
                end
            end

        else
            try
                out{r,c} = char(x);
            catch
                out{r,c} = '';
            end
        end
    end
end
end

function add_vline_label(ax, xValue, labelText, lineStyle)
% Compatibility replacement for xline().

yl = ylim(ax);

line(ax, [xValue xValue], yl, ...
    'LineStyle', lineStyle, ...
    'Color', [0.25 0.25 0.25], ...
    'LineWidth', 1.0);

text(ax, xValue, yl(2), [' ' labelText], ...
    'Rotation', 90, ...
    'VerticalAlignment','top', ...
    'HorizontalAlignment','left', ...
    'FontSize',9, ...
    'Color',[0.15 0.15 0.15]);
end

function add_band_patch(ax, xRange, colorVal, labelText)
% Adds a light background band for a frequency range.

yl = ylim(ax);
x1 = xRange(1);
x2 = xRange(2);

patch(ax, [x1 x2 x2 x1], [yl(1) yl(1) yl(2) yl(2)], colorVal, ...
    'FaceAlpha',0.35, ...
    'EdgeColor','none', ...
    'DisplayName',labelText);
end

function save_figure(figHandle, filePath)
% Saves figure using exportgraphics if available; otherwise uses print.

try
    exportgraphics(figHandle, filePath, 'Resolution', 300);
catch
    print(figHandle, filePath, '-dpng', '-r300');
end
end
