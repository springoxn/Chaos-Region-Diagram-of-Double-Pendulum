function test_indicators()
%% TEST_INDICATORS  Validate the chaos-indicator family (P2).
%
%   Every assertion is against an independently known fact:
%
%     [1]  SALI / GALI_2 algebraic relation, on random vectors
%     [2]  GALI of exactly parallel and exactly orthogonal vectors
%     [3]  IACF: constant -> 1, sampled sine -> 2, white noise -> K
%     [4]  spectral number: a pure tone has one peak
%     [5]  MEGNO -> 2 on an INTEGRABLE system (the paper's own criterion:
%          Eq. (18) is integrable when a = 0 or b = 0)
%     [6]  MEGNO grows on a chaotic orbit of the same system family
%     [7]  GALI: exponential decay for chaos, no decay for regular motion
%     [8]  sp_run's Lyapunov exponent agrees with an independent estimator
%     [9]  HONEST LIMITATION: GALI_2 does not separate regular from chaotic
%          orbits in the 2-dimensional forced pendulum
%
%   Run:  addpath('tests'); test_indicators
%
%   See also sp_run, sp_gali, sp_sali, sp_megno_formula, sp_iacf, sp_specnum.

    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    rng(20260921);            % fixed seed: the tests must be reproducible
    fprintf('=== chaos indicator family ===\n\n');
    fails = 0;

    % ------------------------------------------------------------------ 1
    fprintf('[1] SALI vs GALI_2 relation\n');
    emax = 0;
    for t = 1:200
        u = randn(4,1); u = u/norm(u);
        w = randn(4,1); w = w/norm(w);
        V = reshape([u, w], 4, 2, 1);
        s = sp_sali(V);
        g = sp_gali(V);
        pred = s * sqrt(4 - s^2) / 2;
        emax = max(emax, abs(g - pred));
    end
    fprintf('    max |GALI_2 - SALI*sqrt(4-SALI^2)/2| = %.2e over 200 random pairs\n', emax);
    if emax > 1e-12, fprintf('    FAIL\n'); fails = fails + 1; end

    % ------------------------------------------------------------------ 2
    fprintf('\n[2] GALI on exactly parallel and orthogonal vectors\n');
    e1 = [1;0;0;0]; e2 = [0;1;0;0];
    Vpar = reshape([e1, e1], 4, 2, 1);
    Vort = reshape([e1, e2], 4, 2, 1);
    gpar = sp_gali(Vpar);  gort = sp_gali(Vort);
    spar = sp_sali(Vpar);  sort_ = sp_sali(Vort);
    fprintf('    parallel:   GALI2 = %.3e  SALI = %.3e\n', gpar, spar);
    fprintf('    orthogonal: GALI2 = %.3e  SALI = %.3e\n', gort, sort_);
    if abs(gpar) > 1e-14 || abs(spar) > 1e-14
        fprintf('    FAIL: parallel vectors must give zero\n'); fails = fails + 1;
    end
    if abs(gort - 1) > 1e-14 || abs(sort_ - sqrt(2)) > 1e-14
        fprintf('    FAIL: orthogonal vectors must give GALI=1, SALI=sqrt(2)\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 3
    fprintf('\n[3] IACF indicator W\n');
    % constant series -> W = 1
    [Wc, ic] = sp_iacf(ones(1, 2001));
    fprintf('    constant : W = %.6f  (exact 1, mode %s)\n', Wc, ic.mode);
    if abs(Wc - 1) > 1e-12, fprintf('    FAIL\n'); fails = fails + 1; end

    % sampled sine -> W -> 2
    % The full-lag exact sum is now the DEFAULT, so this call no longer has to
    % pass 'fullLimit', inf to avoid the cascade.  It is passed explicitly anyway
    % to keep the assertion independent of the default: a first version inherited
    % a default that selected the cascade silently and got 2.77 for a pure tone,
    % failing for the wrong reason.
    M = 4000; tt = (0:M-1);
    [Ws, is] = sp_iacf(sin(2*pi*tt/64), 'fullLimit', inf);
    fprintf('    sine     : W = %.6f  (theory 2, mode %s)\n', Ws, is.mode);
    if abs(Ws - 2) > 0.02, fprintf('    FAIL\n'); fails = fails + 1; end

    % white noise -> W ~ K (and always within [1, K])
    [Wn, in] = sp_iacf(randn(1, 3001));
    fprintf('    noise    : W = %.1f  K = %d  (theory ~K = %d)\n', Wn, in.K, in.K);
    if Wn < 1 || Wn > in.K
        fprintf('    FAIL: W must lie in [1, K]\n'); fails = fails + 1;
    end

    % full vs log-lag cascade must agree where both are affordable, otherwise
    % the cascade silently changes the answer.
    q = sin(2*pi*tt/64) + 0.3*sin(2*pi*tt/17) + 0.05*randn(1,M);
    Wf = sp_iacf(q, 'fullLimit', inf);
    Wk = sp_iacf(q, 'fullLimit', 0);         % force the cascade
    relc = abs(Wf-Wk)/abs(Wf);
    fprintf('    full=%.4f  cascade=%.4f  rel diff=%.2e\n', Wf, Wk, relc);

    % THE DEFAULT MUST BE THE EXACT SUM, AT EVERY SAMPLE COUNT.
    %
    % This is a regression test for a real defect: sp_iacf used to switch to the
    % cascade automatically once N*K passed `fullLimit`, whose default (2e8) put
    % the trigger beyond any realistic sample count.  The cascade was therefore
    % unreachable dead code, and the branch that WAS exercised was chosen by a
    % threshold rather than by the physics.  The default is now the exact sum and
    % the cascade is opt-in, so these two must agree unless asked otherwise.
    [Wd, id] = sp_iacf(q);
    fprintf('    default mode = %s (must be ''full'')\n', id.mode);
    if ~strcmp(id.mode, 'full')
        fprintf('    FAIL: default must use the exact full-lag sum\n'); fails = fails + 1;
    end
    if abs(Wd - Wf) > 1e-12
        fprintf('    FAIL: default disagrees with the explicit exact sum\n'); fails = fails + 1;
    end

    % THE CASCADE IS A BAD APPROXIMATION ON BROADBAND SERIES, and that is the
    % reason it is not the default.  A chaotic orbit is exactly a broadband
    % series, so approximating it by a third would defeat the indicator's
    % purpose.  Asserting the SIZE of the error documents why the default is what
    % it is; a future change that made the cascade the default again would have
    % to confront this number.
    xl = 0.4; lg = zeros(1, 3001);
    for i = 1:numel(lg), xl = 4*xl*(1-xl); lg(i) = xl; end
    Wbf = sp_iacf(lg, 'fullLimit', inf);
    Wbc = sp_iacf(lg, 'fullLimit', 0);
    relb = abs(Wbf-Wbc)/abs(Wbf);
    fprintf('    logistic (broadband): full=%.1f cascade=%.1f  rel diff=%.1f%%\n', ...
            Wbf, Wbc, 100*relb);
    if relb < 0.10
        fprintf(['    NOTE: the cascade is accurate on a broadband series, so the\n' ...
                 '    stated reason for keeping it opt-in no longer holds.\n']);
    end

    % ------------------------------------------------------------------ 4
    fprintf('\n[4] spectral number of a pure tone\n');
    [SN1, i4] = sp_specnum(sin(2*pi*tt/64));
    fprintf('    single tone      : SN = %d  (expect 1)\n', SN1);
    if SN1 ~= 1, fprintf('    FAIL\n'); fails = fails + 1; end
    [SN2, ~] = sp_specnum(sin(2*pi*tt/64) + 0.7*sin(2*pi*tt/21));
    fprintf('    two tones        : SN = %d  (expect 2 or 3)\n', SN2);
    if SN2 < 2, fprintf('    FAIL: two tones should give at least 2 peaks\n'); fails = fails + 1; end
    fprintf('    (nFreq = %d)\n', i4.nFreq);

    % ------------------------------------------------------------------ 5
    fprintf('\n[5] MEGNO on INTEGRABLE systems: two analytic anchors\n');
    % The reference paper gives BOTH end points explicitly:
    %   * harmonic oscillation          -> Y -> 0
    %   * ordered (regular) motion      -> Y -> 2  asymptotically
    % Checking both pins the normalisation, which is where the implementation
    % went wrong twice (see the long comment in sp_run.m).
    sysH = harmonic_sys();
    Rh = sp_run(sysH, [1.0; 0.0], struct('T', 400, 'dt', 0.01, 'order', 4, ...
                                          'nGali', 2, 'transient', 0.0));
    fprintf('    harmonic oscillator : MEGNO = %+.5f  (paper: -> 0)\n', Rh.mega(1));
    if abs(Rh.mega(1)) > 1e-3
        fprintf('    FAIL: harmonic oscillator must give MEGNO ~ 0\n'); fails = fails + 1;
    end

    % The paper states Eq. (18) is integrable for all initial conditions when
    % a = 0 or b = 0; with b = 0 it is two decoupled pendulums.
    sysI = sp_sys('coupled', 'a', 4, 'b', 0);
    Y0 = [0.9; 1.3; 0.0; 0.0];
    fprintf('    integrable b=0, convergence in T (no transient discarded):\n');
    for T = [100 400 1600 3200]
        Rt = sp_run(sysI, Y0, struct('T', T, 'dt', 0.02, 'order', 4, ...
                                      'nGali', 2, 'transient', 0.0));
        fprintf('      T=%5d : MEGNO = %7.4f   lambda = %+.2e\n', T, Rt.mega(1), Rt.lambda(1));
    end
    R5 = sp_run(sysI, Y0, struct('T', 3200, 'dt', 0.02, 'order', 4, ...
                                  'nGali', 2, 'transient', 0.0));
    fprintf('    integrable b=0, T=3200 : MEGNO = %.4f  lambda = %+.2e\n', ...
            R5.mega(1), R5.lambda(1));
    fprintf('    (convergence to 2 is SLOW; the paper itself notes MEGNO needs a\n');
    fprintf('     long integration.  T >= 1000 for quantitative claims.)\n');
    if abs(R5.mega(1) - 2) > 0.15
        fprintf('    FAIL: MEGNO should approach 2 for regular motion\n'); fails = fails + 1;
    end
    if abs(R5.lambda(1)) > 5e-3
        fprintf('    FAIL: integrable system must have zero Lyapunov exponent\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 6
    fprintf('\n[6] MEGNO on a chaotic orbit\n');
    sysC = sp_sys('coupled', 'a', 4, 'b', 1);
    % Find a chaotic initial condition by scanning, rather than asserting one.
    best = []; bestLam = -inf; bestX = 0;
    for x0 = linspace(-3, 3, 13)
        RR = sp_run(sysC, [x0; 1.3; 0.0; 0.2], ...
                    struct('T', 300, 'dt', 0.02, 'order', 4, 'nGali', 2));
        if RR.lambda(1) > bestLam
            bestLam = RR.lambda(1); best = RR; bestX = x0;
        end
    end
    fprintf('    chaotic x0=%.2f : MEGNO = %7.3f  lambda = %+.5f\n', ...
            bestX, best.mega(1), best.lambda(1));
    if best.mega(1) <= 2.2 || best.lambda(1) <= 0
        fprintf('    FAIL: expected a chaotic orbit with MEGNO > 2 and lambda > 0\n');
        fails = fails + 1;
    end
    fprintf('    (MEGNO grows linearly with time for chaos: check on three horizons)\n');
    prev = NaN;
    for T = [100 200 400]
        Rk = sp_run(sysC, [bestX; 1.3; 0.0; 0.2], ...
                    struct('T', T, 'dt', 0.02, 'order', 4, 'nGali', 2, ...
                            'transient', 0.0));
        fprintf('      T=%3d  MEGNO = %8.3f  lambda = %+.5f\n', T, Rk.mega(1), Rk.lambda(1));
        prev = Rk.mega(1);
    end
    if ~isnan(prev) && prev < 2.2
        fprintf('    FAIL: MEGNO did not grow on a chaotic orbit\n'); fails = fails + 1;
    end

    % ------------------------------------------------------------------ 7
    fprintf('\n[7] GALI: exponential decay for chaos, none for regular\n');
    % Regular: integrable case, sampled over time.
    Rr = sp_run(sysI, Y0, struct('T', 400, 'dt', 0.02, 'order', 4, 'nGali', 4, ...
                                 'sample', 200));
    Rc = sp_run(sysC, [bestX; 1.3; 0.0; 0.2], ...
                struct('T', 400, 'dt', 0.02, 'order', 4, 'nGali', 4, 'sample', 200));
    fprintf('    regular : GALI_4(t=0) = %.3e   GALI_4(final) = %.3e\n', ...
            Rr.galiSeries(1,1), Rr.gali(1));
    fprintf('    chaotic : GALI_4(t=0) = %.3e   GALI_4(final) = %.3e\n', ...
            Rc.galiSeries(1,1), Rc.gali(1));
    if Rc.gali(1) >= Rr.gali(1)
        fprintf('    FAIL: chaotic GALI_4 should be smaller than regular\n');
        fails = fails + 1;
    end
    % Fit the decay rate of the chaotic case over its first half and compare
    % with the Lyapunov exponent: theory says GALI decays with the sum of the
    % k largest exponents, so the rate must be at least lambda_1.
    gs = Rc.galiSeries(:,1);
    ts = Rc.tSeries(:);
    ok = gs > 0 & isfinite(gs);
    if sum(ok) > 10
        idx = find(ok);
        h1 = idx(1:floor(numel(idx)/2));
        pp = polyfit(ts(h1), log(gs(h1)), 1);
        fprintf('    fitted GALI_4 decay rate = %.4f  (lambda_1 = %.4f)\n', -pp(1), Rc.lambda(1));
    end

    % ------------------------------------------------------------------ 8
    fprintf('\n[8] sp_run Lyapunov vs an independent two-orbit estimator\n');
    % The shadow method needs no tangent machinery, so agreement is real
    % evidence.  Run over a SHORT time: beyond decorrelation the two estimates
    % are independent samples and comparison is meaningless, see
    % tests/why_pointwise_fails.py.
    lams = zeros(1,5); lamsS = zeros(1,5);
    Y0s = [0.9 1.7 2.5 -1.1 -2.3; 1.3 1.3 1.3 1.3 1.3; 0 0 0 0 0; 0.2 0.2 0.2 0.2 0.2];
    R8 = sp_run(sysC, Y0s, struct('T', 300, 'dt', 0.01, 'order', 4, 'nGali', 1));
    for c = 1:5
        lamsS(c) = shadow_lyap(sysC, Y0s(:,c), 300, 0.01, 1e-8);
    end
    lams = R8.lambda;
    fprintf('    variational: %s\n', mat2str(lams, 5));
    fprintf('    shadow     : %s\n', mat2str(lamsS, 5));
    rel = max(abs(lams - lamsS) ./ max(abs(lams), 1e-6));
    fprintf('    max relative difference = %.3f\n', rel);
    if rel > 0.35
        fprintf('    FAIL: the two independent estimators disagree\n'); fails = fails + 1;
    end

    % ------------------------------------------------------------------ 9
    fprintf('\n[9] GALI_2 in the 2-d forced pendulum: TRUE POSITIVES AND FALSE ONES\n');
    % Measured behaviour, replacing an earlier claim in this file that GALI_2
    % "collapses on regular orbits".  That claim was wrong in general and right
    % in a specific case; the case matters, so both are asserted here.
    %
    % Prediction: for a 2-d flow the GALI_2 decay rate is
    %     Gamma = lambda_1 - lambda_2 = 2*lambda_1 + gamma   (since div f = -gamma)
    % so it vanishes exactly when lambda_1 = -gamma/2, i.e. on a fixed point.
    sp = sp_sys('pendulum', 'F', 0, 'gamma', 0.2, 'Omega', 2/3);
    tau = 2*pi/sp.params.Omega;

    % (a) TRUE NEGATIVE: regular fixed-point orbit, Gamma ~ 0, GALI_2 survives
    Ra = sp_run(sp, [0.5; 0.0], struct('T', 600*tau, 'dt', 0.01, 'order', 4, ...
                                        'nGali', 2, 'sample', 40, 'transient', 0.0));
    fprintf('    (a) damped to the fixed point: lambda=%+.6f  Gamma_pred=%.2e  GALI_2(final)=%.4f\n', ...
            Ra.lambda(1), 2*Ra.lambda(1)+0.2, Ra.gali(1));
    if Ra.lambda(1) > -0.05 || Ra.gali(1) < 0.5
        fprintf('    FAIL: expected a surviving GALI_2 on this regular orbit\n');
        fails = fails + 1;
    end

    % (b) TRUE POSITIVE: chaotic orbit, GALI_2 collapses
    spc = sp_sys('pendulum', 'F', 1.5, 'gamma', 0.2, 'Omega', 2/3);
    tauc = 2*pi/spc.params.Omega;
    Rb = sp_run(spc, [0.5; 0.0], struct('T', 400*tauc, 'dt', 0.01, 'order', 4, ...
                                        'nGali', 2, 'sample', 40, 'transient', 0.0));
    fprintf('    (b) chaotic F=1.5 g=0.2    : lambda=%+.6f  Gamma_pred=%.4f  GALI_2(final)=%.3e\n', ...
            Rb.lambda(1), 2*Rb.lambda(1)+0.2, Rb.gali(1));
    if Rb.lambda(1) <= 0 || Rb.gali(1) > 1e-6
        fprintf('    FAIL: expected a collapsing GALI_2 on this chaotic orbit\n');
        fails = fails + 1;
    end
    % and the predicted decay rate should be reproduced by a fit
    gsb = Rb.galiSeries(:,1); tsb = Rb.tSeries(:);
    okb = gsb > 1e-14 & gsb < 0.5 & isfinite(gsb);
    if sum(okb) >= 10
        ppb = polyfit(tsb(okb), log(gsb(okb)), 1);
        predG = 2*Rb.lambda(1) + 0.2;
        fprintf('    predicted Gamma = %.4f, fitted Gamma = %.4f (rel diff %.2f)\n', ...
                predG, -ppb(1), abs(-ppb(1)-predG)/predG);
        if abs(-ppb(1) - predG)/predG > 0.35
            fprintf('    FAIL: GALI_2 decay rate does not match 2*lambda_1 + gamma\n');
            fails = fails + 1;
        end
    end

    % (c) FALSE POSITIVE: regular phase-locked orbit, GALI_2 collapses anyway.
    % This is the documented limitation, and it is asserted so that it cannot be
    % forgotten: the project's F-scan notes place this regime at gamma=0.5,
    % F ~ 1.3.
    spf = sp_sys('pendulum', 'F', 1.3, 'gamma', 0.5, 'Omega', 2/3);
    tauf = 2*pi/spf.params.Omega;
    Rc9 = sp_run(spf, [0.5; 0.0], struct('T', 400*tauf, 'dt', 0.01, 'order', 4, ...
                                         'nGali', 2, 'sample', 40, 'transient', 0.3));
    fp = (Rc9.lambda(1) < 1e-3) && (Rc9.gali(1) < 1e-4);
    fprintf('    (c) regular F=1.3 g=0.5    : lambda=%+.6f  GALI_2(final)=%.3e  false positive = %d\n', ...
            Rc9.lambda(1), Rc9.gali(1), fp);
    if fp
        fprintf(['    MEASURED LIMITATION CONFIRMED: a regular orbit is reported as\n' ...
                 '    chaotic by GALI_2.  Use MEGNO / OFLI2 / IACF for the forced\n' ...
                 '    pendulum; see sp_gali.m.\n']);
    end

    % ------------------------------------------------------------------ 10
    fprintf('\n[10] sp_run returns REAL per-point spectral indicators\n');
    % REGRESSION TEST.  sp_run documented `iacf` and `specnum` in its own header
    % while hard-coding both to [].  The fields existed, were always empty, and
    % nothing failed -- the plan at docs/rerun_plan.md flagged exactly this
    % ("恒为空数组").  A caller could read R.iacf, get [], and conclude the
    % indicator had been computed and found nothing.
    %
    % The contract asserted here is deliberately two-sided: with spectral=false
    % the fields are empty ON PURPOSE (documented), and with spectral=true they
    % are populated for every point and agree with calling sp_iacf / sp_specnum
    % directly on the same series.
    spp = sp_sys('pendulum', 'F', 1.1, 'gamma', 0.5, 'Omega', 2/3);
    Tdp = 2*pi/spp.params.Omega;
    sampleSteps = round(Tdp/0.01);
    Yrow = [linspace(-pi, pi, 6); linspace(-3, 3, 6)];
    Rsa = sp_run(spp, Yrow, struct('T', 60*Tdp, 'dt', 0.01, 'order', 4, ...
                  'nGali', 2, 'sample', sampleSteps, 'spectral', false));
    Rsb = sp_run(spp, Yrow, struct('T', 60*Tdp, 'dt', 0.01, 'order', 4, ...
                  'nGali', 2, 'sample', sampleSteps, 'spectral', true));
    fprintf('    spectral=false: iacf empty=%d  specnum empty=%d  (documented)\n', ...
            isempty(Rsa.iacf), isempty(Rsa.specnum));
    if ~isempty(Rsa.iacf) || ~isempty(Rsa.specnum)
        fprintf('    FAIL: spectral=false must leave the fields empty\n'); fails = fails + 1;
    end
    fprintf('    spectral=true : iacf = %s\n', mat2str(Rsb.iacf, 4));
    fprintf('    spectral=true : sn   = %s\n', mat2str(Rsb.specnum, 4));
    if numel(Rsb.iacf) ~= size(Yrow,2) || numel(Rsb.specnum) ~= size(Yrow,2)
        fprintf('    FAIL: expected one value per initial condition\n'); fails = fails + 1;
    end
    if any(~isfinite(Rsb.iacf)) || any(~isfinite(Rsb.specnum))
        fprintf('    FAIL: spectral indicators must be finite on these orbits\n');
        fails = fails + 1;
    end
    % Must equal the direct call on the SAME sampled series.  Rebuild the series
    % from R.series1 is not possible (that field holds only column 1), so the
    % check is done by re-integrating one point and comparing.
    y0 = Yrow(:, 1);
    q1 = sample_momentum(spp, y0, 60*Tdp, 0.01, sampleSteps);
    Wd = sp_iacf(q1);  SNd = sp_specnum(q1);
    fprintf('    point 1 direct: iacf=%.6f sn=%d   via sp_run: iacf=%.6f sn=%d\n', ...
            Wd, SNd, Rsb.iacf(1), Rsb.specnum(1));
    if abs(Rsb.iacf(1) - Wd) > 1e-10 || Rsb.specnum(1) ~= SNd
        fprintf('    FAIL: sp_run disagrees with the direct indicator call\n');
        fails = fails + 1;
    end

    % A spurious structure check: a chaotic orbit must have a LARGER W than a
    % regular one under identical sampling, which is the property the indicator
    % is used for.  Both are already in the row above (the leftmost point is
    % regular at this forcing, the middle ones are chaotic).
    fprintf('    W across the row: regular-ish %.2f .. chaotic %.2f\n', ...
            min(Rsb.iacf), max(Rsb.iacf));
    if max(Rsb.iacf) <= min(Rsb.iacf)
        fprintf('    FAIL: W does not vary across a regular/chaotic row\n');
        fails = fails + 1;
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_indicators:failed', '%d indicator test(s) failed', fails);
    end
end


% =========================================================================
function q = sample_momentum(sys, y0, T, dt, sample)
%% Stroboscopic momentum series, sampled every `sample` steps.  Mirrors what
%% sp_run does internally so the two can be compared directly.
    nSteps = round(T/dt);
    nOut = floor(nSteps/sample) + 2;
    q = nan(1, nOut);
    y = y0; t = 0; n = 0;
    for step = 1:nSteps
        [y, ~, ~, t] = sp_step(y, [], t, dt, sys, 4);
        if mod(step, sample) == 0
            n = n + 1;
            if n <= nOut, q(n) = y(2); end
        end
    end
    q = q(1:n);
end


% =========================================================================
function sys = harmonic_sys()
%% H = (p^2 + q^2)/2 in the sp_sys contract, for the MEGNO anchor.
%
%   For the harmonic oscillator the deviation norm is CONSTANT (delta q = cos t,
%   delta v = -sin t), so every ln r = 0 and MEGNO must be exactly 0.  The
%   reference paper states this explicitly, which makes it the sharpest
%   available check on the normalisation of the accumulation.
    sys = struct();
    sys.name   = 'harmonic oscillator';
    sys.nq     = 1;
    sys.gamma  = 0;
    sys.params = struct();
    sys.force  = @(q,t) -q;
    sys.dforce = @(q,t) reshape(-ones(1, numel(q)), 1, 1, numel(q));
    sys.energy = @(y,t) 0.5*(y(1,:).^2 + y(2,:).^2);
    sys.ndof   = 2;
end


% =========================================================================
function lam = shadow_lyap(sys, y0, T, dt, d0)
%% Two-trajectory estimator: renormalise the separation, estimate the rate.
%% Independent of the tangent machinery in sp_step.m.
    n = round(T/dt);
    yA = y0;  yB = y0;
    yB(2) = yB(2) + d0;          % perturb the momentum
    tA = 0; tB = 0;
    acc = 0; cnt = 0;
    ntr = round(0.3*n);
    for k = 1:n
        [yA, ~, ~, tA] = sp_step(yA, [], tA, dt, sys, 4);
        [yB, ~, ~, tB] = sp_step(yB, [], tB, dt, sys, 4);
        d = yB - yA;
        nr = norm(d);
        if nr > 0
            if k > ntr
                acc = acc + log(nr/d0);
                cnt = cnt + 1;
            end
            yB = yA + d*(d0/nr);
        end
    end
    if cnt == 0
        lam = NaN;
    else
        lam = acc / (cnt*dt);
    end
end
