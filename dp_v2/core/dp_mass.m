function [M, A, detM] = dp_mass(th1, th2, p)
%% DP_MASS  Mass matrix of the double pendulum and its inverse.
%%
%%   [M, A, detM] = dp_mass(th1, th2, p)
%%
%%   th1, th2  1xN angles (or scalars)
%%   p         struct with m1, m2, L1, L2, g
%%
%%   M    2x2xN  mass matrix, 2x2 when the inputs are scalars
%%   A    2x2xN  its inverse
%%   detM 1xN    determinant
%%
%%       M = [[(m1+m2)L1^2      , m2 L1 L2 cos d],
%%            [m2 L1 L2 cos d   , m2 L2^2       ]] ,   d = th2 - th1
%%
%%   WHY IT MATTERS FOR THE INTEGRATOR
%%   ---------------------------------
%%   The canonical momentum is p = M(q) omega, NOT omega.  The kinetic energy
%%   in canonical variables is  T = 1/2 p' A(q) p  with A = M^-1, so q appears
%%   inside the kinetic term: the Hamiltonian is NOT separable and no explicit
%%   symplectic method applies.  It also means the naive (q, omega) variables
%%   are not canonical, and an integrator that is symplectic in the (q,p) sense
%%   is not symplectic in the (q,omega) sense -- the transformation between
%%   them is nonlinear.  dp_imp_step.m therefore works in (q,p) and converts.
%%
%%   The determinant is positive definite for physical parameters:
%%       det M = m2 L1^2 L2^2 (m1 + m2 sin^2 d) > 0 ,
%%   which is asserted in tests/test_implicit.m.

    th1 = reshape(th1, 1, []);
    th2 = reshape(th2, 1, []);
    n = numel(th1);
    d = th2 - th1;

    M = zeros(2, 2, n);
    A = zeros(2, 2, n);
    detM = zeros(1, n);

    M11 = (p.m1 + p.m2) * p.L1^2;
    M22 = p.m2 * p.L2^2;

    for c = 1:n
        M12 = p.m2 * p.L1 * p.L2 * cos(d(c));
        Mc = [M11, M12; M12, M22];
        detc = M11*M22 - M12^2;
        detM(c) = detc;
        Ac = [M22, -M12; -M12, M11] / detc;
        M(:,:,c) = Mc;
        A(:,:,c) = Ac;
    end

    if n == 1
        M = M(:,:,1);
        A = A(:,:,1);
    end
end
