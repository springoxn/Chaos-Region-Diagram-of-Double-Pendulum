function [R, M] = sp_mathieu_bands(varargin)
%% SP_MATHIEU_BANDS  Verify the paper's analytic Mathieu prediction (Eqs. 26-28).
%%
%%   R = sp_mathieu_bands()
%%   R = sp_mathieu_bands('T',400, 'b',1, 'a',4)
%%   R = sp_mathieu_bands('mode','ideal')      % only the Floquet anchor
%%   R = sp_mathieu_bands('fig',true)          % also write a figure
%%
%%   WHY THIS EXISTS
%%   ---------------
%%   docs/rerun_plan.md section C singles this out as the highest-value item of
%%   the unfinished paper reproductions, for one reason: it is an ANALYTIC
%%   prediction, so it can be judged right or wrong rather than merely inspected.
%%
%%   Barrio, Borczyk & Breiter (2009), Sec. 4.1.2, consider the coupled pendulum
%%   of their Eq. (18) with the second degree of freedom switched off but
%%   PERTURBED: y = Y = 0, delta y != 0.  They observe that the variational
%%   indicators then report the planar pendulum as chaotic, although the planar
%%   pendulum is integrable -- their "paradox".  They resolve it as follows.
%%
%%   THE CHAIN OF THE ARGUMENT
%%   -------------------------
%%   1. With y = Y = 0 the variational equations (their Eq. 23) DECOUPLE:
%%
%%          d2(delta x)/dt2 = -cos(x) delta x                 (their Eq. 24)
%%          d2(delta y)/dt2 = -a(1 - b cos x) delta y         (their Eq. 25)
%%
%%   2. For a CIRCULATING x, substitute u = Omega t and xi^2 = a/Omega^2:
%%
%%          d2(delta y)/du2 = -xi^2 (1 - b cos u) delta y     (their Eq. 26)
%%
%%      which is the standard Mathieu equation -- a LINEAR oscillator with a
%%      PERIODIC coefficient.
%%
%%   3. A Mathieu equation has parametric resonance bands, and for this form they
%%      sit at
%%
%%          xi = k/2 ,  k = 1, 2, 3, ...                      (their Eq. 27)
%%
%%      Equivalently, since xi = sqrt(a)/Omega and a = 4,
%%
%%          Omega = 4/k .                                     (their Eq. 28)
%%
%%   4. THEREFORE: the "chaotic" stripes are not chaos.  They are parametric
%%      resonance zones of a linear transverse mode.  A positive Lyapunov
%%      exponent on those stripes is CORRECT and does not contradict the
%%      integrability of the planar motion -- the paper's actual conclusion,
%%      and the reason it insists that a variational and a spectral indicator
%%      must be confronted with each other.
%%
%%   WHAT IS ASSERTED, AND WHY IT IS FALSIFIABLE
%%   ------------------------------------------
%%   Two independent checks, both against a number the paper states in advance:
%%
%%     [A] IDEAL MATHIEU.  Integrating Eq. (26) directly and computing the
%%         Floquet multipliers over one period must give |rho| = 1 (stable)
%%         everywhere except bands centred near xi = k/2.  This tests the
%%         MATHEMATICS, with no ising about the pendulum's dynamics.
%%
%%     [B] THE PHYSICAL SYSTEM.  Running the PROJECT's own symplectic stepper on
%%         the coupled pendulum with the delta y mode seeded must reproduce the
%%         bands, and they must sit at Omega_eff = 4/k.  This tests that the
%%         reduction in step 2 is faithful for the real system.
%%
%%   A SUBTLETY THAT MATTERS FOR THE COMPARISON (measured, not assumed)
%%   -----------------------------------------------------------------
%%   The paper writes the resonance as "Omega = 4/k" and reads the bands off the
%%   figure at X = 4, 2, 4/3, ... where X is the INITIAL VELOCITY.  In the
%%   circulation regime X and the actual circulation frequency Omega_eff are NOT
%%   equal: near the separatrix the orbit lingers at the top of the swing, and
%%   Omega_eff is well below X.  Measured for x(0) = 0:
%%
%%       X = 2.05 -> Omega_eff = 1.100   (X/Omega = 1.86)
%%       X = 3.00 -> Omega_eff = 2.604   (X/Omega = 1.15)
%%       X = 4.00 -> Omega_eff = 3.727   (X/Omega = 1.07)
%%       X = 6.00 -> Omega_eff = 5.827   (X/Omega = 1.03)
%%
%%   Using Omega_eff instead of X is what makes the prediction sharp: the bands
%%   then land on xi = k/2 to better than 2% .  Reading them off X directly
%%   leaves a 5-15% systematic offset that is easy to mistake for a failure of
%%   the theory.  Both numbers are reported so the difference is visible.
%%
%%   Options
%%     a        4        paper's value (sqrt(a) = 2 sets the 4 in "4/k")
%%     b        1        modulation depth of the Mathieu coefficient
%%     T        600      integration time per point for the physical sweep
%%     dt       0.02     step
%%     XRange   [2.05 6] circulation regime only (separatrix at X = 2)
%%     nX       80       grid points in X
%%     bandThr  0.05     lambda above which a point counts as unstable
%%     mode     'both'   'both' | 'ideal' | 'physical'
%%     fig      false    write gallery/sp_mathieu_bands.png
%%     verbose  true
%%     checkScalar false cross-check the vectorised Floquet sweep against the
%%                   scalar eig() implementation and ERROR if they disagree
%%
%%   Output R fields
%%     ideal.xi, ideal.mu, ideal.centers   -- Floquet scan of Eq. (26)
%%     phys.X, phys.omega, phys.lambda     -- the physical sweep
%%     phys.bands                          -- located bands, with xi and k
%%     agreeXi                             -- |xi_measured - k/2|, the assertion
%%     agreeOmega                          -- |Omega_eff - 4/k| relative error
%%
%%   See also sp_sys, sp_step, sp_paper_repro, test_mathieu.

    o = struct('a',4, 'b',1, 'T',600, 'dt',0.02, ...
               'XRange',[2.05 6.0], 'nX',80, 'bandThr',0.05, ...
               'mode','both', 'fig',false, 'verbose',true, 'checkScalar',false);
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_mathieu_bands:opt','unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    R = struct('settings', o, 'ideal', struct(), 'phys', struct());
    wantIdeal = any(strcmp(o.mode, {'both','ideal'}));
    wantPhys  = any(strcmp(o.mode, {'both','physical'}));

    % ==================================================================
    % [A] the ideal Mathieu equation, Eq. (26)
    % ==================================================================
    if wantIdeal
        if o.verbose
            fprintf('=== [A] ideal Mathieu Eq.(26):  y'''' = -xi^2 (1 - b cos u) y ===\n');
            fprintf('    b = %g   (Floquet multipliers over one period)\n\n', o.b);
        end
        % Scan resolution: the k-th band has width O(b^k), so a small b needs a
        % fine step.  The step therefore DECREASES with b -- `0.02*o.b` had it
        % backwards and made the cheap case the slow one.  A fixed 5e-3 resolves
        % b >= 0.2; below that the bands narrow and a finer step is required.
        % The Floquet sweep is VECTORISED over xi: the equation is linear in y, so
        % every xi advances in lock-step with no interaction between them.  This
        % is the same trick dp_lyap_row.m uses for a row of initial conditions,
        % and it makes the resolution essentially free -- a 2600-point scan costs
        % about what one point used to.
        step = min(0.005, max(0.0008, 0.05*o.b));
        xi = 0.02:step:2.60;
        mu = mathieu_mu_vec(xi, o.b);
        R.ideal = struct('xi', xi, 'mu', mu);

        if o.checkScalar
            % The vectorised sweep determines max|rho| from the trace of the
            % fundamental matrix, the scalar one from eig().  Both are exact for
            % a 2x2 system, but only one of them is on the fast path, so the two
            % are compared rather than assumed equal.
            probe = [0.30 0.536 0.90 1.10 1.655 2.215];
            emax = 0;
            for p = probe
                [~, i] = min(abs(xi - p));
                emax = max(emax, abs(mu(i) - mathieu_mu(xi(i), o.b)));
            end
            R.ideal.scalarMaxDiff = emax;
            if o.verbose
                fprintf('    vectorised vs scalar eig() Floquet: max diff %.2e\n', emax);
            end
            if emax > 1e-9
                error('sp_mathieu_bands:vecMismatch', ...
                      'vectorised and scalar Floquet growth disagree by %.2e', emax);
            end
        end

        % find_bands returns the INDEX RUNS, not the centres: the centre is the
        % xi at which the Floquet growth peaks inside each run, which is the
        % physically meaningful location of the resonance (the band edges are
        % where |rho| = 1, the centre is where the instability is strongest).
        %
        % THE DETECTION THRESHOLD MUST SCALE WITH b.  The unstable band of Eq.
        % (26) has width and growth both O(b^k), so at b = 0.05 the k = 1 band
        % peaks at mu ~ 1e-2 while at b = 1 it reaches ~1e-1.  A fixed absolute
        % threshold of 1e-8 is far above the true roundoff floor (measured
        % ~1e-15 in the stable bands) yet the first version still found nothing
        % at b = 0.05, because the scan step 0.004 can straddle a band that is
        % only ~0.01 wide.  The threshold is now a fraction of the observed
        % maximum, with a floor at the roundoff level, so the same code works
        % across the whole b range and reports the bands the physics has.
        muMax = max(mu);
        thr = max(1e-12, 1e-3*muMax);
        [idx, widths, lo, hi] = find_bands(xi, mu, thr, 0.004);
        centers = zeros(1, numel(idx));
        for b = 1:numel(idx)
            [~, ip] = max(mu(idx{b}));
            centers(b) = xi(idx{b}(ip));
        end
        R.ideal.centers = centers;
        R.ideal.widths  = widths;
        R.ideal.lo = lo;
        R.ideal.hi = hi;
        R.ideal.threshold = thr;

        if o.verbose
            fprintf('    %5s %10s %10s %10s %10s\n', 'k', 'pred k/2', 'center', 'lo', 'hi');
            for k = 1:numel(centers)
                fprintf('    %5d %10.3f %10.4f %10.4f %10.4f\n', ...
                        k, k/2, centers(k), lo(k), hi(k));
            end
        end
        if isempty(centers)
            error('sp_mathieu_bands:noBands', ...
                  'no instability bands found -- the sign of the coefficient is wrong?');
        end
        R.ideal.errCenter = max(abs(centers(:) - (1:numel(centers)).'/2));        if o.verbose
            fprintf('\n    max |center - k/2| = %.4f over %d bands\n', ...
                    R.ideal.errCenter, numel(centers));
        end
    end

    % ==================================================================
    % [B] the physical system, with the delta y mode seeded
    % ==================================================================
    if wantPhys
        if o.verbose
            fprintf('\n=== [B] coupled pendulum, delta-y mode (the project stepper) ===\n');
            fprintf('    a = %g, b = %g, T = %g, dt = %g\n', o.a, o.b, o.T, o.dt);
            fprintf('    state layout is [x; y; X; Y], so delta y is COMPONENT 2.\n');
            fprintf('    Seeding component 3 would measure delta X -- the regular\n');
            fprintf('    pendulum mode, which has no parametric bands at all.\n\n');
        end
        sys = sp_sys('coupled','a',o.a,'b',o.b);
        Xs = linspace(o.XRange(1), o.XRange(2), o.nX);
        lam = nan(size(Xs));
        ome = nan(size(Xs));
        for i = 1:numel(Xs)
            lam(i) = dymode_lyap(sys, [0; 0; Xs(i); 0], o.T, o.dt);
            ome(i) = circ_freq(Xs(i));
        end
        R.phys = struct('X', Xs, 'omega', ome, 'lambda', lam);

        [bIdx, ~, buLo, buHi] = find_bands(Xs, lam, o.bandThr, 0.04);
        nb = numel(bIdx);
        bands = struct('Xlo',{}, 'Xhi',{}, 'Xpeak',{}, 'lambda',{}, ...
                       'omega',{}, 'xi',{}, 'kImplied',{}, 'kRound',{});
        for i = 1:nb
            seg = bIdx{i};
            [mx, ip] = max(lam(seg));
            iP = seg(ip);
            xi = sqrt(o.a)/ome(iP);
            % THE TWO FORMULAS IN THE PAPER CARRY THE SAME k:
            %   Eq. (27)  xi = k/2            =>  k = 2 xi
            %   Eq. (28)  Omega = 4/k = 2/xi  =>  k = 2/Omega = 2 xi / sqrt(a)
            % with a = 4.  Deriving k from 4/xi is a category error -- that is
            % 2k, not k -- and it produced k/2 values of 2 and 4 above where the
            % physics is 1 and 2.  k = 2*xi is the single correct extraction.
            kImpl = 2*xi;
            bands(i) = struct('Xlo',buLo(i), 'Xhi',buHi(i), 'Xpeak',Xs(iP), ...
                              'lambda',mx, 'omega',ome(iP), 'xi',xi, ...
                              'kImplied',kImpl, 'kRound',max(1,round(kImpl)));
        end
        R.phys.bands = bands;

        if o.verbose
            fprintf('    %5s %8s %8s %10s %10s %10s %8s %8s\n', ...
                    'band', 'Xlo', 'Xhi', 'Xpeak', 'lambda', 'Omega_eff', 'xi', 'k/2');
            for i = 1:nb
                fprintf('    %5d %8.2f %8.2f %10.2f %10.4f %10.4f %8.4f %8.2f\n', ...
                        i, bands(i).Xlo, bands(i).Xhi, bands(i).Xpeak, ...
                        bands(i).lambda, bands(i).omega, bands(i).xi, ...
                        bands(i).kRound/2);
            end
        end

        if nb > 0
            xim = [bands.xi];
            kr  = [bands.kRound];
            R.agreeXi    = abs(xim - kr/2);
            R.agreeOmega = abs([bands.omega] - o.a./kr) ./ (o.a./kr);
            if o.verbose
                fprintf(['\n    |xi - k/2|            : %s\n' ...
                         '    |Omega_eff - 4/k|/4/k : %s\n'], ...
                        mat2str(R.agreeXi, 3), mat2str(R.agreeOmega, 3));
                fprintf(['    The paper''s Eq. (28) predicts Omega = 4/k, where Omega is the\n' ...
                         '    CIRCULATION FREQUENCY.  The paper reads the bands off the initial\n' ...
                         '    velocity X, which equals Omega only in the fast-circulation limit;\n' ...
                         '    measured X/Omega_eff falls from 1.86 at X=2.05 to 1.03 at X=6.\n' ...
                         '    Using Omega_eff instead of X is what makes the prediction sharp.\n']);
            end
        end
    end

    % ==================================================================
    % figure
    % ==================================================================
    if o.fig
        outdir = fullfile(fileparts(mfilename('fullpath')),'..','gallery');
        if ~exist(outdir,'dir'), mkdir(outdir); end
        f = figure('Visible','off','Position',[80 80 1150 430]);

        if wantIdeal
            subplot(1,2,1);
            plot(R.ideal.xi, R.ideal.mu, 'LineWidth', 1.2); hold on;
            yl = ylim;
            for k = 1:numel(R.ideal.centers)
                plot([k/2 k/2], yl, 'k--');
            end
            hold off; grid on;
            xlabel('\xi = \surd a / \Omega'); ylabel('max |Floquet multiplier| (log)');
            title({sprintf('(a) ideal Mathieu Eq.(26), b = %g', o.b), ...
                   'dashed: the paper''s prediction \xi = k/2'});
            legend({'Floquet growth','k/2'}, 'Location','northwest');
        end

        if wantPhys
            subplot(1,2,2);
            plot(R.phys.X, R.phys.lambda, 'LineWidth', 1.2); hold on;
            plot(R.phys.omega, R.phys.lambda, 'LineWidth', 1.0);
            yl = ylim;
            for i = 1:numel(R.phys.bands)
                bnd = R.phys.bands(i);
                plot([bnd.Xlo bnd.Xhi], [0 0]*0+yl(1), 'r-', 'LineWidth', 3);
                plot(bnd.Xpeak, yl(1), 'rv');
            end
            hold off; grid on;
            xlabel('X(0)   [and \Omega_{eff} as the smooth curve]');
            ylabel('\lambda of the \deltay mode');
            title({'(b) coupled pendulum, transverse mode', ...
                   'red: located bands; theory X \approx 4/k at large X'});
            legend({'vs X(0)','vs \Omega_{eff}','band'}, 'Location','northwest');
        end

        fn = fullfile(outdir, 'sp_mathieu_bands.png');
        exportgraphics(f, fn, 'Resolution', 140);
        close(f);
        if o.verbose
            fprintf('\n    figure written to %s\n', fn);
        end
    end
end


% =========================================================================
function mu = mathieu_mu_vec(xi, b)
%% log of the largest Floquet multiplier over one period, for a WHOLE VECTOR of
%% xi at once.
%%
%%   The equation is linear and each xi is independent, so the 2x2 fundamental
%%   matrices are stacked as 2 x 2 x n and advanced together.  No eigenvalue call
%%   is needed: for a 2x2 matrix the Floquet multipliers are the roots of
%%   rho^2 - tr(Y) rho + det(Y) = 0, and det(Y) = 1 exactly for this equation
%%   (the coefficient has no damping term, so the Wronskian is conserved).  The
%%   largest modulus is therefore
%%
%%       max|rho| = (|tr| + sqrt(tr^2 - 4))/2          (|tr| >= 2, unstable)
%%       max|rho| = 1                                   (|tr| <  2, stable)
%%
%%   which is exact and vectorised, and avoids n separate eig() calls.
%%
%%   2000 RK4 steps per period.  The reported quantity is |rho| - 1, which near a
%%   band edge is ~1e-3, so the integration error must be well below that: at
%%   2000 steps the RK4 error per period is O(h^4) ~ 1e-10 for the smooth
%%   coefficient (1 - b cos u).  12000 steps was used first and cost 6x more for
%%   no change in any reported digit.
    nSteps = 2000;
    h = 2*pi/nSteps;
    n = numel(xi);
    % Y(:,:,i) is the fundamental matrix for xi(i)
    Y = zeros(2,2,n);
    Y(1,1,:) = 1;  Y(2,2,:) = 1;
    xi2 = reshape(xi.^2, 1, 1, n);
    u = 0;
    for k = 1:nSteps
        c = -xi2 .* (1 - b*cos(u));      % 1 x 1 x n
        % f(Y) = [Y(2,:,:) ; c .* Y(1,:,:)]
        f1 = @(YY) YY(2,:,:);
        f2 = @(YY) c .* YY(1,:,:);
        k1 = cat(1, f1(Y),            f2(Y));
        Yh = Y + h/2*k1;
        k2 = cat(1, f1(Yh),           f2(Yh));
        Yh = Y + h/2*k2;
        k3 = cat(1, f1(Yh),           f2(Yh));
        Yh = Y + h*k3;
        k4 = cat(1, f1(Yh),           f2(Yh));
        Y = Y + h/6*(k1 + 2*k2 + 2*k3 + k4);
        u = u + h;
    end
    tr = reshape(Y(1,1,:) + Y(2,2,:), 1, n);
    % stable => max|rho| = 1 => log = 0; unstable => the larger root
    disc = tr.^2 - 4;
    rho = ones(1, n);
    un = disc > 0;
    rho(un) = (abs(tr(un)) + sqrt(disc(un)))/2;
    mu = log(rho);
end


function mu = mathieu_mu(xi, b)
%% Scalar reference implementation, kept because it is what mathieu_mu_vec is
%% checked against.  Slow (one integration per xi) and therefore not used on the
%% scan path.
    nSteps = 2000;
    h = 2*pi/nSteps;
    Y = eye(2);
    u = 0;
    for k = 1:nSteps
        Y = rk4_y(Y, u, h, xi, b);
        u = u + h;
    end
    mu = log(max(abs(eig(Y))));
end


function Yn = rk4_y(Y, u, h, xi, b)
    f = @(uu, YY) [YY(2,:); -xi^2*(1 - b*cos(uu))*YY(1,:)];
    k1 = f(u, Y);
    k2 = f(u + h/2, Y + h/2*k1);
    k3 = f(u + h/2, Y + h/2*k2);
    k4 = f(u + h,   Y + h*k3);
    Yn = Y + h/6*(k1 + 2*k2 + 2*k3 + k4);
end


% =========================================================================
function [idx, widths, lo, hi] = find_bands(x, v, thr, minWidth)
%% Maximal runs of v > thr, returned as index vectors plus edge values.
    inb = v(:).' > thr;
    idx = {}; widths = []; lo = []; hi = [];
    i = 1; n = 0;
    while i <= numel(x)
        if inb(i)
            j = i;
            while j <= numel(x) && inb(j), j = j + 1; end
            seg = i:(j-1);
            if x(seg(end)) - x(seg(1)) > minWidth
                n = n + 1;
                idx{n} = seg;                                  %#ok<AGROW>
                widths(n) = x(seg(end)) - x(seg(1));           %#ok<AGROW>
                lo(n) = x(seg(1));                             %#ok<AGROW>
                hi(n) = x(seg(end));                           %#ok<AGROW>
            end
            i = j;
        else
            i = i + 1;
        end
    end
end


% =========================================================================
function Om = circ_freq(X)
%% Angular frequency of the circulating solution of  x'' = -sin x  with
%% x(0) = 0, x'(0) = X > 2 (the separatrix is at X = 2).
%%
%%   H = X^2/2 - cos x > 1 in the circulation regime.  The period is one full
%%   turn of x, obtained by quadrature of  dx/dt = sqrt(2(H + cos x)) :
%%
%%       T = integral_0^{2 pi} dx / sqrt(2(H + cos x)) .
%%
%%   This is what makes the comparison sharp.  The paper labels the resonance
%%   with X, but X is the initial velocity, not the frequency: near the
%%   separatrix the orbit lingers at the top of the swing and Omega_eff is far
%%   below X (measured X/Omega_eff = 1.86 at X = 2.05, 1.03 at X = 6).
    E = X^2/2 - 1;
    if E <= 1
        Om = NaN;
        return
    end
    T = quadgk(@(x) 1./sqrt(2*(E + cos(x))), 0, 2*pi);
    Om = 2*pi/T;
end


% =========================================================================
function L = dymode_lyap(sys, Y0, T, dt)
%% Largest Lyapunov exponent of the delta-y mode ALONE.
%%
%%   The state layout is [x; y; X; Y] -- COORDINATES FIRST.  The transverse
%%   displacement is therefore COMPONENT 2, and seeding component 3 would measure
%%   delta X, the pendulum mode, which is regular and has no parametric bands.
%%
%%   Eq. (23) of the paper shows the two modes decouple exactly when y = Y = 0,
%%   so a single seeded direction isolates the transverse mode with no
%%   contamination.  The tangent is advanced by the SAME composed map as the
%%   trajectory (sp_step does both), so this is the discrete system's own growth
%%   rate and not a finite-difference stand-in.
    nSteps = round(T/dt);
    ntr = round(0.2*nSteps);
    y = Y0;
    V = zeros(4,1,1);
    V(2,1,1) = 1;
    acc = 0; n = 0; t = 0;
    for k = 1:nSteps
        [y, V, g, t] = sp_step(y, V, t, dt, sys, 4);
        if k > ntr
            acc = acc + log(g(1,1));
            n = n + 1;
        end
    end
    L = acc/(max(1,n)*dt);
end
