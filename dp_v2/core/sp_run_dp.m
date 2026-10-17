function R = sp_run_dp(y0, T, dt, p, opts)
%% SP_RUN_DP  The chaos-indicator family for the DOUBLE pendulum, using the
%%            implicit symplectic stepper.
%%
%%   R = sp_run_dp(y0, T, dt, p)
%%   R = sp_run_dp(y0, T, dt, p, opts)
%%
%%   y0  4xN initial conditions, rows = [th1; om1; th2; om2]
%%   T   integration time
%%   dt  step
%%   p   parameter struct m1, m2, L1, L2, g
%%
%%   opts
%%     order    2        dp_imp_step order (2 = midpoint, 4 = two-stage Gauss)
%%     transient 0.3     fraction discarded before averaging
%%     nGali    4        number of deviation vectors (1..4); GALI_k uses k
%%     sample   0        sample every this many steps for the GALI series
%%
%%   R fields: lambda, mega, megabar, fli, gali, sali, galiSeries, tSeries,
%%             nVec, nSteps, order, energyDrift
%%
%%   R.sali is [] when fewer than 2 deviation vectors were tracked, because SALI
%%   is defined on exactly two (see sp_sali.m).  All other fields are always
%%   populated.
%%
%%   WHY THE DOUBLE PENDULUM IS THE CASE WHERE SALI/GALI BELONGS
%%   ----------------------------------------------------------
%%   Its tangent space is 4-dimensional, so a chaotic orbit has one positive
%%   exponent and a regular one has TWO vanishing exponents -- the degeneracy
%%   structure GALI needs.  For the 2-dimensional forced pendulum this project
%%   MEASURED a 27% false-positive rate for GALI_2 (see sp_gali.m and
%%   tests/diag_gali2d_sweep.m), so the two systems genuinely require different
%%   indicators.  Using GALI only where it is valid is the point.
%%
%%   The stepper is the implicit symplectic one because the double pendulum's
%%   Hamiltonian is not separable (its mass matrix depends on the configuration),
%%   so no explicit symplectic method exists.  See dp_imp_step.m.
%%
%%   The MEGNO accumulation follows sp_run.m exactly, including the two points
%%   that were settled by measurement there: the weight is the window-local step
%%   index, and the factor 2 makes it Eq. (6) of the reference paper.
%%
%%   See also dp_imp_step, sp_run, sp_gali, sp_sali, dp_lyap_row.

    if nargin < 5, opts = struct(); end
    o = struct('order',2, 'transient',0.3, 'nGali',4, 'sample',0);
    if isstruct(opts)
        f = fieldnames(opts);
        for i = 1:numel(f), o.(f{i}) = opts.(f{i}); end
    else
        for i = 1:2:numel(opts)
            if ~isfield(o, opts{i}), error('sp_run_dp:opt','unknown option "%s"',opts{i}); end
            o.(opts{i}) = opts{i+1};
        end
    end

    p = dp_check_params(p);
    N = size(y0, 2);
    if size(y0,1) ~= 4
        error('sp_run_dp:size', 'y0 must be 4 x N (got %d x %d)', size(y0,1), N);
    end

    nSteps = round(T/dt);
    nTrans = round(o.transient*nSteps);
    k = min(max(1,o.nGali), 4);

    y = y0;
    Q = zeros(4, k, N);
    for j = 1:k
        Q(j,j,:) = 1;
    end

    accLam = zeros(1,N); nLam = 0;
    Ysum = zeros(1,N); nMeg = 0; Ymeg = zeros(1,N); Ybar = zeros(1,N);
    lSum = zeros(1,N); fli = -inf(1,N);
    E0 = dp_hamiltonian(y0, p);
    maxDrift = 0;

    doSample = o.sample > 0;
    if doSample
        nOut = floor(nSteps/o.sample) + 2;
        gSer = nan(nOut, N);  tSer = zeros(1, nOut);  nSer = 0;
    end

    t = 0;
    for step = 1:nSteps
        [y, Q, g, t] = dp_imp_step(y, Q, t, dt, p, o.order);

        accLam = accLam + log(g(1,:));  nLam = nLam + 1;

        if step > nTrans
            nMeg = nMeg + 1;
            Ysum = Ysum + nMeg*log(g(1,:));
            Ymeg = 2*Ysum/nMeg;
            Ybar = ((nMeg-1)*Ybar + Ymeg)/nMeg;
        end

        lSum = lSum + log(g(1,:));
        fli = max(fli, lSum);

        if doSample && mod(step, o.sample) == 0
            nSer = nSer + 1;
            if nSer <= nOut
                gSer(nSer,:) = gali_k(Q, k);
                tSer(nSer) = t;
            end
        end
        if mod(step, max(1,round(nSteps/50))) == 0
            maxDrift = max(maxDrift, max(abs(dp_hamiltonian(y,p) - E0)));
        end
    end

    R = struct();
    R.lambda  = accLam/(max(1,nLam)*dt);
    R.mega    = Ymeg;
    R.megabar = Ybar;
    R.fli     = fli;
    R.gali    = gali_k(Q, k);
    % GALI for EVERY order up to k, from the same tracked vectors.  Returning
    % only GALI_k would force a caller wanting GALI_2 and GALI_4 to run the whole
    % integration twice, and -- worse -- a helper that tried to recover the lower
    % orders from the final Q alone would silently return NaN, because only the
    % final vectors are kept and the wedge of a SUBSET is not a by-product of the
    % full wedge.
    R.galiAll = nan(4, N);
    for kk = 2:k
        R.galiAll(kk,:) = gali_k(Q, kk);
    end
    R.sali    = sp_sali_safe(Q, k);
    R.nVec    = k;
    R.nSteps  = nSteps;
    R.order   = o.order;
    R.T       = T;
    R.dt      = dt;
    R.energyDrift = maxDrift;
    if doSample && nSer > 0
        R.galiSeries = gSer(1:nSer,:);
        R.tSeries    = tSer(1:nSer);
    else
        R.galiSeries = [];
        R.tSeries    = [];
    end
end


% =========================================================================
function s = sp_sali_safe(Q, k)
%% SALI needs EXACTLY two deviation vectors.  sp_run_dp documents nGali = 1..4,
%% and with nGali = 1 only one vector exists, so calling sp_sali(Q(:,1:2,:))
%% unconditionally asked for a column that is not there and raised
%% "index out of bounds" -- a dimension error at the call boundary that reads
%% like a bug in sp_sali rather than a legitimate request for a quantity that
%% simply does not exist yet.
%%
%%   SALI is a 2-vector quantity, so with fewer than 2 vectors there is nothing
%%   to report.  Returning [] (rather than a fabricated number) keeps the
%%   contract honest: every field is either measured or explicitly empty.  With
%%   k >= 2 the first two vectors are exactly the ones SALI is defined on.
    if k < 2
        s = [];
    else
        s = sp_sali(Q(:, 1:2, :));
    end
end

% =========================================================================
function g = gali_k(Q, k)
%% GALI_k per grid point.  Deviation vectors are already unit-norm because
%% dp_imp_step rescales them, so this measures pure ALIGNMENT.
    N = size(Q, 3);
    g = zeros(1, N);
    for c = 1:N
        [~, Rr] = qr(Q(:,1:k,c), 0);
        d = diag(Rr);
        if numel(d) < k
            g(c) = 0;
        else
            g(c) = abs(prod(d(1:k)));
        end
    end
end
