function F = ecg_design_filters(Fs, mainsHz, hpCut, lpCut, notchQ)
%ECG_DESIGN_FILTERS Design classical ECG filters.
if nargin < 2 || isempty(mainsHz), mainsHz = 50; end
if nargin < 3 || isempty(hpCut), hpCut = 0.5; end
if nargin < 4 || isempty(lpCut), lpCut = 40; end
if nargin < 5 || isempty(notchQ), notchQ = 35; end

F.Fs = Fs;
F.mainsHz = mainsHz;
F.hpCut = hpCut;
F.lpCut = lpCut;
F.notchQ = notchQ;

[F.bHP, F.aHP] = butter(2, hpCut/(Fs/2), 'high');
[F.bLP, F.aLP] = butter(2, lpCut/(Fs/2), 'low');
[F.bNotch, F.aNotch] = local_notch_coeffs(mainsHz, Fs, notchQ);

% Optional FIR versions for Task 2 Stream A comparison.
firOrderHP = max(100, 2*round(3*Fs));
if mod(firOrderHP,2)==1, firOrderHP = firOrderHP + 1; end
firOrderLP = max(80, 2*round(Fs/2));
if mod(firOrderLP,2)==1, firOrderLP = firOrderLP + 1; end
F.bFIR_HP = fir1(firOrderHP, hpCut/(Fs/2), 'high', hamming(firOrderHP+1));
F.aFIR_HP = 1;
F.bFIR_LP = fir1(firOrderLP, lpCut/(Fs/2), 'low', hamming(firOrderLP+1));
F.aFIR_LP = 1;
end

function [b, a] = local_notch_coeffs(f0, Fs, Q)
w0 = 2*pi*f0/Fs;
alpha = sin(w0)/(2*Q);
b0 = 1; b1 = -2*cos(w0); b2 = 1;
a0 = 1 + alpha; a1 = -2*cos(w0); a2 = 1 - alpha;
b = [b0 b1 b2] / a0;
a = [1 a1/a0 a2/a0];
end
