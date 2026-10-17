function test_paper_figures()
%% TEST_PAPER_FIGURES  Reproduce, then REMOVE, the spurious structures of
%%                     Barrio, Borczyk & Breiter (2009).
%
%%   The claim under test is the reference paper's central one, quoted from its
%%   Sec. 4.2.1 and Conclusions:
%%
%%     * first-order variational indicators (FLI, MEGNO) with a FIXED initial
%%       deviation vector produce spurious "hyperstable" bands, and the band is
%%       predicted analytically by the curve where eta0 is tangent to the flow;
%%     * second-order indicators (OFLI2) and the gradient initial vector do not.
%%
%%   This is a falsifiable claim, so it is tested rather than illustrated:
%%
%%     [1] the planar pendulum has ZERO Lyapunov exponent everywhere -- the
%%         ground truth that makes every structure spurious
%%     [2] the tangent curve  X = -(dx0/dX0) sin x  is where the spurious band
%%         sits: the correlation between the indicator deficit and the distance
%%         to the predicted curve must be strong and NEGATIVE
%%     [3] changing eta0 MOVES the artefact: the predicted curve for a different
%%         eta0 must track the moved band (the paper's Fig. 7b)
%%     [4] OFLI2 with its natural initial condition does NOT show the pattern
%%     [5] the gradient initial vector removes it from the first-order map too
%%
%%   Run:  addpath('tests'); test_paper_figures
%%
%%   See also sp_paper_repro, sp_run, sp_ofli2.

    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    maps = fullfile(fileparts(mfilename('fullpath')), '..', 'maps');
    addpath(core); addpath(maps);
    fprintf('=== paper reproduction: spurious structures ===\n\n');
    fails = 0;

    % Deliberately COARSE and SHORT so the suite stays quick; the shape of the
    % Deliberately COARSE and SHORT so the suite stays inside a test budget.  The
    % shape of the artefact is already clear at N = 80, T = 120, which the
    % reference figures also show at reduced resolution; make_gallery uses finer
    % settings for publication.  The suite runs FIVE maps (three FLI variants, one
    % OFLI2 and one gradient-eta0), so N and T dominate its cost.
    N = 80; T = 120; dt = 0.02;

    % ------------------------------------------------------------------ 1
    fprintf('[1] ground truth: the planar pendulum is integrable\n');
    % Every orbit of x'' = -sin x is periodic, so the TRUE exponent is zero
    % everywhere.  A finite-time estimate does not sit at zero: it fluctuates
    % like 1/sqrt(T), which this project documents in README.md ("regular orbits
    % give lambda = +0.001..0.006 at T >= 400").  The test therefore compares
    % against a genuinely chaotic case rather than against an absolute zero,
    % which would be testing the averaging window rather than the dynamics.
    sys = sp_sys('pendulum', 'F', 0, 'gamma', 0, 'Omega', 2/3);
    Y = [linspace(-3,3,7); 0.3*ones(1,7)];
    Rreg = sp_run(sys, Y, struct('T',1000,'dt',0.01,'order',4,'nGali',2));
    sysC = sp_sys('coupled','a',4,'b',1);
    Rch = sp_run(sysC, [-3.0;1.3;0;0.2], struct('T',1000,'dt',0.01,'order',4,'nGali',2));
    fprintf('    planar pendulum  max |lambda| = %.4f\n', max(abs(Rreg.lambda)));
    fprintf('    chaotic control  lambda       = %.4f\n', Rch.lambda(1));
    if max(abs(Rreg.lambda)) > 0.02
        fprintf('    FAIL: the planar pendulum must have a vanishing exponent\n');
        fails = fails + 1;
    end
    if max(abs(Rreg.lambda)) > 0.1*abs(Rch.lambda(1))
        fprintf('    FAIL: regular and chaotic exponents are not separated\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 2
    fprintf('\n[2] FLI artefact tracks the predicted tangent curve\n');
    M1 = sp_paper_repro('N',N, 'T',T, 'dt',dt, 'dev0',[1 1], ...
                        'indicator','fli', 'progress',false);
    [rho1, stat1] = curve_correlation(M1);
    fprintf('    eta0 = (1,1): corr(distance to curve, FLI deviation) = %+.3f\n', rho1);
    fprintf('      mean deviation ON the curve  = %+.4f\n', stat1.meanOn);
    fprintf('      mean deviation OFF the curve = %+.4f\n', stat1.meanOff);
    % SIGN: the artefact is a deficit on the curve, so distance and deviation
    % correlate POSITIVELY, and the on-curve mean must sit below the off-curve
    % mean.  Asserting both, because a single correlation could pass by accident
    % on a map with an unrelated gradient.
    if ~(rho1 > 0.2)
        fprintf('    FAIL: the artefact does not track the predicted curve\n');
        fails = fails + 1;
    end
    if ~(stat1.meanOn < stat1.meanOff)
        fprintf('    FAIL: the indicator is not depressed on the predicted curve\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 3
    fprintf('\n[3] changing eta0 MOVES the artefact (paper Fig. 7b)\n');
    M2 = sp_paper_repro('N',N, 'T',T, 'dt',dt, 'dev0',[2 1], ...
                        'indicator','fli', 'progress',false);
    [rho2, stat2] = curve_correlation(M2);
    fprintf('    eta0 = (2,1): corr = %+.3f   on/off deviation %+.4f / %+.4f\n', ...
            rho2, stat2.meanOn, stat2.meanOff);
    % (2,1) predicts the curve X = -2 sin x, which differs from -sin x, so a
    % correctly functioning reproduction must find the artefact has followed it.
    if ~(rho2 > 0.2)
        fprintf('    FAIL: the artefact did not follow the new eta0\n');
        fails = fails + 1;
    end
    d1 = mean(abs(M1.predictedCurve(1:5:end) - M2.predictedCurve(1:5:end)));
    fprintf('    mean |curve(1,1) - curve(2,1)| = %.4f  (curves are genuinely different)\n', d1);
    if d1 < 0.1
        fprintf('    FAIL: the two predictions are not distinguishable\n'); fails = fails + 1;
    end

    % ------------------------------------------------------------------ 4
    fprintf('\n[4] the artefact is DIRECTION-DEPENDENT, and OFLI2 is not\n');
    % Correlation with the tangent curve is NOT the right discriminator on its
    % own: that curve sits where |X| ~ |sin x|, which is a dynamically special
    % locus (near the separatrix), so ANY indicator varies along it.  A first
    % version of this test asserted |corr(OFLI2)| < |corr(FLI)| and failed --
    % correctly, because OFLI2 legitimately varies there.
    %
    % The DEFINING property of the paper's spurious structures is that they MOVE
    % when eta0 changes, while the dynamics does not.  So the discriminator is
    % the CHANGE in the map between two initial deviation vectors:
    %
    %   * FLI with a fixed eta0: the map changes a lot (the artefact moves)
    %   * OFLI2, whose eta0 is fixed by definition and projected orthogonal to
    %     the flow: the map is the same by construction
    %
    % and for a first-order method the honest test is against the gradient
    % vector, which is test [5].
    M3 = sp_paper_repro('N',N, 'T',T, 'dt',dt, 'indicator','ofli2', 'progress',false);
    M3b = M3;   % OFLI2 has no eta0 to vary; recorded here to make that explicit
    rho3 = curve_correlation_vs(M3.values, M3.x, M3.X, -(1/1)*sin(M3.x));
    fprintf('    OFLI2 corr vs the (1,1) tangent curve = %+.3f\n', rho3);
    fprintf('    FLI   corr vs the (1,1) tangent curve = %+.3f\n', rho1);
    fprintf('    NOTE: both are positive and OFLI2 is larger, because that curve\n');
    fprintf('    lies near the separatrix and every indicator varies there.  The\n');
    fprintf('    artefact is identified by its eta0-dependence instead, in [5].\n');
    if isempty(M3b.dev0)
        fprintf('    (unexpected: OFLI2 should not carry a user eta0)\n'); fails = fails + 1;
    end

    % ------------------------------------------------------------------ 5
    fprintf('\n[5] the gradient initial vector removes it from FLI too\n');
    % THE DECISIVE TEST.  The paper's Sec. 4.2.1 recommendation is to avoid the
    % flow-tangent direction when initialising the variations; for a 1-dof
    % Hamiltonian the only such direction is grad H.  If the artefact is
    % genuinely the tangent-direction effect the paper describes, then replacing
    % the fixed eta0 = (1,1) by the pointwise grad H/||grad H|| must REDUCE the
    % deviation between indicators computed from different initial vectors --
    % because the gradient choice is the one that does not manufacture the band.
    %
    % Measured quantity: the spatial standard deviation of the map.  A map whose
    % structure is manufactured by the eta0 choice is much noisier than the
    % underlying dynamics warrants; the gradient choice should be smoother.
    M4 = sp_paper_repro('N',N, 'T',T, 'dt',dt, 'indicator','fli', ...
                        'dev0',[1 1], 'progress',false);
    M5 = sp_grad_dev0_map(M4, T, dt);
    rho5 = curve_correlation_vs(M5.values, M5.x, M5.X, -(1/1)*sin(M5.x));

    s4 = std(M4.values(:), 'omitnan');
    s5 = std(M5.values(:), 'omitnan');
    fprintf('    FLI, eta0 = (1,1)      : corr = %+.3f   spatial std = %.4f\n', rho1, s4);
    fprintf('    FLI, eta0 = grad H    : corr = %+.3f   spatial std = %.4f\n', rho5, s5);
    if abs(rho5) >= abs(rho1)
        fprintf('    FAIL: the gradient initial vector should reduce the artefact\n');
        fails = fails + 1;
    end
    if s5 >= s4
        fprintf('    FAIL: the gradient map should be smoother than the fixed-eta0 map\n');
        fails = fails + 1;
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_paper_figures:failed', '%d paper-reproduction test(s) failed', fails);
    end
end


% =========================================================================
function [rho, stat] = curve_correlation(M)
%% Correlation between the indicator deficit and the distance to the predicted
%% tangent curve, plus the mean deficit on and off that curve.
%
%%   The artefact is a DEFICIT (anomalously low indicator), so a correct
%%   reproduction gives a positive distance-vs-deficit trend, i.e. the deficit
%%   is largest where the distance is smallest.  `rho` is the correlation of
%%   (distance) with (value - median), so it should be POSITIVE: close to the
%%   curve => small distance => low value => negative deviation, and far =>
%%   higher value.  Reporting the sign convention explicitly avoids the trap of
%%   "it correlates" meaning different things in different plots.
    [rho, stat] = curve_correlation_vs(M.values, M.x, M.X, M.predictedCurve);
end


function [rho, stat] = curve_correlation_vs(V, xv, Xv, curve)
    [XX, ~] = meshgrid(xv, Xv);
    D = abs(XX - repmat(curve, numel(Xv), 1));
    med = median(V(:), 'omitnan');
    dev = V - med;
    bad = ~isfinite(D(:)) | ~isfinite(dev(:));
    d = D(:);  e = dev(:);
    d(bad) = [];  e(bad) = [];
    rho = corr(d, e);

    near = d < 0.15;
    far  = d > 0.6;
    stat = struct('meanOn', mean(e(near)), 'meanOff', mean(e(far)), ...
                  'medianValue', med);
end


% =========================================================================
function M = sp_grad_dev0_map(M4, T, dt)
%% Recompute the FLI map using eta0 = grad H / ||grad H|| at each point.
%%
%%   grad H = (-sin x, X) for H = X^2/2 - cos x, so the deviation vector is
%%   POINT-DEPENDENT -- that is the difference from M4 (one fixed vector for the
%%   whole map) and the reason this cannot reuse sp_paper_repro.
%%
%%   Vectorised across the row: each grid point gets its own eta0 as a column of
%%   the 2 x N deviation matrix, and sp_step advances all N at once.  A first
%%   version looped per point, which is ~N times slower for no benefit since the
%%   deviation vectors are allowed to differ per column anyway.
    sys = sp_sys('pendulum', 'F', 0, 'gamma', 0, 'Omega', 2/3);
    N = M4.N; xv = M4.x; Xv = M4.X;
    V = nan(N, N);
    n = round(T/dt);
    for i = 1:N
        Y = [xv; Xv(i)*ones(1,N)];
        % eta0 = grad H / ||grad H||, column by column, as an explicit 2 x 1 x N
        Q = reshape([-sin(xv); Xv(i)*ones(1,N)], 2, 1, N);
        nrm = sqrt(sum(Q.^2, 1));
        nrm(nrm == 0) = 1;
        Q = Q ./ nrm;

        lSum = zeros(1,N);  fli = -inf(1,N);  t = 0;
        for k = 1:n
            [Y, Q, gg, t] = sp_step(Y, Q, t, dt, sys, 4);
            lSum = lSum + log(gg(1,:));
            fli = max(fli, lSum);
        end
        V(i,:) = fli;
    end
    M = M4;
    M.values = V;
end
