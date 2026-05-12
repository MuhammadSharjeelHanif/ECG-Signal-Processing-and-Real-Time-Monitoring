function [rLocs, rAmps] = ecg_detect_rpeaks(ecg, Fs)
%ECG_DETECT_RPEAKS Detect R peaks using adaptive thresholding.
x = double(ecg(:));
if numel(x) < round(2*Fs)
    rLocs = []; rAmps = []; return;
end

recentN = min(numel(x), round(10*Fs));
xr = x(end-recentN+1:end);
medx = median(xr);
p25 = prctile(xr,25); p75 = prctile(xr,75); p90 = prctile(xr,90);
iqrVal = max(p75-p25, 0.05);
minPeakHeight = max(medx + 1.25*iqrVal, p90);
minPeakDistance = round(0.35*Fs);
minProm = max(0.35, 0.55*iqrVal);

try
    [pks, locs] = findpeaks(x, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance, 'MinPeakProminence', minProm);
catch
    [pks, locs] = findpeaks(x, 'MinPeakHeight', minPeakHeight, ...
        'MinPeakDistance', minPeakDistance);
end

edge = round(0.20*Fs);
keep = locs > edge & locs < (numel(x)-edge);
locs = locs(keep); pks = pks(keep);

if numel(locs) >= 3
    rr = diff(locs)/Fs;
    validPair = rr >= 0.35 & rr <= 1.60;
    keepLoc = [true; validPair(:)];
    locs = locs(keepLoc); pks = pks(keepLoc);
end

rLocs = locs(:);
rAmps = pks(:);
end
