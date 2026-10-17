function test_symplectic()
%% TEST_SYMPLECTIC  Validate the explicit symplectic integrator family (P1a).
%
%   Every assertion here is against an INDEPENDENTLY KNOWN fact:
%
%     * the Yoshida weight order conditions    sum(w) = 1, sum(w^3) = 0, ...
%     * the convergence order of the method    measured slope, not assumed
%     * symplecticity                          Phi' J Phi = J, to roundoff
%     * energy boundedness on a CONSERVATIVE system
%     * the analytic forces and Hessians       vs central differences and vs
%                                              the paper's Eq. (19)
%
%   WHAT IS *NOT* ASSERTED, AND WHY
%   -------------------------------
%   Energy boundedness is tested on the autonomous / conservative systems only
%   (the F = 0 pendulum and the coupled pendulum).  It is deliberately NOT
%   tested on the forced pendulum with a rotating orbit: the Hamiltonian
%     H = p^2/2 - cos q - F q cos(Omega t)
%   contains a term linear in q, so on a circulating orbit q grows without
%   bound and so does H.  That H is unbounded is correct physics, not an
%   integrator defect, and a first draft of the scratch script mistakenly read
%   the resulting 1e3 "drift" as a failure.  Symplecticity is the right test
%   for that system, and it is what is used here.
%
%   Run:  addpath('tests'); test_symplectic
%
%   See also sp_step, sp_sys, sp_weights.

    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    fprintf('=== explicit symplectic family ===\n\n');
    fails = 0;

    % ------------------------------------------------------------------ 1
    fprintf('[1] Yoshida weight order conditions\n');
    % For a symmetric composition of a symmetric 2nd-order method the error
    % carries only odd powers of h, so order 2k requires sum(w^(2j-1)) = 0 for
    % j = 2..k and sum(w) = 1.
    for o = [2 4 6]
        w = sp_weights(o);
        s1 = abs(sum(w) - 1);
        s3 = abs(sum(w.^3));
        s5 = abs(sum(w.^5));
        sym = isequal(w, fliplr(w));
        fprintf('    order %d: |sum-1|=%.2e |sum3|=%.2e |sum5|=%.2e palindromic=%d\n', ...
                o, s1, s3, s5, sym);
        if s1 > 1e-14 || ~sym
            fprintf('    FAIL: order %d weights do not satisfy sum(w)=1 or are not symmetric\n', o);
            fails = fails + 1;
        end
        if o >= 4 && s3 > 1e-12
            fprintf('    FAIL: order %d needs sum(w^3)=0\n', o); fails = fails + 1;
        end
        if o >= 6 && s5 > 1e-12
            fprintf('    FAIL: order %d needs sum(w^5)=0\n', o); fails = fails + 1;
        end
    end

    % ------------------------------------------------------------------ 2
    fprintf('\n[2] analytic force and Hessian vs central differences\n');
    sc = sp_sys('coupled', 'a', 4, 'b', 1);
    q = [0.9 -2.1 0.4; 1.3 0.7 -0.5];
    hs = 1e-6; errF = 0; errJ = 0;
    for c = 1:size(q,2)
        J = sc.dforce(q(:,c), 0);
        for j = 1:2
            e = zeros(2,1); e(j) = hs;
            fd = (sc.force(q(:,c)+e,0) - sc.force(q(:,c)-e,0)) / (2*hs);
            errJ = max(errJ, max(abs(J(:,j) - fd)));
        end
    end
    % The force itself must reproduce Eq. (19) of Barrio, Borczyk & Breiter.
    x = 0.9; y = 1.3; a = 4; b = 1;
    ref = [ -(1 + a*b - a*b*cos(y))*sin(x); -a*(1 - b*cos(x))*sin(y) ];
    errF = max(abs(sc.force([x;y], 0) - ref));
    fprintf('    coupled: |force - Eq.(19)| = %.2e\n', errF);
    fprintf('    coupled: |dforce - FD|     = %.2e\n', errJ);
    if errF > 1e-12, fprintf('    FAIL: force disagrees with Eq.(19)\n'); fails = fails+1; end
    if errJ > 1e-8,  fprintf('    FAIL: Hessian disagrees with FD\n');   fails = fails+1; end

    sp = sp_sys('pendulum', 'F', 1.5, 'gamma', 0.2, 'Omega', 2/3);
    tt = 3.77; th = 0.8;
    errP = abs(sp.force(th,tt) - (-sin(th) + 1.5*cos((2/3)*tt)));
    fprintf('    pendulum: |force - fp_lyap rhs| = %.2e\n', errP);
    if errP > 1e-14, fprintf('    FAIL: pendulum force mismatch\n'); fails = fails+1; end

    % ------------------------------------------------------------------ 3
    fprintf('\n[3] convergence order (coupled pendulum, fixed T=20, vs Yoshida6 at h=1e-4)\n');
    % Ratio must approach 2^order as h -> 0.  This is the assertion that would
    % have caught the first draft's composition bug, where the loop composed
    % first-order D-K maps and every order measured WORSE than leapfrog.
    y0 = [1.0; 0.5; 0.0; 0.0];
    yref = run_sp(sc, y0, 20, 1e-4, 6);
    for o = [2 4 6]
        errs = zeros(1,3); k = 0;
        for h = [0.05 0.025 0.0125]
            k = k + 1;
            errs(k) = max(abs(run_sp(sc, y0, 20, h, o) - yref));
        end
        rat = errs(1:end-1) ./ errs(2:end);
        fprintf('    Yoshida%d: errs = %.2e %.2e %.2e   ratios = %.1f %.1f (theory %.1f)\n', ...
                o, errs, rat, 2^o);
        if min(rat) < 0.6 * 2^o
            fprintf('    FAIL: Yoshida%d does not show order %d\n', o, o); fails = fails+1;
        end
    end

    % ------------------------------------------------------------------ 4
    fprintf('\n[4] symplecticity:  Phi'' J Phi = J\n');
    % Build the full monodromy matrix by stepping a basis with renorm = false,
    % then check the defining relation.  Applied to the FORCED pendulum as
    % well: the time-h map of a time-dependent Hamiltonian is symplectic even
    % though the autonomous (q,p) energy is not conserved.  gamma = 0 because
    % damping destroys symplecticity by construction.
    J2 = [0 1; -1 0];
    for tag = {'pendulum','coupled'}
        if strcmp(tag{1}, 'pendulum')
            s = sp_sys('pendulum', 'F', 1.5, 'gamma', 0, 'Omega', 2/3);
            yb = [0.7; -0.4];
        else
            s = sp_sys('coupled', 'a', 4, 'b', 1);
            yb = [0.7; -0.4; 0.9; 0.3];
        end
        for o = [2 4 6]
            h = 0.05; nd = numel(yb);
            Phi = zeros(nd, nd);
            for j = 1:nd
                e = zeros(nd,1); e(j) = 1;
                [~, Vj] = sp_step(yb, reshape(e,nd,1,1), 0, h, s, o, false);
                Phi(:,j) = Vj(:,1,1);
            end
            nq = s.nq;
            Jn = zeros(nd,nd);
            Jn(1:nq, nq+1:nd) = eye(nq);
            Jn(nq+1:nd, 1:nq) = -eye(nq);
            resid = max(max(abs(Phi' * Jn * Phi - Jn)));
            fprintf('    %-9s Yoshida%d: max|Phi''JPhi - J| = %.2e\n', tag{1}, o, resid);
            % Roundoff in a single step is ~1e-16; allow a wide margin but
            % still catch a non-symplectic scheme, which would give O(h).
            if resid > 1e-12
                fprintf('    FAIL: %s Yoshida%d is not symplectic\n', tag{1}, o);
                fails = fails + 1;
            end
        end
    end

    % ------------------------------------------------------------------ 5
    fprintf('\n[5] energy: bounded band (symplectic) vs secular drift (RK4)\n');
    % The decisive difference is NOT the size of the error but its behaviour in
    % time.  A symplectic method keeps H on a bounded band whose width scales
    % like h^order; a non-symplectic one drifts secularly, so its error keeps
    % growing with the integration length no matter how small h is.
    %
    % Measured as  max|dE| over the FIRST half  vs  over the SECOND half.
    % Symplectic: ratio ~ 1.  RK4: ratio > 1 and growing with run length.
    %
    % F = 0 here because for the forced Hamiltonian p^2/2 - cos q - F q cos(Om t)
    % the term linear in q makes H unbounded along a circulating orbit -- that
    % is correct physics, and it makes H unusable as a conservation check.
    sp0 = sp_sys('pendulum', 'F', 0, 'gamma', 0, 'Omega', 2/3);
    y0p = [0.5; 0.0]; tend = 4000; nstep = 20000;
    fprintf('    plain pendulum, t in [0,%g], %d steps (h=%.2f)\n', tend, nstep, tend/nstep);
    for o = [2 4 6]
        [h1, h2, tot] = energy_halves(sp0, y0p, tend, nstep, o);
        fprintf('      Yoshida%d  max|dE| 1st half=%.3e  2nd half=%.3e  ratio=%.2f  (total %.2e)\n', ...
                o, h1, h2, h2/max(h1,realmin), tot);
        if h2 > 3*h1
            fprintf('      FAIL: Yoshida%d shows secular energy growth\n', o);
            fails = fails + 1;
        end
    end
    [h1, h2, tot] = energy_halves_rk4(sp0, y0p, tend, nstep);
    fprintf('      RK4        max|dE| 1st half=%.3e  2nd half=%.3e  ratio=%.2f  (total %.2e)\n', ...
            h1, h2, h2/max(h1,realmin), tot);
    if h2 <= h1
        fprintf('    FAIL: RK4 was expected to drift secularly here\n'); fails = fails + 1;
    end

    fprintf('\n    error scales as h^order (coupled pendulum, fixed T=2000)\n');
    % Symplectic error amplitude must fall like h^order.  Ratios ~4 / ~16 / ~64.
    y0c_ord = [1.0; 0.5; 0.0; 0.0];
    for o = [2 4 6]
        ratio = zeros(1,2); k = 0; prev = NaN;
        for h = [0.08 0.04 0.02]
            [~, ~, tot] = energy_halves(sc, y0c_ord, 2000, round(2000/h), o);
            if ~isnan(prev)
                k = k + 1; ratio(k) = prev / tot;
            end
            prev = tot;
        end
        fprintf('      Yoshida%d  ratio = %.1f %.1f  (theory %.0f)\n', o, ratio, 2^o);
        if min(ratio) < 0.6 * 2^o
            fprintf('      FAIL: energy error does not scale as h^%d\n', o); fails = fails + 1;
        end
    end

    % ------------------------------------------------------------------ 6
    fprintf('\n[6] coupled pendulum: energy bounded over a long conservative run\n');
    y0c = [1.0; 0.5; 0.0; 0.0];
    E0c = sc.energy(y0c, 0);
    for o = [2 4 6]
        [h1, h2, tot] = energy_halves(sc, y0c, 5000, round(5000/0.02), o);
        fprintf('      Yoshida%d h=0.02 max|dE|/|E0|=%.3e  half-ratio=%.2f\n', ...
                o, tot/abs(E0c), h2/max(h1,realmin));
        if tot/abs(E0c) > 1e-2
            fprintf('      FAIL: relative energy error too large\n'); fails = fails+1;
        end
        if h2 > 3*h1
            fprintf('      FAIL: secular growth on a conservative system\n'); fails = fails+1;
        end
    end

    % ------------------------------------------------------------------ 7
    fprintf('\n[7] vectorised row advance == scalar loop\n');
    yinit = [0.3 1.1; 0.2 -0.7; 1.0 0.4; 0.0 0.2];
    n = 500; h = 0.01;
    yv = yinit; tv = 0;
    for k = 1:n
        [yv, ~, ~, tv] = sp_step(yv, [], tv, h, sc, 4);
    end
    dmax = 0;
    for c = 1:size(yinit,2)
        yy = yinit(:,c); tt = 0;
        for k = 1:n
            [yy, ~, ~, tt] = sp_step(yy, [], tt, h, sc, 4);
        end
        dmax = max(dmax, max(abs(yv(:,c) - yy)));
    end
    fprintf('    max |vectorised - scalar| = %.2e\n', dmax);
    if dmax > 1e-12
        fprintf('    FAIL: vectorised path disagrees with the scalar loop\n'); fails = fails+1;
    end

    % ------------------------------------------------------------------ 8
    fprintf('\n[8] composed tangent == finite difference of the map\n');
    % The tangent map that produces the deviation vectors must be the
    % derivative of the very map that advances the state.  If it is not, every
    % indicator measures a numerical system that is not the one being
    % integrated.  Checked at O(h^2) agreement for a second-order step.
    for o = [2 4 6]
        h = 1e-4; yb = y0c; dv = 1e-6;
        v = [1; 0.3; -0.2; 0.7]; v = v/norm(v);
        Phi = zeros(4,4);
        for j = 1:4
            e = zeros(4,1); e(j) = 1;
            [~, Vj] = sp_step(yb, reshape(e,4,1,1), 0, h, sc, o, false);
            Phi(:,j) = Vj(:,1,1);
        end
        yp = step_num(yb + dv*v, 0, h, sc, o);
        ym = step_num(yb - dv*v, 0, h, sc, o);
        fd = (yp - ym) / (2*dv);
        e = max(abs(Phi*v - fd));
        fprintf('    Yoshida%d: |Phi v - d(flow) v| = %.2e\n', o, e);
        if e > 1e-8
            fprintf('    FAIL: tangent is not the derivative of the step\n'); fails = fails+1;
        end
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_symplectic:failed', '%d symplectic-family test(s) failed', fails);
    end
end


% =========================================================================
function y = run_sp(sys, y0, tend, h, order)
    n = round(tend/h); y = y0; t = 0;
    for k = 1:n
        [y, ~, ~, t] = sp_step(y, [], t, h, sys, order);
    end
end


function y = step_num(y, t, h, sys, order)
    [y, ~, ~, ~] = sp_step(y, [], t, h, sys, order);
end


function [h1, h2, tot] = energy_halves(sys, y0, tend, nstep, order)
%% ENERGY_HALVES  Max |dE| over the first half and the second half of a run.
%
%   The half-over-half ratio is the discriminator between a bounded symplectic
%   oscillation (ratio ~ 1) and a secular drift (ratio > 1, growing with the
%   run length).  A pure "max over the whole run" would confuse the two.
    h = tend/nstep; y = y0; t = 0; E0 = sys.energy(y0, 0);
    half = floor(nstep/2);
    h1 = 0; h2 = 0; tot = 0;
    for k = 1:nstep
        [y, ~, ~, t] = sp_step(y, [], t, h, sys, order);
        e = abs(sys.energy(y,t) - E0);
        tot = max(tot, e);
        if k <= half, h1 = max(h1, e); else, h2 = max(h2, e); end
    end
end


function [h1, h2, tot] = energy_halves_rk4(sys, y0, tend, nstep)
%% Same halves measurement for classical RK4, for the comparison in [5].
%
%   Restricted to the 1-degree-of-freedom pendulum (ndof = 2): the state is
%   [q; p] and sys.force takes the CONFIGURATION q, not the full state.  A
%   first draft passed the whole state and produced a dimension mismatch.
    h = tend/nstep; y = y0; t = 0; E0 = sys.energy(y0, 0);
    half = floor(nstep/2);
    h1 = 0; h2 = 0; tot = 0;
    for k = 1:nstep
        k1 = [y(2);               sys.force(y(1), t)];
        k2 = [y(2)+h/2*k1(2);     sys.force(y(1)+h/2*k1(1), t+h/2)];
        k3 = [y(2)+h/2*k2(2);     sys.force(y(1)+h/2*k2(1), t+h/2)];
        k4 = [y(2)+h*k3(2);       sys.force(y(1)+h*k3(1),   t+h)];
        y = y + h/6*(k1 + 2*k2 + 2*k3 + k4);
        t = t + h;
        e = abs(sys.energy(y,t) - E0);
        tot = max(tot, e);
        if k <= half, h1 = max(h1, e); else, h2 = max(h2, e); end
    end
end
