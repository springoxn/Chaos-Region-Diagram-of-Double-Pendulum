function R = sp_run(sys, Y0, opts)
%% SP_RUN  One symplectic integration of a row of initial conditions,
%%         accumulating the whole variational chaos-indicator family.
%%
%%   R = sp_run(sys, Y0)
%%   R = sp_run(sys, Y0, opts)
%%
%%   sys  struct from sp_sys  (separable Hamiltonian, explicit symplectic)
%%   Y0   ndof x N initial conditions, [q ; p]
%%   opts fields
%%     order      4        Yoshida composition order, 2 | 4 | 6
%%     T          100      total integration time
%%     dt         0.01     step
%%     transient  0.3      fraction discarded before averaging the exponent
%%     nGali      2        number of deviation vectors to track (1..ndof)
%%     sample     []       sample the time series every `sample` steps for the
%%                         spectral indicators ([] disables)
%%     nSamp      4000     target number of samples when sample is []
%%     spectral   false    also compute the IACF (W) and spectral number (SN)
%%                         per initial condition, from the sampled series
%%     progress   false
%%
%%   R fields (each 1 x N unless noted)
%%     lambda      largest Lyapunov exponent, from the growth of vector 1
%%     mega        the MEGNO running average Ybar at the final time
%%     fli         log of the largest growth accumulated (sup over the run)
%%     gali        GALI_k at the final time, k = nGali
%%     sali        SALI at the final time (only when nGali >= 2)
%%     galiSeries  nTimes x N, GALI_k sampled through the run ([])
%%     tSeries     1 x nTimes sample times ([])
%%     iacf        W from the IACF, per point ([])
%%     specnum     SN per point ([])
%%     nSteps, dt, T, order, sys name
%%
%%   WHY ONE DRIVER
%%   --------------
%%   All the first-order variational indicators are different functionals of the
%%   SAME deviation vectors, so computing them together costs one integration
%%   instead of one per indicator.  This matters because the integration, not
%%   the post-processing, is the whole cost (see fp_map.m for the same argument
%%   on the forced pendulum).
%%
%%   THE INDICATORS, AND WHAT EACH IS FOR
%%   ------------------------------------
%%     lambda   the reference quantity.  Positive and sizeable => chaos.  It is
%%              SLOW to converge: a finite-time estimate scatters like
%%              1/sqrt(lambda*T), so it is not reliable on short runs, which is
%%              precisely the regime where the others are meant to help.
%%     mega     Mean Exponential Growth factor of Nearby Orbits (Cincotta &
%%              Simo).  An ABSOLUTE indicator: it tends to 2 for regular motion
%%              and grows linearly for chaotic motion, so no calibration orbit
%%              is needed.  It is the indicator the reference paper singles out
%%              as the best of the variational methods.  Its known failure mode
%%              is documented in the paper (Sec. 4.2) and reproduced in
%%              test_paper_figures.m: a first-order indicator can show spurious
%%              "hyperstable" bands that depend only on the initial deviation
%%              direction.  mega here is accumulated with the recurrence of
%%              Eqs. (6)-(7) of the paper,
%%                  Y_n    = Y_{n-1} + 2 ln(||n_n|| / ||n_{n-1}||)
%%                  Ybar_n = ((n-1) Ybar_{n-1} + Y_n) / n
%%              and the growth per step is exactly the log of the norm that
%%              sp_step.m divides out, so no extra bookkeeping is needed.
%%     fli      Fast Lyapunov Indicator: the running supremum of ln||n||.
%%              Exponential growth above the regular baseline signals chaos.
%%              A RELATIVE indicator -- it needs a known-regular calibration
%%              point in the same run, which the paper stresses.
%%     gali     Generalized Alignment Index, ||v1 ^ ... ^ vk||.  Uses only
%%              SECOND-order information in the sense of the paper's Sec. 4.2.1:
%%              it does not depend on the flow-tangent component, so it is free
%%              of the spurious-direction artefact that affects FLI and MEGNO.
%%              Decays exponentially to zero for chaos, oscillates for regular
%%              motion.  THIS IS THE INDICATOR THAT REPLACES log(1+var).
%%     sali     Smallest Alignment Index, equivalent to GALI_2 (see sp_sali.m).
%%              Reported because the literature quotes it directly.
%%     iacf     the paper's integrated-autocorrelation indicator W, computed
%%              from a sampled time series.  A SPECTRAL indicator, so it is the
%%              independent cross-check the paper recommends: confronting one
%%              variational and one spectral indicator is what prevents an
%%              unstable regular orbit being read as chaotic.
%%
%%   NOT INCLUDED HERE: OFLI2, which needs second-order variational equations
%%   and therefore second derivatives of the field.  It is implemented
%%   separately in sp_ofli2.m for the separable systems, where those
%%   derivatives are available in closed form.  It is NOT provided for the
%%   double pendulum: that would need third derivatives of the potential
%%   through the mass matrix, and the double pendulum is 4-dimensional, so GALI
%%   already does the job there without them.
%%
%%   See also sp_step, sp_sys, sp_megno_formula, sp_gali, sp_sali, sp_iacf.

    if nargin < 3, opts = struct(); end
    o = run_defaults(opts);

    ndof = sys.ndof;
    N    = size(Y0, 2);
    nq   = sys.nq;

    if size(Y0,1) ~= ndof
        error('sp_run:size', 'Y0 must be %d x N (got %d x %d)', ndof, size(Y0,1), N);
    end

    nSteps = round(o.T / o.dt);
    nTrans = round(o.transient * nSteps);
    k      = min(max(1, o.nGali), ndof);

    y = Y0;
    V = zeros(ndof, k, N);
    for j = 1:k
        V(j,j,:) = 1;
    end

    % accumulators
    accLam  = zeros(1, N);  nLam = 0;
    Ybar    = zeros(1, N);  Ysum = zeros(1, N);  nMeg = 0;  Ymeg = zeros(1, N);
    fli     = -inf(1, N);
    lSum    = zeros(1, N);          % running sum of ln g_1, for FLI

    doSample = o.sample > 0;
    if doSample
        nOut = floor(nSteps / o.sample) + 2;
        gSer = nan(nOut, N);
        tSer = zeros(1, nOut);
        % Two scalar time series, for IACF / SN.  `ser` keeps only the first grid
        % column, for backwards compatibility with callers that read R.series1;
        % `pSer` keeps the representative momentum for EVERY point, which is what
        % a per-point spectral indicator needs.
        ser  = zeros(2, nOut);
        pSer = nan(nOut, N);
        nSer = 0;
    end

    t = 0;
    for step = 1:nSteps
        [y, V, g, t] = sp_step(y, V, t, o.dt, sys, o.order);

        if step > nTrans
            % ---- Lyapunov: growth of the first (leading) vector ----
            accLam = accLam + log(g(1,:));
            nLam   = nLam + 1;

            % ---- MEGNO, paper Eqs. (5)-(7) ----
            %   Y_n    = (2/n) * sum_{k=1}^{n} k * ln( ||n_k|| / ||n_{k-1}|| )
            %   Ybar_n = ((n-1) Ybar_{n-1} + Y_n) / n
            %
            % THE WEIGHT COUNTS FROM THE END OF THE TRANSIENT, NOT FROM t = 0.
            % This is the subtle part and it was got wrong twice.
            %
            %   * The weight must be a genuine STEP INDEX, not a plain counter
            %     incremented per accepted sample with the weight omitted: that
            %     version (mean of 2 ln r_k) gave 0.0003 on the integrable
            %     system and is useless.
            %   * But it must ALSO not be the absolute step number when a
            %     transient is discarded.  Y_n is defined as a running mean over
            %     an averaging window; starting that window at step nTrans and
            %     weighting by the absolute `step` leaves a constant offset in
            %     the reference origin, and the weighted sum then converges to
            %     the wrong value.  Measured on the integrable system with
            %     transient = 0.3: MEGNO = 1.28 (offset origin) versus 1.93 with
            %     the window-local index.  The transient exists to let the orbit
            %     reach its attractor; once discarded, the average must restart.
            %
            % The factor 2 is what makes this exactly Eq. (6): expanding the
            % recurrence gives Y_n = (2/n) sum k ln r_k, which tends to 2 for
            % ordered motion.
            %
            % VALIDATION (tests/diag_megno_conv.m): the harmonic oscillator,
            % where the reference paper states Y -> 0, gives 0.00000 exactly; a
            % non-isochronous libration converges to 2.00 as T grows (1.75 at
            % T = 100 rising to 1.9993 at T = 3200, with no transient).  The
            % SLOW convergence is a property of the indicator, not a defect --
            % the paper's own Sec. 4.2.1 remarks that MEGNO needs a long
            % integration to settle.  Use T >= 1000 for quantitative claims.
            nMeg = nMeg + 1;
            Ysum = Ysum + nMeg * log(g(1,:));
            Yn   = 2 * Ysum / nMeg;
            Ybar = ((nMeg-1)*Ybar + Yn) / nMeg;
            Ymeg = Yn;

            % ---- FLI: running supremum of ln||n|| ----
            lSum = lSum + log(g(1,:));
            fli  = max(fli, lSum);
        end

        if doSample && mod(step, o.sample) == 0
            nSer = nSer + 1;
            if nSer <= nOut
                gSer(nSer, :) = gali_now(V, k);
                tSer(nSer)    = t;
                ser(1, nSer)  = y(nq+1, 1);      % a representative momentum
                ser(2, nSer)  = y(1, 1);         % a representative coordinate
                pSer(nSer, :) = y(nq+1, :);      % momentum of EVERY point
            end
        end

        if o.progress && mod(step, max(1,round(nSteps/10))) == 0
            fprintf('    sp_run %3.0f%%\n', 100*step/nSteps);
        end
    end

    nAvg = max(1, nLam);
    R = struct();
    R.lambda = accLam / (nAvg * o.dt);
    R.mega   = Ymeg;          % MEGNO proper, tends to 2 for regular motion
    R.megabar = Ybar;         % its running mean (paper Eq. 7); lags on regular
    R.fli    = fli;
    R.gali   = gali_now(V, k);
    if k >= 2
        R.sali = sp_sali(V(:, 1:2, :));
    else
        R.sali = [];
    end
    R.nVec   = k;
    R.dt     = o.dt;
    R.T      = o.T;
    R.order  = o.order;
    R.nSteps = nSteps;
    R.sys    = sys.name;

    if doSample && nSer > 0
        R.galiSeries = gSer(1:nSer, :);
        R.tSeries    = tSer(1:nSer);
        R.series1    = ser(:, 1:nSer);

        % ---- the spectral indicators, PER POINT -------------------------
        % These used to be hard-coded to [] with a comment claiming a per-point
        % FFT "is a separate pass -- see sp_map.m", a file that does not exist.
        % The consequence was that sp_run advertised iacf and specnum in its own
        % header and could never return them, so sp_compare_forced grew its own
        % duplicate implementation (series_at there re-integrates each point and
        % then calls the same two functions).  Two implementations of one
        % definition is how the two drift apart, so the real one lives here and
        % the duplicate is gone.
        %
        % The series is the representative MOMENTUM, sampled every `sample`
        % steps.  Both indicators are defined on a scalar observable and are
        % sensitive to the sampling, so the caller must keep `sample` and `nSamp`
        % fixed when comparing two runs -- sp_specnum.m states this explicitly.
        if o.spectral
            S = pSer(1:nSer, :);
            R.iacf    = zeros(1, N);
            R.specnum = zeros(1, N);
            for c = 1:N
                q = S(:, c).';
                if numel(q) >= 8 && any(isfinite(q)) && std(q) > 0
                    q = fillmissing(q, 'linear');
                    R.iacf(c) = sp_iacf(q);
                else
                    R.iacf(c) = NaN;
                end
                if numel(q) >= 16 && any(isfinite(q)) && std(q) > 0
                    R.specnum(c) = sp_specnum(q);
                else
                    R.specnum(c) = NaN;
                end
            end
        else
            R.iacf    = [];
            R.specnum = [];
        end
    else
        R.galiSeries = [];
        R.tSeries    = [];
        R.iacf       = [];
        R.specnum    = [];
        R.series1    = [];
    end
end


% =========================================================================
function g = gali_now(V, k)
%% GALI_k of the first k deviation vectors, computed as sp_gali.m does.
%%
%% NOTE ON NORMALISATION: sp_step.m rescales every vector to unit norm each
%% step, so what is measured here is pure ALIGNMENT, not growth.  That is the
%% convention the GALI literature uses, and it is what makes GALI complementary
%% to the Lyapunov exponent rather than a restatement of it.  The wedge norm of
%% unit vectors is 1 when they are mutually orthogonal and 0 when dependent.
    N = size(V, 3);
    g = zeros(1, N);
    for c = 1:N
        [~, Rr] = qr(V(:, 1:k, c), 0);
        d = diag(Rr);
        if numel(d) < k
            g(c) = 0;
        else
            g(c) = abs(prod(d(1:k)));
        end
    end
end


% =========================================================================
function o = run_defaults(o)
    def = struct('order',4, 'T',100, 'dt',0.01, 'transient',0.3, ...
                 'nGali',2, 'sample',[], 'nSamp',4000, 'spectral',false, ...
                 'progress',false);
    f = fieldnames(def);
    for i = 1:numel(f)
        if ~isfield(o, f{i}) || isempty(o.(f{i}))
            o.(f{i}) = def.(f{i});
        end
    end
    if o.dt <= 0, error('sp_run:dt', 'dt must be positive'); end
    if o.T  <= 0, error('sp_run:T',  'T must be positive'); end

    % `sample` is a step interval; when the caller leaves it empty it is derived
    % from nSamp so that the time series has roughly that many samples.  A
    % non-positive value disables sampling entirely (GALI series and the
    % spectral indicators then come back empty rather than wrong).
    if isempty(o.sample)
        nSteps = round(o.T / o.dt);
        if o.nSamp > 0
            o.sample = max(1, floor(nSteps / o.nSamp));
        else
            o.sample = 0;
        end
    end
end
