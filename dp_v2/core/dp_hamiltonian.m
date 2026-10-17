function E = dp_hamiltonian(y, p)
%% DP_HAMILTONIAN  Total mechanical energy of the double pendulum.
%
%   E = dp_hamiltonian(y, p)
%
%   y  4xN state, rows = [th1; om1; th2; om2]
%   p  struct with m1, m2, L1, L2, g
%
%   Kinetic energy is built from the two centre-of-mass speeds,
%
%       KE = 1/2 m1 |v1|^2 + 1/2 m2 |v2|^2 ,
%       |v1|^2 = L1^2 om1^2
%       |v2|^2 = L1^2 om1^2 + L2^2 om2^2 + 2 L1 L2 om1 om2 cos(th2 - th1)
%
%   and potential energy from the heights,
%
%       PE = -m1 g L1 cos(th1) - m2 g (L1 cos(th1) + L2 cos(th2)) .
%
%   Equivalent to  H = 1/2 p' M(q)^-1 p + V(q)  with
%       M = [[(m1+m2)L1^2, m2 L1 L2 cos d], [m2 L1 L2 cos d, m2 L2^2]]
%       V = -(m1+m2) g L1 cos th1 - m2 g L2 cos th2 ,   d = th2 - th1 .
%   The mass-matrix form is what makes the Hamiltonian NON-separable and forces
%   the implicit stepper in dp_imp_step.m; this velocity form is cheaper to
%   evaluate and is what the energy-conservation checks use.
%
%   This is the quantity a symplectic integrator keeps on a bounded oscillating
%   band instead of letting drift.  dp_v2/tests/test_implicit.m measures that.

    th1 = y(1,:);  om1 = y(2,:);
    th2 = y(3,:);  om2 = y(4,:);

    v1sq = p.L1^2 * om1.^2;
    v2sq = v1sq + p.L2^2 * om2.^2 ...
           + 2*p.L1*p.L2*om1.*om2.*cos(th2 - th1);

    KE = 0.5*p.m1*v1sq + 0.5*p.m2*v2sq;
    PE = -p.m1*p.g*p.L1*cos(th1) ...
         - p.m2*p.g*(p.L1*cos(th1) + p.L2*cos(th2));

    E = KE + PE;
end
