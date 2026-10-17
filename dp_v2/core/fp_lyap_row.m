function [lam, wnd, drift] = fp_lyap_row(th0, om0, o)
%% FP_LYAP_ROW  Lyapunov exponent and winding number for MANY initial
%%              conditions of the forced damped pendulum at once.
%%
%%   [lam, wnd, drift] = fp_lyap_row(th0, om0, o)
%%
%%   th0, om0 : 1xN initial conditions (t = 0)
%%   o        : options struct, same fields as fp_lyap:
%%              F, gamma, Omega, dt, periods, transient, reortho, progress
%%
%%   lam   : 1xN largest Lyapunov exponents
%%   wnd   : 1xN winding numbers  <omega>/Omega
%%   drift : 1xN largest |theta| wrapping residual, an accuracy diagnostic
%%
%%   Same rationale as dp_lyap_row: holding the N grid points as columns of a
%%   2xN array lets one loop body advance the whole row, so the per-call and
%%   per-step function overhead is amortised over the row instead of paid N
%%   times.  The tangent is 2-dimensional and its Jacobian is 2x2, so the
%%   product is written out inline -- for a 2x2 there is nothing to gain from a
%%   generated helper.
%%
%%   The angle is wrapped into [-pi,pi) every step.  This is exact (the field is
%%   2*pi-periodic in theta) and it keeps the roundoff floor from growing with
%%   the accumulated rotation, which matters because a rotating orbit reaches
%%   theta ~ 1e4 within a few thousand drive periods.
%%
%%   dp_v2/tests/test_speed_fp.m checks this against fp_lyap point by point.

    d = fp_row_defaults(o);
    Tdrive = 2*pi/d.Omega;
    nSteps = round(d.periods * Tdrive / d.dt);
    nTrans = round(d.transient * nSteps);

    th0 = th0(:).';  om0 = om0(:).';
    n = numel(th0);
    if numel(om0) ~= n
        error('fp_lyap_row:size', 'th0 and om0 must have the same number of elements');
    end

    TH = th0;
    OM = om0;
    % tangent: rows are (d theta, d omega), columns are grid points
    Q1 = ones(1,n);
    Q2 = zeros(1,n);

    t = 0;
    dt = d.dt;
    dt2 = 0.5*dt;  dt6 = dt/6;

    acc = zeros(1,n);
    nSamp = 0;
    wSum = zeros(1,n);
    nAvg = 0;
    drift = zeros(1,n);
    nextT = Tdrive;

    for step = 1:nSteps
        % ---- state, RK4 ----
        f1 = -d.gamma*OM - sin(TH) + d.F*cos(d.Omega*t);
        a1 = TH + dt2*OM;      b1 = OM + dt2*f1;
        f2 = -d.gamma*b1 - sin(a1) + d.F*cos(d.Omega*(t+dt2));
        a2 = TH + dt2*b1;      b2 = OM + dt2*f2;
        f3 = -d.gamma*b2 - sin(a2) + d.F*cos(d.Omega*(t+dt2));
        a3 = TH + dt*b2;       b3 = OM + dt*f3;
        f4 = -d.gamma*b3 - sin(a3) + d.F*cos(d.Omega*(t+dt));
        THn = TH + dt6*(OM + 2*b1 + 2*b2 + b3);
        Omn = OM + dt6*(f1 + 2*f2 + 2*f3 + f4);

        % ---- tangent, RK4 with J = [[0,1],[-cos(th),-gamma]] ----
        e1_1 = Q2;                       e1_2 = -cos(TH).*Q1 - d.gamma*Q2;
        r1_1 = Q1 + dt2*e1_1;            r1_2 = Q2 + dt2*e1_2;
        e2_1 = r1_2;                     e2_2 = -cos(a1).*r1_1 - d.gamma*r1_2;
        r2_1 = Q1 + dt2*e2_1;            r2_2 = Q2 + dt2*e2_2;
        e3_1 = r2_2;                     e3_2 = -cos(a2).*r2_1 - d.gamma*r2_2;
        r3_1 = Q1 + dt*e3_1;             r3_2 = Q2 + dt*e3_2;
        e4_1 = r3_2;                     e4_2 = -cos(a3).*r3_1 - d.gamma*r3_2;
        Q1n = Q1 + dt6*(e1_1 + 2*e2_1 + 2*e3_1 + e4_1);
        Q2n = Q2 + dt6*(e1_2 + 2*e2_2 + 2*e3_2 + e4_2);

        TH = THn;  OM = Omn;  Q1 = Q1n;  Q2 = Q2n;
        t = t + dt;

        % ---- exact wrap; track how far the wrap moved anything ----
        wrapped = mod(TH + pi, 2*pi) - pi;
        drift = max(drift, abs(wrapped - TH));
        TH = wrapped;

        % ---- renormalise the single tangent vector ----
        if mod(step, d.reortho) == 0
            nr = sqrt(Q1.^2 + Q2.^2);
            nr(nr == 0) = 1;
            if step > nTrans
                acc = acc + log(nr);
                nSamp = nSamp + 1;
            end
            Q1 = Q1 ./ nr;  Q2 = Q2 ./ nr;
        end

        if step > nTrans
            wSum = wSum + OM;
            nAvg = nAvg + 1;
        end
    end

    if nSamp == 0
        error('fp_lyap_row:transient', 'transient consumes the whole run');
    end

    lam = acc / (nSamp * d.reortho * dt);
    wnd = (wSum / max(1,nAvg)) / d.Omega;
end


% =========================================================================
function d = fp_row_defaults(o)
    def = struct('F',1.5, 'gamma',0.2, 'Omega',2/3, 'dt',0.01, ...
                 'periods',300, 'transient',0.3, 'reortho',10, 'progress',false);
    if nargin < 1 || isempty(o), o = struct(); end
    d = def;
    f = fieldnames(def);
    for i = 1:numel(f)
        if isfield(o, f{i}) && ~isempty(o.(f{i}))
            d.(f{i}) = o.(f{i});
        end
    end
    if d.Omega <= 0, error('fp_lyap_row:Omega', 'Omega must be positive'); end
    if d.gamma < 0,  error('fp_lyap_row:gamma', 'gamma must be non-negative'); end
    if d.dt <= 0,    error('fp_lyap_row:dt', 'dt must be positive'); end
end
