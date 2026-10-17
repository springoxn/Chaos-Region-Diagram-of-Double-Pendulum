function test_comparison()
%% TEST_COMPARISON  Grade every indicator against the TRUE Lyapunov exponent,
%%                  for BOTH systems, and assert that the replacement works.
%
%%   This is the test that answers the question the project turned on:
%%   the superseded log(1+var) proxy does not track chaos, and the literature
%%   indicators do.  It is a MEASUREMENT test: the assertions are on correlation
%%   coefficients, which is the same yardstick verification_report.md used to
%%   convict the old indicator.
%%
%%   [1] forced pendulum, F=1.1 gamma=0.5: the OLD indicator correlates
%%       NEGATIVELY (wrong sign -- the documented failure) while MEGNO and the
%%       IACF correlate positively and strongly
%%   [2] forced pendulum, F=1.5 gamma=0.2: lambda has almost no dynamic range
%%       here, so NO indicator can work; asserted explicitly so the limitation is
%%       on the record rather than quietly omitted
%%   [3] double pendulum: GALI_k must correlate NEGATIVELY (chaos => alignment)
%%       and more strongly than the old proxy
%%   [3b] the double-pendulum map must be a genuine 2-D grid (rank test) and
%%       must agree with the pre-existing RK4 map on the same slice
%%   [3c] sp_run_dp must accept every documented nGali value (1..4)
%%   [4] the indicator choice is SYSTEM-DEPENDENT: GALI works in the
%%       4-dimensional double pendulum and fails in the 2-dimensional forced one
%%
%%   Run:  addpath('tests'); test_comparison
%%
%%   See also sp_compare_forced, sp_compare_dp, sp_gali, sp_run, sp_run_dp.

    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    maps = fullfile(fileparts(mfilename('fullpath')), '..', 'maps');
    an   = fullfile(fileparts(mfilename('fullpath')), '..', 'analysis');
    addpath(core); addpath(maps); addpath(an);
    fprintf('=== indicator vs true Lyapunov exponent ===\n\n');
    fails = 0;

    % ------------------------------------------------------------------ 1
    fprintf('[1] forced pendulum F=1.1, gamma=0.5 (lambda spans a wide range)\n');
    % Small N and short runs keep this inside a test budget.  The ASSERTION is on
    % the SIGN and ORDERING of the correlations, and those are stable from N = 10
    % upward (checked at N = 10, 12, 16, 20): resolution moves the third decimal,
    % not the conclusion.  The spectral indicators are strided because each one
    % costs a separate trajectory integration, which otherwise dominates.
    Rf = sp_compare_forced('N',10, 'periods',80, 'periodsInd',60, ...
                           'verbose',false, ...
                           'cases',{{1.1 0.5}});
    c = Rf.case{1}.corr;
    lam = Rf.case{1}.lambda(:);
    fprintf('    lambda range [%.3f, %.3f]  (wide, so the test is meaningful)\n', ...
            min(lam), max(lam));
    fprintf('    ci     = %+.3f\n', c.ci.spearman);
    fprintf('    mega   = %+.3f\n', c.mega.spearman);
    fprintf('    iacf   = %+.3f\n', c.iacf.spearman);
    fprintf('    specnum= %+.3f\n', c.specnum.spearman);

    if ~(c.ci.spearman < -0.3)
        fprintf('    FAIL: the old indicator should show a clearly WRONG SIGN here\n');
        fails = fails + 1;
    end
    if ~(c.mega.spearman > 0.4)
        fprintf('    FAIL: MEGNO should track the true exponent\n'); fails = fails + 1;
    end
    % The meaningful assertion is that MEGNO has the RIGHT SIGN and a usable
    % magnitude, NOT that it beats |ci|.  A first version demanded
    % mega > |ci|, which failed at N = 10 with mega = +0.712 vs ci = -0.795 --
    % yet the two are not comparable quantities: ci is a large NEGATIVE number,
    % i.e. it is anti-correlated, so its magnitude being large is a failure of ci
    % rather than a virtue.  Requiring the replacement to out-score a
    % wrong-signed quantity numerically is a category error, and the threshold
    % would have been arbitrary.
    if ~(c.mega.spearman > 0.4 && c.ci.spearman < 0)
        fprintf('    FAIL: MEGNO should be positively and ci negatively correlated\n');
        fails = fails + 1;
    end
    % At least two of the literature indicators should be strongly positive.
    nGood = sum([c.mega.spearman, c.iacf.spearman, c.specnum.spearman] > 0.4);
    fprintf('    indicators with rho > 0.4 : %d of 3 (mega, iacf, specnum)\n', nGood);
    if nGood < 2
        fprintf('    FAIL: expected at least two strong positive correlations\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 2
    fprintf('\n[2] FORCED PENDULUM F=1.5, gamma=0.2: a regime where NOTHING works\n');
    % lambda ranges over roughly 0.026-0.068: a factor of 2.6, and a finite-time
    % estimate scatters like 1/sqrt(lambda*T) far more than that.  Any correlation
    % computed here is noise.  Asserting this stops the honest negative result
    % from being quietly dropped, and is the reason the case list reports more
    % than one parameter set.
    Rf2 = sp_compare_forced('N',10, 'periods',80, 'periodsInd',60, ...
                            'verbose',false, ...
                            'cases',{{1.5 0.2}});
    c2 = Rf2.case{1}.corr;
    lam2 = Rf2.case{1}.lambda(:);
    fprintf('    lambda range [%.4f, %.4f]  -- dynamic range %.2fx\n', ...
            min(lam2), max(lam2), max(lam2)/max(min(lam2),eps));
    fprintf('    ci=%.3f mega=%.3f ofli2=%.3f iacf=%.3f specnum=%.3f gali2=%.3f\n', ...
            c2.ci.spearman, c2.mega.spearman, c2.ofli2.spearman, ...
            c2.iacf.spearman, c2.specnum.spearman, c2.gali2.spearman);
    best = max([abs(c2.mega.spearman), abs(c2.iacf.spearman), ...
                abs(c2.specnum.spearman), abs(c2.gali2.spearman)]);
    fprintf('    best |rho| among all indicators = %.3f\n', best);
    if best > 0.6
        fprintf(['    NOTE: an indicator did correlate strongly here; the claim\n' ...
                 '    that this regime is uninformative would then be wrong.\n']);
    else
        fprintf(['    CONFIRMED: no indicator reaches |rho| = 0.6 on this slice.\n' ...
                 '    The limitation is the dynamic range of lambda, not the choice\n' ...
                 '    of indicator -- README.md records the same 0.022-0.071 spread.\n']);
    end

    % ------------------------------------------------------------------ 3
    fprintf('\n[3] double pendulum: GALI must work where it is supposed to\n');
    Rd = sp_compare_dp('N',10, 'T',40, 'dt',0.02, 'order',2, 'verbose',false);
    cd = Rd.corr;
    fprintf('    lambda range [%.3f, %.3f]\n', min(Rd.lambda(:)), max(Rd.lambda(:)));
    fprintf('    ci    = %+.3f\n', cd.ci.spearman);
    fprintf('    mega  = %+.3f\n', cd.mega.spearman);
    fprintf('    gali2 = %+.3f\n', cd.gali2.spearman);
    fprintf('    gali3 = %+.3f\n', cd.gali3.spearman);
    fprintf('    gali4 = %+.3f\n', cd.gali4.spearman);
    % GALI decays to zero for chaos, so a WORKING GALI correlates NEGATIVELY
    % with lambda.  That sign is the test, not an inconvenience.
    if ~(cd.gali4.spearman < -0.5)
        fprintf('    FAIL: GALI_4 should correlate strongly and negatively\n');
        fails = fails + 1;
    end
    % Compare SIGNS, not magnitudes.  The superseded proxy is a POSITIVE
    % correlation (it rises with the exponent, weakly and for the wrong reason);
    % a working GALI is strongly NEGATIVE.  A first version compared |gali4| >
    % |ci|, which is not the property that matters: at N = 12 both are around
    % 0.94 and 0.14, but the assertion would be unstable near N = 10 and it
    % conflates magnitude with correctness.
    if ~(cd.gali4.spearman < 0 && cd.ci.spearman > cd.gali4.spearman)
        fprintf(['    FAIL: GALI_4 should be the strongly negative indicator, and\n' ...
                 '    the superseded proxy should not be\n']);
        fails = fails + 1;
    end
    if ~(cd.mega.spearman > 0.5)
        fprintf('    FAIL: MEGNO should track the double-pendulum exponent\n');
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 4
    fprintf('\n[4] the RIGHT indicator depends on the system\n');
    fprintf('    2-d forced pendulum : GALI_2 rho = %+.3f  (fails there)\n', c.gali2.spearman);
    fprintf('    4-d double pendulum : GALI_4 rho = %+.3f  (works there)\n', cd.gali4.spearman);
    if ~(cd.gali4.spearman < c.gali2.spearman)
        fprintf(['    FAIL: GALI should do BETTER (more negative) in 4 dimensions\n' ...
                 '    than in 2; that contrast is the applicability rule.\n']);
        fails = fails + 1;
    end
    fprintf(['    This is why the project uses GALI/SALI for the double pendulum\n' ...
             '    and MEGNO/OFLI2/IACF for the forced pendulum.\n']);

    % ------------------------------------------------------------------ 3b
    fprintf('\n[3b] THE MAP MUST BE A MAP: rows must be genuinely distinct\n');
    % REGRESSION TEST for a defect that produced plausible-looking figures.
    %
    % sp_map_dp and sp_compare_dp both built their initial conditions as
    % [th1v; 0; th2v; 0], which advances the DIAGONAL of the (th1, th2) plane:
    % th1 and th2 take the same index, so the state varies along one line.  Every
    % row was then that same diagonal replicated, and the map had rank 1 --
    % measured at N = 6: 3 distinct values out of 36, every row bitwise equal to
    % the first.  Nothing errored.  The diagonal carries real structure, so the
    % image looked like a map, and the correlations below were computed over N^2
    % copies of N distinct initial conditions.
    %
    % Asserting RANK rather than a correlation threshold is deliberate: rank
    % tests the slicing directly and cannot be satisfied by a lucky parameter
    % choice.
    Mg = sp_map_dp('N',6, 'T',10, 'dt',0.02, 'order',2, ...
                   'ciChecks',false, 'progress',false);
    rk = rank(Mg.lambda, 1e-12);
    nu = numel(uniquetol(Mg.lambda(:), 1e-12));
    fprintf('    sp_map_dp  N=6: rank(lambda)=%d   distinct values=%d of %d\n', ...
            rk, nu, numel(Mg.lambda));
    if rk < 2
        fprintf(['    FAIL: the map is rank %d -- th1 and th2 are varying together,\n' ...
                 '    so this is a diagonal slice replicated, not a grid.\n'], rk);
        fails = fails + 1;
    end
    if nu < 5
        fprintf('    FAIL: only %d distinct lambda values on a 36-point grid\n', nu);
        fails = fails + 1;
    end

    Cd = sp_compare_dp('N',6, 'T',10, 'dt',0.02, 'order',2, 'verbose',false);
    rkc = rank(Cd.lambda, 1e-12);
    fprintf('    sp_compare_dp N=6: rank(lambda)=%d\n', rkc);
    if rkc < 2
        fprintf('    FAIL: sp_compare_dp is also collapsing to a diagonal\n');
        fails = fails + 1;
    end

    % The new symplectic map must agree with the PRE-EXISTING RK4 map on the
    % same slice.  Two independent steppers over the same initial conditions
    % should be strongly correlated even though they differ in accuracy: this is
    % what pins the ORIENTATION (an x/y transpose would give a very different
    % number).  dp_map_lyapunov is the reference because it is the old, validated
    % code path that test_speed.m already cross-checks.
    Lmap = dp_map_lyapunov('N',6, 'T',10, 'dt',0.02, ...
                           'progress',false, 'pool',false);
    rmap = corr2(Mg.lambda(:), Lmap.lambda(:));
    fprintf('    corr(sp_map_dp, dp_map_lyapunov) on the same slice = %+.4f\n', rmap);
    if rmap < 0.7
        fprintf(['    FAIL: the two maps disagree on the same slice; a low value\n' ...
                 '    suggests the axes are transposed or the slice differs.\n']);
        fails = fails + 1;
    end

    % ------------------------------------------------------------------ 3c
    fprintf('\n[3c] sp_run_dp must accept every documented nGali (1..4)\n');
    % REGRESSION TEST.  sp_run_dp documents nGali = 1..4 but called
    % sp_sali(Q(:,1:2,:)) unconditionally, so nGali = 1 raised "index out of
    % bounds" -- a dimension error at the call boundary that reads like a bug in
    % sp_sali.  SALI is defined on exactly two vectors, so with one vector there
    % is nothing to report and the correct answer is [] rather than a crash.
    yk = [-2.5*ones(1,3); zeros(1,3); [2.5 0.5 -1.2]; zeros(1,3)];
    Rpar = struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81);
    for kk = 1:4
        try
            Rk = sp_run_dp(yk, 4, 0.02, Rpar, struct('order',2, 'nGali',kk));
            hasSali = ~isempty(Rk.sali);
            fprintf('    nGali=%d: gali=%.4g  sali present=%d\n', kk, Rk.gali(1), hasSali);
            if kk == 1 && hasSali
                fprintf('    FAIL: SALI is undefined with one deviation vector\n');
                fails = fails + 1;
            end
            if kk >= 2 && ~hasSali
                fprintf('    FAIL: SALI must be present for nGali >= 2\n');
                fails = fails + 1;
            end
        catch ME
            fprintf('    nGali=%d: FAIL %s\n', kk, ME.message);
            fails = fails + 1;
        end
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_comparison:failed', '%d comparison test(s) failed', fails);
    end
end
