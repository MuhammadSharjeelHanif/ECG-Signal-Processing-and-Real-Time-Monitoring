clear; clc; close all;

%% ----------------------- SELECT INPUT MODE -----------------------------
modeChoice = menu('Select ECG input mode', 'Live ESP32 / AD8232', 'Dataset / saved ECG file');
if modeChoice == 0
    error('No input mode selected.');
end
useLiveESP32 = (modeChoice == 1);

%% ----------------------- PATIENT INFORMATION ---------------------------
answer = inputdlg({'Patient/Subject name:', 'Age in years:', 'Gender/notes:'}, ...
    'Patient Information', [1 45], {'Subject 1','21','Male'});
if isempty(answer)
    patientName = 'Subject'; patientAge = NaN; patientNotes = '';
else
    patientName = strtrim(answer{1});
    patientAge  = str2double(answer{2});
    patientNotes = strtrim(answer{3});
    if isempty(patientName), patientName = 'Subject'; end
end

%% ----------------------- USER SETTINGS ---------------------------------
port            = 'COM4';
baudRate        = 115200;
Fs              = 250;
serialValueMode = 'last';
plotWindowSec   = 12;
bpmWindowSec    = 10;
hrvWindowSec    = 60;
bufferSec       = 70;
cyclePreSec     = 0.25;
cyclePostSec    = 0.45;
mainsHz         = 50;
samplesPerDraw  = 10;
minProcessSec   = 4;
fftWindowSec    = 25;
fftMaxFreq      = 60;
fftSaveFolder   = pwd;
datasetSpeed    = 4;

%% ----------------------- CONNECT OR LOAD DATA --------------------------
s = [];
serialMode = '';
portUsed = 'dataset';
datasetX = [];
datasetIndex = 1;
datasetMeta = struct();

if useLiveESP32
    fprintf('\nOpening ESP32 serial connection...\n');
    [s, serialMode, portUsed] = open_ecg_serial(port, baudRate);
    cleanupObj = onCleanup(@() close_ecg_serial(s, serialMode));
    fprintf('Connected to ESP32 on %s at %d baud.\n', portUsed, baudRate);
else
    fprintf('\nLoading dataset/saved ECG signal...\n');
    [datasetX, Fs, datasetMeta] = ecg_load_signal_interactive(Fs, max(bufferSec, 90));
    portUsed = sprintf('%s | %s', datasetMeta.source, datasetMeta.recordID);
    fprintf('Loaded %s, Fs = %.2f Hz, duration = %.2f s\n', portUsed, Fs, numel(datasetX)/Fs);
end

%% ----------------------- FILTERS ---------------------------------------
F = ecg_design_filters(Fs, mainsHz, 0.5, 40, 35);

%% ========================= COLOUR PALETTE ==============================
C.figBg   = [0.055 0.075 0.11];
C.panelBg = [0.08  0.10  0.145];
C.panelBd = [0.14  0.22  0.35];
C.axBg    = [0.065 0.085 0.125];
C.gridCol = [0.11  0.16  0.24];

C.line    = [0.18  0.82  0.72];
C.r       = [1.00  0.35  0.35];

C.title   = [0.90  0.95  1.00];
C.sub     = [0.45  0.58  0.72];
C.accent  = [0.20  0.72  0.90];

C.ok      = [0.18  0.88  0.52];
C.warn    = [1.00  0.72  0.12];
C.bad     = [1.00  0.28  0.28];
C.dark    = [0.65  0.75  0.85];

C.p       = [1.00  0.75  0.20];
C.q       = [0.70  0.45  1.00];
C.s       = [0.20  0.75  1.00];
C.t       = [0.25  0.95  0.55];

%% ========================= FIGURE LAYOUT ===============================
fig = figure('Name', 'ECG Dashboard', 'NumberTitle', 'off', ...
    'Color', C.figBg, 'Position', [40 30 1560 880]);
setappdata(fig, 'stopFlag', false);

function draw_panel(fig, pos, bgColor, bdColor)
    ax_ = axes('Parent', fig, 'Units','normalized', 'Position', pos, ...
        'Color', bgColor, 'Box','on', 'LineWidth', 1.2, ...
        'XColor', bdColor, 'YColor', bdColor, ...
        'XTick',[], 'YTick',[], 'XLim',[0 1], 'YLim',[0 1]);
    set(ax_, 'PickableParts','none');
end

draw_panel(fig, [0.025 0.865 0.955 0.11],  C.panelBg, C.panelBd);  % header
draw_panel(fig, [0.025 0.43  0.955 0.44], C.panelBg, C.panelBd);  % ECG main
draw_panel(fig, [0.025 0.07  0.495 0.355], C.panelBg, C.panelBd);  % cycle
draw_panel(fig, [0.535 0.07  0.445 0.355], C.panelBg, C.panelBd);  % stats

% ---- HEADER ------------------------------------------------------------
annotation(fig, 'textbox', [0.038 0.928 0.30 0.040], ...
    'String', 'ECG  MONITOR', ...
    'EdgeColor','none', 'FontWeight','bold', 'FontSize', 24, ...
    'Color', C.title, 'FontName','Courier New', ...
    'VerticalAlignment','middle');

annotation(fig, 'line', [0.038 0.962], [0.918 0.918], ...
    'Color', C.accent, 'LineWidth', 1.5);

modeText = 'LIVE  ESP32';
if ~useLiveESP32, modeText = 'DATASET  PLAYBACK'; end

inputDisplay = compact_input_label_local(portUsed, 44);
annotation(fig, 'textbox', [0.355 0.936 0.41 0.024], ...
    'String', sprintf('MODE:  %s     INPUT:  %s', modeText, inputDisplay), ...
    'EdgeColor','none', 'FontSize', 8.8, 'Color', C.sub, ...
    'FontName','Courier New', 'Interpreter','none', ...
    'VerticalAlignment','middle', 'FitBoxToText','off');

annotation(fig, 'textbox', [0.038 0.890 0.34 0.024], ...
    'String', sprintf('BPM window:  %ds     HRV after:  %ds', ...
    bpmWindowSec, hrvWindowSec), ...
    'EdgeColor','none', 'FontSize', 8.8, 'Color', C.sub, ...
    'FontName','Courier New', 'Interpreter','none', ...
    'VerticalAlignment','middle', 'FitBoxToText','off');

annotation(fig, 'textbox', [0.805 0.936 0.065 0.024], ...
    'String', sprintf('Fs: %.0f Hz', Fs), ...
    'EdgeColor','none', 'FontSize', 8.8, 'Color', C.sub, ...
    'FontName','Courier New', 'Interpreter','none', ...
    'VerticalAlignment','middle', 'FitBoxToText','off');

% Patient info is kept separate from the status text so the two labels never overlap.
annotation(fig, 'textbox', [0.405 0.888 0.45 0.024], ...
    'String', sprintf('PATIENT:  %s     AGE: %s yrs     %s', ...
    upper(patientName), num2str(patientAge), upper(patientNotes)), ...
    'EdgeColor','none', 'FontSize', 8.8, 'Color', C.accent, ...
    'FontName','Courier New', 'Interpreter','none', ...
    'VerticalAlignment','middle', 'FitBoxToText','off');

% ---- STOP BUTTON -------------------------------------------------------
uicontrol('Parent', fig, 'Style','pushbutton', ...
    'String', 'STOP', ...
    'FontSize', 13, 'FontWeight','bold', 'FontName','Courier New', ...
    'ForegroundColor', [1 1 1], ...
    'BackgroundColor', [0.62 0.06 0.06], ...
    'Units','normalized', 'Position', [0.882 0.885 0.084 0.050], ...
    'Callback', @(~,~) setappdata(fig,'stopFlag',true));

% ---- STATUS BAR --------------------------------------------------------
% Kept in its own left-side box; patient info starts at x = 0.245.
textStatus = annotation(fig, 'textbox', [0.038 0.868 0.26 0.020], ...
    'String', 'STATUS: INIT', ...
    'EdgeColor','none', 'FontSize', 9, 'FontWeight','bold', ...
    'Color', C.warn, 'FontName','Courier New', 'Interpreter','none', ...
    'VerticalAlignment','middle', 'FitBoxToText','off');

%% ========================= AXES: ECG MAIN ==============================
ax1 = axes('Parent', fig, 'Position', [0.055 0.50 0.905 0.30], ...
    'Color', C.axBg, 'Box','off', 'LineWidth', 1.2, ...
    'FontSize', 10, 'FontName','Courier New', ...
    'XColor', C.sub, 'YColor', C.sub, ...
    'GridColor', C.gridCol, 'GridAlpha', 1, ...
    'MinorGridColor', C.gridCol, 'MinorGridAlpha', 0.5, ...
    'TickDir','out', 'TickLength',[0.005 0.005]);
hold(ax1,'on'); grid(ax1,'on');

title(ax1, 'REAL-TIME  ECG  TRACE', ...
    'Color', C.accent, 'FontWeight','bold', 'FontSize', 12, ...
    'FontName','Courier New');
xlabel(ax1, 'Time (s)', 'FontWeight','bold', 'Color', C.sub);
ylabel(ax1, 'Amplitude (norm.)', 'FontWeight','bold', 'Color', C.sub);

plot(ax1, [0 1e6], [0 0], '-', 'Color', [C.gridCol 0.6], 'LineWidth', 0.8);

plotLive  = plot(ax1, NaN, NaN, 'Color', C.line, 'LineWidth', 1.6);
plotRLive = plot(ax1, NaN, NaN, 'v', 'LineStyle','none', ...
    'MarkerSize', 7, 'MarkerFaceColor', C.r, 'MarkerEdgeColor', C.figBg, 'LineWidth', 0.5);
xlim(ax1,[0 plotWindowSec]); ylim(ax1,[-3 5]);

%% ========================= AXES: ECG CYCLE =============================
ax2 = axes('Parent', fig, 'Position', [0.060 0.135 0.44 0.255], ...
    'Color', C.axBg, 'Box','off', 'LineWidth', 1.2, ...
    'FontSize', 10, 'FontName','Courier New', ...
    'XColor', C.sub, 'YColor', C.sub, ...
    'GridColor', C.gridCol, 'GridAlpha', 1, ...
    'TickDir','out', 'TickLength',[0.008 0.008]);
hold(ax2,'on'); grid(ax2,'on');

title(ax2, 'SINGLE  CYCLE  —  P Q R S T', ...
    'Color', C.accent, 'FontWeight','bold', 'FontSize', 11, ...
    'FontName','Courier New');
xlabel(ax2, 'Time rel. to R-peak (s)', 'FontWeight','bold', 'Color', C.sub);
ylabel(ax2, 'Amplitude (norm.)', 'FontWeight','bold', 'Color', C.sub);

plotCycle = plot(ax2, NaN, NaN, 'Color', C.line, 'LineWidth', 2.2);
plotZero  = plot(ax2, [0 0], [-2 4], '--', 'Color', C.panelBd, 'LineWidth', 1);

plotP  = plot(ax2, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize', 9, ...
    'MarkerFaceColor', C.p, 'MarkerEdgeColor', C.figBg, 'LineWidth', 0.5);
plotQ  = plot(ax2, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize', 9, ...
    'MarkerFaceColor', C.q, 'MarkerEdgeColor', C.figBg);
plotR2 = plot(ax2, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize', 10, ...
    'MarkerFaceColor', C.r, 'MarkerEdgeColor', C.figBg);
plotS  = plot(ax2, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize', 9, ...
    'MarkerFaceColor', C.s, 'MarkerEdgeColor', C.figBg);
plotT  = plot(ax2, NaN, NaN, 'o', 'LineStyle','none', 'MarkerSize', 9, ...
    'MarkerFaceColor', C.t, 'MarkerEdgeColor', C.figBg);

lgd = legend(ax2, [plotP plotQ plotR2 plotS plotT], {'P','Q','R','S','T'}, ...
    'Location','northeast', 'Box','off', 'FontSize', 9.5, 'FontName','Courier New');
lgd.TextColor = C.sub;

xlim(ax2,[-cyclePreSec cyclePostSec]); ylim(ax2,[-2.5 5]);
cycleTextHandles = [];

%% ========================= STATS PANEL =================================
ax3 = axes('Parent', fig, 'Position', [0.548 0.08 0.425 0.34], ...
    'Color', C.panelBg, 'Box','off', ...
    'XColor', C.panelBd, 'YColor', C.panelBd, ...
    'XTick',[], 'YTick',[], 'XLim',[0 1], 'YLim',[0 1], ...
    'FontName','Courier New', 'Clipping','on');
hold(ax3,'on');

% Dividers
plot(ax3, [0.04 0.96], [0.87 0.87], '-', 'Color', C.panelBd, 'LineWidth', 1);
plot(ax3, [0.04 0.96], [0.55 0.55], '-', 'Color', C.panelBd, 'LineWidth', 0.6);
plot(ax3, [0.04 0.96], [0.33 0.33], '-', 'Color', C.panelBd, 'LineWidth', 0.6);
plot(ax3, [0.04 0.96], [0.18 0.18], '-', 'Color', C.panelBd, 'LineWidth', 0.6);

% Panel title
text(ax3, 0.05, 0.94, 'CLINICAL  SUMMARY', ...
    'Color', C.title, 'FontWeight','bold', 'FontSize', 14, ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');

% Patient line
text(ax3, 0.05, 0.80, ...
    compact_label_local(sprintf('%s  |  %s yrs  |  %s', ...
    upper(patientName), num2str(patientAge), modeText), 58), ...
    'Color', C.sub, 'FontSize', 9, 'FontName','Courier New', ...
    'Interpreter','none', 'Clipping','on');

% HEART RATE
text(ax3, 0.05, 0.68, 'HEART  RATE', ...
    'Color', C.sub, 'FontSize', 9.5, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');
textBPM = text(ax3, 0.05, 0.57, 'waiting...', ...
    'Color', C.warn, 'FontSize', 26, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');

% HRV — RMSSD (short window, always active)
text(ax3, 0.05, 0.47, 'HRV  —  RMSSD  (live)', ...
    'Color', C.sub, 'FontSize', 9.5, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');
textHRV = text(ax3, 0.05, 0.39, 'collecting...', ...
    'Color', C.warn, 'FontSize', 13, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');

% HRV — SDNN (60 s window)
text(ax3, 0.05, 0.29, 'SDNN  (60 s  window)', ...
    'Color', C.sub, 'FontSize', 9.5, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');
textSDNN = text(ax3, 0.05, 0.22, 'SDNN:  ---', ...
    'Color', C.dark, 'FontSize', 11, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');

% Health status — wrapped inside the stats panel so it cannot run out of the window
text(ax3, 0.05, 0.162, 'STATUS', ...
    'Color', C.sub, 'FontSize', 8.5, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', 'Clipping','on');
textHealth = text(ax3, 0.05, 0.132, 'waiting...', ...
    'Color', C.warn, 'FontSize', 7.1, 'FontWeight','bold', ...
    'FontName','Courier New', 'Interpreter','none', ...
    'VerticalAlignment','top', 'Clipping','on');

% Footer (elapsed / R-peaks) — moved to ax1 area bottom so they don't
% compete for space inside ax3
textET = text(ax3, 0.05, 0.022, 'ELAPSED:  0.0 s', ...
    'Color', C.sub, 'FontSize', 8.5, 'FontName','Courier New', ...
    'Interpreter','none', 'Clipping','on');
textN  = text(ax3, 0.58, 0.022, 'R-PEAKS:  0', ...
    'Color', C.sub, 'FontSize', 8.5, 'FontName','Courier New', ...
    'Interpreter','none', 'Clipping','on');

drawnow;

%% ----------------------- LIVE / PLAYBACK LOOP --------------------------
rawBuffer    = [];
idxBuffer    = [];
sampleCounter = 0;
bpmValue     = NaN;
hrvSdnn      = NaN;
nextBpmUpdateSec = bpmWindowSec;
polarity     = 1;
polarityLocked = false;
fftDone      = false;

while ishandle(fig) && ~getappdata(fig,'stopFlag')
    newValues = [];
    if useLiveESP32
        try
            line = read_ecg_line(s, serialMode);
        catch ME
            warning('Serial read failed: %s', ME.message);
            break;
        end
        adcValue = parse_ecg_value(line, serialValueMode);
        if isnan(adcValue), continue; end
        newValues = adcValue;
    else
        if datasetIndex > numel(datasetX)
            set(textStatus,'String','STATUS: FINISHED','Color',C.ok);
            pause(0.05); drawnow; continue;
        end
        nTake = min(samplesPerDraw, numel(datasetX)-datasetIndex+1);
        newValues = datasetX(datasetIndex:datasetIndex+nTake-1);
        datasetIndex = datasetIndex + nTake;
        pause((nTake/Fs)/datasetSpeed);
    end

    for nv = 1:numel(newValues)
        sampleCounter = sampleCounter + 1;
        rawBuffer(end+1) = newValues(nv);
        idxBuffer(end+1) = sampleCounter;
    end

    maxSamples = round(bufferSec*Fs);
    if numel(rawBuffer) > maxSamples
        rawBuffer = rawBuffer(end-maxSamples+1:end);
        idxBuffer = idxBuffer(end-maxSamples+1:end);
    end

    if mod(sampleCounter, samplesPerDraw) ~= 0 && useLiveESP32
        continue;
    end

    elapsedSec = sampleCounter/Fs;

    %% --- Early stage: not enough data yet ------------------------------
    if numel(rawBuffer) < round(minProcessSec*Fs)
        preview = double(rawBuffer(:)); preview = preview - median(preview);
        sc = max(abs(preview)); if sc < eps, sc = 1; end
        preview = preview/sc;
        tPreview = (idxBuffer-1)/Fs;
        plotStart = max(1, numel(preview)-round(plotWindowSec*Fs)+1);
        set(plotLive,'XData',tPreview(plotStart:end),'YData',preview(plotStart:end));
        set(plotRLive,'XData',NaN,'YData',NaN);
        if tPreview(end) <= plotWindowSec
            xlim(ax1,[0 plotWindowSec]);
        else
            xlim(ax1,[tPreview(plotStart) tPreview(end)]);
        end
        ylim(ax1,[-1.2 1.2]);
        set(textBPM,   'String','collecting...', 'Color',C.warn);
        set(textHRV,   'String','collecting...',  'Color',C.warn);
        set(textSDNN,  'String','SDNN:  ---',     'Color',C.dark);
        [hs, hc] = ecg_health_status(patientAge, NaN, NaN);
        set(textHealth,'String', wrap_status_text_local(hs, 42), 'Color', hc);
        set(textET,    'String', sprintf('ELAPSED:  %.1f s', elapsedSec));
        set(textN,     'String', 'R-PEAKS:  0');
        set(textStatus,'String','STATUS: COLLECT','Color',C.warn);
        drawnow; continue;
    end

    %% --- Filter & polarity ---------------------------------------------
    [clean, ~] = ecg_apply_classical_filters(rawBuffer, Fs, F);
    if ~polarityLocked && numel(clean) >= round(5*Fs)
        polarity = estimate_r_polarity(clean, Fs);
        polarityLocked = true;
    end
    clean = polarity * clean;

    %% --- FFT snapshot --------------------------------------------------
    if ~fftDone && elapsedSec >= fftWindowSec && numel(clean) >= round(fftWindowSec*Fs)
        nFFTwin    = round(fftWindowSec*Fs);
        winIdx     = numel(clean)-nFFTwin+1:numel(clean);
        fftSegment = clean(winIdx);
        fftTime    = (0:nFFTwin-1)'/Fs;
        timeStamp  = datestr(now,'yyyymmdd_HHMMSS');
        matFile    = fullfile(fftSaveFolder, ['ECG_FFT_Window_' timeStamp '.mat']);
        csvFile    = fullfile(fftSaveFolder, ['ECG_FFT_Window_' timeStamp '.csv']);
        save(matFile, 'fftSegment','fftTime','Fs','fftWindowSec','patientName','patientAge','patientNotes');
        writematrix([fftTime(:), fftSegment(:)], csvFile);
        plot_ecg_fft_annotated(fftSegment, Fs, fftMaxFreq, 'Dashboard ECG FFT Window', mainsHz);
        ecg_export_current_figure(fullfile(fftSaveFolder, ['dashboard_fft_' timeStamp '.png']));
        fftDone = true;
        fprintf('\nSaved %.1f s ECG window for FFT.\nMAT: %s\nCSV: %s\n', fftWindowSec, matFile, csvFile);
    end

    %% --- R-peak detection ----------------------------------------------
    [rLocs, rAmps] = ecg_detect_rpeaks(clean, Fs);
    rAbs = idxBuffer(rLocs);

    %% --- BPM update ----------------------------------------------------
    if elapsedSec >= nextBpmUpdateSec
        recentMask = rAbs >= sampleCounter - round(bpmWindowSec*Fs) + 1;
        bpmValue   = compute_bpm_from_rpeaks_local(rAbs(recentMask), Fs);
        while nextBpmUpdateSec <= elapsedSec
            nextBpmUpdateSec = nextBpmUpdateSec + bpmWindowSec;
        end
    end

    %% --- HRV: RMSSD always (short window), SDNN after 60 s ------------
    % Short-window RMSSD — active as soon as R-peaks exist
    rmssdMask  = rAbs >= sampleCounter - round(bpmWindowSec*Fs) + 1;
    [~, shortRmssd, ~] = ecg_bpm_hrv(rAbs(rmssdMask), Fs);

    % Long-window SDNN — only after hrvWindowSec
    if elapsedSec >= hrvWindowSec
        hrvMask = rAbs >= sampleCounter - round(hrvWindowSec*Fs) + 1;
        [~, ~, hrvSdnn] = ecg_bpm_hrv(rAbs(hrvMask), Fs);
    end

    %% --- ECG main trace ------------------------------------------------
    tBuffer   = (idxBuffer-1)/Fs;
    plotStart = max(1, numel(clean)-round(plotWindowSec*Fs)+1);
    idxPlot   = plotStart:numel(clean);
    displayScale = ecg_display_scale_local(clean(idxPlot));
    cleanDisplay = clean ./ displayScale;
    rAmpsDisplay = rAmps ./ displayScale;
    set(plotLive,'XData',tBuffer(idxPlot),'YData',cleanDisplay(idxPlot));
    liveMask = rLocs >= plotStart;
    set(plotRLive,'XData',tBuffer(rLocs(liveMask)),'YData',rAmpsDisplay(liveMask));
    if tBuffer(end) <= plotWindowSec
        xlim(ax1,[0 plotWindowSec]);
    else
        xlim(ax1,[tBuffer(plotStart) tBuffer(end)]);
    end
    ylim(ax1, [-1.35 1.35]);

    %% --- Single cycle --------------------------------------------------
    if ~isempty(rLocs)
        latestR  = rLocs(end);
        preSamp  = round(cyclePreSec*Fs);
        postSamp = round(cyclePostSec*Fs);
        if latestR-preSamp >= 1 && latestR+postSamp <= numel(clean)
            cycIdx  = latestR-preSamp:latestR+postSamp;
            cycleY  = clean(cycIdx);
            cycleYDisplay = cycleY ./ displayScale;
            cycleT  = (cycIdx-latestR)/Fs;
            centerIdx = preSamp+1;
            set(plotCycle,'XData',cycleT,'YData',cycleYDisplay);
            [ptLoc, ptAmp, ptLabel] = locate_pqrst_local(cycleY, centerIdx, Fs);
            ptAmpDisplay = ptAmp ./ displayScale;
            set(plotP, 'XData',cycleT(ptLoc(1)),'YData',ptAmpDisplay(1));
            set(plotQ, 'XData',cycleT(ptLoc(2)),'YData',ptAmpDisplay(2));
            set(plotR2,'XData',cycleT(ptLoc(3)),'YData',ptAmpDisplay(3));
            set(plotS, 'XData',cycleT(ptLoc(4)),'YData',ptAmpDisplay(4));
            set(plotT, 'XData',cycleT(ptLoc(5)),'YData',ptAmpDisplay(5));
            ySpan = max(cycleYDisplay)-min(cycleYDisplay); if ySpan < 1, ySpan = 1; end
            set(plotZero,'XData',[0 0],'YData',[min(cycleYDisplay)-0.15*ySpan max(cycleYDisplay)+0.15*ySpan]);
            xlim(ax2,[cycleT(1) cycleT(end)]);
            ylim(ax2,[min(cycleYDisplay)-0.20*ySpan max(cycleYDisplay)+0.22*ySpan]);
            if ~isempty(cycleTextHandles)
                delete_valid_handles_local(cycleTextHandles);
            end
            colorList = [C.p; C.q; C.r; C.s; C.t];
            offsets   = [0.06 0.06 0.08 0.06 0.07];
            cycleTextHandles = gobjects(1,5);
            for m = 1:5
                cycleTextHandles(m) = text(ax2, cycleT(ptLoc(m)), ...
                    ptAmpDisplay(m)+offsets(m)*ySpan, ptLabel{m}, ...
                    'Color',colorList(m,:), 'FontWeight','bold', 'FontSize',12, ...
                    'HorizontalAlignment','center', 'FontName','Courier New');
            end
        end
    end

    %% --- Stats panel updates -------------------------------------------
    % BPM
    if isnan(bpmValue)
        set(textBPM,'String','---','Color',C.warn);
    else
        [bpmLo, bpmHi] = ecg_resting_hr_range(patientAge);
        if bpmValue >= bpmLo && bpmValue <= bpmHi
            bpmColor = C.ok;
        elseif bpmValue > bpmHi
            bpmColor = C.bad;
        else
            bpmColor = C.warn;
        end
        set(textBPM,'String',sprintf('%.1f  BPM', bpmValue),'Color',bpmColor);
    end

    % RMSSD (short window — always shown)
    if isnan(shortRmssd)
        set(textHRV,'String','need more R-peaks','Color',C.warn);
    else
        set(textHRV,'String',sprintf('%.1f  ms', shortRmssd),'Color',C.ok);
    end

    % SDNN (60 s window — countdown then value)
    if elapsedSec < hrvWindowSec
        set(textSDNN,'String', ...
            sprintf('SDNN:  waiting  (%ds)', ceil(hrvWindowSec-elapsedSec)), ...
            'Color', C.warn);
    elseif isnan(hrvSdnn)
        set(textSDNN,'String','SDNN:  n/a','Color',C.dark);
    else
        set(textSDNN,'String',sprintf('SDNN:  %.1f ms', hrvSdnn),'Color',C.dark);
    end

    % Health status
    [healthText, healthColor] = ecg_health_status(patientAge, bpmValue, shortRmssd);
    set(textHealth,'String', wrap_status_text_local(healthText, 42), 'Color', healthColor);

    % Footer
    set(textET,'String',sprintf('ELAPSED:  %.1f s', elapsedSec));
    set(textN, 'String',sprintf('R-PEAKS:  %d', numel(rAbs)));

    % Status bar (trimmed string so it never reaches STOP button)
    set(textStatus,'String','STATUS: ACTIVE','Color',C.ok);

    drawnow;
end

if ishandle(fig)
    set(textStatus,'String','STATUS: STOPPED','Color',C.bad);
end
fprintf('\nDashboard stopped. Total samples: %d\n', sampleCounter);
if exist('cleanupObj','var'), clear cleanupObj; end

%% ========================= LOCAL FUNCTIONS =============================


function out = wrap_status_text_local(txt, maxChars)
    % Compact and wrap health status for the small clinical-summary area.
    % Keep this to two lines so it never collides with ELAPSED / R-PEAKS.
    if nargin < 2, maxChars = 52; end
    txt = char(txt);
    txt = regexprep(txt, '^Health status:\s*', '');
    txt = regexprep(txt, '\s+', ' ');

    % Shorten common phrases from ecg_health_status().
    txt = strrep(txt, 'BPM in expected resting range', 'BPM expected');
    txt = strrep(txt, 'BPM above expected resting range', 'BPM high');
    txt = strrep(txt, 'BPM below expected resting range', 'BPM low');
    txt = strrep(txt, 'age range ~', 'age ~');
    txt = strrep(txt, 'Educational only', 'Edu. only');

    % Put the RMSSD/HRV part on a separate line instead of letting MATLAB
    % draw one long line over the footer.
    txt = regexprep(txt, ';\s*(RMSSD)', sprintf('\n$1'));
    txt = regexprep(txt, ';\s*(HRV)', sprintf('\n$1'));

    parts = regexp(strtrim(txt), '\n', 'split');
    lines = {};
    for pp = 1:numel(parts)
        words = regexp(strtrim(parts{pp}), '\s+', 'split');
        if isempty(words) || (numel(words) == 1 && isempty(words{1}))
            continue;
        end
        line = '';
        for ww = 1:numel(words)
            if isempty(line)
                trial = words{ww};
            else
                trial = [line ' ' words{ww}]; 
            end
            if numel(trial) > maxChars && ~isempty(line)
                lines{end+1} = line; 
                line = words{ww};
            else
                line = trial;
            end
        end
        if ~isempty(line)
            lines{end+1} = line; 
        end
    end

    maxLines = 2;
    if numel(lines) > maxLines
        lines = lines(1:maxLines);
        if numel(lines{end}) > maxChars - 3
            lines{end} = [lines{end}(1:maxChars-3) '...'];
        else
            lines{end} = [lines{end} '...'];
        end
    end

    if isempty(lines)
        out = 'waiting...';
    else
        out = strjoin(lines, sprintf('\n'));
    end
end

function out = compact_label_local(txt, maxChars)
    if nargin < 2, maxChars = 58; end
    out = char(txt);
    out = regexprep(out, '\s+', ' ');
    if numel(out) > maxChars
        out = [out(1:maxChars-3) '...'];
    end
end

function out = compact_input_label_local(txt, maxChars)
    if nargin < 2, maxChars = 44; end
    txt = char(txt);
    parts = strsplit(txt, '|');
    if numel(parts) >= 2
        src = strtrim(parts{1});
        rec = strtrim(parts{end});
        [~, recBase, recExt] = fileparts(rec);
        if isempty(recBase)
            recLabel = rec;
        else
            recLabel = [recBase recExt];
        end
        out = [src ' | ' recLabel];
    else
        [~, recBase, recExt] = fileparts(strtrim(txt));
        if isempty(recBase)
            out = strtrim(txt);
        else
            out = [recBase recExt];
        end
    end
    out = regexprep(out, '\s+', ' ');
    if numel(out) > maxChars
        out = [out(1:maxChars-3) '...'];
    end
end

function scale = ecg_display_scale_local(x)
    x = double(x(:));
    x = x(isfinite(x));
    if isempty(x)
        scale = 1;
        return;
    end
    scale = prctile(abs(x), 99);
    if ~isfinite(scale) || scale < eps
        scale = max(abs(x));
    end
    if ~isfinite(scale) || scale < eps
        scale = 1;
    end
    scale = max(scale, 1);
end

function [s, mode, portUsed] = open_ecg_serial(portName, baudRate)
    portUsed = portName;
    if strcmpi(strtrim(portName), 'AUTO')
        ports = serialportlist("available");
        if isempty(ports), error('No available serial ports found.'); end
        portUsed = char(ports(end));
    end
    if exist('serialport','file') || exist('serialport','class')
        s = serialport(portUsed, baudRate, 'Timeout', 2);
        configureTerminator(s, "CR/LF"); flush(s); pause(0.5); mode = 'serialport';
    else
        s = serial(portUsed, 'BaudRate', baudRate, 'Terminator','LF', 'Timeout',2); %#ok<SERIAL>
        fopen(s); flushinput(s); mode = 'legacy';
    end
end

function line = read_ecg_line(s, mode)
    line = '';
    try
        if strcmp(mode,'serialport')
            if s.NumBytesAvailable > 0, line = char(readline(s)); else, pause(0.001); end
        else
            line = fgetl(s);
        end
    catch
    end
end

function close_ecg_serial(s, mode)
    try
        if strcmp(mode,'legacy'), fclose(s); delete(s); else, flush(s); end
    catch
    end
end

function val = parse_ecg_value(line, valueMode)
    val = NaN;
    if isempty(line), return; end
    line = strtrim(char(line)); if isempty(line), return; end
    upperLine = upper(line);
    if contains(upperLine,'LO') || contains(upperLine,'LEAD'), return; end
    nums = regexp(line, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
    if isempty(nums), return; end
    vals = str2double(nums); vals = vals(isfinite(vals)); if isempty(vals), return; end
    if strcmpi(valueMode,'first'), val = vals(1); else, val = vals(end); end
    if abs(val) > 1e7, val = NaN; end
end

function polarity = estimate_r_polarity(x, Fs)
    minDist = round(0.40*Fs);
    try
        [~, posLoc] = findpeaks(x,  'MinPeakDistance', minDist);
        [~, negLoc] = findpeaks(-x, 'MinPeakDistance', minDist);
    catch
        posLoc = []; negLoc = [];
    end
    posScore = 0; negScore = 0;
    if ~isempty(posLoc)
        posVals = sort(x(posLoc),'descend');
        posScore = mean(posVals(1:min(5,numel(posVals))));
    end
    if ~isempty(negLoc)
        negVals = sort(-x(negLoc),'descend');
        negScore = mean(negVals(1:min(5,numel(negVals))));
    end
    polarity = 1; if negScore > posScore, polarity = -1; end
end

function bpm = compute_bpm_from_rpeaks_local(rAbs, Fs)
    bpm = NaN; if numel(rAbs) < 2, return; end
    rr = diff(rAbs)/Fs; rr = rr(rr >= 0.35 & rr <= 1.60);
    if isempty(rr), return; end
    medRR = median(rr); rr = rr(abs(rr-medRR) <= 0.25*medRR);
    if isempty(rr), return; end
    bpm = 60/median(rr);
end

function yl = nice_ylim_local(y, fallback)
    if isempty(y) || all(~isfinite(y)), yl = fallback; return; end
    y = y(isfinite(y)); lo = prctile(y,1); hi = prctile(y,99.5);
    if ~isfinite(lo) || ~isfinite(hi) || hi <= lo, yl = fallback; return; end
    pad = 0.18*max(hi-lo,1); yl = [lo-pad hi+pad];
    if yl(2)-yl(1) < 2, mid = mean(yl); yl = [mid-1 mid+1]; end
end

function [ptLoc, ptAmp, ptLabel] = locate_pqrst_local(cycleSig, rIndex, Fs)
    n  = numel(cycleSig);
    pA = max(1,rIndex-round(0.22*Fs)); pB = max(1,rIndex-round(0.08*Fs));
    qA = max(1,rIndex-round(0.06*Fs)); qB = max(1,rIndex-round(0.005*Fs));
    sA = min(n,rIndex+round(0.005*Fs)); sB = min(n,rIndex+round(0.08*Fs));
    tA = min(n,rIndex+round(0.10*Fs)); tB = min(n,rIndex+round(0.35*Fs));
    if pB < pA, pA=max(1,rIndex-5);  pB=max(1,rIndex-1);  end
    if qB < qA, qA=max(1,rIndex-3);  qB=max(1,rIndex-1);  end
    if sB < sA, sA=min(n,rIndex+1);  sB=min(n,rIndex+3);  end
    if tB < tA, tA=min(n,rIndex+1);  tB=min(n,rIndex+5);  end
    [~,pRel] = max(cycleSig(pA:pB)); P = pA+pRel-1;
    [~,qRel] = min(cycleSig(qA:qB)); Q = qA+qRel-1;
    R = rIndex;
    [~,sRel] = min(cycleSig(sA:sB)); S = sA+sRel-1;
    [~,tRel] = max(cycleSig(tA:tB)); T = tA+tRel-1;
    ptLoc   = [P Q R S T];
    ptAmp   = cycleSig(ptLoc);
    ptLabel = {'P','Q','R','S','T'};
end

function delete_valid_handles_local(h)
    for ii = 1:numel(h)
        if ishandle(h(ii)), delete(h(ii)); end
    end
end

function plot_ecg_fft_annotated(x, Fs, maxFreq, plotTitle, mainsHz)
    feat = ecg_fft_features(x, Fs, mainsHz);
    f = feat.f; mag = feat.mag; keep = f <= maxFreq;
    figure('Name', plotTitle, 'Color','w', 'Position',[120 100 1100 700]);
    subplot(2,1,1);
    t = (0:numel(x)-1)/Fs; plot(t,x,'LineWidth',1.2); grid on;
    xlabel('Time (s)'); ylabel('Normalized amplitude');
    title('ECG window used for FFT');
    subplot(2,1,2);
    plot(f(keep), mag(keep), 'LineWidth',1.4); grid on; hold on;
    xlabel('Frequency (Hz)'); ylabel('Magnitude');
    title('Annotated single-sided FFT magnitude spectrum'); xlim([0 maxFreq]);
    xline(0.5,  '--','Baseline <0.5 Hz',   'LabelVerticalAlignment','bottom');
    xline(10,   '--','P/T ~0.5-10 Hz',     'LabelVerticalAlignment','bottom');
    xline(40,   '--','QRS ~1-40 Hz',        'LabelVerticalAlignment','bottom');
    xline(mainsHz,':',sprintf('%d Hz mains',mainsHz),'LabelVerticalAlignment','bottom');
    if isfinite(feat.hrPeakHz)
        plot(feat.hrPeakHz, feat.hrPeakMag, 'rv', 'MarkerFaceColor','r');
        text(feat.hrPeakHz, feat.hrPeakMag, ...
            sprintf(' HR %.2f Hz = %.1f BPM', feat.hrPeakHz, feat.hrBpm));
    end
    if isfinite(feat.qrsPeakHz)
        plot(feat.qrsPeakHz, feat.qrsPeakMag, 'ko', 'MarkerFaceColor','y');
    end
    sgtitle(sprintf('%s | HR peak %.2f Hz = %.1f BPM', plotTitle, feat.hrPeakHz, feat.hrBpm), ...
        'Interpreter','none');
end
