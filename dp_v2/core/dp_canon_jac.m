function [Jz, Tinv] = dp_canon_jac(y, p)
%% DP_CANON_JAC  Jacobian of the (theta,omega) -> (theta,p) change of variables.
%%
%%   [Jz, Tinv] = dp_canon_jac(y, p)
%%
%%   y    4x1 project state [th1; om1; th2; om2]
%%   Jz   4x4, Jz = d z / d y  with z = [th1; th2; p1; p2]
%%   Tinv 4x4, Tinv = d y / d z = inv(Jz)
%%
%%   DERIVATION
%%   ----------
%%   With q = (th1, th2), omega = (om1, om2) and p = M(q) omega,
%%
%%       z1 = y1 ,  z2 = y3 ,  z(3:4) = M(y1,y3) * [y2; y4] .
%%
%%   Writing N = [[0, beta],[beta, 0]] with beta = m2 L1 L2 sin(th2-th1), the
%%   chain rule on M12 = m2 L1 L2 cos(th2-th1) gives
%%
%%       dM/dth1 = +N ,   dM/dth2 = -N ,
%%
%%   because d(th2-th1)/dth1 = -1 and d(cos d)/dd = -sin d.  (A first draft had
%%   these the other way round; the sign is fixed by the central-difference
%%   check in tests/test_implicit.m, not by inspection.)
%%
%%   The nonzero blocks are therefore
%%
%%       dz1/dy1 = 1                       dz2/dy3 = 1
%%       d p/dy1 = (dM/dth1) omega = +N omega
%%       d p/dy3 = (dM/dth2) omega = -N omega
%%       d p/dy2 = M(:,1)                  d p/dy4 = M(:,2)
%%
%%   Tinv is obtained by solving Jz * Tinv = I rather than by a second hand
%%   derivation.  Two rounds of hand algebra on this transformation already
%%   produced a wrong symplectic form, and the round trip Jz * Tinv = I is a
%%   cheap, checkable assertion -- so the inverse is computed, not re-derived.
%%
%%   Jz is verified against central differences of dp_canon_convert in
%%   tests/test_implicit.m.
%%
%%   See also dp_canon_convert, dp_mass, dp_imp_step.

    th1 = y(1);  th2 = y(3);
    om1 = y(2);  om2 = y(4);

    M = dp_mass(th1, th2, p);

    dd   = th2 - th1;
    beta = p.m2 * p.L1 * p.L2 * sin(dd);
    N    = [0, beta; beta, 0];
    om   = [om1; om2];

    Jz = zeros(4,4);
    Jz(1,1) = 1;
    Jz(2,3) = 1;
    Jz(3:4, 1) = +N * om;
    Jz(3:4, 3) = -N * om;
    Jz(3:4, 2) = M(:,1);
    Jz(3:4, 4) = M(:,2);

    if nargout > 1
        Tinv = Jz \ eye(4);
    end
end
