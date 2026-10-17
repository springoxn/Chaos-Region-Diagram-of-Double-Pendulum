function [SN, info] = sp_specnum(q, varargin)
%% SP_SPECNUM  Spectral number of a scalar time series.
%%
%%   [SN, info] = sp_specnum(q)
%%   [SN, info] = sp_specnum(q, 'cutoff', 0.1)
%%
%%   q   1 x M evenly sampled scalar time series
%%   SN  number of peaks in the power spectrum above the cut-off
%%
%%   DEFINITION (Barrio, Borczyk & Breiter 2009, Sec. 2.2.1)
%%
%%   The power spectrum is computed with an FFT and the peaks are COUNTED.
%%   The paper distinguishes two variants and shows they behave very
%%   differently:
%%
%%       SSN  "simplistic spectral number": counts EVERY amplitude above the
%%            cut-off.  Because of spectral leakage a single broad line is
%%            counted many times, and the resulting map is dominated by
%%            spurious Moire fringes (their Fig. 1a).
%%       SN   counts only LOCAL PEAKS: A_i with A_{i-1} < A_i > A_{i+1}.
%%            Their Fig. 1b shows the Moire disappears under this rule.
%%
%%   Only the local-peak variant (SN) is implemented here.  Implementing SSN
%%   as well would add a quantity this project has no use for: the paper's own
%%   conclusion is that SSN is a diagnostic of the spectral-leakage artefact,
%%   not of the dynamics.
%%
%%   WHY SN IS INCLUDED EVEN THOUGH IT IS NOT A CHAOS TEST
%%   ----------------------------------------------------
%%   SN is a SPECTRAL indicator: like the IACF it looks at one orbit's time
%%   series and never touches the variational equations.  The paper's central
%%   recommendation is to confront a variational indicator with a spectral one,
%%   because that is what exposes an unstable periodic orbit being mistaken for
%%   a chaotic one.  SN is the cheapest such confrontation available, so it is
%%   kept for that role -- not as a primary chaos measure.
%%
%%   ITS UNDESIRABLE PROPERTY, STATED PLAINLY
%%   ----------------------------------------
%%   SN is a RELATIVE indicator and is sensitive to the sampling: the paper
%%   shows that even the same orbit yields different leakage depending on where
%%   sampling starts, and that low-frequency resolution bounds how many peaks
%%   can be resolved at all.  Interpret SN comparatively (regular vs chaotic
%%   regions of the same run, same settings), never as an absolute number.
%%
%%   See also sp_iacf, sp_run.

    o = struct('cutoff', 0.1, 'removeMean', true);
    if nargin > 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_specnum:opt', 'unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    q = q(:).';
    M = numel(q);
    if M < 16
        error('sp_specnum:short', 'need at least 16 samples (got %d)', M);
    end
    if o.removeMean
        q = q - mean(q);
    end

    A = abs(fft(q));
    A = A(1:floor(M/2)+1);          % one-sided
    if numel(A) < 3
        SN = 0; info = struct('cutoff', o.cutoff, 'nPeaks', 0); return
    end

    thr = o.cutoff * max(A);
    isPeak = false(size(A));
    for i = 2:numel(A)-1
        if A(i) > A(i-1) && A(i) > A(i+1) && A(i) >= thr
            isPeak(i) = true;
        end
    end
    if A(1) >= thr, isPeak(1) = true; end
    if A(end) >= thr, isPeak(end) = true; end

    SN = sum(isPeak);
    info = struct('cutoff', o.cutoff, 'nPeaks', SN, 'nFreq', numel(A));
end
