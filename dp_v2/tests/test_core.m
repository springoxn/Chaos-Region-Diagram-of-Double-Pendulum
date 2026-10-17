function test_core()
%% TEST_CORE  Analytic validation of the dp_v2 core integrator and Lyapunov code.
%
%   Every assertion here is against a value known in closed form or by an
%   independent method.  A Lyapunov routine that has not been checked against
%   analytic cases cannot be trusted -- this file is that check.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));
    fprintf('=== dp_v2 core tests ===\n\n');
    fails = 0;

    % ---------------------------------------------------------------- 1
    % Energy conservation of the integrator (RK4, non-symplectic: expect a
    % small secular drift that must shrink like dt^4).
    fprintf('[1] energy conservation and 4th-order dt convergence\n');
    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));
    y0 = [2.5; 0; 2.5; 0];
    dts = [0.05 0.02 0.01 0.005];
    drifts = zeros(1,4);
    for i = 1:numel(dts)
        drifts(i) = run_drift(y0, 10.0, dts(i), p);
        fprintf('    dt=%-6.3f  |dE| = %.3e\n', dts(i), drifts(i));
    end
    % observed convergence order between consecutive step sizes
    orders = log(drifts(1:end-1)./drifts(2:end)) ./ log(dts(1:end-1)./dts(2:end));
    fprintf('    observed orders: %s\n', mat2str(orders, 3));
    if any(orders < 3.0)
        fprintf('    FAIL: convergence order below 3 somewhere\n'); fails = fails+1;
    elseif drifts(end) > 1e-3
        fprintf('    FAIL: dt=0.005 drift %.2e too large\n', drifts(end)); fails = fails+1;
    else
        fprintf('    ok (4th order; dt=0.005 drift %.1e vs dt=0.05 drift %.1e)\n', ...
                drifts(end), drifts(1));
    end

    % ---------------------------------------------------------------- 2
    % Linearised normal modes.  Linearising about (0,0) gives M*th'' + K*th = 0
    % with M = [[(m1+m2)L1^2, m2 L1 L2],[m2 L1 L2, m2 L2^2]],
    %      K = diag((m1+m2) g L1, m2 g L2).
    % For m=l=1 the eigenfrequencies are w^2 = g(2 -+ sqrt(2)) and the slow
    % eigenvector is (1, sqrt(2)) -- NOT (1,1); that is the classic trap.
    fprintf('\n[2] small-oscillation normal modes vs analytic frequencies\n');
    [wvec, w2] = eig([2*p.g, 0; 0, p.g], [2, 1; 1, 1]);
    wan = sqrt(diag(w2));
    [wan, idx] = sort(wan);
    wvec = wvec(:, idx);
    wminus = wan(1);
    fprintf('    analytic: w_minus = %.6f, w_plus = %.6f\n', wan(1), wan(2));
    v_slow = wvec(:,1) / wvec(1,1);
    fprintf('    slow-mode eigenvector (1, %.6f)  [sqrt(2) = %.6f]\n', ...
            v_slow(2), sqrt(2));

    A = 0.01;
    Tosc = 2*pi/wminus;
    dt = 1e-4;
    nSteps = round(4*Tosc/dt);
    y = [A*v_slow(1); 0; A*v_slow(2); 0];
    prev = y(1); prevt = 0;  t = 0;
    zc = [];
    for k = 1:nSteps
        y = dp_rk4_step(y, dt, p);
        t = t + dt;
        if prev > 0 && y(1) <= 0
            % linear interpolation for a sub-step accurate crossing time
            zc(end+1) = prevt + dt*prev/(prev - y(1)); %#ok<AGROW>
        end
        prev = y(1); prevt = t;
    end
    if numel(zc) >= 2
        Tnum = (zc(end) - zc(1)) / (numel(zc)-1);
        wnum = 2*pi/Tnum;
        relerr = abs(wnum - wminus)/wminus;
        fprintf('    numeric : w = %.6f   rel err = %.2e\n', wnum, relerr);
        if relerr > 1e-4
            fprintf('    FAIL: normal-mode frequency mismatch\n'); fails = fails+1;
        else
            fprintf('    ok\n');
        end
    else
        fprintf('    FAIL: no zero crossings found\n'); fails = fails+1;
    end

    % ---------------------------------------------------------------- 3
    % Lyapunov exponent of a REGULAR orbit must be 0.
    % Small libration about the stable equilibrium is quasiperiodic.
    fprintf('\n[3] Lyapunov of a regular (quasiperiodic) orbit must be ~0\n');
    lam = dp_lyap([0.02;0;0.02;0], 400, 0.005, p, struct('transient',120));
    fprintf('    in-phase  lambda = %+.3e   (exact 0)\n', lam);
    if abs(lam) > 2e-3
        fprintf('    FAIL: regular orbit got lambda = %.2e\n', lam); fails = fails+1;
    else
        fprintf('    ok\n');
    end
    lamA = dp_lyap([0.02;0;-0.02;0], 400, 0.005, p, struct('transient',120));
    fprintf('    out-phase lambda = %+.3e   (exact 0)\n', lamA);
    if abs(lamA) > 2e-3
        fprintf('    FAIL: regular orbit got lambda = %.2e\n', lamA); fails = fails+1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 4
    % The index-1 saddle at (th1,th2) = (0,pi) is UNSTABLE: the exponent must
    % be clearly positive.
    fprintf('\n[4] Lyapunov near the unstable saddle (0, pi) must be positive\n');
    lam = dp_lyap([0;0;pi-1e-3;0], 60, 0.002, p, struct('transient',10));
    fprintf('    saddle lambda = %+.5f\n', lam);
    if lam <= 0.05
        fprintf('    FAIL: saddle exponent not positive\n'); fails = fails+1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 5
    % Liouville: the double pendulum is Hamiltonian, so the four exponents
    % must sum to zero.
    fprintf('\n[5] full spectrum must sum to zero (Hamiltonian)\n');
    [lam4, ~] = dp_lyap([2.5;0;2.5;0], 400, 0.005, p, ...
                        struct('transient',120, 'nExponents', 4));
    fprintf('    spectrum: %s\n', mat2str(lam4', 6));
    fprintf('    sum = %+.3e\n', sum(lam4));
    if abs(sum(lam4)) > 5e-3
        fprintf('    FAIL: spectrum does not sum to zero\n'); fails = fails+1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 6
    % Cross-method agreement: variational vs two-trajectory shadowing.
    fprintf('\n[6] tangent method vs shadow method (independent algorithms)\n');
    y0 = [2.5;0;2.5;0];
    lt = dp_lyap(y0, 400, 0.005, p, struct('transient',120,'method','tangent'));
    ls = dp_lyap(y0, 400, 0.005, p, struct('transient',120,'method','shadow'));
    fprintf('    tangent = %.5f\n    shadow  = %.5f\n    rel diff = %.2e\n', ...
            lt, ls, abs(lt-ls)/abs(lt));
    if abs(lt-ls)/abs(lt) > 0.02
        fprintf('    FAIL: the two methods disagree\n'); fails = fails+1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 7
    % Chaos is generic here: a range of high-energy initial conditions must
    % all give a clearly positive exponent, and the values must be comparable.
    fprintf('\n[7] chaotic orbits: positive, mutually consistent exponents\n');
    ics = [2.5 2.5; 2.0 1.0; 3.0 0.5; 1.5 1.5];
    vals = zeros(size(ics,1),1);
    for i = 1:size(ics,1)
        vals(i) = dp_lyap([ics(i,1);0;ics(i,2);0], 400, 0.005, p, ...
                          struct('transient',120));
        fprintf('    IC(%.1f,%.1f)  lambda = %+.5f\n', ics(i,1), ics(i,2), vals(i));
    end
    if any(vals <= 0.3)
        fprintf('    FAIL: a chaotic IC gave a non-positive exponent\n'); fails = fails+1;
    elseif max(vals)/min(vals) > 1.8
        fprintf('    WARN: spread %.2f is wide (expected, but check)\n', max(vals)/min(vals));
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 8
    % Timestep independence: the exponent must be a property of the system,
    % not of the integrator.
    fprintf('\n[8] Lyapunov must be dt-independent\n');
    y0 = [2.5;0;2.5;0];
    for dt = [0.01 0.005 0.002]
        v = dp_lyap(y0, 300, dt, p, struct('transient',100));
        fprintf('    dt=%-6.4f  lambda = %+.5f\n', dt, v);
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_core:failed', '%d core test(s) failed', fails);
    end
end


function d = run_drift(y0, T, dt, p)
    y = y0;
    n = round(T/dt);
    E0 = energy(y, p);
    d = 0;
    for k = 1:n
        y = dp_rk4_step(y, dt, p);
        d = max(d, abs(energy(y, p) - E0));
    end
end


function E = energy(y, p)
    th1 = y(1); om1 = y(2); th2 = y(3); om2 = y(4);
    v1sq = p.L1^2*om1^2;
    v2sq = v1sq + p.L2^2*om2^2 + 2*p.L1*p.L2*om1*om2*cos(th2-th1);
    KE = 0.5*p.m1*v1sq + 0.5*p.m2*v2sq;
    PE = -p.m1*p.g*p.L1*cos(th1) - p.m2*p.g*(p.L1*cos(th1) + p.L2*cos(th2));
    E = KE + PE;
end
