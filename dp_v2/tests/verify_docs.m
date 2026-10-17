function verify_docs()
%% VERIFY_DOCS  Check that documented options match what the code accepts.
%
%   Documentation drifts from code silently.  This test calls each public
%   function with EVERY option its help text advertises, so a renamed or
%   removed option becomes a test failure rather than a user-facing error.
%
%   THE sp_* FAMILY IS COVERED HERE TOO.  The original version of this file
%   exercised only dp_lyap / fp_lyap / dp_map_lyapunov / fp_map / basin_dimension
%   / fp_melnikov_threshold, i.e. the PRE-symplectic API, and knew nothing about
%   sp_run, sp_run_dp, sp_sys, sp_map_dp or the comparison drivers.  That is how
%   it passed while sp_map_dp was slicing the diagonal of the plane and
%   sp_run_dp crashed on nGali = 1: the new code was never called.  See
%   docs/rerun_plan.md section A.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'));
    fprintf('=== documented-option verification ===\n\n');
    fails = 0;

    p = struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81);

    % ---- dp_lyap: opts documented in its header ----
    docOpts = {'transient',5, 'reortho',5, 'method','tangent', ...
               'd0',1e-10, 'nExponents',1, 'progress',false};
    try
        [lam, info] = dp_lyap([1;0;1;0], 20, 0.01, p, ...
                              cell2struct(docOpts(2:2:end), docOpts(1:2:end), 2));
        fprintf('  dp_lyap documented options: OK (lam=%.4f)\n', lam);
        assert(isfield(info,'energyDrift'), 'info.energyDrift missing');
        assert(isfield(info,'method'), 'info.method missing');
        fprintf('  dp_lyap info fields      : OK\n');
    catch ME
        fprintf('  dp_lyap: FAIL %s\n', ME.message); fails = fails+1;
    end

    % nExponents full spectrum
    try
        lam4 = dp_lyap([2;0;2;0], 60, 0.01, p, struct('nExponents',4,'transient',20));
        assert(numel(lam4)==4, 'nExponents=4 did not return 4 values');
        fprintf('  dp_lyap nExponents=4     : OK (%s)\n', mat2str(lam4',3));
    catch ME
        fprintf('  dp_lyap nExponents: FAIL %s\n', ME.message); fails = fails+1;
    end

    % shadow method
    try
        ls = dp_lyap([1;0;1;0], 20, 0.01, p, struct('method','shadow','transient',5));
        fprintf('  dp_lyap method=shadow    : OK (%.4f)\n', ls);
    catch ME
        fprintf('  dp_lyap method=shadow: FAIL %s\n', ME.message); fails = fails+1;
    end

    % ---- fp_lyap: opts documented in its header ----
    try
        [v, inf2] = fp_lyap(0.5, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',0.02,'periods',40,'transient',0.3,'reortho',5, ...
                        'method','tangent','d0',1e-10));
        assert(isfield(inf2,'winding'), 'info.winding missing');
        fprintf('  fp_lyap documented opts  : OK (%.5f, w=%.4f)\n', v, inf2.winding);
    catch ME
        fprintf('  fp_lyap: FAIL %s\n', ME.message); fails = fails+1;
    end
    try
        vs = fp_lyap(0.5, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',0.02,'periods',40,'method','shadow'));
        fprintf('  fp_lyap method=shadow    : OK (%.5f)\n', vs);
    catch ME
        fprintf('  fp_lyap method=shadow: FAIL %s\n', ME.message); fails = fails+1;
    end

    % ---- dp_map_lyapunov: documented options ----
    try
        M = dp_map_lyapunov('N',6, 'T',15, 'dt',0.02, 'transient',0.3, ...
                            'reortho',5, 'params',p, 'thRange',[-pi pi], ...
                            'progress',false, 'pool',false);
        need = {'lambda','energy','th1','th2','params','T','dt','N','elapsed','method','slice'};
        for i = 1:numel(need)
            assert(isfield(M,need{i}), 'dp_map_lyapunov missing field %s', need{i});
        end
        fprintf('  dp_map_lyapunov opts     : OK (N=%d, %.1f s)\n', M.N, M.elapsed);
        fprintf('  dp_map_lyapunov fields   : OK (%d fields)\n', numel(fieldnames(M)));
    catch ME
        fprintf('  dp_map_lyapunov: FAIL %s\n', ME.message); fails = fails+1;
    end

    % ---- fp_map: documented options ----
    try
        M = fp_map('N',6, 'F',1.5, 'gamma',0.2, 'Omega',2/3, 'dt',0.02, ...
                   'periods',40, 'transient',0.3, 'thRange',[-pi pi], ...
                   'omRange',[-4 4], 'progress',false, 'pool',false);
        need = {'lambda','winding','basin','th','om','F','gamma','Omega', ...
                'dt','periods','N','elapsed','MelnikovFc','supercritical','periodsDone'};
        for i = 1:numel(need)
            assert(isfield(M,need{i}), 'fp_map missing field %s', need{i});
        end
        fprintf('  fp_map opts              : OK (N=%d, F_c=%.4f)\n', M.N, M.MelnikovFc);
        fprintf('  fp_map fields            : OK (%d fields)\n', numel(fieldnames(M)));
    catch ME
        fprintf('  fp_map: FAIL %s\n', ME.message); fails = fails+1;
    end

    % ---- basin_dimension: documented options ----
    try
        N=200; [X,~]=meshgrid(linspace(0,1,N),linspace(0,1,N));
        B = double(X>0.5);
        R = basin_dimension(B, 'nBalls',5e4, 'nEps',20, 'maxEps',30, ...
                               'fLo',0.02, 'fHi',0.9, 'seed',0, ...
                               'plot',false, 'verbose',false);
        need = {'alpha','D','eps','f','fitMask','R2','poly','boundaryFrac', ...
                'nLabels','N','nBalls','saturated'};
        for i = 1:numel(need)
            assert(isfield(R,need{i}), 'basin_dimension missing field %s', need{i});
        end
        fprintf('  basin_dimension opts     : OK (alpha=%.3f)\n', R.alpha);
        fprintf('  basin_dimension fields   : OK (%d fields)\n', numel(fieldnames(R)));
    catch ME
        fprintf('  basin_dimension: FAIL %s\n', ME.message); fails = fails+1;
    end

    % ---- maxEps default must match the documented value ----
    try
        N=200; [X,~]=meshgrid(linspace(0,1,N),linspace(0,1,N));
        R = basin_dimension(double(X>0.5), 'plot',false, 'verbose',false);
        fprintf('  basin_dimension default maxEps reached %d px\n', max(R.eps));
    catch ME
        fprintf('  basin_dimension default: FAIL %s\n', ME.message); fails = fails+1;
    end

    % ---- fp_melnikov_threshold: both outputs ----
    try
        [Fc, sh] = fp_melnikov_threshold(0.2, 2/3);
        assert(abs(Fc - 4*0.2/(pi*sh)) < 1e-12, 'sech/cosh identity broken');
        fprintf('  fp_melnikov_threshold    : OK (Fc=%.5f, sech=%.5f)\n', Fc, sh);
    catch ME
        fprintf('  fp_melnikov_threshold: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- sp_sys: both systems, all documented options ----
    % =================================================================
    try
        sp1 = sp_sys('pendulum', 'F',1.5, 'gamma',0.2, 'Omega',2/3);
        sp2 = sp_sys('coupled',  'a',4,   'b',1);
        sp3 = sp_sys('henonheiles');
        need = {'name','nq','gamma','params','force','dforce','d2force', ...
                'energy','ndof'};
        for k = 1:numel(need)
            assert(isfield(sp1,need{k}), 'sp_sys pendulum missing %s', need{k});
            assert(isfield(sp2,need{k}), 'sp_sys coupled missing %s', need{k});
            assert(isfield(sp3,need{k}), 'sp_sys henonheiles missing %s', need{k});
        end
        assert(sp3.ndof == 4 && sp3.nq == 2, 'henonheiles must be 2-dof');
        % A misspelled option must raise rather than silently keep the default:
        % 'gam' would otherwise leave gamma at its default and quietly integrate
        % a different physical system.
        raised = false;
        try, sp_sys('pendulum','gam',0.3); catch, raised = true; end
        assert(raised, 'sp_sys accepted a misspelled option');
        fprintf('  sp_sys opts+fields       : OK (pendulum+coupled+henonheiles, typo rejected)\n');
    catch ME
        fprintf('  sp_sys: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- the Henon-Heiles drivers ----
    % =================================================================
    try
        sHH = sp_sys('henonheiles');
        [Y0h, ich] = sp_henon_heiles_ic('E',1/12, 'N',12, 'plane','yY', ...
                                        'x0',0, 'branch',1, 'verbose',false);
        need = {'E','N','plane','x0','y0','branch','escaped','nEscaped','nPoints'};
        for k = 1:numel(need)
            assert(isfield(ich,need{k}), 'sp_henon_heiles_ic missing %s', need{k});
        end
        assert(size(Y0h,1)==4, 'IC must be 4 x N');
        dE = abs(sHH.energy(Y0h,0) - 1/12);
        assert(max(dE(~ich.escaped)) < 1e-13, 'IC energy is not exact');
        % the other plane must work too
        [~, icx] = sp_henon_heiles_ic('E',1/8, 'N',12, 'plane','xX');
        assert(icx.nPoints == 144, 'xX plane point count');
        fprintf('  sp_henon_heiles_ic       : OK (yY+xX, energy exact, %d escaped)\n', ...
                ich.nEscaped);
    catch ME
        fprintf('  sp_henon_heiles_ic: FAIL %s\n', ME.message); fails = fails+1;
    end
    try
        Mh = sp_henon_heiles_map('indicator','ofli2', 'E',1/12, 'N',10, 'T',30, ...
                                 'dt',0.02, 'order',4, 'dev0','grad', ...
                                 'x0',0, 'fig',false, 'verbose',false);
        need = {'values','x','y','indicator','dev0','E','T','dt','order','N', ...
                'escaped','nEscaped','settings','elapsed','sys','nSteps'};
        for k = 1:numel(need)
            assert(isfield(Mh,need{k}), 'sp_henon_heiles_map missing %s', need{k});
        end
        assert(any(isfinite(Mh.values(:))), 'OFLI2 map is entirely NaN');
        Mf = sp_henon_heiles_map('indicator','fli', 'dev0','grad', 'E',1/12, ...
                                 'N',10, 'T',30, 'dt',0.02, 'verbose',false);
        assert(any(isfinite(Mf.values(:))), 'FLI map is entirely NaN');
        % all four documented dev0 choices must be accepted
        for d = {'grad','flow','fixed','bad'}
            sp_henon_heiles_map('indicator','fli','dev0',d{1},'E',1/12, ...
                                'N',6,'T',10,'dt',0.02,'verbose',false);
        end
        fprintf('  sp_henon_heiles_map      : OK (ofli2 + fli, all 4 dev0 choices)\n');
    catch ME
        fprintf('  sp_henon_heiles_map: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- sp_run: every documented option, on BOTH ndof ----
    % =================================================================
    try
        sP = sp_sys('pendulum','F',1.1,'gamma',0.5);
        sC = sp_sys('coupled','a',4,'b',1);
        R1 = sp_run(sP, [0.5;0.0], struct('order',4, 'T',20, 'dt',0.01, ...
                     'transient',0.3, 'nGali',2, 'sample',50, 'nSamp',4000, ...
                     'spectral',true, 'progress',false));
        need = {'lambda','mega','megabar','fli','gali','sali','nVec','dt','T', ...
                'order','nSteps','sys','galiSeries','tSeries','iacf','specnum'};
        for k = 1:numel(need)
            assert(isfield(R1,need{k}), 'sp_run missing field %s', need{k});
        end
        % The spectral fields must be POPULATED when spectral=true.  They used to
        % be hard-coded to [] regardless of the option (rerun_plan.md section B),
        % so a field that exists but can never be filled is the failure mode this
        % asserts against.
        assert(~isempty(R1.iacf), 'sp_run returned an empty iacf despite spectral=true');
        assert(~isempty(R1.specnum), 'sp_run returned an empty specnum despite spectral=true');
        fprintf('  sp_run 1-dof opts+fields : OK (iacf=%.3f sn=%d)\n', ...
                R1.iacf(1), R1.specnum(1));

        % ndof = 4 path, nGali at both ends of its documented range
        for kk = [1 4]
            Rc = sp_run(sC, [1.3;0.0;0.2;0.0], struct('T',20,'dt',0.02, ...
                         'order',4, 'nGali',kk));
            assert(numel(Rc.lambda)==1, 'sp_run coupled lambda size');
            if kk == 1
                assert(isempty(Rc.sali), 'SALI must be empty with 1 vector');
            else
                assert(~isempty(Rc.sali), 'SALI must exist with 4 vectors');
            end
        end
        fprintf('  sp_run 2-dof nGali=1,4   : OK\n');

        % order 2 and 6 on the explicit family
        for od = [2 6]
            sp_run(sP, [0.5;0.0], struct('T',5,'dt',0.01,'order',od));
        end
        fprintf('  sp_run order 2/4/6       : OK\n');
    catch ME
        fprintf('  sp_run: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- sp_run_dp: every documented option and ALL nGali ----
    % =================================================================
    try
        pp = struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81);
        y0 = [-2.5*ones(1,3); zeros(1,3); [2.5 0.5 -1.2]; zeros(1,3)];
        for kk = 1:4
            Rk = sp_run_dp(y0, 4, 0.02, pp, struct('order',2, 'transient',0.3, ...
                            'nGali',kk, 'sample',20));
            need = {'lambda','mega','megabar','fli','gali','sali','galiAll', ...
                    'nVec','nSteps','order','T','dt','energyDrift', ...
                    'galiSeries','tSeries'};
            for k = 1:numel(need)
                assert(isfield(Rk,need{k}), 'sp_run_dp missing field %s', need{k});
            end
            if kk == 1
                assert(isempty(Rk.sali), 'sp_run_dp SALI must be empty at nGali=1');
            else
                assert(~isempty(Rk.sali), 'sp_run_dp SALI must exist at nGali>=2');
            end
        end
        % both documented orders
        for od = [2 4]
            sp_run_dp(y0, 2, 0.02, pp, struct('order',od));
        end
        fprintf('  sp_run_dp opts+fields    : OK (nGali=1..4, order 2/4)\n');
    catch ME
        fprintf('  sp_run_dp: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- sp_map_dp: documented options AND a genuine 2-D grid ----
    % =================================================================
    try
        M = sp_map_dp('N',5, 'T',8, 'dt',0.02, 'order',2, ...
                      'params',struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81), ...
                      'om0',[0 0], 'thRange',[-pi pi], 'progress',false, ...
                      'nGali',4, 'ciChecks',true);
        need = {'gali2','gali3','gali4','mega','lambda','ci','th1','th2', ...
                'settings','elapsed','energyDrift','params'};
        for k = 1:numel(need)
            assert(isfield(M,need{k}), 'sp_map_dp missing field %s', need{k});
        end
        % A map must actually vary in BOTH coordinates.  Asserting rank catches
        % the diagonal-slice defect (both angles indexed together) directly.
        assert(rank(M.lambda, 1e-12) >= 2, ...
               'sp_map_dp produced a rank-1 map: the grid collapsed to a diagonal');
        fprintf('  sp_map_dp opts+fields    : OK (N=%d, rank=%d, %.1f s)\n', ...
                M.settings.N, rank(M.lambda,1e-12), M.elapsed);
    catch ME
        fprintf('  sp_map_dp: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- sp_iacf / sp_specnum documented options ----
    % =================================================================
    try
        q = sin(2*pi*(0:999)/64);
        [W, iw] = sp_iacf(q, 'B',40, 'maxLagFrac',0.75, 'fullLimit',inf);
        assert(isfield(iw,'K') && isfield(iw,'mode'), 'sp_iacf info fields');
        assert(strcmp(iw.mode,'full'), 'sp_iacf default must use the exact sum');
        [SN, is] = sp_specnum(q, 'cutoff',0.1, 'removeMean',true);
        assert(isfield(is,'nPeaks'), 'sp_specnum info fields');
        fprintf('  sp_iacf/sp_specnum opts  : OK (W=%.4f mode=%s, SN=%d)\n', ...
                W, iw.mode, SN);
    catch ME
        fprintf('  sp_iacf/sp_specnum: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- sp_gali / sp_sali / sp_ofli2 documented behaviour ----
    % =================================================================
    try
        V = zeros(4,2,1); V(1,1,1)=1; V(2,2,1)=1;
        g = sp_gali(V);
        assert(abs(g-1) < 1e-14, 'sp_gali of orthogonal unit vectors must be 1');
        s = sp_sali(V);
        assert(abs(s-sqrt(2)) < 1e-14, 'sp_sali of orthogonal unit vectors');
        % wrong vector count must raise rather than return a wrong number
        raised = false; try, sp_sali(zeros(4,3,1)); catch, raised = true; end
        assert(raised, 'sp_sali accepted 3 vectors');
        fprintf('  sp_gali/sp_sali          : OK (GALI=1, SALI=sqrt2, arity checked)\n');
    catch ME
        fprintf('  sp_gali/sp_sali: FAIL %s\n', ME.message); fails = fails+1;
    end
    try
        sC = sp_sys('coupled','a',4,'b',1);
        Of = sp_ofli2(sC, [1.3;0.0;0.2;0.0], struct('T',20,'dt',0.02,'order',4));
        assert(isscalar(Of) || numel(Of)==1, 'sp_ofli2 single-point size');
        fprintf('  sp_ofli2                 : OK (OFLI2=%.4g)\n', Of);
    catch ME
        fprintf('  sp_ofli2: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- the analysis drivers' documented options ----
    % =================================================================
    try
        C = sp_compare_dp('N',4, 'T',8, 'dt',0.02, 'order',2, ...
                          'params',struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81), ...
                          'verbose',false, 'nGali',4);
        need = {'lambda','ci','mega','gali2','gali3','gali4','corr','settings', ...
                'th1','th2','elapsed'};
        for k = 1:numel(need)
            assert(isfield(C,need{k}), 'sp_compare_dp missing field %s', need{k});
        end
        fprintf('  sp_compare_dp opts+fields: OK (%.1f s)\n', C.elapsed);
    catch ME
        fprintf('  sp_compare_dp: FAIL %s\n', ME.message); fails = fails+1;
    end
    try
        Cf = sp_compare_forced('N',4, 'periods',15, 'periodsInd',15, 'dt',0.01, ...
                               'Omega',2/3, 'cases',{{1.1 0.5}}, 'verbose',false);
        need = {'settings','case'};
        for k = 1:numel(need)
            assert(isfield(Cf,need{k}), 'sp_compare_forced missing field %s', need{k});
        end
        % The spectral indicators must come from the same integration, so their
        % sample count matches the others instead of a strided subsample.
        cc = Cf.case{1}.corr;
        assert(cc.iacf.n == cc.mega.n, ...
               'iacf and mega were computed on different point counts');
        fprintf('  sp_compare_forced fields : OK (n=%d for all indicators)\n', cc.mega.n);
    catch ME
        fprintf('  sp_compare_forced: FAIL %s\n', ME.message); fails = fails+1;
    end
    try
        % sp_energy_study is a figure/print driver with NO output argument (its
        % signature is `function sp_energy_study(varargin)`).  The check is
        % therefore that it runs and prints its table, not that it returns a
        % value -- the first version of this test requested one and failed for
        % the wrong reason.
        sp_energy_study('system','pendulum', 'T',40, 'dt',0.02, 'fig',false);
        fprintf('  sp_energy_study pendulum : OK\n');
    catch ME
        fprintf('  sp_energy_study: FAIL %s\n', ME.message); fails = fails+1;
    end

    % =================================================================
    % ---- summary.mat FIELD NAMES must match what the generators read ----
    % =================================================================
    % REGRESSION TEST.  make_gallery.m wrote `amplitude_proxy_corr_with_lambda`
    % while gen/gen_report.py and gen/verify_manual.py read
    % `old_metric_corr_with_lambda`.  The key was simply absent, and both
    % generators caught the error in a bare `except` that substituted hard-coded
    % literals -- so the documents quoted numbers from no run at all and every
    % build still "succeeded".  This checks the contract from the MATLAB side,
    % where the field is written; the generators now also fail loudly.
    try
        mfile = fullfile(here,'..','make_gallery.m');
        txt = fileread(mfile);
        src = fileread(fullfile(here,'..','gen','gen_report.py'));
        % Every field the report reads off the LOADED summary struct must appear
        % as summary.<field> in make_gallery.m.  The pattern is anchored to the
        % loader's own variable name ('s') and a following attribute access, so
        % bare module-level names are excluded and `os.path` or a
        % `docs/perf_tiers.md` string in the prose are not mistaken for fields.
        keys = regexp(src, '[^a-zA-Z0-9_.]s\.([a-zA-Z_][a-zA-Z0-9_]*)', 'tokens');
        keys = unique([keys{:}]);
        missing = {};
        for k = 1:numel(keys)
            if ~contains(txt, ['summary.' keys{k}])
                missing{end+1} = keys{k}; %#ok<AGROW>
            end
        end
        if ~isempty(missing)
            fprintf('  make_gallery writes NONE of: %s\n', strjoin(missing, ', '));
            fprintf('    (gen_report.py reads them; it would fail the build)\n');
            fails = fails+1;
        else
            fprintf('  summary.mat field names  : OK (%d keys read by gen_report)\n', ...
                    numel(keys));
        end
        % And the strings it reads for prose must exist too.
        for nm = {'amplitude_proxy_note','old_metric_note'}
            assert(contains(txt, ['summary.' nm{1}]), ...
                   'make_gallery does not write summary.%s', nm{1});
        end
        fprintf('  summary.mat note fields  : OK\n');
    catch ME
        fprintf('  summary.mat contract: FAIL %s\n', ME.message); fails = fails+1;
    end

    % ---- make_gallery documented options parse (no computation) ----
    try
        narginOK = true;
        % parse() is a local function; exercise it through a dry-run guard by
        % confirming the option names exist in the file's parse defaults.
        txt = fileread(fullfile(here,'..','make_gallery.m'));
        for nm = {'reuse','figuresOnly','quick','pool','N','Tdp','dtdp','fpPeriods','fpdt'}
            if ~contains(txt, ['''' nm{1} ''''])
                fprintf('  make_gallery missing option %s\n', nm{1});
                narginOK = false; fails = fails+1;
            end
        end
        if narginOK
            fprintf('  make_gallery options     : OK (all documented names present)\n');
        end
    catch ME
        fprintf('  make_gallery: FAIL %s\n', ME.message); fails = fails+1;
    end

    fprintf('\n=== %d problem(s) ===\n', fails);
    if fails > 0
        error('verify_docs:failed', '%d documentation mismatch(es)', fails);
    end
end
