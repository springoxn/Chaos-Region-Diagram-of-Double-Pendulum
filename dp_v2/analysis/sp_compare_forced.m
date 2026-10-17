function R = sp_compare_forced(varargin)
%% SP_COMPARE_FORCED  Head-to-head: does each indicator track the TRUE largest
%%                    Lyapunov exponent of the forced damped pendulum?
%%
%%   R = sp_compare_forced()
%%   R = sp_compare_forced('N',30, 'cases',{{1.5 0.2; 1.1 0.5}})
%%   R = sp_compare_forced(struct('N',30))
%%
%%   THIS IS THE MEASUREMENT THE PROJECT TURNED ON
%%   --------------------------------------------
%%   The superseded indicator was  ci = log(1 + var(theta) + var(omega)) .
%%   verification_report.md records that it correlates with the true exponent at
%%   r = -0.0066 (F=1.5, gamma=0.2) and r = -0.99 (F=1.1, gamma=0.5) -- no
%%   information in one case and the WRONG SIGN in the other.  This function
%%   recomputes that comparison and adds the literature indicators, so the
%%   replacement is judged by the same yardstick as what it replaces.
%%
%%   GROUND TRUTH
%%   ------------
%%   `lambda` is the true largest Lyapunov exponent from the variational
%%   equations, computed by the PRE-EXISTING project kernel fp_lyap_row.m, which
%%   tests/test_fp.m already anchors against analytic decay rates.  Grading the
%%   new indicators against code that is not part of the new code is deliberate.
%%
%%   WHY RANK CORRELATION
%%   --------------------
%%   What matters for a MAP is whether the ORDERING of points is right, not
%%   whether the relation is linear.  Spearman is therefore the headline number
%%   and Pearson is reported alongside so the difference is visible.
%%
%%   A CAVEAT THAT MUST TRAVEL WITH THE NUMBERS
%%   ------------------------------------------
%%   At strongly supercritical forcing nearly every initial condition is chaotic
%%   and lambda varies little across the plane (README.md notes 0.022-0.071 at
%%   F=1.5).  When the reference quantity has a small dynamic range, every
%%   correlation is dominated by noise.  That is why the default `cases` includes
%%   near-threshold parameter sets where lambda spans a wide range, and why a
%%   single (F, gamma) pair would be misleading.
%%
%%   COST
%%   ----
%%   The ground truth dominates: fp_lyap_row integrates `periods` drive cycles
%%   per point.  The symplectic indicators are computed from ONE additional
%%   integration per row, which is why they are cheap once the reference exists.
%%   The spectral indicators (IACF, SN) come out of that same sp_run call, so
%%   they add post-processing rather than another trajectory pass.
%%
%%   Options
%%     N         30     grid points per axis
%%     periods   300    drive periods for the ground-truth exponent
%%     periodsInd 200   drive periods for the indicators
%%     dt        0.01
%%     Omega     2/3
%%     cases     {{F,gamma}, ...}
%%
%%   See also fp_lyap_row, sp_run, sp_ofli2, sp_iacf, sp_specnum, sp_gali.

    opts = varargin;
    if isempty(opts), opts = struct(); end
    o = struct('N',30, 'periods',300, 'periodsInd',200, 'dt',0.01, ...
               'Omega',2/3, 'verbose',true);
    o.cases = {1.5 0.2; 1.1 0.5; 0.9 0.5; 1.5 0.5};
    % Accept EITHER a struct or name-value pairs.  The first version declared
    % `function R = sp_compare_forced(opts)` only, so calling it with
    % 'N',24,'periods',150,... raised "too many input arguments" at the call
    % boundary, with an empty stack -- which reads like an arity bug inside the
    % function rather than a wrong calling convention.
    if numel(opts) == 1 && isstruct(opts)
        f = fieldnames(opts);
        for i = 1:numel(f), o.(f{i}) = opts.(f{i}); end
    else
        for i = 1:2:numel(opts)
            if ~isfield(o, opts{i})
                error('sp_compare_forced:opt', 'unknown option "%s"', opts{i});
            end
            o.(opts{i}) = opts{i+1};
        end
    end

    % `cases` must be an M x 2 cell of {F, gamma} pairs.  Callers naturally write
    % 'cases',{{1.1 0.5}} -- name-value syntax forces the outer braces, so the
    % value arrives as a 1x1 cell CONTAINING the 1x2 pair, and o.cases{c,1} then
    % indexes one level too deep and yields a 1x2 cell instead of a scalar.
    % Normalising here means both {{F,g}} and {F,g; F2,g2} work.
    if iscell(o.cases) && numel(o.cases) == 1 && iscell(o.cases{1}) ...
            && size(o.cases{1}, 2) >= 2
        o.cases = o.cases{1};
    end
    if ~iscell(o.cases) || size(o.cases,2) < 2
        error('sp_compare_forced:cases', ...
              'cases must be an M x 2 cell of {F, gamma} pairs');
    end

    thv = linspace(-pi, pi, o.N);
    omv = linspace(-4, 4, o.N);

    R = struct('settings', o, 'case', {cell(size(o.cases,1),1)});

    fprintf('Spearman rank correlation with the TRUE largest Lyapunov exponent\n');
    fprintf('(the superseded indicator is ci; the replacements are the rest)\n\n');
    fprintf('%-16s %8s %8s %8s %8s %8s %8s %10s\n', ...
            'case', 'ci', 'mega', 'ofli2', 'iacf', 'specnum', 'gali2', 'lamRange');

    for c = 1:size(o.cases,1)
        F = o.cases{c,1};  gam = o.cases{c,2};

        % ---- ground truth from the existing validated kernel ----
        ro = struct('F',F, 'gamma',gam, 'Omega',o.Omega, 'dt',o.dt, ...
                    'periods',o.periods, 'transient',0.3, 'reortho',10);
        LAM = nan(o.N, o.N);
        for i = 1:o.N
            [LAM(i,:), ~] = fp_lyap_row(thv, omv(i)*ones(1,o.N), ro);
        end

        % ---- the superseded amplitude proxy, from its ORIGINAL definition ----
        CI = nan(o.N, o.N);
        for i = 1:o.N
            for j = 1:o.N
                CI(i,j) = old_ci(thv(j), omv(i), F, gam, o.Omega, 40, 0.04);
            end
        end

        % ---- new indicators, ONE symplectic integration per row ----
        sys = sp_sys('pendulum', 'F', F, 'gamma', gam, 'Omega', o.Omega);
        Td  = 2*pi/o.Omega;
        Tind = o.periodsInd*Td;
        % The spectral indicators are computed by sp_run itself, from the same
        % integration that produces MEGNO and GALI.  They used to be computed by
        % a private `series_at` helper here that re-integrated every point and
        % then called sp_iacf / sp_specnum -- a second implementation of the same
        % definition, which is how the two silently diverge.  sp_run now returns
        % real per-point iacf / specnum, so this file consumes them.
        %
        % `sample` is set to the drive period in STEPS so the sampled series is
        % stroboscopic: that is the natural sampling for this system (it removes
        % the explicit time dependence), and it is what the previous private
        % helper did.  Both spectral indicators are sampling-sensitive, so the
        % interval must stay fixed across the comparison.
        sampleSteps = max(1, round(Td/o.dt));
        MEG = nan(o.N,o.N); OFL = nan(o.N,o.N); GAL = nan(o.N,o.N);
        IAC = nan(o.N,o.N); SPN = nan(o.N,o.N);
        for i = 1:o.N
            Yrow = [thv; omv(i)*ones(1,o.N)];
            rr = sp_run(sys, Yrow, struct('T', Tind, 'dt', o.dt, 'order',4, ...
                         'nGali',2, 'transient',0.3, ...
                         'sample',sampleSteps, 'spectral',true));
            MEG(i,:) = rr.mega;
            GAL(i,:) = rr.gali;
            if ~isempty(rr.iacf),    IAC(i,:) = rr.iacf;    end
            if ~isempty(rr.specnum), SPN(i,:) = rr.specnum; end

            % OFLI2 vectorises over the whole row, so one call per row.
            OFL(i,:) = sp_ofli2(sys, Yrow, struct('T', Tind, 'dt', o.dt, 'order',4));

            if o.verbose && mod(i, max(1,round(o.N/5))) == 0
                fprintf('    (%g,%g): %3.0f%%\n', F, gam, 100*i/o.N);
            end
        end

        % ---- correlations against the ground truth ----
        lam = LAM(:);
        names = {'ci','mega','ofli2','iacf','specnum','gali2'};
        vals  = {CI(:), MEG(:), OFL(:), IAC(:), SPN(:), GAL(:)};
        tab = struct();
        fprintf('%-16s', sprintf('F=%g g=%g', F, gam));
        for k = 1:numel(names)
            v = vals{k};
            ok = isfinite(v) & isfinite(lam);
            if sum(ok) < 5 || std(v(ok)) == 0 || std(lam(ok)) == 0
                tab.(names{k}) = struct('spearman',NaN,'pearson',NaN,'r2',NaN,'n',sum(ok));
                fprintf(' %8s', 'n/a');
                continue
            end
            rs = corr(v(ok), lam(ok), 'type','Spearman');
            rp = corr(v(ok), lam(ok), 'type','Pearson');
            tab.(names{k}) = struct('spearman',rs, 'pearson',rp, 'r2',rp^2, 'n',sum(ok));
            fprintf(' %+8.3f', rs);
        end
        fprintf('  [%.3f,%.3f]\n', min(lam), max(lam));

        R.case{c} = struct('F',F, 'gamma',gam, 'lambda',LAM, 'ci',CI, ...
                           'mega',MEG, 'ofli2',OFL, 'iacf',IAC, ...
                           'specnum',SPN, 'gali2',GAL, 'corr',tab, ...
                           'th',thv, 'om',omv);
    end

    fprintf(['\nci    = log(1+var(theta_detrended)+var(omega)), the superseded proxy\n' ...
             'mega  = MEGNO, ofli2 = second-order OFLI, iacf = integrated\n' ...
             'autocorrelation W, specnum = spectral number, gali2 = alignment index.\n' ...
             'A reliable indicator must correlate clearly ABOVE the ci column.\n' ...
             'iacf and specnum are computed from the same sp_run integration as\n' ...
             'mega and gali2, so their n equals the others (no strided subsample).\n']);
end


% =========================================================================
function ci = old_ci(th0, om0, F, gam, Om, periods, dt)
%% OLD_CI  The superseded indicator, reproduced from its ORIGINAL definition so
%%         the comparison is not against a paraphrase of it.
    Tp = 2*pi/Om;
    nTotal = round(periods*Tp/dt);
    ntrp = max(5, round(periods/3));
    ntr = round(ntrp*Tp/dt);
    nextT = ceil(ntr*dt/Tp)*Tp;

    y = [th0; om0];  t = 0;
    sc = 0;  nsMax = (periods - ntrp) + 3;
    bth = zeros(1, nsMax);  bom = zeros(1, nsMax);
    dt2 = 0.5*dt;  dt6 = dt/6;
    for k = 1:nTotal
        f1 = -gam*y(2) - sin(y(1)) + F*cos(Om*t);
        a1 = y(1) + dt2*y(2);   b1 = y(2) + dt2*f1;
        f2 = -gam*b1 - sin(a1) + F*cos(Om*(t+dt2));
        a2 = y(1) + dt2*b1;     b2 = y(2) + dt2*f2;
        f3 = -gam*b2 - sin(a2) + F*cos(Om*(t+dt2));
        a3 = y(1) + dt*b2;      b3 = y(2) + dt*f3;
        f4 = -gam*b3 - sin(a3) + F*cos(Om*(t+dt));
        y(1) = y(1) + dt6*(y(2) + 2*b1 + 2*b2 + b3);
        y(2) = y(2) + dt6*(f1 + 2*f2 + 2*f3 + f4);
        t = t + dt;
        if t >= nextT
            sc = sc + 1;
            if sc <= nsMax
                bth(sc) = y(1);  bom(sc) = y(2);
            end
            nextT = nextT + Tp;
        end
    end
    n = min(sc, nsMax);
    w = (bth(n) - bth(1))/(2*pi*(n-1));
    thd = bth(1:n) - (bth(1) + 2*pi*w*(0:n-1));
    ci = log(1 + var(thd) + var(bom(1:n)));
end


% =========================================================================
% REMOVED: sp_iacf_of_point, sp_specnum_of_point and the private `series_at`
% they shared.
%
%   Those three were a SECOND implementation of the spectral indicators: they
%   re-integrated each initial condition with a bare `sp_step` loop and then
%   called sp_iacf / sp_specnum -- the same two functions sp_run already calls.
%   Two code paths computing one definition is how the two drift apart, and the
%   plan at docs/rerun_plan.md flagged exactly that.
%
%   They were local functions here, so nothing outside this file could call them
%   and no external caller can break.  sp_run now computes the per-point IACF and
%   spectral number from the integration it is already doing, which is both the
%   single source of truth and cheaper: no second trajectory pass.

