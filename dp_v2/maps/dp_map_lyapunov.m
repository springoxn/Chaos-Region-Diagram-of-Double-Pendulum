function M = dp_map_lyapunov(varargin)
%% DP_MAP_LYAPUNOV  Largest-Lyapunov-exponent map of the double pendulum.
%%
%%   M = dp_map_lyapunov
%%   M = dp_map_lyapunov('tier','preview')
%%   M = dp_map_lyapunov('N',120, 'T',120, 'dt',0.01, 'params',p)
%%
%%   Sweeps the (theta1, theta2) plane with both angular velocities ZERO and
%%   colours it by the TRUE largest Lyapunov exponent, computed from the
%%   variational equations.
%%
%%   WHY THE SLICE IS WHAT IT IS
%%   At omega = 0 the (theta1,theta2) plane is NOT an energy shell: each point
%%   sits at its own energy E = V(theta1,theta2).  So this map necessarily
%%   mixes energies and its structure partly reflects the potential-energy
%%   landscape.  That is a property of the SLICE, not of the indicator.  The
%%   static energy is returned alongside so the two can be compared directly.
%%
%%   ACCURACY TIERS
%%   A converged exponent needs T >> 1/lambda, and that is the entire cost.
%%   Rather than force every use to pay the publication price, three calibrated
%%   tiers are available (see dp_apply_tier for the measured deviations):
%%
%%     'preview'   ~8x cheaper; for interactive exploration
%%     'standard'  default; safe for figures and for any claim about which
%%                 region a point falls in
%%     'accurate'  converged reference; use when publishing a number
%%
%%   Passing 'tier' expands into N/T/dt/periods; any of those may be given
%%   explicitly as well and the explicit value wins.
%%
%%   PERFORMANCE
%%   Rows are computed with dp_lyap_row, which advances a whole row of initial
%%   conditions in lock-step so the per-call and per-step overhead is amortised
%%   over the row.  Measured 7x faster than calling dp_lyap point by point, at
%%   agreement of 5e-11 relative (tests/test_speed.m).
%%
%%   Name-value options
%%     N         64       grid points per axis
%%     T         120      integration time per point (seconds)
%%     dt        0.01     RK4 step
%%     transient 0.3      fraction of T discarded before averaging
%%     reortho   10       steps between renormalisations
%%     params    struct   m1,m2,L1,L2,g
%%     thRange   [-pi pi]
%%     tier      ''       'preview' | 'standard' | 'accurate'
%%     progress  true     print progress
%%     pool      true     use parfor when a parallel pool is available
%%
%%   Output M fields
%%     lambda, energy, drift, th1, th2, params, T, dt, N, elapsed, method,
%%     slice, tier, pointsPerSec

    o = parse_opts(varargin{:});
    o = dp_apply_tier(o);
    p = dp_check_params(o.params);

    th1v = linspace(o.thRange(1), o.thRange(2), o.N);
    th2v = linspace(o.thRange(1), o.thRange(2), o.N);

    lambda = nan(o.N, o.N);
    drift  = nan(o.N, o.N);

    ro = struct('transient', o.transient*o.T, 'reortho', o.reortho, 'progress', false);
    usePool = o.pool && has_pool();
    t0 = tic;

    if usePool
        parfor i = 1:o.N
            [lambda(i,:), drift(i,:)] = dp_lyap_row(th2v, th1v(i)*ones(1,o.N), ...
                                                    o.T, o.dt, p, ro);
        end
    else
        for i = 1:o.N
            [lambda(i,:), drift(i,:)] = dp_lyap_row(th2v, th1v(i)*ones(1,o.N), ...
                                                    o.T, o.dt, p, ro);
            if o.progress && (mod(i, max(1,round(o.N/20)))==0 || i==o.N)
                fprintf('    %5.1f%%  (%.1f s)\n', 100*i/o.N, toc(t0));
            end
        end
    end
    elapsed = toc(t0);

    [E1, E2] = meshgrid(th1v, th2v);
    energy = -p.m1*p.g*p.L1*cos(E1) - p.m2*p.g*(p.L1*cos(E1) + p.L2*cos(E2));

    M = struct('lambda', lambda, 'energy', energy, 'drift', drift, ...
               'th1', th1v, 'th2', th2v, ...
               'params', p, 'T', o.T, 'dt', o.dt, 'N', o.N, ...
               'elapsed', elapsed, 'method', 'largest Lyapunov exponent', ...
               'slice', 'omega1 = omega2 = 0', 'tier', o.tier, ...
               'pointsPerSec', o.N^2/max(elapsed,eps));

    if o.progress
        tn = o.tier; if isempty(tn), tn = 'custom'; end
        fprintf(['\n  dp_map_lyapunov: %dx%d in %.1f s  (%.0f pts/s, %.1f ms/point)' ...
                 '   tier=%s\n'], o.N, o.N, elapsed, M.pointsPerSec, ...
                 1000*elapsed/o.N^2, tn);
        fprintf('          lambda in [%.4f, %.4f], mean %.4f\n', ...
                min(lambda(:)), max(lambda(:)), mean(lambda(:)));
        fprintf('          max energy drift %.2e\n', max(drift(:)));
    end
end


% =========================================================================
function tf = has_pool()
    tf = false;
    try
        if license('test','Distrib_Computing_Toolbox')
            tf = ~isempty(gcp('nocreate'));
        end
    catch
        tf = false;
    end
end

function o = parse_opts(varargin)
    o = struct('N',120, 'T',120, 'dt',0.01, 'transient',0.3, 'reortho',10, ...
               'params',struct(), 'thRange',[-pi pi], 'progress',true, ...
               'pool',true, 'tier','');
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
        return
    end
    for i = 1:2:numel(varargin)
        if ~isfield(o, varargin{i})
            error('dp_map_lyapunov:opt', 'unknown option "%s"', varargin{i});
        end
        o.(varargin{i}) = varargin{i+1};
    end
end
