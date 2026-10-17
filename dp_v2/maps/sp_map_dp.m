function M = sp_map_dp(varargin)
%% SP_MAP_DP  GALI / MEGNO map of the double pendulum on the (th1, th2) plane,
%%            computed with the implicit symplectic stepper.
%%
%%   M = sp_map_dp()
%%   M = sp_map_dp('N',120, 'T',120, 'dt',0.01, 'order',2)
%%
%%   This is the 4-dimensional counterpart of fp_map.m.  The existing
%%   dp_map_lyapunov.m already maps the Lyapunov exponent with RK4; this map
%%   exists to show the indicator family that the RK4 map cannot provide, and to
%%   demonstrate that the symplectic stepper is fast enough to be used for maps
%%   rather than only for single trajectories.
%%
%%   WHAT IT ADDS OVER dp_map_lyapunov.m
%%   -----------------------------------
%%     * GALI_k for k = 2, 3, 4.  Alignment indices need several deviation
%%       vectors and a 4-dimensional tangent space; the double pendulum has one,
%%       the forced pendulum does not (see sp_gali.m).
%%     * MEGNO, which needs no calibration orbit.
%%     * A comparison column: the SAME initial conditions evaluated with the
%%       SUPERSEDED indicator log(1+var), so the replacement is visible in one
%%       figure rather than asserted in prose.
%%     * An energy-drift diagnostic from the symplectic stepper itself.
%%
%%   Name-value options
%%     N        80      grid points per axis
%%     T        60      integration time per point
%%     dt       0.02    step
%%     order    2       dp_imp_step order
%%     params   struct  m1, m2, L1, L2, g
%%     om0      [0 0]   both angular velocities at the slice
%%     progress true
%%
%%   Output M fields
%%     gali2, gali3, gali4, mega, lambda, ci, th1, th2, settings, elapsed,
%%     energyDrift
%%
%%   THE SLICE IS NOT AN ENERGY SHELL -- STATED BECAUSE IT IS EASY TO MISREAD
%%   ----------------------------------------------------------------------
%%   Fixing om1 = om2 = 0 makes every grid point a DIFFERENT energy, exactly as
%%   README.md warns for the existing (th1, th2) maps.  A map here therefore
%%   shows how the indicators vary over a range of energies, not the structure
%%   of one energy surface.  It is the same slice the project already uses, so
%%   the new maps are comparable with the old ones.
%%
%%   See also sp_run_dp, dp_map_lyapunov, dp_lab, sp_compare_dp.

    o = struct('N',80, 'T',60, 'dt',0.02, 'order',2, ...
               'params',struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81), ...
               'om0',[0 0], 'thRange',[-pi pi], 'progress',true, ...
               'nGali',4, 'ciChecks',true);
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_map_dp:opt','unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    p = dp_check_params(o.params);
    th1v = linspace(o.thRange(1), o.thRange(2), o.N);
    th2v = linspace(o.thRange(1), o.thRange(2), o.N);

    G2 = nan(o.N,o.N); G3 = nan(o.N,o.N); G4 = nan(o.N,o.N);
    MG = nan(o.N,o.N); LM = nan(o.N,o.N); CI = nan(o.N,o.N);
    drift = 0;

    t0 = tic;
    for i = 1:o.N
        % ROW i HOLDS th1 FIXED AND SWEEPS th2 ALONG THE ROW.
        %
        % The first version of this file built
        %     y0 = [th1v; om0(1)*ones(1,N); th2v; om0(2)*ones(1,N)]
        % which advances the DIAGONAL of the (th1, th2) plane: th1 and th2 come
        % from the same index, so the state varies along one line rather than over
        % a grid.  Every row was then the identical diagonal replicated N times,
        % and the resulting "map" had rank 1 -- measured on a 6x6 grid, 3 distinct
        % values out of 36, with every row bitwise equal to the first.
        %
        % Nothing errored, and the map still looked like a plausible image because
        % the diagonal does carry real structure.  This is the same slicing
        % convention dp_map_lyapunov.m uses (th2 sweeps the row, th1 selects it),
        % which is what makes the two maps directly comparable -- and the
        % comparison is the reason this file exists.
        y0 = [th1v(i)*ones(1,o.N); o.om0(1)*ones(1,o.N); ...
              th2v;                o.om0(2)*ones(1,o.N)];
        R = sp_run_dp(y0, o.T, o.dt, p, struct('order',o.order, 'nGali',4));
        LM(i,:) = R.lambda;
        MG(i,:) = R.mega;
        drift = max(drift, R.energyDrift);
        % GALI for every order comes straight from the run: sp_run_dp returns
        % galiAll(k,:) for each k up to the number of tracked vectors.  Recovering
        % GALI_2 from a run that tracked 4 vectors is NOT possible from the final
        % state alone -- the wedge of a subset is not a by-product of the full
        % wedge -- so the lower orders must be accumulated during the run.
        G2(i,:) = R.galiAll(2,:);
        if size(R.galiAll,1) >= 3, G3(i,:) = R.galiAll(3,:); end
        if size(R.galiAll,1) >= 4, G4(i,:) = R.galiAll(4,:); end
        if o.ciChecks
            for j = 1:o.N
                CI(i,j) = old_ci_dp(y0(:,j), min(o.T, 10), 0.05, p);
            end
        end
        if o.progress && mod(i, max(1,round(o.N/10))) == 0
            fprintf('    sp_map_dp %3.0f%%  (%.1f s)\n', 100*i/o.N, toc(t0));
        end
    end
    elapsed = toc(t0);

    M = struct('gali2',G2, 'gali3',G3, 'gali4',G4, 'mega',MG, ...
               'lambda',LM, 'ci',CI, 'th1',th1v, 'th2',th2v, ...
               'settings',o, 'elapsed',elapsed, 'energyDrift',drift, ...
               'params',p);
end


% =========================================================================
function ci = old_ci_dp(y0, T, dt, p)
%% The superseded indicator for the double pendulum, from the ORIGINAL
%% definition in compute_chaos_index.m: log(1 + var(th1) + var(th2)) over the
%% last two thirds of the trajectory, with theta left unwrapped.
%%
%%   Kept deliberately: the comparison figure is meaningless if the thing being
%%   replaced is reimplemented differently from the original.
    n = round(T/dt);
    y = y0;
    th1 = zeros(1,n); th2 = zeros(1,n);
    for k = 1:n
        dt2 = 0.5*dt; dt6 = dt/6;
        k1 = dp_field_dyn(y, p);
        k2 = dp_field_dyn(y + dt2*k1, p);
        k3 = dp_field_dyn(y + dt2*k2, p);
        k4 = dp_field_dyn(y + dt*k3, p);
        y = y + dt6*(k1 + 2*k2 + 2*k3 + k4);
        th1(k) = y(1);  th2(k) = y(3);
    end
    i0 = round(n/3) + 1;
    ci = log(1 + var(th1(i0:end)) + var(th2(i0:end)));
end
