function test_analysis()
%% TEST_ANALYSIS  Validate the analysis modules against cases with known answers.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), fullfile(here,'..','analysis'));
    fprintf('=== analysis module tests ===\n\n');
    fails = 0;

    % ---------------------------------------------------------------- 1
    % Melnikov threshold against the closed form and its defining identity.
    fprintf('[1] Melnikov threshold\n');
    for gam = [0.1 0.2 0.5 1.0]
        Fc = fp_melnikov_threshold(gam, 2/3);
        exact = (4*gam/pi)*cosh(pi/3);
        fprintf('    gamma=%.2f  F_c=%.6f  exact=%.6f\n', gam, Fc, exact);
        if abs(Fc-exact) > 1e-12
            fprintf('    FAIL\n'); fails = fails+1;
        end
    end
    Fc0 = fp_melnikov_threshold(0, 2/3);
    fprintf('    gamma=0 -> F_c=%.1e (no damping => any forcing splits manifolds)\n', Fc0);
    fprintf('    ok\n');

    % ---------------------------------------------------------------- 2
    % Uncertainty exponent on synthetic basins with KNOWN dimension.
    fprintf('\n[2] uncertainty exponent on synthetic boundaries\n');

    N = 1200;
    [X, Y] = meshgrid(linspace(0,1,N), linspace(0,1,N));

    % (a) smooth straight boundary: alpha should be 1, D should be 1
    B = double(X > 0.5);
    R = basin_dimension(B, 'verbose', false);
    fprintf('    smooth vertical line : alpha=%.3f  D=%.3f   (expect alpha~1, D~1)\n', ...
            R.alpha, R.D);
    if abs(R.alpha - 1) > 0.15
        fprintf('    FAIL: smooth boundary should give alpha ~ 1\n'); fails = fails+1;
    end

    % (b) a straight line at 45 degrees -- same dimension, tests isotropy
    B = double(X + Y > 1.0);
    R = basin_dimension(B, 'verbose', false);
    fprintf('    smooth diagonal line : alpha=%.3f  D=%.3f   (expect alpha~1, D~1)\n', ...
            R.alpha, R.D);
    if abs(R.alpha - 1) > 0.15
        fprintf('    FAIL: diagonal boundary should give alpha ~ 1\n'); fails = fails+1;
    end

    % (c) A THREE-SCALE CANTOR SET, whose dimension is known exactly.
    %     Remove the middle third (in x) at each of k levels; the boundary is
    %     the Cartesian product of the resulting Cantor set with a full line
    %     in y, so
    %         D   = 1 + log(2^k)/log(3^k) = 1 + log(2)/log(3) = 1.6309
    %         alpha = 2 - D = 1 - log(2)/log(3)           = 0.3691
    %     That makes this a quantitative test, not a qualitative one.
    D_exact = 1 + log(2)/log(3);
    a_exact = 2 - D_exact;
    Nc = 2187;                        % 3^7, so the Cantor construction is exact
    B = zeros(Nc, Nc);
    keep = true(1, Nc);
    for lev = 1:7
        w = 3^(7-lev);                % current cell width in pixels
        newKeep = keep;
        for s = 1:3:(Nc/w)
            c0 = (s-1)*w + 1;
            newKeep(c0 + w : c0 + 2*w - 1) = false;
        end
        keep = newKeep;
    end
    B(:, keep) = 1;
    R = basin_dimension(B, 'verbose', false, 'maxEps', 300, 'nEps', 30, 'nBalls', 4e5);
    fprintf('    Cantor x line        : alpha=%.4f  D=%.4f   (exact alpha=%.4f D=%.4f)\n', ...
            R.alpha, R.D, a_exact, D_exact);
    if abs(R.alpha - a_exact) > 0.06
        fprintf('    FAIL: Cantor test off by %.3f\n', abs(R.alpha-a_exact)); fails = fails+1;
    else
        fprintf('    ok  (error %.4f)\n', abs(R.alpha - a_exact));
    end

    % (d) completely random labels: the "boundary" fills the plane, so there is
    %     no scaling range left; the code must report alpha = 0, not error out.
    rng(1);
    Nn = 300;
    B = double(rand(Nn,Nn) > 0.5);
    R = basin_dimension(B, 'verbose', false, 'maxEps', 6, 'nBalls', 2e5);
    fprintf('    uncorrelated noise   : alpha=%.3f  D=%.3f  saturated=%d  (expect alpha~0)\n', ...
            R.alpha, R.D, R.saturated);
    if R.alpha > 0.4
        fprintf('    FAIL: white noise should give alpha near 0\n'); fails = fails+1;
    end

    % ---------------------------------------------------------------- 3
    % The dimension must be robust to grid resolution: a smooth boundary's
    % alpha should not drift as N changes.
    fprintf('\n[3] resolution robustness of alpha (smooth boundary)\n');
    for N2 = [300 600 1200]
        [X2, ~] = meshgrid(linspace(0,1,N2), linspace(0,1,N2));
        B = double(X2 > 0.5);
        R = basin_dimension(B, 'verbose', false, 'nBalls', 1e5);
        fprintf('    N=%5d  alpha=%.4f  D=%.4f\n', N2, R.alpha, R.D);
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_analysis:failed', '%d analysis test(s) failed', fails);
    end
end
