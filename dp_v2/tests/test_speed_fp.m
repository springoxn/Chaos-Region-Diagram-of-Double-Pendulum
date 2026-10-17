function test_speed_fp()
%% TEST_SPEED_FP  Correctness and speed of the forced-pendulum fast path.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'));
    fprintf('=== forced-pendulum fast-path tests ===\n\n');
    fails = 0;

    o = struct('F',1.5,'gamma',0.2,'Omega',2/3,'dt',0.01,'periods',80,'transient',0.3);

    % ---------------------------------------------------------------- 1
    fprintf('[1] fp_lyap_row vs fp_lyap, point by point\n');
    N = 12;
    th = linspace(-pi, pi, N);
    om = linspace(-4, 4, N);
    [TH, OM] = meshgrid(th, om);

    t0 = tic;
    [lamRow, wndRow] = fp_lyap_row(TH(:).', OM(:).', o);
    tRow = toc(t0);

    t0 = tic;
    lamRef = zeros(1, numel(TH));  wndRef = zeros(1, numel(TH));
    for k = 1:numel(TH)
        [v, info] = fp_lyap(TH(k), OM(k), o);
        lamRef(k) = v;  wndRef(k) = info.winding;
    end
    tRef = toc(t0);

    dL = abs(lamRow - lamRef);  dW = abs(wndRow - wndRef);
    fprintf('    %dx%d grid, %d periods, dt=%.3f\n', N, N, o.periods, o.dt);
    fprintf('    row method : %.3f s  (%.2f ms/point)\n', tRow, 1000*tRow/N^2);
    fprintf('    per-point  : %.3f s  (%.2f ms/point)\n', tRef, 1000*tRef/N^2);
    fprintf('    speedup    : %.1fx\n', tRef/tRow);
    fprintf('    lambda   max|diff| = %.3e\n', max(dL));
    fprintf('    winding  max|diff| = %.3e\n', max(dW));
    if max(dL) > 1e-9
        fprintf('    FAIL: lambda disagrees\n'); fails = fails + 1;
    elseif max(dW) > 1e-9
        fprintf('    FAIL: winding disagrees\n'); fails = fails + 1;
    else
        fprintf('    ok (both agree to near machine precision)\n');
    end

    % ---------------------------------------------------------------- 2
    fprintf('\n[2] winding must be a sharp invariant, not an approximate one\n');
    fprintf('    (it is a property of the attractor: a whole basin shares one value)\n');
    m1 = wndRow > 0.5;  m2 = wndRow < -0.5;
    fprintf('    +w basin: %d points, w in [%.6f, %.6f]\n', ...
            sum(m1), min(wndRow(m1)), max(wndRow(m1)));
    fprintf('    -w basin: %d points, w in [%.6f, %.6f]\n', ...
            sum(m2), min(wndRow(m2)), max(wndRow(m2)));
    if sum(m1) && (max(wndRow(m1)) - min(wndRow(m1))) > 1e-2
        fprintf('    FAIL: +w basin is not sharp\n'); fails = fails + 1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 3
    fprintf('\n[3] speedup must be real\n');
    if tRef/tRow < 2
        fprintf('    FAIL: only %.1fx faster\n', tRef/tRow); fails = fails + 1;
    else
        fprintf('    ok (%.1fx)\n', tRef/tRow);
    end

    % ---------------------------------------------------------------- 4
    fprintf('\n[4] angle wrap must be exact, not an approximation\n');
    [~, ~, drift] = fp_lyap_row(th.', om.'.*0, o);
    fprintf('    max |wrapped - unwrapped| over the run = %.3e\n', max(drift));
    fprintf('    (should be <= 2*pi: the wrap only ever moves theta by one period)\n');
    if max(drift) > 2*pi + 1e-9
        fprintf('    FAIL: wrap moved theta by more than one period\n'); fails = fails + 1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 5
    fprintf('\n[5] edge cases\n');
    try
        fp_lyap_row(1:3, 1:4, o);
        fprintf('    FAIL: mismatched lengths did not raise\n'); fails = fails + 1;
    catch
        fprintf('    mismatched lengths raise  : ok\n');
    end
    try
        fp_lyap_row(0, 0, struct('periods',2,'transient',5));
        fprintf('    FAIL: over-long transient did not raise\n'); fails = fails + 1;
    catch
        fprintf('    over-long transient raises: ok\n');
    end
    [v, w] = fp_lyap_row(1, 0, o);
    fprintf('    single point works        : ok (lambda=%.5f, w=%.4f)\n', v, w);
    if ~isscalar(v) || ~isscalar(w)
        fprintf('    FAIL: single point did not return scalars\n'); fails = fails + 1;
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_speed_fp:failed', '%d test(s) failed', fails);
    end
end
