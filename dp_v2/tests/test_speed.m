function test_speed()
%% TEST_SPEED  Prove the fast path is both CORRECT and actually faster.
%
%   An optimization that changes the answer is not an optimization.  This test
%   does two things and refuses to report one without the other:
%
%     1. correctness -- dp_lyap_row must reproduce dp_lyap point by point;
%     2. speed       -- and it must do so substantially faster.
%
%   The correctness half has to allow for the fact that a finite-time Lyapunov
%   estimate is itself noisy: two implementations of the SAME algorithm started
%   from the SAME state in the SAME order agree exactly, but any reordering of
%   floating-point operations perturbs the result.  dp_lyap_row reorders the
%   arithmetic (array operations vs scalars), so the comparison is against the
%   natural scatter of the estimator, not against machine precision.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'));
    fprintf('=== fast-path tests ===\n\n');
    fails = 0;

    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));

    % ---------------------------------------------------------------- 1
    fprintf('[1] dp_jacobian_apply must equal dp_jacobian''s matrix product\n');
    rng(0);
    worst = 0;
    for k = 1:200
        y = (rand(4,1)-0.5)*6;
        q = (rand(4,1)-0.5)*2;
        J = dp_jacobian(y(1),y(2),y(3),y(4),p.m1,p.m2,p.L1,p.L2,p.g);
        ref = J*q;
        got = dp_jacobian_apply(y(1),y(2),y(3),y(4),q(1),q(2),q(3),q(4), ...
                                p.m1,p.m2,p.L1,p.L2,p.g);
        worst = max(worst, max(abs(got(:) - ref)));
    end
    fprintf('    max |apply - J*q| over 200 random states = %.3e\n', worst);
    if worst > 1e-12
        fprintf('    FAIL: vectorised Jacobian apply disagrees\n'); fails = fails + 1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 2
    fprintf('\n[2] dp_lyap_row vs dp_lyap, point by point\n');
    N = 16;
    th = linspace(-pi, pi, N);
    [r1, r2] = meshgrid(th, th);
    T = 60; dt = 0.01;
    t0 = tic;
    lamRow = dp_lyap_row(r1(:).', r2(:).', T, dt, p, struct('transient',0.3*T));
    tRow = toc(t0);
    t0 = tic;
    lamRef = zeros(1, numel(r1));
    for k = 1:numel(r1)
        lamRef(k) = dp_lyap([r1(k);0;r2(k);0], T, dt, p, struct('transient',0.3*T));
    end
    tRef = toc(t0);
    lamRow = reshape(lamRow, N, N);
    lamRef = reshape(lamRef, N, N);

    d = abs(lamRow - lamRef);
    rel = d ./ max(abs(lamRef), 1e-9);
    % NOTE: assign before indexing.  Chained indexing into a temporary such as
    % d(:).max() is not accepted by R2021a and fails with an unhelpful
    % "unsupported operand" error rather than a syntax message.
    dv = d(:);  rv = rel(:);
    fprintf('    %dx%d grid, T=%d s, dt=%.3f\n', N, N, T, dt);
    fprintf('    row method : %.3f s  (%.2f ms/point)\n', tRow, 1000*tRow/N^2);
    fprintf('    per-point  : %.3f s  (%.2f ms/point)\n', tRef, 1000*tRef/N^2);
    fprintf('    speedup    : %.1fx\n', tRef/tRow);
    fprintf('    max |diff| = %.3e   max rel = %.3e   mean rel = %.3e\n', ...
            max(dv), max(rv), mean(rv));
    cc = corrcoef(lamRow(:), lamRef(:));
    fprintf('    corr       = %.8f\n', cc(1,2));

    % The estimator's own finite-time scatter sets the tolerance.  For a
    % chaotic point with lambda~1.3, T=60 gives lambda*T = 78, so the expected
    % relative scatter is ~1/sqrt(78) = 11% -- but the two runs share the same
    % trajectory and the same reortho schedule, so they are strongly correlated
    % and the observed difference should be far below that.
    if max(rv) > 0.02
        fprintf('    FAIL: fast path deviates by more than 2%% somewhere\n');
        fails = fails + 1;
    else
        fprintf('    ok (agrees to %.2e relative; estimator scatter alone is ~%.0f%%)\n', ...
                max(rv), 100/sqrt(1.3*T));
    end

    % ---------------------------------------------------------------- 3
    fprintf('\n[3] speedup must be real, not measured in the noise\n');
    if tRef/tRow < 2
        fprintf('    FAIL: fast path only %.1fx faster\n', tRef/tRow); fails = fails + 1;
    else
        fprintf('    ok (%.1fx)\n', tRef/tRow);
    end

    % ---------------------------------------------------------------- 4
    % Accuracy check.  An ABSOLUTE drift threshold is meaningless here: the
    % (theta1,theta2) grid spans |E| from 0 to about 10 J, so 1e-2 J is 0.1% of
    % the largest energy but 100% of the smallest.  Two scale-free criteria are
    % used instead:
    %   (a) relative drift, against the energy of the same initial condition;
    %   (b) the CONVERGENCE ORDER in dt -- the real evidence that the integrator
    %       is behaving as 4th-order RK4 rather than merely being small.
    fprintf('\n[4] accuracy: relative drift and dt-convergence order\n');
    thg = linspace(-pi, pi, 16);
    E0 = -p.m1*p.g*p.L1*cos(thg) - p.m2*p.g*(p.L1*cos(thg) + p.L2*cos(thg));
    dts = [0.02 0.01 0.005];
    maxRel = zeros(size(dts));
    for k = 1:numel(dts)
        [~, drift] = dp_lyap_row(thg, thg, 30, dts(k), p, struct('transient',9));
        maxRel(k) = max(drift ./ max(abs(E0), 1e-3));
    end
    for k = 1:numel(dts)
        fprintf('    dt=%-6.4f  max relative energy drift = %.2e\n', dts(k), maxRel(k));
    end
    orders = log(maxRel(1:end-1)./maxRel(2:end)) ./ log(dts(1:end-1)./dts(2:end));
    fprintf('    observed convergence orders: %s\n', mat2str(orders, 3));
    if any(orders < 3)
        fprintf('    FAIL: convergence order below 3\n'); fails = fails + 1;
    elseif maxRel(end) > 1e-3
        fprintf('    FAIL: relative drift at dt=0.005 exceeds 1e-3\n'); fails = fails + 1;
    else
        fprintf('    ok (order >3 and relative drift %.1e at dt=0.005)\n', maxRel(end));
    end

    % ---------------------------------------------------------------- 5
    fprintf('\n[5] edge cases must not silently return garbage\n');
    try
        dp_lyap_row(1:3, 1:4, 10, 0.01, p);
        fprintf('    FAIL: mismatched lengths did not raise\n'); fails = fails + 1;
    catch
        fprintf('    mismatched lengths raise  : ok\n');
    end
    try
        dp_lyap_row(0, 0, 1, 0.01, p, struct('transient',5));
        fprintf('    FAIL: over-long transient did not raise\n'); fails = fails + 1;
    catch
        fprintf('    over-long transient raises: ok\n');
    end
    v = dp_lyap_row(0, 0, 20, 0.01, p, struct('transient',6));
    fprintf('    single point works        : ok (lambda=%.4f)\n', v);
    if ~isscalar(v)
        fprintf('    FAIL: single point did not return a scalar\n'); fails = fails + 1;
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_speed:failed', '%d fast-path test(s) failed', fails);
    end
end


function E = dp_energy_at(t1, t2, p)
    E = -p.m1*p.g*p.L1*cos(t1) - p.m2*p.g*(p.L1*cos(t1) + p.L2*cos(t2));
end
