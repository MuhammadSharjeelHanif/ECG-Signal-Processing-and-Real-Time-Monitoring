function [statusText, statusColor] = ecg_health_status(ageYears, bpm, rmssd)
%ECG_HEALTH_STATUS Educational heart-rate/HRV status for dashboard display.
% This is NOT a medical diagnosis. It only compares BPM with broad resting
% ranges by age and flags low HRV when RMSSD is low.

if nargin < 3, rmssd = NaN; end
if isempty(ageYears) || ~isfinite(ageYears), ageYears = 25; end

[lo, hi, ageGroup] = ecg_resting_hr_range(ageYears);

if ~isfinite(bpm)
    statusText = sprintf('Health status: waiting for BPM | %s expected ~%d-%d BPM', ...
        ageGroup, lo, hi);
    statusColor = [0.86 0.48 0.05];
    return;
end

if bpm < lo
    hrText = sprintf('Low for %s (%.0f BPM; expected ~%d-%d)', ageGroup, bpm, lo, hi);
    statusColor = [0.86 0.48 0.05];
elseif bpm > hi
    hrText = sprintf('High for %s (%.0f BPM; expected ~%d-%d)', ageGroup, bpm, lo, hi);
    statusColor = [0.85 0.18 0.18];
else
    hrText = sprintf('Normal for %s (%.0f BPM; expected ~%d-%d)', ageGroup, bpm, lo, hi);
    statusColor = [0.10 0.55 0.32];
end

% Very simple HRV educational flag for adults/older teens. Children vary more.
if isfinite(rmssd) && ageYears >= 18
    if rmssd < 20
        hrvText = 'RMSSD low';
        if bpm >= lo && bpm <= hi
            statusColor = [0.86 0.48 0.05];
        end
    elseif rmssd < 30
        hrvText = 'RMSSD borderline';
    else
        hrvText = 'RMSSD acceptable';
    end
    statusText = sprintf('Health status: %s; %s | Educational only', hrText, hrvText);
else
    statusText = sprintf('Health status: %s | Educational only', hrText);
end
end
