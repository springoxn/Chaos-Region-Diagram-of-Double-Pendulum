function dy = dp_field_dyn(y, p)
%% DP_FIELD_DYN  Right-hand side of the double pendulum.
%
%   dy = dp_field_dyn(y, p)
%
%   y   4xN state, rows = [th1; om1; th2; om2]
%   p   struct with m1, m2, L1, L2, g
%
%   Equations
%   ---------
%   th1'' = ( m2*L1*th1'^2*sin(d)cos(d) + m2*g*sin(th2)*cos(d)
%             + m2*L2*th2'^2*sin(d) - (m1+m2)*g*sin(th1) ) / den1
%   th2'' = ( -m2*L2*th2'^2*sin(d)cos(d) + (m1+m2)*g*sin(th1)*cos(d)
%             - (m1+m2)*L1*th1'^2*sin(d) - (m1+m2)*g*sin(th2) ) / den2
%   den1 = (m1+m2)*L1 - m2*L1*cos(d)^2 ,  den2 = (L2/L1)*den1 ,  d = th2-th1
%
%   Verified symbolically against the Euler-Lagrange equations in
%   verification/derive_dp_eom.py (difference identically zero).
%
%   WHY THIS IS A SEPARATE FILE
%   ---------------------------
%   dp_v2 has one numerical kernel shared by every caller; dp_rk4_step.m, the
%   implicit symplectic stepper dp_imp_step.m and any future integrator all
%   call this same function.  Two copies of the vector field would be two
%   things to keep in step, and a silent divergence between them would look
%   exactly like a physics result.  test_symplectic.m cross-checks the implicit
%   stepper against the RK4 stepper, which is only meaningful because both
%   share this field.

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
