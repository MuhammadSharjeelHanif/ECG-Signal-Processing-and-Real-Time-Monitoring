function [x, Fs, meta] = ecg_load_signal_interactive(defaultFs, defaultDurationSec)
%ECG_LOAD_SIGNAL_INTERACTIVE Load ECG from PhysioNet WFDB, CSV, MAT, or synthetic demo.
if nargin < 1, defaultFs = 250; end
if nargin < 2, defaultDurationSec = 30; end
choice = menu('Dataset input source', ...
    'MIT-BIH record 100 using WFDB toolbox', ...
    'Load local CSV file', ...
    'Load local MAT file', ...
    'Use synthetic demo ECG');

switch choice
    case 1
        recordName = 'mitdb/100';
        durationSec = defaultDurationSec;
        if exist('rdsamp','file') ~= 2
            error(['WFDB Toolbox function rdsamp was not found. Install WFDB Toolbox ' ...
                   'or choose local CSV/MAT/synthetic.']);
        end
        try
            [sig, Fs, ~] = rdsamp(recordName, [], round(durationSec*360), 1);
        catch
            try
                [sig, Fs, ~] = rdsamp(recordName, [], round(durationSec*360));
            catch
                [sig, Fs, ~] = rdsamp(recordName);
                sig = sig(1:min(end, round(durationSec*Fs)), :);
            end
        end
        x = sig(:,1);
        meta = struct('source','MIT-BIH Arrhythmia Database', 'recordID','100', ...
            'durationSec', numel(x)/Fs, 'patientAge',69, 'patientGender','Male', ...
            'classification','Abnormal conduction noted; normal sinus rhythm episodes', ...
            'url','https://physionet.org/content/mitdb/1.0.0/');
    case 2
        [file, path] = uigetfile({'*.csv;*.txt','CSV/TXT files'}, 'Select ECG CSV file');
        if isequal(file,0), error('No CSV selected.'); end
        T = readmatrix(fullfile(path,file));
        if size(T,2) >= 2
            maybeTime = T(:,1);
            x = T(:,2);
            dt = median(diff(maybeTime),'omitnan');
            if isfinite(dt) && dt > 0 && dt < 10
                Fs = 1/dt;
            else
                Fs = defaultFs;
            end
        else
            x = T(:,1); Fs = defaultFs;
        end
        meta = struct('source','Local CSV', 'recordID',file, 'durationSec',numel(x)/Fs, ...
            'patientAge',NaN,'patientGender','User entered','classification','User file');
    case 3
        [file, path] = uigetfile({'*.mat','MAT files'}, 'Select MAT file containing ECG vector');
        if isequal(file,0), error('No MAT selected.'); end
        S = load(fullfile(path,file));
        names = fieldnames(S);
        x = [];
        for k = 1:numel(names)
            v = S.(names{k});
            if isnumeric(v) && isvector(v) && numel(v) > 100
                x = v(:); break;
            end
        end
        if isempty(x), error('No numeric ECG vector found in MAT file.'); end
        if isfield(S,'Fs'), Fs = S.Fs; else, Fs = defaultFs; end
        meta = struct('source','Local MAT', 'recordID',file, 'durationSec',numel(x)/Fs, ...
            'patientAge',NaN,'patientGender','User entered','classification','User file');
    otherwise
        [x, Fs, meta] = ecg_synthetic_signal(defaultDurationSec, defaultFs, 75);
end
x = double(x(:));
x = x(isfinite(x));
end
