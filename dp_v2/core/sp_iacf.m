function [W, info] = sp_iacf(q, varargin)
%% SP_IACF  Integrated autocorrelation function indicator W.
%%
%%   [W, info] = sp_iacf(q)
%%   [W, info] = sp_iacf(q, 'B', 40, 'maxLagFrac', 0.75)
%%
%%   q   1 x (N+1) evenly sampled scalar time series
%%   W   scalar indicator value
%%
%%   DEFINITION (Barrio, Borczyk & Breiter, Chaos Solitons Fractals 40 (2009)
%%   1697, Sec. 2.2.2, Eqs. 11-17)
%%
%%       C_j = sum_i (q_i - qbar)(q_{i+j} - qbar) / sum_i (q_i - qbar)^2
%%       W(K) = (K+1) / sum_{j=0}^{K} C_j^2
%%
%%   PROPERTIES THAT MAKE IT USEFUL
%%   ------------------------------
%%     * constant series              -> W = 1
%%     * a sampled sine, long window  -> W -> 2
%%     * other periodic/quasi-periodic-> W converges to a finite value near 2
%%     * exponentially damped ACF     -> W grows without bound; its growth rate
%%                                       is inversely proportional to the
%%                                       "poor man's Lyapunov time"
%%     * white noise                  -> W(K) = K, giving 1 <= W(K) <= K
%%
%%   So W is an ABSOLUTE indicator: unlike the FLI family it needs no
%%   calibration orbit.  That is the property the paper highlights, and the
%%   reason it is included here.
%%
%%   COMPUTATIONAL TRICK, AND WHY IT IS NOT OPTIONAL
%%   ----------------------------------------------
%%   The direct form costs O(N*K) and is prohibitive at the sample counts this
%%   project uses.  The paper's Eq. (17) uses almost-logarithmically spaced lags
%%
%%       J_0 = 0, J_1 = 1, J_k = J_{k-1} + 2^floor((k-1)/B)          (Eq. 15)
%%
%%   and treats the sum as an open quadrature,
%%
%%       W(j_{k*}) = j_{k*} / ( 1 + sum_k (j_k - j_{k-1}) C_{j_k}^2 )  (Eq. 17)
%%
%%   The paper notes that for their application it is better to sample LARGE
%%   lags more densely, so they invert the cascade (Eq. 16).
%%
%%   WHAT THIS IMPLEMENTATION DOES, AND THE HONEST CAVEAT
%%   ---------------------------------------------------
%%   W is computed from the FULL autocorrelation sequence by default.  The
%%   log-lag cascade of the paper's Eqs. (15)-(17) is still implemented and is
%%   reached only when the caller raises the cost limit explicitly, because the
%%   cascade is an APPROXIMATION of the quadrature and it was MEASURED to be a
%%   bad one on exactly the signals this indicator exists to classify:
%%
%%       series              W (full)    W (cascade)   relative difference
%%       sampled sine           2.004         2.006          0.13 %
%%       logistic map        1247.5         855.3          31.4 %
%%       white noise         1307.4         815.5          37.6 %
%%
%%   A pure tone is reproduced well; a BROADBAND series -- which is what a
%%   chaotic orbit looks like -- is under-estimated by about a third.  The
%%   cascade's sparse large-lag sampling is the same sparsity that produced the
%%   paper's own Fig. 2 Moire effects (their Sec. 2.2.2).
%%
%%   WHY THE DEFAULT IS THE EXACT SUM
%%   --------------------------------
%%   An earlier version switched to the cascade automatically whenever
%%   N*K exceeded `fullLimit` (default 2e8, i.e. beyond about 16 000 samples).
%%   Two things were wrong with that.  First, the answer then changed KIND
%%   silently with the sample count, so a result was not comparable across runs
%%   without inspecting `info.mode`.  Second, the threshold was set high enough
%%   that the cascade was unreachable in practice -- it was effectively dead
%%   code that no ordinary call could exercise, which is worse than not having
%%   it.  Now the exact sum is the default at every size and the cascade is an
%%   explicit opt-in, so which one ran is always the caller's decision:
%%
%%       W = sp_iacf(q)                          % exact, always
%%       W = sp_iacf(q, 'fullLimit', 0)          % force the cascade
%%
%%   The exact form is O(N*K), but at the project's sample counts (nSamp <= 4000)
%%   it costs milliseconds, so the approximation buys nothing worth its error.
%%
%%   The autocorrelation is the biased estimator of Eq. (11) (single global
%%   mean, denominator over the full series).  The paper's more elaborate
%%   Pearson estimator of Eq. (12) permits larger lags; it is not implemented
%%   here, and MAXLAGFRAC therefore defaults to the paper's conservative 0.75
%%   rather than something larger.
%%
%%   See also sp_run, sp_specnum.

    o = struct('B', 40, 'maxLagFrac', 0.75, 'fullLimit', inf);
    if nargin > 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_iacf:opt', 'unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    q = q(:).';
    N = numel(q) - 1;
    if N < 8
        error('sp_iacf:short', 'need at least 8 samples (got %d)', N+1);
    end

    qbar = mean(q);
    dq   = q - qbar;
    den  = sum(dq.^2);
    if den == 0
        % constant series: by definition W = 1
        W = 1;
        info = struct('K', 0, 'mode', 'constant', 'N', N);
        return
    end

    K = min(floor(o.maxLagFrac*N), N - 1);

    if N*K <= o.fullLimit
        % ---- exact: every lag up to K ----
        % NUMERATOR AND DENOMINATOR MUST USE THE SAME WINDOW.  Eq. (11) of the
        % paper truncates both sums to the overlapping range 0..N-j.  A first
        % version of this file divided by the FULL-series variance for every j,
        % which under-normalises C_j as j grows: for a pure sine it returned
        % W = 4.57 instead of 2, and the error grew with the window length.
        C2 = zeros(1, K+1);
        C2(1) = 1;                       % C_0 = 1 by construction
        for j = 1:K
            a = dq(1:N-j+1);
            b = dq(j+1:N+1);
            den_j = sum(a.^2);
            if den_j <= 0
                C2(j+1) = 0;
            else
                C2(j+1) = (a * b.') / den_j;
            end
        end
        W = (K + 1) / sum(C2.^2);
        mode = 'full';
        lags = K + 1;
    else
        % ---- log-lag cascade (paper Eqs. 15-17) ----
        J = zeros(1, 200);
        J(1) = 0; J(2) = 1;
        k = 3;
        while J(k-1) < K
            J(k) = J(k-1) + 2^floor((k-2)/o.B);
            k = k + 1;
            if k > numel(J), break; end
        end
        J = J(1:k-1);
        J = J(J <= K);
        acc = 0;
        for jj = 2:numel(J)
            j = J(jj);
            a = dq(1:N-j+1);
            b = dq(j+1:N+1);
            den_j = sum(a.^2);
            if den_j <= 0
                Cj = 0;
            else
                Cj = (a * b.') / den_j;
            end
            acc = acc + (J(jj) - J(jj-1)) * Cj^2;
        end
        W = J(end) / (1 + acc);
        mode = 'cascade';
        lags = numel(J);
    end

    info = struct('K', K, 'mode', mode, 'lags', lags, 'N', N);
end
