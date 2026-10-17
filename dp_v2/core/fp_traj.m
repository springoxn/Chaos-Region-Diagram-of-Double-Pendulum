function varargout = fp_traj(th0, om0, T, dt, opts)
%% FP_TRAJ  Integrate the forced damped pendulum for time T.
%%
%%   thetaEnd            = fp_traj(th0, om0, T, dt)
%%   thetaEnd            = fp_traj(th0, om0, T, dt, opts)
%%   [thetaEnd, omEnd]   = fp_traj(...)
%%   [theta, om, t]      = fp_traj(...)   % full trajectory when asked
%%
%%   opts fields: F, gamma, Omega (defaults 1.5, 0.2, 2/3)
%%
%%   The angle is wrapped into [-pi, pi) at every step.  This is exact -- the
%%   field is 2*pi-periodic in theta -- and it keeps the roundoff floor from
%%   growing with the accumulated rotation, which matters over long runs.

    if nargin < 5, opts = struct(); end
    if ~isfield(opts,'F')     || isempty(opts.F),     opts.F = 1.5;   end
    if ~isfield(opts,'gamma') || isempty(opts.gamma), opts.gamma = 0.2; end
    if ~isfield(opts,'Omega') || isempty(opts.Omega), opts.Omega = 2/3; end

    n = round(T / dt);
    wantFull = nargout >= 3;

    th = th0;  om = om0;  t = 0;
    if wantFull
        TH = zeros(1, n+1);  OM = zeros(1, n+1);  TT = zeros(1, n+1);
        TH(1) = th;  OM(1) = om;  TT(1) = t;
    end

    dt2 = 0.5*dt;  dt6 = dt/6;
    for k = 1:n
        f1 = -opts.gamma*om - sin(th) + opts.F*cos(opts.Omega*t);
        a1 = th + dt2*om;     b1 = om + dt2*f1;
        f2 = -opts.gamma*b1 - sin(a1) + opts.F*cos(opts.Omega*(t+dt2));
        a2 = th + dt2*b1;     b2 = om + dt2*f2;
        f3 = -opts.gamma*b2 - sin(a2) + opts.F*cos(opts.Omega*(t+dt2));
        a3 = th + dt*b2;      b3 = om + dt*f3;
        f4 = -opts.gamma*b3 - sin(a3) + opts.F*cos(opts.Omega*(t+dt));
        th = th + dt6*(om + 2*b1 + 2*b2 + b3);
        om = om + dt6*(f1 + 2*f2 + 2*f3 + f4);
        th = mod(th + pi, 2*pi) - pi;
        t = t + dt;
        if wantFull
            TH(k+1) = th;  OM(k+1) = om;  TT(k+1) = t;
        end
    end

    if wantFull
        varargout{1} = TH;  varargout{2} = OM;  varargout{3} = TT;
    else
        varargout{1} = th;
        if nargout >= 2, varargout{2} = om; end
    end
end
