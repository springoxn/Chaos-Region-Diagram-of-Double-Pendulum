function [F, J] = dp_canon_rhs(z, p)
%% DP_CANON_RHS  Hamiltonian vector field of the double pendulum in CANONICAL
%%               variables, together with its analytic Jacobian.
%%
%%   [F, J] = dp_canon_rhs(z, p)
%%
%%   z = [th1; th2; p1; p2]   canonical coordinates and momenta, 4xN
%%   p = parameter struct m1, m2, L1, L2, g
%%
%%   F  = z' = J_sym * grad H ,  4xN
%%   J  = dF/dz ,  4x4xN
%%
%%   THE HAMILTONIAN AND WHY CANONICAL VARIABLES ARE MANDATORY
%%   --------------------------------------------------------
%%       H(q,p) = 1/2 p' A(q) p + V(q) ,      A = M(q)^-1
%%       V(q)   = -(m1+m2) g L1 cos th1 - m2 g L2 cos th2
%%
%%   q appears inside the kinetic term, so the system is not separable and no
%%   explicit symplectic integrator exists for it.  It must also be integrated
%%   in (q,p): the common (q, omega) variables are not canonical, since
%%   p = M(q) omega, and a method that is symplectic in (q,p) is NOT symplectic
%%   in (q, omega).  dp_imp_step.m therefore works here and converts at the
%%   boundary.
%%
%%   DERIVATIVES, ALL CLOSED FORM
%%   ----------------------------
%%   Write d = th2 - th1, beta = m2 L1 L2 sin d, and N = [[0,beta],[beta,0]] so
%%   that  dM/dth1 = -N ,  dM/dth2 = +N .  With K = A N A and A = A(d),
%%
%%       dA/dth1 = -K ,   dA/dth2 = +K ,   dA/dd = K ,
%%       dK/dd   = K N A + A N' A + A N K ,    N' = [[0, m2 L1 L2 cos d],[.,0]]
%%
%%   and the second derivatives are  d2A/dth1^2 = d2A/dth2^2 = +dK/dd  and
%%   d2A/dth1 dth2 = -dK/dd .  Hence
%%
%%       F1 = A p                                        (2x1)
%%       G_i = -dH/dq_i = -1/2 p' (dA/dq_i) p - dV/dq_i
%%           G_1 = +1/2 p'Kp - (m1+m2) g L1 sin th1
%%           G_2 = -1/2 p'Kp - m2 g L2 sin th2
%%
%%   and the 4x4 Jacobian is assembled from
%%
%%       dF1/dq_j = (dA/dq_j) p = [-Kp , +Kp]     dF1/dp = A
%%       dG_1/dq  = [ -1/2 p'(dK/dd)p - (m1+m2)gL1 cos th1 ,  +1/2 p'(dK/dd)p ]
%%       dG_2/dq  = [ +1/2 p'(dK/dd)p ,  -1/2 p'(dK/dd)p - m2 g L2 cos th2 ]
%%       dG/dp    = [ +Kp ; -Kp ]  as rows
%%
%%   VERIFICATION
%%   ------------
%%   The Jacobian is not trusted: tests/test_implicit.m differences it against
%%   central differences of F, and separately checks that F itself reproduces
%%   the project's own dp_field_dyn.m after converting through p = M omega.
%%   Every symbol above was fixed by those two checks after a first draft got
%%   the (q, omega) symplectic structure wrong.
%%
%%   See also dp_mass, dp_imp_step, dp_field_dyn.

    th1 = z(1,:);  th2 = z(2,:);
    pv  = z(3:4,:);
    n   = size(z, 2);
    d   = th2 - th1;

    M11 = (p.m1 + p.m2) * p.L1^2;
    M22 = p.m2 * p.L2^2;

    F = zeros(4, n);
    if nargout > 1
        J = zeros(4, 4, n);
    end

    for c = 1:n
        dc  = d(c);
        sd  = sin(dc);  cd = cos(dc);
        beta = p.m2 * p.L1 * p.L2 * sd;
        betap = p.m2 * p.L1 * p.L2 * cd;

        M12 = p.m2 * p.L1 * p.L2 * cd;
        detc = M11*M22 - M12^2;
        Ac = [M22, -M12; -M12, M11] / detc;
        N  = [0, beta; beta, 0];
        Np = [0, betap; betap, 0];

        K   = Ac * N  * Ac;
        dKdd = K*N*Ac + Ac*Np*Ac + Ac*N*K;

        pc = pv(:,c);
        Kp = K * pc;
        qK  = pc' * K * pc;        % needed by the FORCE
        s   = pc' * dKdd * pc;     % needed by the JACOBIAN only

        F(1:2, c) = Ac * pc;
        F(3, c)   =  0.5*qK - (p.m1+p.m2)*p.g*p.L1*sin(th1(c));
        F(4, c)   = -0.5*qK - p.m2*p.g*p.L2*sin(th2(c));

        if nargout > 1
            Jc = zeros(4,4);
            Jc(1:2, 1) = -Kp;
            Jc(1:2, 2) = +Kp;
            Jc(1:2, 3:4) = Ac;

            Jc(3,1) = -0.5*s - (p.m1+p.m2)*p.g*p.L1*cos(th1(c));
            Jc(3,2) = +0.5*s;
            Jc(4,1) = +0.5*s;
            Jc(4,2) = -0.5*s - p.m2*p.g*p.L2*cos(th2(c));

            Jc(3,3:4) =  Kp';
            Jc(4,3:4) = -Kp';

            J(:,:,c) = Jc;
        end
    end
end
