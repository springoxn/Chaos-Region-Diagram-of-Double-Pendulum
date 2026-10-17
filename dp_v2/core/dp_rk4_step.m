function varargout = dp_rk4_step(y, dt, p, Phi)
%% DP_RK4_STEP  One classical RK4 step of the double pendulum, with tangent flow.
%%
%%   y    - state, 4x1 = [th1; om1; th2; om2]  (or 4xN for a vectorised sweep)
%%   dt   - step size
%%   p    - parameter struct: m1, m2, L1, L2, g
%%   Phi  - (optional) tangent matrix, 4x4 (or 4x4xN).  When supplied, the
%%          step also propagates  Phi' = J(y) Phi  with the SAME RK4 stages.
%%
%%   y_new        = dp_rk4_step(y, dt, p)
%%   [y_new, Phin] = dp_rk4_step(y, dt, p, Phi)
%%
%%   Why propagate the tangent inside the same loop: the variational equation
%%   must be integrated with a scheme consistent with the trajectory's, or the
%%   Lyapunov exponent inherits the mismatch as a systematic error.  Sharing
%%   the stages costs nothing extra in the vector field evaluations.
%%
%%   The Jacobian comes from dp_jacobian (machine-generated, analytic) rather
%%   than from finite differences -- see that file's header.

    if nargin < 4 || isempty(Phi)
        want_tangent = false;
    else
        want_tangent = true;
    end

    dt2 = 0.5 * dt;
    dt6 = dt / 6;

    % ---- stage 1 ----
    k1 = dp_field(y, p);
    if want_tangent
        K1 = dp_tangent(y, p, Phi);
    end

    % ---- stage 2 ----
    y2 = y + dt2 * k1;
    k2 = dp_field(y2, p);
    if want_tangent
        K2 = dp_tangent(y2, p, Phi + dt2 * K1);
    end

    % ---- stage 3 ----
    y3 = y + dt2 * k2;
    k3 = dp_field(y3, p);
    if want_tangent
        K3 = dp_tangent(y3, p, Phi + dt2 * K2);
    end

    % ---- stage 4 ----
    y4 = y + dt * k3;
    k4 = dp_field(y4, p);
    if want_tangent
        K4 = dp_tangent(y4, p, Phi + dt * K3);
    end

    y = y + dt6 * (k1 + 2*k2 + 2*k3 + k4);

    if want_tangent
        Phin = Phi + dt6 * (K1 + 2*K2 + 2*K3 + K4);
        varargout{1} = y;
        varargout{2} = Phin;
    else
        varargout{1} = y;
    end
end


function dy = dp_field(y, p)
%% DP_FIELD  Right-hand side of the double pendulum, written once, used everywhere.
%
%   th1'' = ( m2*L1*th1'^2*sin(d)cos(d) + m2*g*sin(th2)*cos(d)
%             + m2*L2*th2'^2*sin(d) - (m1+m2)*g*sin(th1) ) / den1
%   th2'' = ( -m2*L2*th2'^2*sin(d)cos(d) + (m1+m2)*g*sin(th1)*cos(d)
%             - (m1+m2)*L1*th1'^2*sin(d) - (m1+m2)*g*sin(th2) ) / den2
%   den1 = (m1+m2)*L1 - m2*L1*cos(d)^2 ,  den2 = (L2/L1)*den1 ,  d = th2-th1
%
%   Verified symbolically against the Euler-Lagrange equations in
%   verification/derive_dp_eom.py (difference identically zero).

    th1 = y(1,:);  om1 = y(2,:);
    th2 = y(3,:);  om2 = y(4,:);

    d   = th2 - th1;
    sd  = sin(d);
    cd  = cos(d);

    den1 = (p.m1 + p.m2)*p.L1 - p.m2*p.L1*cd.*cd;
    den2 = (p.L2/p.L1)*den1;

    a1 = ( p.m2*p.L1*om1.*om1.*sd.*cd ...
         + p.m2*p.g*sin(th2).*cd ...
         + p.m2*p.L2*om2.*om2.*sd ...
         - (p.m1 + p.m2)*p.g*sin(th1) ) ./ den1;

    a2 = ( -p.m2*p.L2*om2.*om2.*sd.*cd ...
         + (p.m1 + p.m2)*p.g*sin(th1).*cd ...
         - (p.m1 + p.m2)*p.L1*om1.*om1.*sd ...
         - (p.m1 + p.m2)*p.g*sin(th2) ) ./ den2;

    dy = [om1; a1; om2; a2];
end


function K = dp_tangent(y, p, Phi)
%% DP_TANGENT  Right-hand side of the variational equation  Phi' = J(y) Phi.
%
%   Handles both a single 4x4 Phi and a stacked 4x4xN sweep.  For the stacked
%   case each column of each slice uses the y of the matching column, so a
%   whole row of initial conditions can be swept in lock-step.

    if ndims(Phi) == 2
        J = dp_jacobian(y(1), y(2), y(3), y(4), p.m1, p.m2, p.L1, p.L2, p.g);
        K = J * Phi;
    else
        n = size(Phi, 3);
        K = zeros(4, 4, n);
        for i = 1:n
            J = dp_jacobian(y(1,i), y(2,i), y(3,i), y(4,i), ...
                            p.m1, p.m2, p.L1, p.L2, p.g);
            K(:,:,i) = J * Phi(:,:,i);
        end
    end
end
