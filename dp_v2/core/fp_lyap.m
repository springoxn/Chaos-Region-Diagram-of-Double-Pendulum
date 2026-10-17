function varargout = fp_lyap(th0, om0, opts)
%% FP_LYAP  Largest Lyapunov exponent of the forced damped pendulum.
%%
%%   theta'' + gamma*theta' + sin(theta) = F*cos(Omega*t)
%%
%%   [lam, info] = fp_lyap(th0, om0)
%%   [lam, info] = fp_lyap(th0, om0, opts)
%%
%%   opts fields (with defaults)
%%     F      1.5      forcing amplitude
%%     gamma  0.2      damping
%%     Omega  2/3      drive frequency
%%     dt     0.01     fixed RK4 step
%%     periods 300     number of DRIVE PERIODS to integrate (not seconds)
%%     transient 0.3   fraction of the run discarded before averaging
%%     reortho 10      steps between reorthonormalisations
%%     method 'tangent' | 'shadow'
%%     d0     1e-10    initial separation for 'shadow'
%%
%%   lam  - largest Lyapunov exponent
%%   info - struct with diagnostics including winding number
%%
%%   The tangent space is 2-dimensional, so the variational equation is cheap;
%%   a whole map of TRUE exponents is affordable here, unlike for a method that
%%   has to difference two full trajectories at every grid point.
%%
%%   Two deliberate choices worth stating:
%%
%%   * Integration length is counted in DRIVE PERIODS, not seconds.  A fixed
%%     number of seconds silently means a different number of drive cycles at
%%     each Omega, which would make a frequency sweep incomparable with itself.
%%
%%   * `info.winding` is the measured rotation number <theta_dot>/Omega over the
%%     averaging window.  It is reported alongside the exponent because at
%%     strongly supercritical forcing (F >> F_c) essentially ALL initial
%%     conditions are chaotic; there the attractors are distinguished by their
%%     winding number, not by their exponent.  Reading the exponent alone would
%%     suggest a uniform system where there are in fact two distinct attractors.

    if nargin < 3, opts = struct(); end
    o = fp_defaults(opts);

    Tdrive = 2*pi/o.Omega;
    dt     = o.dt;
    nTotal = round(o.periods * Tdrive / dt);
    nTrans = round(o.transient * nTotal);

    if strcmpi(o.method, 'tangent')
        [lam, info] = fp_run_tangent(th0, om0, o, dt, nTotal, nTrans);
    elseif strcmpi(o.method, 'shadow')
        [lam, info] = fp_run_shadow(th0, om0, o, dt, nTotal, nTrans);
    else
        error('fp_lyap:method', 'unknown method "%s"', o.method);
    end

    varargout{1} = lam;
    if nargout > 1, varargout{2} = info; end
end


% =========================================================================
function o = fp_defaults(o)
    def = struct('F',1.5, 'gamma',0.2, 'Omega',2/3, 'dt',0.01, ...
                 'periods',300, 'transient',0.3, 'reortho',10, ...
                 'method','tangent', 'd0',1e-10);
    f = fieldnames(def);
    for i = 1:numel(f)
        if ~isfield(o, f{i}) || isempty(o.(f{i}))
            o.(f{i}) = def.(f{i});
        end
    end
    if o.Omega <= 0, error('fp_lyap:Omega','Omega must be positive'); end
    if o.gamma < 0,  error('fp_lyap:gamma','gamma must be non-negative'); end
    if o.dt <= 0,    error('fp_lyap:dt','dt must be positive'); end
end


% =========================================================================
function [lam, info] = fp_run_tangent(th0, om0, o, dt, nTotal, nTrans)
    y = [th0; om0];   t = 0;
    q = [1; 0];
    acc = 0; nSamp = 0;
    wSum = 0; nAvg = 0;

    for step = 1:nTotal
        [y, q, t] = fp_rk4(y, q, t, dt, o);

        if mod(step, o.reortho) == 0
            nr = norm(q);
            if nr > 0
                if step > nTrans
                    acc = acc + log(nr);
                    nSamp = nSamp + 1;
                end
                q = q / nr;
            end
        end
        if step > nTrans
            wSum = wSum + y(2);
            nAvg = nAvg + 1;
        end
    end

    if nSamp == 0
        error('fp_lyap:transient', 'transient consumes the whole run');
    end
    lam = acc / (nSamp * o.reortho * dt);

    info = struct('nSteps', nTotal, 'nSamples', nSamp, ...
                  'tTotal', nTotal*dt, 'periods', o.periods, ...
                  'meanOmega', wSum/max(1,nAvg), ...
                  'winding', (wSum/max(1,nAvg))/o.Omega, ...
                  'method', 'tangent');
end


% =========================================================================
function [lam, info] = fp_run_shadow(th0, om0, o, dt, nTotal, nTrans)
    d0 = o.d0;
    yA = [th0; om0];   tA = 0;
    yB = [th0 + d0; om0];  tB = 0;

    acc = 0; nSamp = 0;
    wSum = 0; nAvg = 0;

    for step = 1:nTotal
        [yA, ~, tA] = fp_rk4(yA, [], tA, dt, o);
        [yB, ~, tB] = fp_rk4(yB, [], tB, dt, o);

        d = [fp_wrapdiff(yB(1), yA(1)); yB(2) - yA(2)];
        nr = norm(d);
        if nr > 0
            if step > nTrans
                acc = acc + log(nr/d0);
                nSamp = nSamp + 1;
            end
            yB(1) = fp_wrap(yA(1) + d(1)*(d0/nr));
            yB(2) = yA(2) + d(2)*(d0/nr);
        end
        if step > nTrans
            wSum = wSum + yA(2);
            nAvg = nAvg + 1;
        end
    end

    if nSamp == 0
        error('fp_lyap:transient', 'transient consumes the whole run');
    end
    lam = acc / (nSamp * dt);

    info = struct('nSteps', nTotal, 'nSamples', nSamp, ...
                  'tTotal', nTotal*dt, 'periods', o.periods, ...
                  'meanOmega', wSum/max(1,nAvg), ...
                  'winding', (wSum/max(1,nAvg))/o.Omega, ...
                  'method', 'shadow');
end


% =========================================================================
function [y, q, t] = fp_rk4(y, q, t, dt, o)
%% FP_RK4  One RK4 step of the forced pendulum, optionally with its tangent.
%
%   rhs(y,t) = [ om ; -gamma*om - sin(th) + F*cos(Omega*t) ]
%   J(y)     = [ 0, 1 ; -cos(th), -gamma ]
%
%   Time is carried explicitly as an argument and returned.  Keeping it out of
%   persistent state is deliberate: a persistent clock would leak the drive
%   phase between calls and silently corrupt any sweep over initial conditions.
%
%   The angle is wrapped into [-pi, pi) after every step.  This is EXACT, not
%   an approximation: the vector field and its Jacobian are both 2*pi-periodic
%   in theta, so the wrapped trajectory is the same physical orbit.  It matters
%   because a rotating orbit accumulates theta ~ |w|*Omega*t; after a few
%   thousand drive periods theta reaches ~1e4, where a double has an absolute
%   spacing of ~2e-12.  Left unwrapped, that roundoff floor swamps any
%   trajectory-separation test with a perturbation smaller than ~1e-9 -- which
%   is exactly the regime the two-trajectory method operates in.

    dt2 = 0.5*dt;  dt6 = dt/6;
    wantQ = ~isempty(q);

    k1 = fp_field(y, t, o);
    k2 = fp_field(y + dt2*k1, t + dt2, o);
    k3 = fp_field(y + dt2*k2, t + dt2, o);
    k4 = fp_field(y + dt*k3,  t + dt,   o);

    if wantQ
        l1 = fp_jacq(y, q, o);
        l2 = fp_jacq(y + dt2*k1, q + dt2*l1, o);
        l3 = fp_jacq(y + dt2*k2, q + dt2*l2, o);
        l4 = fp_jacq(y + dt*k3,  q + dt*l3,  o);
        q = q + dt6*(l1 + 2*l2 + 2*l3 + l4);
    end

    y = y + dt6*(k1 + 2*k2 + 2*k3 + k4);
    y(1) = fp_wrap(y(1));
    t = t + dt;
end


function a = fp_wrap(a)
%% FP_WRAP  Map an angle to [-pi, pi).  Exact for the pendulum: the dynamics
%%          are 2*pi-periodic in theta, so this changes no physics.
    a = mod(a + pi, 2*pi) - pi;
end


function d = fp_wrapdiff(a, b)
%% FP_WRAPDIFF  Separation of two angles on the circle, in [-pi, pi).
    d = mod(a - b + pi, 2*pi) - pi;
end


function dy = fp_field(y, t, o)
    dy = [ y(2);
          -o.gamma*y(2) - sin(y(1)) + o.F*cos(o.Omega*t) ];
end


function dq = fp_jacq(y, q, o)
    dq = [ q(2);
          -cos(y(1))*q(1) - o.gamma*q(2) ];
end
