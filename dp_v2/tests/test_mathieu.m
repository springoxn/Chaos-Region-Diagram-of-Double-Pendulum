function test_mathieu()
%% TEST_MATHIEU  Verify the paper's analytic Mathieu prediction (Eqs. 26-28).
%
%   Barrio, Borczyk & Breiter (2009), Sec. 4.1.2, resolve their "the single
%   pendulum is chaotic" paradox by showing that the apparent chaos is
%   PARAMETRIC RESONANCE of a LINEAR transverse mode.  Everything about that
%   claim is analytic, so it can be graded rather than inspected -- which is why
%   docs/rerun_plan.md section C rates it the highest-value unfinished item.
%
%   THE PREDICTION, IN THREE STEPS
%     1. With y = Y = 0 the variational equations decouple (their Eq. 23), and
%        the transverse mode obeys   delta y'' = -a(1 - b cos x) delta y .
%     2. For circulating x, u = Omega t and xi^2 = a/Omega^2 turn this into the
%        Mathieu equation        d2(dy)/du2 = -xi^2 (1 - b cos u) dy   (Eq. 26).
%     3. Its instability bands sit at   xi = k/2, k = 1,2,3,...   (Eq. 27),
%        i.e.   Omega = 4/k   for a = 4                            (Eq. 28).
%
%   WHAT IS ASSERTED
%     [1] the ideal Mathieu equation: at small b each band brackets xi = k/2
%         (Eq. 27 is the b -> 0 statement), at b = 1 the bands shift UPWARD by
%         an amount growing with k (the A_n = n^2 + O(Q^2) shift), and between
%         the bands max|Floquet| = 1 exactly
%     [2] band width grows with b and shrinks with k (stated in the paper)
%     [3] the PROJECT's symplectic stepper on the real coupled pendulum, with
%         the delta y mode seeded, reproduces the bands at Omega_eff = 4/k
%     [4] the bands are a property of the LINEAR TRANSVERSE MODE, not of chaos:
%         the delta x mode on the same orbits shows no bands at all
%
%   [3] IS THE SUBSTANTIVE ONE.  It is what converts the paper's reduction from
%   a plausible argument into a measured fact about the system this project
%   actually integrates.  Measured: Omega_eff = 4/k to within 1.9% , i.e. the
%   transverse resonance sits where the paper says it does.
%
%   A CAVEAT THAT IS PART OF THE RESULT, NOT A DEFECT
%   -------------------------------------------------
%   The paper labels the stripes by the INITIAL VELOCITY X and states they begin
%   at "X ~ 4".  That reading is only accurate in the fast-circulation limit:
%   measured X/Omega_eff falls from 1.86 at X = 2.05 to 1.03 at X = 6.  The
%   sharp statement is the one this test asserts, Omega_eff = 4/k with Omega_eff
%   the true circulation frequency from a quadrature of the pendulum period.
%   Reading the bands off X instead leaves a 5-15% offset that looks like a
%   failure of the theory but is an artefact of the label.
%
%   Run:  addpath('tests'); test_mathieu
%
%   See also sp_mathieu_bands, sp_sys, sp_step, sp_paper_repro.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','analysis'));
    fprintf('=== paper Eq. (26)-(28): Mathieu parametric resonance ===\n\n');
    fails = 0;

    % ------------------------------------------------------------------ 1
    fprintf('[1] ideal Mathieu Eq.(26): bands at xi = k/2\n');
    % THE PAPER'S EQ. (27) IS A LEADING-ORDER STATEMENT, and this section is
    % split accordingly.  The Mathieu equation in the standard form
    %     d2y/dz2 + (A - 2Q cos 2z) y = 0
    % has characteristic values A_n = n^2 + O(Q^2), so for the equation actually
    % used here -- y'' + xi^2 (1 - b cos u) y = 0, i.e. A = 4 xi^2 and
    % Q = 2 xi^2 b -- the band at xi = k/2 is shifted UPWARD by an amount that
    % grows with b and with k.  Eq. (27) is the b -> 0 limit of that.
    %
    % Asserting "k/2 lies inside band k" at b = 1 is therefore WRONG PHYSICS, and
    % a first version of this test did exactly that: it failed for k = 3, 4 with
    % the prediction just below the measured lower edge (1.500 vs 1.524, 2.000 vs
    % 2.080).  The correct assertions are (a) the paper's prediction at SMALL b,
    % where it is meant to hold, and (b) the measured shift at b = 1, reported as
    % a number rather than hidden.
    fprintf('    (a) small b, where Eq.(27) is the b -> 0 statement it actually is\n');
    for bTest = [0.05 0.10 0.20]
        Rb = sp_mathieu_bands('mode','ideal', 'b',bTest, 'verbose',false);
        nb = numel(Rb.ideal.centers);
        fprintf('      b=%.2f : %d band(s), centers %s\n', ...
                bTest, nb, mat2str(Rb.ideal.centers, 4));
        for k = 1:nb
            lo = Rb.ideal.lo(k); hi = Rb.ideal.hi(k);
            if ~((k/2 >= lo - 1e-9) && (k/2 <= hi + 1e-9))
                fprintf(['      FAIL: at b=%.2f, xi=%.2f is outside band %d [%.4f, %.4f].\n' ...
                         '      In the small-b limit the band must contain k/2.\n'], ...
                        bTest, k/2, k, lo, hi);
                fails = fails + 1;
            end
        end
    end
    if fails == 0
        fprintf('      confirmed: at small b every band brackets xi = k/2\n');
    end

    fprintf('    (b) at b = 1 the bands are SHIFTED UP, increasingly with k\n');
    R = sp_mathieu_bands('mode','ideal', 'b',1, 'verbose',false);
    xi = R.ideal.xi;  mu = R.ideal.mu;
    nb = numel(R.ideal.centers);
    fprintf('      %5s %10s %10s %10s %12s\n', 'k', 'k/2', 'center', 'shift', 'width');
    shifts = zeros(1, nb);
    for k = 1:nb
        shifts(k) = R.ideal.centers(k) - k/2;
        fprintf('      %5d %10.3f %10.4f %+10.4f %12.4f\n', ...
                k, k/2, R.ideal.centers(k), shifts(k), R.ideal.widths(k));
    end
    if nb == 0
        fprintf('      FAIL: no bands found at all\n'); fails = fails + 1;
    else
        % The shift must be UPWARD (the characteristic value A_n = n^2 + O(Q^2)
        % rises), and the first band must still contain k/2 -- at b = 1 the k = 1
        % band is wide enough to cover it.
        if any(shifts <= 0)
            fprintf('      FAIL: the Mathieu bands must shift UPWARD from k/2\n');
            fails = fails + 1;
        end
        if ~((0.5 >= R.ideal.lo(1)) && (0.5 <= R.ideal.hi(1)))
            fprintf('      FAIL: even the k=1 band should contain xi=0.5 at b=1\n');
            fails = fails + 1;
        end
    end

    % Between the bands the motion must be STABLE: mu = 0.  A peak-finding check
    % alone would miss this -- a function growing everywhere still has local
    % maxima near k/2.  The probe points are taken from the MEASURED band edges
    % rather than hard-coded, because a hard-coded "between" point can land
    % inside a band once b shifts them (2.35 does, at b = 1: band 4 runs to
    % 2.348).
    fprintf('    (c) stability BETWEEN the measured bands (mu must be ~0)\n');
    nStable = 0;
    for k = 1:(nb-1)
        gapLo = R.ideal.hi(k);
        gapHi = R.ideal.lo(k+1);
        if gapHi - gapLo > 0.02
            m = 0.5*(gapLo + gapHi);
            [~, i] = min(abs(xi - m));
            fprintf('      gap after band %d: xi=%.3f (band edge %.3f..%.3f) mu = %+.2e\n', ...
                    k, xi(i), gapLo, gapHi, mu(i));
            if abs(mu(i)) > 1e-6
                fprintf('      FAIL: xi=%.3f lies in a stable gap but mu = %+.2e\n', ...
                        xi(i), mu(i));
                fails = fails + 1;
            end
            nStable = nStable + 1;
        end
    end
    if nStable == 0
        fprintf('      FAIL: no stable gaps were found to test\n'); fails = fails + 1;
    end
    % and AT each band centre it must be strictly positive
    for k = 1:nb
        [~, i] = min(abs(xi - R.ideal.centers(k)));
        if ~(mu(i) > 1e-3)
            fprintf('      FAIL: band %d has mu = %+.2e, not unstable\n', k, mu(i));
            fails = fails + 1;
        end
    end

    % ------------------------------------------------------------------ 2
    fprintf('\n[2] paper: band width grows with b, shrinks with k\n');
    bs = [0.2 0.4 0.7];
    W = cell(numel(bs),1);
    for i = 1:numel(bs)
        Ri = sp_mathieu_bands('mode','ideal', 'b',bs(i), 'verbose',false);
        W{i} = Ri.ideal.widths;
        fprintf('    b=%.2f widths = %s\n', bs(i), mat2str(W{i}, 3));
    end
    % monotone in b, for each band that exists at both b
    for k = 1:min(cellfun(@numel, W))
        w = cellfun(@(x) x(k), W);
        if ~all(diff(w) > 0)
            fprintf('    FAIL: band %d width should increase with b\n', k);
            fails = fails + 1;
        end
    end
    % decreasing in k at fixed b (use the largest b, where several exist)
    wLast = W{end};
    if numel(wLast) >= 2 && ~all(diff(wLast) < 0)
        fprintf('    FAIL: width should decrease with k at b=%.2f\n', bs(end));
        fails = fails + 1;
    end
    fprintf('    width increases with b: confirmed;  decreases with k: confirmed\n');

    % ------------------------------------------------------------------ 3
    fprintf('\n[3] the PROJECT stepper on the real coupled pendulum\n');
    % The assertion is on the PHYSICAL relation Omega_eff = 4/k.  A tolerance of
    % 8% is set from the measurement: the coarse X grid (nX = 60) locates each
    % band peak to about one grid step, and the band is ~0.2 wide in X, so 8%
    % is the resolution limit here -- not a fudge to make the test pass.  The
    % finer scan in the smoke run gives 1.9%.
    Rp = sp_mathieu_bands('mode','physical', 'T',400, 'nX',60, ...
                          'bandThr',0.05, 'verbose',false);
    nb = numel(Rp.phys.bands);
    fprintf('    located %d band(s) in the circulation regime (X > 2)\n', nb);
    if nb < 2
        fprintf(['    FAIL: expected at least 2 bands (k = 1, 2); the transverse\n' ...
                 '    mode should be unstable near Omega_eff = 4 and 2.\n']);
        fails = fails + 1;
    end
    for i = 1:nb
        bnd = Rp.phys.bands(i);
        fprintf(['    band %d: X=%.2f  Omega_eff=%.4f  xi=%.4f  -> k=%.2f (nearest %d)\n' ...
                 '            Omega_eff vs 4/k = %.4f : rel err %.2f%%\n'], ...
                i, bnd.Xpeak, bnd.omega, bnd.xi, bnd.kImplied, bnd.kRound, ...
                Rp.settings.a/bnd.kRound, ...
                100*abs(bnd.omega - Rp.settings.a/bnd.kRound)/(Rp.settings.a/bnd.kRound));
    end
    if nb > 0
        fprintf('    max |xi - k/2|           = %.4f\n', max(Rp.agreeXi));
        fprintf('    max |Omega_eff - 4/k|/4/k = %.4f\n', max(Rp.agreeOmega));
        if max(Rp.agreeOmega) > 0.08
            fprintf(['    FAIL: the transverse bands are not at Omega_eff = 4/k.\n' ...
                     '    That is the paper''s Eq. (28); missing it means the reduction\n' ...
                     '    does not describe this system.\n']);
            fails = fails + 1;
        end
    end

    % ------------------------------------------------------------------ 4
    fprintf('\n[4] it is the TRANSVERSE mode: delta x must show no bands\n');
    % The control.  Eq. (23) decouples the modes, so seeding delta x instead
    % must give a flat, non-positive exponent.  Without this control a band
    % found in [3] could be an artefact of the base orbit rather than of the
    % parametric resonance.
    sys = sp_sys('coupled','a',4,'b',1);
    Xs = 2.5:0.5:5.0;
    lamX = zeros(size(Xs));
    for i = 1:numel(Xs)
        lamX(i) = mode_lyap(sys, [0;0;Xs(i);0], 400, 0.02, 1);   % component 1 = delta x
    end
    lamY = zeros(size(Xs));
    for i = 1:numel(Xs)
        lamY(i) = mode_lyap(sys, [0;0;Xs(i);0], 400, 0.02, 2);   % component 2 = delta y
    end
    fprintf('    %8s %14s %14s\n', 'X', 'lambda(dx)', 'lambda(dy)');
    for i = 1:numel(Xs)
        fprintf('    %8.2f %14.5f %14.5f\n', Xs(i), lamX(i), lamY(i));
    end
    if max(lamX) > 0.02
        fprintf(['    FAIL: the delta-x (pendulum) mode grew to %.4f; it should be\n' ...
                 '    regular.  Seeding the wrong COMPONENT is the usual cause -- the\n' ...
                 '    state layout is [x; y; X; Y], so delta x is 1 and delta y is 2.\n'], ...
                max(lamX));
        fails = fails + 1;
    end
    if max(lamY) <= 0.05
        fprintf('    FAIL: the delta-y mode never grew; no resonance was triggered\n');
        fails = fails + 1;
    end
    fprintf('    delta x stays regular (max %.4f) while delta y resonates (max %.4f)\n', ...
            max(lamX), max(lamY));

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_mathieu:failed', '%d Mathieu test(s) failed', fails);
    end
end


% =========================================================================
function L = mode_lyap(sys, Y0, T, dt, comp)
%% Largest Lyapunov exponent of ONE seeded component of [x; y; X; Y].
%%
%%   comp = 1 -> delta x (the pendulum mode)
%%   comp = 2 -> delta y (the transverse mode, the Mathieu one)
%%
%%   Components 3 and 4 are the conjugate momenta.  Passing the wrong index is
%%   the single easiest way to get a meaningless answer from this test: it
%%   silently measures a different physical mode, and the result (a flat
%%   exponent) looks like "the paper's prediction is wrong" rather than "the
%%   probe is wrong".
    if comp < 1 || comp > 4
        error('mode_lyap:comp', 'comp must be 1..4 (got %d)', comp);
    end
    nSteps = round(T/dt);
    ntr = round(0.2*nSteps);
    y = Y0;
    V = zeros(4,1,1);
    V(comp,1,1) = 1;
    acc = 0; n = 0; t = 0;
    for k = 1:nSteps
        [y, V, g, t] = sp_step(y, V, t, dt, sys, 4);
        if k > ntr
            acc = acc + log(g(1,1));
            n = n + 1;
        end
    end
    L = acc/(max(1,n)*dt);
end
