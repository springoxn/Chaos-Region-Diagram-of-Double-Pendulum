function bench_baseline()
%% BENCH_BASELINE  Where does the time actually go?
%
%   Before optimizing anything we measure.  The complaint is "10x slower than
%   before", so the first job is to separate the costs that are INHERENT to
%   computing a true Lyapunov exponent from the costs that are merely an
%   artifact of how the current code is written.
%
%   Inherent: a true exponent needs a long integration (T >> 1/lambda) and a
%   tangent solve.  Nothing removes that.
%   Avoidable: per-point MATLAB call overhead, re-allocating small matrices in
%   an inner loop, and running the whole grid at production resolution when a
%   preview would answer the same question.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'));
    fprintf('=== baseline timing ===\n\n');

    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));

    % --------------------------------------------------------------
    % 1. raw integrator throughput: steps/second for a single trajectory
    % --------------------------------------------------------------
    fprintf('[1] single-trajectory integrator throughput\n');
    for dt = [0.02 0.01 0.005]
        T = 20; n = round(T/dt);
        y = [2.5;0;2.5;0]; t0 = tic;
        for k=1:n, y = dp_rk4_step(y, dt, p); end
        el = toc(t0);
        fprintf('    dt=%-6.3f  %6d steps in %.3f s  -> %.2f us/step\n', ...
                dt, n, el, 1e6*el/n);
    end

    % --------------------------------------------------------------
    % 2. Lyapunov call overhead: cost vs integration length
    %    If overhead dominated, cost would not scale with T.
    % --------------------------------------------------------------
    fprintf('\n[2] dp_lyap cost vs integration length (overhead check)\n');
    base = [];
    for T = [10 40 160 640]
        t0 = tic;
        v = dp_lyap([2.5;0;2.5;0], T, 0.01, p, struct('transient',0.3*T));
        el = toc(t0);
        base(end+1,:) = [T el]; %#ok<AGROW>
        fprintf('    T=%-5d  %7.3f s   lambda=%.4f\n', T, el, v);
    end
    % fit cost = a + b*T ; b is the marginal cost per unit T
    cf = polyfit(base(:,1), base(:,2), 1);
    fprintf('    linear fit: cost = %.4f + %.5f * T\n', cf(2), cf(1));
    fprintf('    intercept (per-call overhead) = %.4f s  (%.0f%% of T=10 cost)\n', ...
            cf(2), 100*cf(2)/base(1,2));

    % --------------------------------------------------------------
    % 3. what the per-point cost buys: steps needed per point
    % --------------------------------------------------------------
    fprintf('\n[3] why a true exponent costs more than a variance probe\n');
    Tdrive = 2*pi/(2/3);
    rows = {
      'old variance probe  (40 periods, dt=0.04)',   40*Tdrive/0.04, 0, 'no tangent'
      'new Lyapunov, T=120s, dt=0.01',              120/0.01,       0, 'with tangent+QR'
      'new Lyapunov, F=1.5 g=0.2, 250 periods',     250*Tdrive/0.01,0, 'with tangent+QR'
    };
    for i = 1:size(rows,1)
        n = rows{i,2};
        fprintf('    %-42s %8d steps  %s\n', rows{i,1}, n, rows{i,4});
    end
    r = (250*Tdrive/0.01) / (40*Tdrive/0.04);
    fprintf('    -> the forced-pendulum default needs %.0fx more steps than the\n', r);
    fprintf('       old probe, and each step now also carries a tangent solve.\n');

    % --------------------------------------------------------------
    % 4. parfor efficiency: is a row-at-a-time sweep leaving cores idle?
    % --------------------------------------------------------------
    fprintf('\n[4] parallel efficiency of the current row-based sweep\n');
    N = 12;
    th = linspace(-pi,pi,N);
    t0 = tic;
    for i=1:N
        for j=1:N
            dp_lyap([th(j);0;th(i);0], 20, 0.01, p, struct('transient',6));
        end
    end
    elSerial = toc(t0);
    fprintf('    serial  %dx%d (T=20): %.2f s  (%.1f ms/point)\n', ...
            N,N, elSerial, 1000*elSerial/N^2);
    try
        if isempty(gcp('nocreate')), parpool; end
        t0 = tic;
        parfor i=1:N
            row = zeros(1,N);
            for j=1:N
                row(j) = dp_lyap([th(j);0;th(i);0], 20, 0.01, p, struct('transient',6));
            end
        end
        elPar = toc(t0);
        nw = gcp('nocreate').NumWorkers;
        fprintf('    parfor  %dx%d (%d workers): %.2f s  -> speedup %.1fx\n', ...
                N,N, nw, elPar, elSerial/elPar);
    catch ME
        fprintf('    parfor skipped: %s\n', ME.message);
    end

    fprintf('\n=== baseline done ===\n');
end
