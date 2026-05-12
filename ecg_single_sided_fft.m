function [f, mag, powerSpec] = ecg_single_sided_fft(x, Fs, useHann)
%ECG_SINGLE_SIDED_FFT Single-sided amplitude and power spectrum.
if nargin < 3, useHann = true; end
x = double(x(:));
x = x - mean(x,'omitnan');
x(~isfinite(x)) = 0;
N = numel(x);
if N < 2
    f = []; mag = []; powerSpec = []; return;
end
if useHann
    w = 0.5 - 0.5*cos(2*pi*(0:N-1)'/(N-1));
else
    w = ones(N,1);
end
xw = x .* w;
Y = fft(xw);
P2 = abs(Y)/sum(w);
P1 = P2(1:floor(N/2)+1);
if numel(P1) > 2
    P1(2:end-1) = 2*P1(2:end-1);
end
f = Fs*(0:floor(N/2))/N;
mag = P1(:);
powerSpec = mag.^2;
end
