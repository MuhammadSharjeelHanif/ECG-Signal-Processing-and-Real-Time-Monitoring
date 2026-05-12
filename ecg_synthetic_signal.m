function [x, Fs, meta] = ecg_synthetic_signal(durationSec, Fs, bpm)
%ECG_SYNTHETIC_SIGNAL Simple synthetic ECG-like signal for testing if no data file is available.
if nargin < 1, durationSec = 30; end
if nargin < 2, Fs = 250; end
if nargin < 3, bpm = 75; end

t = (0:1/Fs:durationSec-1/Fs)';
rr = 60/bpm;
x = zeros(size(t));
rTimes = 0.6:rr:durationSec-0.5;
for r = rTimes
    x = x + 0.12*exp(-0.5*((t-(r-0.18))/0.035).^2);   % P
    x = x - 0.20*exp(-0.5*((t-(r-0.035))/0.012).^2);  % Q
    x = x + 1.20*exp(-0.5*((t-r)/0.015).^2);          % R
    x = x - 0.35*exp(-0.5*((t-(r+0.035))/0.014).^2);  % S
    x = x + 0.35*exp(-0.5*((t-(r+0.24))/0.070).^2);   % T
end
x = x + 0.06*sin(2*pi*0.25*t) + 0.02*randn(size(t));
meta = struct('source','Synthetic ECG-like demo signal','recordID','synthetic', ...
    'durationSec',durationSec,'patientAge',NaN,'patientGender','N/A', ...
    'classification','Demo only');
end
