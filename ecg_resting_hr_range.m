function [lo, hi, ageGroup] = ecg_resting_hr_range(ageYears)
%ECG_RESTING_HR_RANGE Broad educational resting BPM ranges by age.
% These are dashboard guidance ranges, not a medical diagnosis.
if nargin < 1 || isempty(ageYears) || ~isfinite(ageYears)
    ageYears = 25;
end

if ageYears < 1/12
    lo = 100; hi = 180; ageGroup = 'newborn';
elseif ageYears < 1
    lo = 100; hi = 160; ageGroup = 'infant';
elseif ageYears < 3
    lo = 90; hi = 150; ageGroup = 'toddler';
elseif ageYears < 6
    lo = 80; hi = 140; ageGroup = 'preschool child';
elseif ageYears < 13
    lo = 70; hi = 120; ageGroup = 'school-age child';
elseif ageYears < 18
    lo = 60; hi = 100; ageGroup = 'teen';
else
    lo = 60; hi = 100; ageGroup = 'adult';
end
end
