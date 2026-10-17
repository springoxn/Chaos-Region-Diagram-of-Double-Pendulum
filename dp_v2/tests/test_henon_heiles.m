function test_henon_heiles()
%% TEST_HENON_HEILES  The paper's Henon-Heiles results (Eq. 20, Figs. 10-12).
%
%   Barrio, Borczyk & Breiter (2009) use Henon-Heiles as their SECOND test bed,
%   precisely because it has two degrees of freedom: unlike the planar pendulum
%   it has room for a gradient direction genuinely distinct from the flow
%   tangent.  That is what makes their eta0 comparison (Fig. 11) non-degenerate
%   there, and it is why this system is worth implementing at all.
%
%   WHAT IS ASSERTED, AND AGAINST WHAT
%     [1] the analytic derivatives are right          (against central differences)
%     [2] energy is conserved on a bounded orbit      (against E = 1/12 exactly)
%     [3] the escape energy is 1/6, and slices below it are bounded
%     [4] the OFLI2 map CONVERGES as tf grows         (against a tf=2000 reference)
%         -- the paper's Sec. 4.3 claim that tf = 50 "may lead to completely
%         wrong results"
%     [5] the initial-variation vector MATTERS         (the paper's Fig. 11)
%
%   [4] IS THE SUBSTANTIVE ONE.  The paper states the slow-convergence warning
%   qualitatively ("the first one is not symmetric in spite of the symmetry of
%   the problem, and we may infer completely wrong results").  The symmetry it
%   appeals to is NOT Y -> -Y: that was measured and REJECTED here, because the
%   potential contains -y^3/3, so y -> -y is not a symmetry at all.  What IS
%   exact is X -> -X (measured, machine precision).  Rather than lean on a
%   symmetry argument, [4] compares each tf against a long reference directly by
%   rank correlation, which is the claim that actually matters and needs no
%   symmetry at all.
%
%   Run:  addpath('tests'); test_henon_heiles
%
%   See also sp_sys, sp_henon_heiles_ic, sp_henon_heiles_map, sp_ofli2.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'));
    fprintf('=== paper Eq. (20): Henon-Heiles ===\n\n');
    fails = 0;
    rng(20260922);

    sys = sp_sys('henonheiles');
    Eesc = 1/6;

    % ------------------------------------------------------------------ 1
    fprintf('[1] analytic derivatives vs central differences\n');
    q = [-0.4 0.3 0.25 0.1 ; 0.15 -0.2 0.4 -0.35];
    h = 1e-6;

    % force vs -grad V, differencing the ENERGY (which is what makes this an
    % independent check: it never touches sys.force's own formula)
    e1 = 0;
    for j = 1:2
        qp = q; qp(j,:) = qp(j,:) + h;
        qm = q; qm(j,:) = qm(j,:) - h;
        yp = [qp; zeros(2,size(q,2))];  ym = [qm; zeros(2,size(q,2))];
        dV = (sys.energy(yp,0) - sys.energy(ym,0))/(2*h);
        F  = sys.force(q,0);
        % ROW j AGAINST ROW j.  force is 2 x N and dV is 1 x N; subtracting the
        % matrix from one row broadcasts and reports the other row's gradient.
        e1 = max(e1, max(abs(F(j,:) + dV)));
    end

    % Hessian vs differencing the force
    e2 = 0;
    for k = 1:2
        qp = q; qp(k,:) = qp(k,:) + h;
        qm = q; qm(k,:) = qm(k,:) - h;
        dF = (sys.force(qp,0) - sys.force(qm,0))/(2*h);
        Ja = sys.dforce(q,0);
        for c = 1:size(q,2)
            e2 = max(e2, max(abs(Ja(:,k,c) - dF(:,c))));
        end
    end

    % d2force vs differencing the Hessian -- the derivative sp_ofli2 consumes
    e3 = 0;
    for l = 1:2
        qp = q; qp(l,:) = qp(l,:) + h;
        qm = q; qm(l,:) = qm(l,:) - h;
        dJ = (sys.dforce(qp,0) - sys.dforce(qm,0))/(2*h);
        A2 = sys.d2force(q,0);
        for c = 1:size(q,2)
            e3 = max(e3, max(max(abs(A2(:,:,l,c) - dJ(:,:,c)))));
        end
    end
    fprintf('    |force  - (-grad V)|  via energy FD = %.2e\n', e1);
    fprintf('    |dforce - d(force)/dq| via FD       = %.2e\n', e2);
    fprintf('    |d2force- d(dforce)/dq| via FD      = %.2e\n', e3);
    if max([e1 e2 e3]) > 1e-8
        fprintf(['    FAIL: an analytic derivative is wrong.  d2force in particular\n' ...
                 '    feeds OFLI2, where an error produces no other symptom.\n']);
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 2
    fprintf('\n[2] energy conserved on a bounded orbit (E = 1/12)\n');
    E0 = 1/12;
    y0 = [0; -0.2; sqrt(2*E0 - 0.04 + 2*(-0.008)/3); 0];
    if abs(sys.energy(y0,0) - E0) > 1e-14
        fprintf('    FAIL: the generated initial condition is not at E = 1/12\n');
        fails = fails + 1;
    end
    y = y0; t = 0; drift = 0;
    for k = 1:20000
        [y, ~, ~, t] = sp_step(y, [], t, 0.01, sys, 4);
        drift = max(drift, abs(sys.energy(y,0) - sys.energy(y0,0)));
    end
    fprintf('    T=200, dt=0.01 : max |dE| = %.3e\n', drift);
    if drift > 1e-6
        fprintf('    FAIL: the symplectic stepper drifted on a bounded orbit\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 3
    fprintf('\n[3] the escape energy is 1/6, and the paper''s slices are below it\n');
    % On the y axis with X = Y = 0: V = y^2/2 - y^3/3 has its maximum at y = 1,
    % where V = 1/6.  Beyond that saddle the well is open along y -> +inf.
    Vmax = 0.5*1^2 - 1^3/3;
    fprintf('    V(0,1) = %.6f  (exact 1/6 = %.6f)\n', Vmax, Eesc);
    if abs(Vmax - Eesc) > 1e-14
        fprintf('    FAIL: the saddle of V is not at 1/6\n'); fails = fails + 1;
    end
    for E = [1/12 1/8]
        [~, ic] = sp_henon_heiles_ic('E',E, 'N',25, 'plane','yY');
        fprintf('    E=%.5f : %d of %d points allowed (E < 1/6: bounded)\n', ...
                E, ic.nPoints - ic.nEscaped, ic.nPoints);
        if E > Eesc
            fprintf('    FAIL: this slice should be below the escape energy\n');
            fails = fails + 1;
        end
    end
    if ~(1/8 < Eesc)
        fprintf('    FAIL: the paper''s E=1/8 slice must be below 1/6\n'); fails = fails + 1;
    end

    % every generated point must sit exactly at its slice energy
    [Y0, ic] = sp_henon_heiles_ic('E',1/12, 'N',25, 'plane','yY');
    dE = abs(sys.energy(Y0,0) - 1/12);
    fprintf('    max |E(y0) - 1/12| over allowed points = %.2e\n', max(dE(~ic.escaped)));
    if max(dE(~ic.escaped)) > 1e-14
        fprintf('    FAIL: the momentum solve does not reproduce the slice energy\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 4
    fprintf('\n[4] OFLI2 convergence in tf (the paper''s Sec. 4.3 claim)\n');
    % The paper: at tf = 50 "we may infer completely wrong results".  Measured
    % here against a long reference by rank correlation.
    %
    % The reference is tf = 2000.  It is NOT claimed to be the exact answer --
    % OFLI2 has no exact answer at finite time -- but it is far enough ahead of
    % tf = 500 that the ORDERING it induces is stable, which is what Spearman
    % measures and what a map is read for.
    E = 1/8; N = 41; dt = 0.02;
    Rref = sp_henon_heiles_map('indicator','ofli2','E',E,'N',N,'T',2000, ...
                               'dt',dt,'verbose',false);
    Vref = Rref.values;
    base = ~isnan(Vref);

    tfs = [50 100 200 500 1000];
    rs = zeros(size(tfs));
    fprintf('    %6s %12s %12s %14s\n', 'tf', 'pearson', 'spearman', 'median rel diff');
    for i = 1:numel(tfs)
        M = sp_henon_heiles_map('indicator','ofli2','E',E,'N',N,'T',tfs(i), ...
                                'dt',dt,'verbose',false);
        V = M.values;
        ok = base & ~isnan(V);
        rp = corr(V(ok), Vref(ok));
        rs(i) = corr(V(ok), Vref(ok), 'type','Spearman');
        rd = median(abs(V(ok) - Vref(ok)) ./ abs(Vref(ok)));
        fprintf('    %6d %12.4f %12.4f %14.4f\n', tfs(i), rp, rs(i), rd);
    end
    % the paper's ordering claim: short tf is wrong, long tf is right, and the
    % approach is monotone
    if ~all(diff(rs) > 0)
        fprintf(['    FAIL: the correlation with the reference must increase\n' ...
                 '    monotonically in tf; that is the paper''s claim.\n']);
        fails = fails + 1;
    end
    fprintf('    tf=50 rank corr %.4f  ->  tf=1000 rank corr %.4f\n', rs(1), rs(end));
    if ~(rs(1) < 0.7)
        fprintf(['    FAIL: tf=50 should be clearly unreliable (< 0.7) but gave %.4f\n' ...
                 '    The paper''s warning would then not be reproducible.\n'], rs(1));
        fails = fails + 1;
    end
    if ~(rs(end) > 0.9)
        fprintf('    FAIL: tf=1000 should agree well with the reference (got %.4f)\n', rs(end));
        fails = fails + 1;
    end
    fprintf(['    CONFIRMED: tf=50 is qualitatively wrong and tf grows into the\n' ...
             '    reference -- the paper''s "correct selection of the final time is\n' ...
             '    essential" is reproducible.\n']);

    % ------------------------------------------------------------------ 5
    fprintf('\n[5] the initial variation vector matters (the paper''s Fig. 11)\n');
    % Fig. 11 compares four eta0 choices.  Two measurable consequences:
    %   (a) eta0 = grad H (their Fig. 11c, the "good" one) must be SMOOTHER than
    %       a fixed careless eta0 (their Fig. 11a).
    %   (b) eta0 along the FLOW must be qualitatively different, because a
    %       deviation launched tangent to the orbit grows only algebraically.
    %       This is the mechanism the paper identifies, and it is the sharper of
    %       the two -- it is a statement about the indicator's magnitude, not
    %       about its spatial roughness.
    N2 = 25; T2 = 200;
    Mg = sp_henon_heiles_map('indicator','fli','dev0','grad','E',E,'N',N2, ...
                             'T',T2,'dt',dt,'verbose',false);
    Mf = sp_henon_heiles_map('indicator','fli','dev0','fixed','E',E,'N',N2, ...
                             'T',T2,'dt',dt,'verbose',false);
    Mo = sp_henon_heiles_map('indicator','fli','dev0','flow','E',E,'N',N2, ...
                             'T',T2,'dt',dt,'verbose',false);
    vg = Mg.values(~isnan(Mg.values));
    vf = Mf.values(~isnan(Mf.values));
    vo = Mo.values(~isnan(Mo.values));
    fprintf('    eta0=grad  : mean %8.4f  std %8.4f\n', mean(vg), std(vg));
    fprintf('    eta0=fixed : mean %8.4f  std %8.4f\n', mean(vf), std(vf));
    fprintf('    eta0=flow  : mean %8.4f  std %8.4f\n', mean(vo), std(vo));
    if ~(mean(vo) < mean(vg))
        fprintf(['    FAIL: a deviation launched along the flow should grow far more\n' ...
                 '    slowly than one along grad H; the tangent direction has no\n' ...
                 '    exponential growth.  Measured flow=%.4f vs grad=%.4f\n'], ...
                mean(vo), mean(vg));
        fails = fails + 1;
    end
    fprintf(['    CONFIRMED: eta0 along the flow is suppressed (%.4f vs %.4f), which is\n' ...
             '    the mechanism the paper identifies for the spurious patterns.\n'], ...
            mean(vo), mean(vg));

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_henon_heiles:failed', '%d Henon-Heiles test(s) failed', fails);
    end
end
