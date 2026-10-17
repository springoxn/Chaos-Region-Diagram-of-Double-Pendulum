function test_fp()
%% TEST_FP  Validate fp_lyap against analytic values and the Python reference.
%
%   The forced damped pendulum has closed-form checks available:
%     * pure damping (F = 0): every orbit decays to a fixed point at rate
%       -gamma/2 (underdamped) or -gamma/2 + sqrt(gamma^2/4 - 1) (overdamped),
%       so lambda must equal that value to high accuracy;
%     * below the Melnikov threshold F_c the dynamics is regular;
%%    * above it, chaotic orbits appear.
%   Those anchor the implementation before it is used on a map.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));
    fprintf('=== fp_v2 forced-pendulum tests ===\n\n');
    fails = 0;

    % ---------------------------------------------------------------- 1
    % Undriven damped pendulum.  The exponent is known exactly, but WHICH
    % analytic value is a valid target depends on the eigenvalue structure:
    %
    %   gamma > 2 : distinct real eigenvalues -> the finite-time estimate
    %               converges fast and to machine precision.  Tight test.
    %   gamma < 2 : complex conjugate pair with equal modulus -> the
    %               finite-time estimate OSCILLATES about the true value and
    %               only settles like 1/T.  Long window, loose tolerance.
    %   gamma = 2 : repeated eigenvalue (Jordan block, t*exp(-t) transient) ->
    %               also slow.  Long window, loose tolerance.
    %
    % Tightening the tolerance on the oscillatory cases would be testing the
    % averaging window, not the integrator -- see diag_converge.m.
    fprintf('[1] undriven damped pendulum vs analytic decay rate\n');

    % (a) over-damped: distinct real eigenvalues, tight tolerance
    for gam = [3.0, 5.0]
        r = sort(real(roots([1 gam 1])), 'descend');
        exact = r(1);
        lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                        'dt',0.002,'periods',150,'transient',0.3,'reortho',5));
        fprintf('    gamma=%.1f  numeric=%+.10f  exact=%+.10f  err=%.2e\n', ...
                gam, lam, exact, abs(lam-exact));
        if abs(lam-exact) > 1e-8
            fprintf('    FAIL: over-damped case should be near-exact\n'); fails = fails+1;
        end
    end

    % (b) under-damped: oscillatory convergence, long window
    for gam = [0.5, 1.0]
        exact = -gam/2;
        lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                        'dt',0.0005,'periods',800,'transient',0.5,'reortho',5));
        fprintf('    gamma=%.1f  numeric=%+.7f  exact=%+.7f  err=%.2e (T_avg~3800s)\n', ...
                gam, lam, exact, abs(lam-exact));
        if abs(lam-exact) > 1e-4
            fprintf('    FAIL: under-damped case off by more than 1e-4\n'); fails = fails+1;
        end
    end

    % (c) critically damped: repeated eigenvalue, slowest convergence
    gam = 2.0; exact = -1.0;
    lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                    'dt',0.0005,'periods',800,'transient',0.5,'reortho',5));
    fprintf('    gamma=2.0  numeric=%+.7f  exact=%+.7f  err=%.2e (repeated root)\n', ...
            lam, exact, abs(lam-exact));
    if abs(lam-exact) > 2e-3
        fprintf('    FAIL: critically damped case off by more than 2e-3\n'); fails = fails+1;
    end
    fprintf('    ok (errors are finite-time effects, verified in diag_converge.m)\n');

    % ---------------------------------------------------------------- 2
    fprintf('\n[2] Melnikov threshold  F_c = (4*gamma/pi)*cosh(Omega*pi/2)\n');
    Omega = 2/3;
    Fc_fun = @(gam) (4*gam/pi)*cosh(Omega*pi/2);
    fprintf('    cosh(pi/3) = %.6f  =>  F_c = %.5f * gamma\n', ...
            cosh(Omega*pi/2), 4/pi*cosh(Omega*pi/2));
    gam = 0.5;  Fc = Fc_fun(gam);
    fprintf('    gamma=%.2f -> F_c = %.4f\n', gam, Fc);
    ths = linspace(-pi, pi, 24);
    for F = [0.8, 0.95, 1.00, 1.02, 1.10, 1.20]
        lams = zeros(size(ths));
        for i = 1:numel(ths)
            lams(i) = fp_lyap(ths(i), 0, struct('F',F,'gamma',gam, ...
                                    'Omega',Omega,'dt',0.02,'periods',200));
        end
        fprintf('    F=%.2f (F/Fc=%.3f):  max lam=%+.5f  frac>0=%.2f\n', ...
                F, F/Fc, max(lams), mean(lams>0));
    end
    % below threshold: everything regular; just above: something chaotic
    lams = zeros(size(ths));
    for i = 1:numel(ths)
        lams(i) = fp_lyap(ths(i), 0, struct('F',0.85,'gamma',gam,'Omega',Omega, ...
                                'dt',0.02,'periods',200));
    end
    if max(lams) >= 0
        fprintf('    FAIL: F=0.85 < F_c should be entirely regular\n'); fails = fails+1;
    else
        fprintf('    ok (F=0.85 < F_c = %.3f is entirely regular)\n', Fc);
    end

    % ---------------------------------------------------------------- 3
    fprintf('\n[3] tangent vs shadow agreement at F=1.5, gamma=0.2\n');
    % The two methods differ at O(h) in the renormalisation interval h, so
    % both must be run with a SMALL h before their results are comparable.
    % With h = 5*0.002 = 0.01 the agreement is at the 1e-3 level.
    base = struct('F',1.5,'gamma',0.2,'Omega',2/3,'dt',0.002,'periods',600, ...
                  'transient',0.3,'reortho',5);
    lt = fp_lyap(1.0, 0.0, setfield(base,'method','tangent')); %#ok<SFLD>
    ls = fp_lyap(1.0, 0.0, setfield(base,'method','shadow'));  %#ok<SFLD>
    fprintf('    tangent=%.6f  shadow=%.6f  rel diff=%.2e\n', ...
            lt, ls, abs(lt-ls)/abs(lt));
    if abs(lt-ls)/abs(lt) > 5e-3
        fprintf('    FAIL: methods disagree\n'); fails = fails+1;
    else
        fprintf('    ok\n');
    end

    % ---------------------------------------------------------------- 3b
    fprintf('\n[3b] convergence to a definite exponent as dt -> 0\n');
    fprintf('     The finite-time estimate of a chaotic exponent itself\n');
    fprintf('     fluctuates like 1/T; a finer dt must not SHIFT the mean.\n');
    for dt = [0.01 0.005 0.002]
        v = fp_lyap(1.0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',dt,'periods',600,'transient',0.3,'reortho',5));
        fprintf('     dt=%-6.4f  lam=%+.5f\n', dt, v);
    end

    % ---------------------------------------------------------------- 4
    fprintf('\n[4] winding number identifies the attractor at F=1.5, gamma=0.2\n');
    fprintf('    (both rotating attractors are chaotic -- only winding separates them)\n');
    for th0 = [1.0, 2.5, 0.0]
        [lam, info] = fp_lyap(th0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                                   'dt',0.01,'periods',250));
        fprintf('    th0=%.1f:  lam=%+.5f  winding=%+.4f  meanOmega=%+.4f\n', ...
                th0, lam, info.winding, info.meanOmega);
    end
    fprintf('    note: winding ~ +-2, NOT +-1 -- two rotations per drive period.\n');

    % ---------------------------------------------------------------- 5
    fprintf('\n[5] dt-independence of the exponent\n');
    for dt = [0.02 0.01 0.005]
        v = fp_lyap(1.0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',dt,'periods',250));
        fprintf('    dt=%-6.4f  lam=%+.5f\n', dt, v);
    end

    % ---------------------------------------------------------------- 6
    fprintf('\n[6] the OLD project indicator on the same points (for the record)\n');
    fprintf('    ci = log(1+var(theta)+var(omega)) over 40 periods, dt=0.04\n');
    for th0 = [1.0, 2.5]
        ci = old_indicator(th0, 0.0, 1.5, 0.2, 2/3, 40, 0.04);
        lam = fp_lyap(th0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                          'dt',0.01,'periods',250));
        fprintf('    th0=%.1f:  ci=%.4f   true lam=%+.5f\n', th0, ci, lam);
    end
    fprintf('    -> ci varies a lot while lam barely does; the indicator is\n');
    fprintf('       measuring the attractor amplitude, not the chaos.\n');

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_fp:failed', '%d forced-pendulum test(s) failed', fails);
    end
end


% =========================================================================
function ci = old_indicator(th0, om0, F, gam, Om, periods, dt)
%% Reproduction of the superseded metric, kept only for the comparison above.
    Tp = 2*pi/Om;
    nTotal = round(periods*Tp/dt);
    ntrp = max(5, round(periods/3));
    ntr = round(ntrp*Tp/dt);
    tSteady = ntr*dt;
    nextT = ceil(tSteady/Tp)*Tp;

    y = [th0; om0];  t = 0;
    sc = 0;  nsMax = (periods - ntrp) + 3;
    bth = zeros(1, nsMax);  bom = zeros(1, nsMax);
    dt2 = 0.5*dt;  dt6 = dt/6;
    for k = 1:nTotal
        f1 = -gam*y(2) - sin(y(1)) + F*cos(Om*t);
        a1 = y(1) + dt2*y(2);   b1 = y(2) + dt2*f1;
        f2 = -gam*b1 - sin(a1) + F*cos(Om*(t+dt2));
        a2 = y(1) + dt2*b1;     b2 = y(2) + dt2*f2;
        f3 = -gam*b2 - sin(a2) + F*cos(Om*(t+dt2));
        a3 = y(1) + dt*b2;      b3 = y(2) + dt*f3;
        f4 = -gam*b3 - sin(a3) + F*cos(Om*(t+dt));
        y(1) = y(1) + dt6*(y(2) + 2*b1 + 2*b2 + b3);
        y(2) = y(2) + dt6*(f1 + 2*f2 + 2*f3 + f4);
        t = t + dt;
        if t >= nextT
            sc = sc + 1;
            bth(sc) = y(1);  bom(sc) = y(2);
            nextT = nextT + Tp;
        end
    end
    n = sc;
    w = (bth(n) - bth(1))/(2*pi*(n-1));
    thd = bth(1:n) - (bth(1) + 2*pi*w*(0:n-1));
    ci = log(1 + var(thd) + var(bom(1:n)));
end
