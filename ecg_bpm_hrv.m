function [bpm, rmssd, sdnn, rrMs] = ecg_bpm_hrv(rLocs, Fs)
%ECG_BPM_HRV Compute BPM, RMSSD, SDNN from R-peak sample locations.
bpm = NaN; rmssd = NaN; sdnn = NaN; rrMs = [];
if numel(rLocs) < 2, return; end
rr = diff(rLocs(:))/Fs;
rr = rr(rr >= 0.35 & rr <= 1.60);
if isempty(rr), return; end
medRR = median(rr);
rr = rr(abs(rr-medRR) <= 0.25*medRR);
if isempty(rr), return; end
bpm = 60/median(rr);
rrMs = rr*1000;
if numel(rrMs) >= 3
    rmssd = sqrt(mean(diff(rrMs).^2));
    sdnn = std(rrMs);
end
end
