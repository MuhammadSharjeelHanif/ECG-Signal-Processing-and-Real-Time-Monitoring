function feat = ecg_fft_features(x, Fs, mainsHz)
%ECG_FFT_FEATURES Extract frequency-domain ECG features and HR estimate.
if nargin < 3, mainsHz = 50; end
[f, mag, pwr] = ecg_single_sided_fft(x, Fs, true);
feat = struct(); feat.f = f; feat.mag = mag; feat.power = pwr;

% Heart-rate fundamental band: 0.7-2.5 Hz = 42-150 BPM.
maskHR = f >= 0.7 & f <= 2.5;
[feat.hrPeakMag, idxHR] = max(mag(maskHR));
fh = f(maskHR);
if isempty(fh)
    feat.hrPeakHz = NaN; feat.hrBpm = NaN;
else
    feat.hrPeakHz = fh(idxHR);
    feat.hrBpm = 60*feat.hrPeakHz;
end

% Use non-overlapping display bands so the heart-rate fundamental is not
% also reported as the P/T or QRS peak.
maskPT = f >= 0.5 & f <= 10 & ~maskHR;
[feat.ptPeakMag, idxPT] = max(mag(maskPT)); fpt = f(maskPT);
if isempty(fpt), feat.ptPeakHz = NaN; else, feat.ptPeakHz = fpt(idxPT); end

maskQRS = f >= 10 & f <= 40;
[feat.qrsPeakMag, idxQRS] = max(mag(maskQRS)); fqrs = f(maskQRS);
if isempty(fqrs), feat.qrsPeakHz = NaN; else, feat.qrsPeakHz = fqrs(idxQRS); end

maskBW = f > 0 & f < 0.5;
feat.baselinePower = sum(pwr(maskBW));
maskSig = f >= 0.5 & f <= 40;
feat.signalPower = sum(pwr(maskSig));
maskNoise = (f > 40 & f <= min(Fs/2,120)) | maskBW;
feat.noisePower = sum(pwr(maskNoise));
feat.snrDb = 10*log10(feat.signalPower / max(feat.noisePower, eps));

maskMains = f >= mainsHz-1 & f <= mainsHz+1;
[feat.mainsMag, idxM] = max(mag(maskMains)); fm = f(maskMains);
if isempty(fm), feat.mainsHz = NaN; else, feat.mainsHz = fm(idxM); end
end
