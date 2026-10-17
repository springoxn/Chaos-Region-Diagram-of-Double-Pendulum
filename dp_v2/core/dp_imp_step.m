function [y, Q, g, t] = dp_imp_step(y, Q, t, h, p, order, renorm)
%% DP_IMP_STEP  Implicit symplectic step for the double pendulum, in the
%%              project's (theta, omega) layout.
%%
%%   [y, Q, g, t] = dp_imp_step(y, Q, t, h, p, order, renorm)
%%
%%   y   4xN state, rows = [th1; om1; th2; om2]   (the project layout used by
%%       dp_field_dyn.m and dp_rk4_step.m)
%%   Q   4xkxN deviation vectors in the SAME layout ([] to skip the tangent)
%%   t   unused (the system is autonomous); present so the signature matches
%%       sp_step.m and the two steppers are interchangeable to callers
%%   h   step
%%   p   struct m1, m2, L1, L2, g
%%   order 2 (implicit midpoint) or 4 (two-stage Gauss-Legendre)
%%   renorm (optional, default true) rescale deviation vectors to unit norm
%%
%%   Returns Q advanced by the tangent of this step and g = the norms divided
%%   out: the same contract as sp_step.m.
%%
%%   WHAT IT DOES
%%   ------------
%%   Converts (q, omega) -> (q, p), runs the implicit step in canonical
%%   variables (dp_imp_canon.m), converts back.  Deviation vectors are pushed
%%   through with the Jacobian of the conversion, not the conversion itself.
%%
%%   WHY THE CONVERSION IS NOT OPTIONAL
%%   ----------------------------------
%%   p = M(q) omega, with M the configuration-dependent mass matrix, so omega
%%   is NOT the canonical momentum.  A Gauss-Legendre method is symplectic in
%%   (q,p); composed with this nonlinear change of variables it is NOT
%%   symplectic in (q,omega).  A version of this file that integrated
%%   (q,omega) directly measured a symplectic residual of 0.78, which is the
%%   correct answer for what it was doing and the wrong thing to do.
%%
%%   ALIGNMENT INDICES ARE LAYOUT-INDEPENDENT
%%   ----------------------------------------
%%   GALI and SALI are invariant under an invertible linear map applied to all
%%   deviation vectors simultaneously, and the conversion's Jacobian is exactly
%%   such a map.  The Lyapunov exponents are invariant too, being asymptotic
%%   rates.  So the indicators are the same in either layout; only raw vector
%%   components differ.  tests/test_implicit.m checks this invariance rather
%%   than assuming it.
%%
%%   See also dp_imp_canon, dp_canon_convert, dp_canon_jac, dp_mass.

    if nargin < 6 || isempty(order), order = 2; end
    if nargin < 7 || isempty(renorm), renorm = true; end

    n = size(y, 2);

    % ---- state and tangent to canonical ----
    z = dp_canon_convert(y, p, 'to_canon');
    Qz = [];
    if ~isempty(Q)
        k = size(Q, 2);
        Qz = zeros(4, k, n);
        for c = 1:n
            Tz = dp_canon_jac(y(:,c), p);        % dz/dy at the OLD point
            for j = 1:k
                Qz(:,j,c) = Tz * Q(:,j,c);
            end
        end
    end

    % ---- one implicit step in canonical variables ----
    [z, Qz, g, t] = dp_imp_canon(z, Qz, t, h, p, order, renorm);

    % ---- tangent and state back to the project layout ----
    y = dp_canon_convert(z, p, 'from_canon');
    if isempty(Qz)
        Q = [];
    else
        k = size(Qz, 2);
        Q = zeros(4, k, n);
        for c = 1:n
            % dy/dz at the NEW point.  dp_canon_jac takes PROJECT-layout input,
            % so it is fed y (just converted), not z.  Passing z here is a
            % silent error: the function would read th2 from the p1 slot.
            [~, Ty] = dp_canon_jac(y(:,c), p);
            for j = 1:k
                Q(:,j,c) = Ty * Qz(:,j,c);
            end
        end
    end
end
