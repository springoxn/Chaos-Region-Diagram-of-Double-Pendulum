function varargout = fp_map(varargin)
%% FP_MAP  Map of the forced damped pendulum over the (theta, omega) plane.
%%
%%   M = fp_map('N', 300)
%%   M = fp_map('N',300, 'F',1.5, 'gamma',0.2, 'Omega',2/3)
%%
%%   Unlike the double-pendulum (theta1,theta2) slice, the (theta, omega) plane
%%   at t = 0 IS a genuine phase-space section of a single system: every point
%%   belongs to the same periodically driven flow.  So a map on this plane can
%%   legitimately be read as a picture of the dynamics.
%%
%%   ONE CALL COMPUTES THREE QUANTITIES -- there is no 'metric' switch, because
%%   the three answer different questions and are meant to be read together:
%%
%%     M.lambda   largest Lyapunov exponent      <- is the motion chaotic?
%%     M.winding  rotation number <omega>/Omega  <- WHICH attractor is reached
%%     M.basin    discrete label from the winding number, for basin analysis
%%
%%   WHY BOTH lyapunov AND winding ARE NEEDED
%%   At strongly supercritical forcing (F >> F_c) essentially every initial
%%   condition is chaotic, so the Lyapunov map is nearly uniform and looks like
%%   noise.  The structure that IS there lives in the winding number: the plane
%%   splits into basins of two counter-rotating attractors with a fractal
%%   boundary.  Reporting only the exponent would suggest a featureless system.
%%   fp_map returns all three so the user sees the full picture.
%%
%%   Name-value options
%%     N         200        grid points per axis
%%     F         1.5        forcing amplitude
%%     gamma     0.2        damping
%%     Omega     2/3        drive frequency
%%     dt        0.01       RK4 step
%%     periods   200        drive periods per point
%%     transient 0.3        fraction discarded
%%     thRange   [-pi pi]
%%     omRange   [-4 4]
%%     progress  true
%%     pool      true
%%
%%   Output M fields
%%     lambda, winding, basin, th, om, F, gamma, Omega, dt, periods, N,
%%     elapsed, MelnikovFc, supercritical, periodsDone

    o = fp_map_opts(varargin{:});
    o = dp_apply_tier(o);

    thv = linspace(o.thRange(1), o.thRange(2), o.N);
    omv = linspace(o.omRange(1), o.omRange(2), o.N);

    LAM = nan(o.N, o.N);
    WND = nan(o.N, o.N);

    % One call handles a whole row of initial conditions.  See fp_lyap_row for
    % why this is ~17x faster than a per-point loop, and test_speed_fp.m for
    % the correctness check against fp_lyap.
    ro = struct('F',o.F, 'gamma',o.gamma, 'Omega',o.Omega, 'dt',o.dt, ...
                'periods',o.periods, 'transient',o.transient, 'reortho',o.reortho);

    t0 = tic;
    usePool = o.pool && fp_has_pool();

    if usePool
        parfor i = 1:o.N
            [LAM(i,:), WND(i,:)] = fp_lyap_row(thv, omv(i)*ones(1,o.N), ro);
        end
    else
        for i = 1:o.N
            [LAM(i,:), WND(i,:)] = fp_lyap_row(thv, omv(i)*ones(1,o.N), ro);
            if o.progress && (mod(i, max(1,round(o.N/20)))==0 || i==o.N)
                fprintf('    %5.1f%%  (%.1f s)\n', 100*i/o.N, toc(t0));
            end
        end
    end
    elapsed = toc(t0);

    % basin label from the winding number: the two rotation directions
    BASIN = zeros(o.N, o.N);
    BASIN(WND >  0.5) =  1;
    BASIN(WND < -0.5) = -1;

    Fc = fp_melnikov_threshold(o.gamma, o.Omega);

    M = struct('lambda', LAM, 'winding', WND, 'basin', BASIN, ...
               'th', thv, 'om', omv, ...
               'F', o.F, 'gamma', o.gamma, 'Omega', o.Omega, ...
               'dt', o.dt, 'periods', o.periods, 'N', o.N, ...
               'elapsed', elapsed, 'MelnikovFc', Fc, ...
               'supercritical', o.F/Fc, ...
               'periodsDone', o.periods, 'tier', o.tier, ...
               'pointsPerSec', o.N^2/max(elapsed,eps));

    if o.progress
        tn = o.tier; if isempty(tn), tn = 'custom'; end
        fprintf(['\n  fp_map: %dx%d in %.1f s  (%.0f pts/s) | ' ...
                 'F=%.3f gamma=%.3f Omega=%.4f  tier=%s\n' ...
                 '          Melnikov F_c = %.4f  ->  F/F_c = %.2f\n'], ...
                o.N, o.N, elapsed, M.pointsPerSec, o.F, o.gamma, o.Omega, tn, ...
                Fc, o.F/Fc);
        fprintf('          basins: +w %d, -w %d, other %d\n', ...
                sum(BASIN(:)>0), sum(BASIN(:)<0), sum(BASIN(:)==0));
        fprintf('          lambda in [%.5f, %.5f], mean %.5f\n', ...
                min(LAM(:)), max(LAM(:)), mean(LAM(:)));
    end

    if nargout > 0, varargout{1} = M; end
end


% =========================================================================
function o = fp_map_opts(varargin)
    o = struct('N',200, 'F',1.5, 'gamma',0.2, 'Omega',2/3, 'dt',0.01, ...
               'periods',200, 'transient',0.3, 'reortho',10, ...
               'thRange',[-pi pi], 'omRange',[-4 4], 'progress',true, ...
               'pool',true, 'tier','');
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
        return
    end
    for i = 1:2:numel(varargin)
        if ~isfield(o, varargin{i})
            error('fp_map:opt', 'unknown option "%s"', varargin{i});
        end
        o.(varargin{i}) = varargin{i+1};
    end
end


function tf = fp_has_pool()
    tf = false;
    try
        licensed = license('test','Distrib_Computing_Toolbox');
        if licensed
            tf = ~isempty(gcp('nocreate'));
        end
    catch
        tf = false;
    end
end
