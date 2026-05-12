function [clean, stages] = ecg_apply_classical_filters(raw, Fs, F)
%ECG_APPLY_CLASSICAL_FILTERS Baseline removal + HP + notch + LP + normalize.
raw = double(raw(:));
stages = struct();
stages.raw = raw;

baseWin = max(5, round(0.8*Fs));
if mod(baseWin,2)==0, baseWin = baseWin + 1; end
try
    baseline = movmedian(raw, baseWin);
catch
    baseline = movmean(raw, baseWin);
end
x = raw - baseline;
stages.baselineRemoved = x;

x = filtfilt(F.bHP, F.aHP, x);
stages.highpass = x;

x = filtfilt(F.bNotch, F.aNotch, x);
stages.notch = x;

x = filtfilt(F.bLP, F.aLP, x);
stages.lowpass = x;

x = movmean(x, 5);
x = x - median(x);
scale = prctile(abs(x), 95);
if ~isfinite(scale) || scale < eps
    scale = max(abs(x));
end
if ~isfinite(scale) || scale < eps
    scale = 1;
end
clean = x ./ scale;
stages.normalized = clean;
end
