function R = sp_compare_dp(varargin)
%% SP_COMPARE_DP  Double pendulum: does GALI/SALI track the TRUE Lyapunov
%%                exponent, and does the superseded log(1+var) fail?
%%
%%   R = sp_compare_dp()
%%   R = sp_compare_dp('N',16, 'T',40, 'dt',0.02)
%%
%%   THE MEASUREMENT
%%   ---------------
%%   For a grid of (th1, th2) initial conditions with om1 = om2 = 0, compute
%%        lambda   true largest Lyapunov exponent   (reference)
%%        gali2/3/4  alignment indices at the final time
%%        mega     MEGNO
%%        ci       log(1+var(th1)+var(th2)), the superseded indicator
%%   and report Spearman rank correlations between each candidate and lambda.
%%
%%   WHY THE DOUBLE PENDULUM IS THE DECISIVE CASE FOR SALI/GALI
%%   ----------------------------------------------------------
%%   Its tangent space is 4-dimensional: a chaotic orbit has lambda_1 > 0 and a
%%   regular one has TWO vanishing exponents.  That is exactly the degeneracy
%%   structure GALI exploits, and exactly what the 2-dimensional forced pendulum
%%   lacks (where this project measured a 27% false-positive rate for GALI_2 --
%%   see sp_gali.m and tests/diag_gali2d_sweep.m).
%%
%%   So the two systems test opposite things, and this function is the one that
%%   can actually justify calling GALI a chaos indicator:
%%
%%     forced pendulum  -> GALI_2 fails; MEGNO / OFLI2 / IACF work
%%     double pendulum  -> GALI should work; this measures it
%%
%%   A CAVEAT ON THE SLICE
%%   ---------------------
%%   (th1, th2) at zero angular velocity is NOT an energy shell, so lambda varies
%%   with the initial condition for two reasons at once (chaos AND energy).  That
%%   makes the correlation a fair test of "does the indicator rank points the same
%%   way the true exponent does", which is what a map needs, but it does NOT mean
%%   the indicator measures energy.  dp_map_lyapunov.m's documentation makes the
%%   same point.
%%
%%   Options
%%     N      14     grid points per axis
%%     T      40     integration time per point
%%     dt     0.02
%%     order  2      dp_imp_step order
%%     params struct m1, m2, L1, L2, g
%%     verbose true
%%
%%   See also sp_run_dp, dp_lyap_row, sp_gali, sp_map_dp.

    o = struct('N',14, 'T',40, 'dt',0.02, 'order',2, ...
               'params',struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81), ...
               'verbose',true, 'nGali',4);
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_compare_dp:opt','unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    p = dp_check_params(o.params);
    th1v = linspace(-pi, pi, o.N);
    th2v = linspace(-pi, pi, o.N);

    LAM = nan(o.N,o.N); G2 = nan(o.N,o.N); G3 = nan(o.N,o.N); G4 = nan(o.N,o.N);
    MG = nan(o.N,o.N); CI = nan(o.N,o.N);

    fprintf('double pendulum: %dx%d, T=%g, dt=%g, order=%d\n', ...
            o.N, o.N, o.T, o.dt, o.order);
    t0 = tic;
    for i = 1:o.N
        % Row i fixes th1 = th1v(i) and sweeps th2 along the row.  The first
        % version used [th1v; 0; th2v; 0], which advances only the DIAGONAL of the
        % plane (rank 1: 3 distinct values out of 36 at N = 6), so what was
        % correlated was one line of initial conditions replicated N times -- not
        % a grid.  The correlations below are computed over N^2 points and need
        % N^2 genuinely distinct states.  Splitting the two coordinates is what
        % makes this the same slice dp_map_lyapunov.m and sp_map_dp.m use.
        y0 = [th1v(i)*ones(1,o.N); zeros(1,o.N); th2v; zeros(1,o.N)];
        Rr = sp_run_dp(y0, o.T, o.dt, p, struct('order',o.order, 'nGali',o.nGali));
        LAM(i,:) = Rr.lambda;
        MG(i,:)  = Rr.mega;
        G2(i,:)  = Rr.galiAll(2,:);
        if size(Rr.galiAll,1) >= 3, G3(i,:) = Rr.galiAll(3,:); end
        if size(Rr.galiAll,1) >= 4, G4(i,:) = Rr.galiAll(4,:); end
        for j = 1:o.N
            CI(i,j) = old_ci_dp(y0(:,j), 10, 0.05, p);
        end
        if o.verbose && mod(i, max(1,round(o.N/4))) == 0
            fprintf('  %3.0f%%  (%.1f s)\n', 100*i/o.N, toc(t0));
        end
    end

    lam = LAM(:);
    names = {'ci','mega','gali2','gali3','gali4'};
    vals  = {CI(:), MG(:), G2(:), G3(:), G4(:)};
    fprintf('\n%-10s %9s %9s %9s %8s\n', 'indicator', 'Spearman', 'Pearson', 'n', 'range');
    tab = struct();
    for k = 1:numel(names)
        v = vals{k};
        ok = isfinite(v) & isfinite(lam);
        if sum(ok) < 5 || std(v(ok)) == 0 || std(lam(ok)) == 0
            tab.(names{k}) = struct('spearman',NaN,'pearson',NaN,'n',sum(ok));
            fprintf('%-10s %9s\n', names{k}, 'n/a');
            continue
        end
        rs = corr(v(ok), lam(ok), 'type','Spearman');
        rp = corr(v(ok), lam(ok), 'type','Pearson');
        tab.(names{k}) = struct('spearman',rs,'pearson',rp,'n',sum(ok));
        fprintf('%-10s %+9.3f %+9.3f %8d  [%.2f,%.2f]\n', ...
                names{k}, rs, rp, sum(ok), min(v(ok)), max(v(ok)));
    end
    fprintf('\nlambda range on this slice: [%.4f, %.4f]\n', min(lam), max(lam));
    fprintf(['SIGN CONVENTION: lambda positive means chaotic, and GALI decays to\n' ...
             'zero for chaos, so a WORKING GALI must correlate NEGATIVELY with\n' ...
             'lambda.  A working amplitude proxy would correlate POSITIVELY.\n']);

    R = struct('lambda',LAM, 'ci',CI, 'mega',MG, 'gali2',G2, 'gali3',G3, ...
               'gali4',G4, 'corr',tab, 'settings',o, 'th1',th1v, 'th2',th2v, ...
               'elapsed',toc(t0));
end


% =========================================================================
function ci = old_ci_dp(y0, T, dt, p)
%% The superseded indicator from compute_chaos_index.m, reproduced verbatim:
%% log(1 + var(th1) + var(th2)) over the last two thirds, theta unwrapped.
    n = round(T/dt);
    y = y0;
    th1 = zeros(1,n); th2 = zeros(1,n);
    dt2 = 0.5*dt; dt6 = dt/6;
    for k = 1:n
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
