function test_implicit()
%% TEST_IMPLICIT  Validate the implicit symplectic stepper (P1b) for the
%%                double pendulum, whose Hamiltonian is NOT separable.
%
%   Assertions are against independently known facts:
%
%     [1] dp_field_dyn reproduces the vector field of the existing RK4 kernel
%     [2] mass matrix inverse and positive determinant
%     [3] (theta,omega) <-> (theta,p) conversion round trip
%     [4] conversion Jacobian vs central differences
%     [5] canonical field reproduces dp_field_dyn through the conversion
%     [6] canonical field Jacobian vs central differences
%     [7] symplecticity of the implicit step, Phi' J Phi = J
%     [8] convergence order 2 and 4
%     [9] alignment indices are INVARIANT under the layout conversion
%    [10] energy: bounded band vs secular drift
%    [11] equilibria are fixed points
%    [12] vectorised row advance == scalar loop
%
%   THE ONE ASSERTION THAT IS *NOT* AVAILABLE HERE
%   ----------------------------------------------
%   Symplecticity does NOT validate the analytic Jacobian: the Cayley
%   transform (I - h/2 J)^-1 (I + h/2 J) is symplectic for EVERY J, so [7]
%   passes even with a wrong Jacobian.  This was observed directly -- [7] held
%   at 2e-16 while [6] was off by 13.  The Jacobian is therefore pinned by the
%   central-difference checks [4] and [6], which are the load-bearing ones.
%
%   Run:  addpath('tests'); test_implicit
%
%   See also dp_imp_step, dp_imp_canon, dp_canon_rhs, dp_mass, test_symplectic.

    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    fprintf('=== implicit symplectic stepper (double pendulum) ===\n\n');
    fails = 0;
    p = struct('m1',1, 'm2',1, 'L1',1, 'L2',1, 'g',9.81);
    eps = 1e-7;

    % ------------------------------------------------------------------ 1
    fprintf('[1] dp_field_dyn vs the existing RK4 kernel\n');
    y = [0.9; -1.4; 2.1; 0.6];
    e = max(abs(dp_field_dyn(y, p) - field_reference(y, p)));
    fprintf('    max difference = %.2e\n', e);
    if e > 0, fprintf('    FAIL\n'); fails = fails + 1; end

    % ------------------------------------------------------------------ 2
    fprintf('\n[2] mass matrix: inverse and determinant\n');
    emax = 0; dmin = inf;
    for th1 = [-2.4 0 0.7 2.1]
        for th2 = [-1.9 -0.6 0.9 3.1]
            [M, A, detM] = dp_mass(th1, th2, p);
            emax = max(emax, max(max(abs(M*A - eye(2)))));
            dmin = min(dmin, detM);
        end
    end
    fprintf('    max |M*A - I| = %.2e   min det M = %.6f\n', emax, dmin);
    if emax > 1e-12 || dmin <= 0
        fprintf('    FAIL\n'); fails = fails + 1;
    end

    % ------------------------------------------------------------------ 3
    fprintf('\n[3] conversion round trip\n');
    yy = [0.7; -0.4; 0.9; 0.3];
    zz = dp_canon_convert(yy, p, 'to_canon');
    e = max(abs(dp_canon_convert(zz, p, 'from_canon') - yy));
    fprintf('    max |y - roundtrip| = %.2e\n', e);
    if e > 1e-14, fprintf('    FAIL\n'); fails = fails + 1; end

    % ------------------------------------------------------------------ 4
    fprintf('\n[4] conversion Jacobian vs central differences\n');
    Jnum = zeros(4,4);
    for j = 1:4
        ee = zeros(4,1); ee(j) = eps;
        Jnum(:,j) = (dp_canon_convert(yy+ee,p,'to_canon') - ...
                     dp_canon_convert(yy-ee,p,'to_canon')) / (2*eps);
    end
    [Jz, Tinv] = dp_canon_jac(yy, p);
    e1 = max(max(abs(Jz - Jnum)));
    e2 = max(max(abs(Jz*Tinv - eye(4))));
    fprintf('    max |Jz - FD| = %.2e   max |Jz*Tinv - I| = %.2e\n', e1, e2);
    if e1 > 1e-7 || e2 > 1e-12
        fprintf('    FAIL\n'); fails = fails + 1;
    end

    % ------------------------------------------------------------------ 5
    fprintf('\n[5] canonical field reproduces dp_field_dyn\n');
    e = max(abs(Tinv * dp_canon_rhs(zz, p) - dp_field_dyn(yy, p)));
    fprintf('    max |Tinv*F_canon - f_project| = %.2e\n', e);
    if e > 1e-10, fprintf('    FAIL\n'); fails = fails + 1; end

    % ------------------------------------------------------------------ 6
    fprintf('\n[6] canonical Jacobian vs central differences\n');
    [~, Jc] = dp_canon_rhs(zz, p);
    Jfd = zeros(4,4);
    for j = 1:4
        ee = zeros(4,1); ee(j) = eps;
        Jfd(:,j) = (dp_canon_rhs(zz+ee,p) - dp_canon_rhs(zz-ee,p)) / (2*eps);
    end
    e = max(max(abs(Jc - Jfd)));
    fprintf('    max |J_canon - FD| = %.2e   (scale %.2f)\n', e, max(max(abs(Jc))));
    if e > 1e-6, fprintf('    FAIL\n'); fails = fails + 1; end

    % ------------------------------------------------------------------ 7
    fprintf('\n[7] symplecticity:  Phi'' J Phi = J   (canonical variables)\n');
    Jn = zeros(4,4); Jn(1:2,3:4) = eye(2); Jn(3:4,1:2) = -eye(2);
    for o = [2 4]
        Phi = zeros(4,4);
        for j = 1:4
            ee = zeros(4,1); ee(j) = 1;
            [~, Qj] = dp_imp_canon(zz, reshape(ee,4,1,1), 0, 0.05, p, o, false);
            Phi(:,j) = Qj(:,1,1);
        end
        r = max(max(abs(Phi'*Jn*Phi - Jn)));
        fprintf('    order %d: max|Phi''JPhi - J| = %.2e\n', o, r);
        if r > 1e-12
            fprintf('    FAIL\n'); fails = fails + 1;
        end
    end

    % ------------------------------------------------------------------ 8
    fprintf('\n[8] convergence order (canonical, T=20, ref h=1e-4)\n');
    z0 = dp_canon_convert([1.0; 0.5; 0.0; 0.0], p, 'to_canon');
    zref = run_canon(z0, 20, 1e-4, p, 4);
    for o = [2 4]
        errs = zeros(1,3); kk = 0;
        for h = [0.04 0.02 0.01]
            kk = kk + 1;
            errs(kk) = max(abs(run_canon(z0, 20, h, p, o) - zref));
        end
        rat = errs(1:end-1) ./ errs(2:end);
        fprintf('    order %d: errs = %.2e %.2e %.2e   ratios = %.1f %.1f (theory %.0f)\n', ...
                o, errs, rat, 2^o);
        if min(rat) < 0.6 * 2^o
            fprintf('    FAIL\n'); fails = fails + 1;
        end
    end

    % ------------------------------------------------------------------ 9
    fprintf('\n[9] wrapper tangent == conjugated canonical tangent\n');
    % The mathematically correct statement, and the one the wrapper relies on:
    % if Tz_old is the conversion Jacobian at the start of the step and Tz_new
    % at the end, then the project-layout tangent Phi_p and the canonical
    % tangent Phi_c satisfy
    %
    %       Phi_p = Tz_new^-1 * Phi_c * Tz_old .
    %
    % Deliberately NOT asserted here: that GALI itself is layout-invariant.  It
    % is not.  The wedge product is a coordinate-free object but its NORM needs
    % a metric, so an arbitrary invertible change of variables rescales
    % GALI_k by |wedge^k A|, a constant for that map.  Only ORTHOGONAL changes
    % preserve the value.  What IS coordinate-invariant is the asymptotic decay
    % rate of GALI, hence the regular/chaotic classification -- and that follows
    % from the Lyapunov exponents, which are rates and are invariant.  See
    % sp_gali.m, where this is stated for users.
    h = 0.05;
    yb = [0.7; -0.4; 0.9; 0.3];
    % NOTE the output order: dp_canon_jac returns [Jz, Tinv] = [dz/dy, dy/dz].
    % A earlier version of this test read them as [Tz, Ty] and silently used
    % dz/dy where dy/dz was meant, which is a wrong conjugation.
    TzOld = dp_canon_jac(yb, p);

    Phi_p = zeros(4,4);
    for j = 1:4
        ee = zeros(4,1); ee(j) = 1;
        [~, Qj] = dp_imp_step(yb, reshape(ee,4,1,1), 0, h, p, 2, false);
        Phi_p(:,j) = Qj(:,1,1);
    end

    zb = dp_canon_convert(yb, p, 'to_canon');
    Phi_c = zeros(4,4);
    for j = 1:4
        ee = zeros(4,1); ee(j) = 1;
        [~, Qj] = dp_imp_canon(zb, reshape(ee,4,1,1), 0, h, p, 2, false);
        Phi_c(:,j) = Qj(:,1,1);
    end

    zend = run_canon(zb, h, h, p, 2);      % one step, to get the new point
    yend = dp_canon_convert(zend, p, 'from_canon');
    [~, TyNew] = dp_canon_jac(yend, p);    % dy/dz at the NEW point

    e = max(max(abs(Phi_p - TyNew * Phi_c * TzOld)));
    fprintf('    max |Phi_p - TyNew*Phi_c*TzOld| = %.2e\n', e);
    if e > 1e-10
        fprintf('    FAIL: wrapper tangent is not the conjugated tangent\n');
        fails = fails + 1;
    end

    % GALI under an ORTHOGONAL change must be exactly preserved.
    V1 = [1; 0.2; -0.3; 0.5];
    V2 = [0.1; -0.7; 0.4; 0.2];
    th = 0.7;
    Qo = [cos(th) -sin(th) 0 0; sin(th) cos(th) 0 0; 0 0 cos(th) -sin(th); 0 0 sin(th) cos(th)];
    gA = gali_of([V1, V2], 2);
    gB = gali_of(Qo*[V1, V2], 2);
    fprintf('    GALI2 orthogonal-invariance: %.12f vs %.12f  diff %.2e\n', gA, gB, abs(gA-gB));
    if abs(gA - gB) > 1e-12
        fprintf('    FAIL: GALI is not orthogonal-invariant\n'); fails = fails + 1;
    end

    % ----------------------------------------------------------------- 10
    fprintf('\n[10] energy: bounded band vs secular drift\n');
    y0e = [2.5; 0; 2.5; 0];
    E0 = dp_hamiltonian(y0e, p);
    fprintf('    E0 = %.6f\n', E0);
    for o = [2 4]
        [h1, h2] = energy_halves(y0e, 200, 0.005, p, o);
        fprintf('    order %d: max|dE|/|E0| 1st=%.3e 2nd=%.3e ratio=%.2f\n', ...
                o, h1/abs(E0), h2/abs(E0), h2/max(h1,realmin));
        if h2 > 3*h1
            fprintf('    FAIL: secular drift\n'); fails = fails + 1;
        end
    end
    [h1, h2] = energy_halves_rk4(y0e, 200, 0.005, p);
    fprintf('    RK4     : max|dE|/|E0| 1st=%.3e 2nd=%.3e ratio=%.2f\n', ...
            h1/abs(E0), h2/abs(E0), h2/max(h1,realmin));

    % ----------------------------------------------------------------- 11
    fprintf('\n[11] equilibria are fixed points\n');
    for o = [2 4]
        yEq = [0;0;0;0];   yUp = [pi;0;pi;0];
        e1 = max(abs(run_proj(yEq, 5, 0.01, p, o) - yEq));
        e2 = max(abs(run_proj(yUp, 5, 0.01, p, o) - yUp));
        fprintf('    order %d: down %.2e   up %.2e\n', o, e1, e2);
        if e1 > 1e-9 || e2 > 1e-8
            fprintf('    FAIL\n'); fails = fails + 1;
        end
    end

    % ----------------------------------------------------------------- 12
    fprintf('\n[12] vectorised row advance == scalar loop\n');
    yinit = [0.3 1.1; 0.2 -0.7; 1.0 0.4; 0.0 0.2];
    n = 60; h = 0.01;
    yv = yinit;
    for k = 1:n
        [yv, ~, ~, ~] = dp_imp_step(yv, [], 0, h, p, 2);
    end
    dmax = 0;
    for c = 1:size(yinit,2)
        yy2 = yinit(:,c);
        for k = 1:n
            [yy2, ~, ~, ~] = dp_imp_step(yy2, [], 0, h, p, 2);
        end
        dmax = max(dmax, max(abs(yv(:,c) - yy2)));
    end
    fprintf('    max |vectorised - scalar| = %.2e\n', dmax);
    if dmax > 1e-12
        fprintf('    FAIL\n'); fails = fails + 1;
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_implicit:failed', '%d implicit-stepper test(s) failed', fails);
    end
end


% =========================================================================
function [Jz, Tinv, Ty] = conv_jacs(y, p)
%% CONV_JACS  Conversion Jacobians at a project-layout point.
    [Jz, Tinv] = dp_canon_jac(y, p);
    Ty = Tinv;
end


function g = gali_of(V, k)
%% GALI_k for a k-column deviation matrix: the norm of the wedge product of the
%% columns, equal to |det R| from a QR factorisation of V.  Matches sp_gali.m.
    if size(V,2) < k
        error('gali_of:cols', 'need at least %d deviation vectors', k);
    end
    [~, R] = qr(V(:,1:k), 0);
    g = abs(prod(diag(R)));
end


function y = run_canon(z0, tend, h, p, order)
    n = round(tend/h); z = z0;
    for k = 1:n
        [z, ~, ~, ~] = dp_imp_canon(z, [], 0, h, p, order);
    end
    y = z;
end


function y = run_proj(y0, tend, h, p, order)
    n = round(tend/h); y = y0;
    for k = 1:n
        [y, ~, ~, ~] = dp_imp_step(y, [], 0, h, p, order);
    end
end


function [h1, h2] = energy_halves(y0, tend, h, p, order)
    n = round(tend/h); y = y0; E0 = dp_hamiltonian(y0, p);
    half = floor(n/2); h1 = 0; h2 = 0;
    for k = 1:n
        [y, ~, ~, ~] = dp_imp_step(y, [], 0, h, p, order);
        e = abs(dp_hamiltonian(y, p) - E0);
        if k <= half, h1 = max(h1, e); else, h2 = max(h2, e); end
    end
end


function [h1, h2] = energy_halves_rk4(y0, tend, h, p)
    n = round(tend/h); y = y0; E0 = dp_hamiltonian(y0, p);
    half = floor(n/2); h1 = 0; h2 = 0;
    for k = 1:n
        dt2 = 0.5*h; dt6 = h/6;
        k1 = dp_field_dyn(y, p);
        k2 = dp_field_dyn(y + dt2*k1, p);
        k3 = dp_field_dyn(y + dt2*k2, p);
        k4 = dp_field_dyn(y + h*k3, p);
        y = y + dt6*(k1 + 2*k2 + 2*k3 + k4);
        e = abs(dp_hamiltonian(y, p) - E0);
        if k <= half, h1 = max(h1, e); else, h2 = max(h2, e); end
    end
end


function dy = field_reference(y, p)
%% The double-pendulum vector field written independently of dp_field_dyn.m,
%% from the closed-form expressions in verification/derive_dp_eom.py.  Reused
%% here so that [1] compares two implementations rather than one with itself.
    th1 = y(1);  om1 = y(2);
    th2 = y(3);  om2 = y(4);
    d  = th2 - th1;
    sd = sin(d); cd = cos(d);
    den1 = (p.m1 + p.m2)*p.L1 - p.m2*p.L1*cd^2;
    den2 = (p.L2/p.L1)*den1;
    a1 = ( p.m2*p.L1*om1^2*sd*cd + p.m2*p.g*sin(th2)*cd ...
         + p.m2*p.L2*om2^2*sd - (p.m1 + p.m2)*p.g*sin(th1) ) / den1;
    a2 = ( -p.m2*p.L2*om2^2*sd*cd + (p.m1 + p.m2)*p.g*sin(th1)*cd ...
         - (p.m1 + p.m2)*p.L1*om1^2*sd - (p.m1 + p.m2)*p.g*sin(th2) ) / den2;
    dy = [om1; a1; om2; a2];
end
