function [lam, drift] = dp_lyap_row(th1, th2, T, dt, p, opts)
%% DP_LYAP_ROW  Largest Lyapunov exponent for MANY initial conditions at once.
%%
%%   [lam, drift] = dp_lyap_row(th1, th2, T, dt, p)
%%   [lam, drift] = dp_lyap_row(th1, th2, T, dt, p, opts)
%%
%%   th1, th2 : 1xN row vectors of initial angles (angular velocities are 0)
%%   lam      : 1xN largest Lyapunov exponents
%%   drift    : max energy drift over the run, 1xN  (accuracy diagnostic)
%%
%%   opts: transient (seconds), reortho (steps), progress (logical)
%%
%%   WHY THIS IS THE FAST PATH
%%   -------------------------
%%   Calling dp_lyap once per grid point pays a fixed per-call cost (measured at
%%   about 0.07 s: argument validation, struct parsing, QR setup) on every single
%%   point.  On a 60x60 grid that is roughly 250 s of pure overhead, before any
%%   physics happens.
%%
%%   Here the N states are held as COLUMNS of a 4xN array and advanced together.
%%   One pass of the loop body serves every point in the row, so:
%%     * the per-call overhead is paid once per ROW, not once per point;
%%     * the tangent solve uses dp_jacobian_apply, which evaluates  J(y)*q  for
%%       all N points in one expression instead of forming N 4x4 matrices;
%%     * the single-exponent renormalisation is a plain division, because for one
%%       vector a QR factorisation IS just normalisation -- the measured cost of
%%       calling qr() per point per step was pure function-call overhead.
%%
%%   This computes the SAME quantity as dp_lyap with nExponents=1, and
%%   dp_v2/tests/test_speed.m asserts the two agree.
%%
%%   Only the largest exponent is available here, because that is what a map
%%   needs.  For the full spectrum use dp_lyap (which does a real QR on a small
%%   basis and is correct to keep doing so).

    if nargin < 6, opts = struct(); end
    if ~isfield(opts,'transient') || isempty(opts.transient), opts.transient = 0.3*T; end
    if ~isfield(opts,'reortho')   || isempty(opts.reortho),   opts.reortho = 10;      end
    if ~isfield(opts,'progress')  || isempty(opts.progress),  opts.progress = false;  end

    p = dp_check_params(p);

    th1 = th1(:).';  th2 = th2(:).';
    n = numel(th1);
    if numel(th2) ~= n
        error('dp_lyap_row:size', 'th1 and th2 must have the same number of elements');
    end

    nSteps = round(T/dt);
    nTrans = round(opts.transient/dt);

    % state: rows are [th1; om1; th2; om2], columns are grid points
    Y = [th1; zeros(1,n); th2; zeros(1,n)];
    % tangent: one vector per point, same layout
    Q = [ones(1,n); zeros(1,n); zeros(1,n); zeros(1,n)];

    acc = zeros(1,n);
    nSamp = 0;

    dt2 = 0.5*dt;  dt6 = dt/6;
    E0 = dp_energy_vec(Y, p);
    drift = zeros(1,n);

    for step = 1:nSteps
        % ---- RK4 on state and tangent together ----
        k1 = dp_field_vec(Y, p);
        K1 = dp_tan_vec(Y, Q, p);

        Y2 = Y + dt2*k1;
        k2 = dp_field_vec(Y2, p);
        K2 = dp_tan_vec(Y2, Q + dt2*K1, p);

        Y3 = Y + dt2*k2;
        k3 = dp_field_vec(Y3, p);
        K3 = dp_tan_vec(Y3, Q + dt2*K2, p);

        Y4 = Y + dt*k3;
        k4 = dp_field_vec(Y4, p);
        K4 = dp_tan_vec(Y4, Q + dt*K3, p);

        Y = Y + dt6*(k1 + 2*k2 + 2*k3 + k4);
        Q = Q + dt6*(K1 + 2*K2 + 2*K3 + K4);

        % ---- renormalise ----
        if mod(step, opts.reortho) == 0
            nrm = sqrt(sum(Q.^2, 1));
            nrm(nrm == 0) = 1;
            if step > nTrans
                acc = acc + log(nrm);
                nSamp = nSamp + 1;
            end
            Q = Q ./ nrm;
        end

        if mod(step, max(1,round(nSteps/25))) == 0
            drift = max(drift, abs(dp_energy_vec(Y, p) - E0));
        end
    end

    if nSamp == 0
        error('dp_lyap_row:transient', 'transient (%g s) consumes the whole run', opts.transient);
    end

    lam = acc / (nSamp * opts.reortho * dt);
end


% =========================================================================
function dY = dp_field_vec(Y, p)
%% Vectorised double-pendulum field.  Y is 4xN; dY is 4xN.
    th1 = Y(1,:);  om1 = Y(2,:);  th2 = Y(3,:);  om2 = Y(4,:);

    d  = th2 - th1;
    sd = sin(d);  cd = cos(d);
    cd2 = cd.*cd;

    den1 = (p.m1 + p.m2)*p.L1 - p.m2*p.L1*cd2;
    den2 = (p.L2/p.L1)*den1;

    a1 = ( p.m2*p.L1*om1.*om1.*sd.*cd ...
         + p.m2*p.g*sin(th2).*cd ...
         + p.m2*p.L2*om2.*om2.*sd ...
         - (p.m1 + p.m2)*p.g*sin(th1) ) ./ den1;

    a2 = ( -p.m2*p.L2*om2.*om2.*sd.*cd ...
         + (p.m1 + p.m2)*p.g*sin(th1).*cd ...
         - (p.m1 + p.m2)*p.L1*om1.*om1.*sd ...
         - (p.m1 + p.m2)*p.g*sin(th2) ) ./ den2;

    dY = [om1; a1; om2; a2];
end


% =========================================================================
function K = dp_tan_vec(Y, Q, p)
%% Vectorised tangent field  K = J(Y) * Q, both 4xN.
%
%% Uses the machine-generated dp_jacobian_apply, which expands the product so
%% that the shared denominator and trig terms are evaluated once per row rather
%% than once per point.  Measurably the dominant saving in this loop.
    K = dp_jacobian_apply(Y(1,:), Y(2,:), Y(3,:), Y(4,:), ...
                          Q(1,:), Q(2,:), Q(3,:), Q(4,:), ...
                          p.m1, p.m2, p.L1, p.L2, p.g);
end


% =========================================================================
function E = dp_energy_vec(Y, p)
%% Vectorised mechanical energy, 1xN.
    th1 = Y(1,:);  om1 = Y(2,:);  th2 = Y(3,:);  om2 = Y(4,:);
    v1sq = p.L1^2 * om1.^2;
    v2sq = v1sq + p.L2^2 * om2.^2 + 2*p.L1*p.L2*om1.*om2.*cos(th2 - th1);
    KE = 0.5*p.m1*v1sq + 0.5*p.m2*v2sq;
    PE = -p.m1*p.g*p.L1*cos(th1) - p.m2*p.g*(p.L1*cos(th1) + p.L2*cos(th2));
    E = KE + PE;
end
