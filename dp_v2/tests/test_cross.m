function test_cross()
%% TEST_CROSS  Cross-validate dp_v2 against the independent Python reference.
%
%   The Python reference (crosscheck_ref.py) was written independently of
%   dp_v2, so agreement is evidence about the physics rather than about shared
%   code.  What can be compared is constrained by chaos itself -- two integrators
%   of the same chaotic orbit decorrelate after T* ~ ln(1/eps)/lambda.  So the
%   test is split into three tiers, each of which IS testable:
%
%     A. short-horizon pointwise agreement   (T << T*)
%     B. sharp invariants over long runs     (rotation number)
%     C. statistical agreement of grids      (mean, spread, quantiles)
%
%   Tier A validates the vector field and integrator; B validates the attractor
%   structure; C validates that both produce the same physics in aggregate.
%   See why_pointwise_fails.py for the arithmetic behind the horizon.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..', 'core'));

    outdir = fullfile(here, 'crosscheck');
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    fprintf('=== cross-validation against the independent Python reference ===\n\n');
    fails = 0;

    % ================================================================
    % Tier A : short-horizon pointwise trajectory agreement
    % ================================================================
    fprintf('[A] short-horizon pointwise agreement (T << decorrelation time)\n');
    Ns = 8;
    thShort = linspace(-pi, pi, Ns);
    Tshort = 2.0;         % dp horizon T* ~ 28 s, so 2 s is safely inside
    dtShort = 0.001;
    Yshort = zeros(Ns, Ns, 4);
    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));
    for i = 1:Ns
        for j = 1:Ns
            Yshort(i,j,:) = dp_traj([thShort(j);0;thShort(i);0], Tshort, dtShort, p);
        end
    end
    TpShort = 20.0;       % fp horizon T* ~ 77 drive periods ~ 725 s
    dtpShort = 0.001;
    thpShort = linspace(-pi, pi, Ns);
    ompShort = linspace(-4, 4, Ns);
    YPshort = zeros(Ns, Ns, 2);
    for i = 1:Ns
        for j = 1:Ns
            [th, om] = fp_traj(thpShort(j), ompShort(i), TpShort, dtpShort, ...
                               struct('F',1.5,'gamma',0.2,'Omega',2/3));
            YPshort(i,j,:) = [th, om];
        end
    end
    save(fullfile(outdir, 'matlab_short.mat'), 'Yshort', 'Tshort', 'dtShort', ...
         'thShort', 'Ns');
    save(fullfile(outdir, 'matlab_fpshort.mat'), 'YPshort', 'TpShort', ...
         'dtpShort', 'thpShort', 'ompShort');
    fprintf('    MATLAB side done (%dx%d ICs each)\n', Ns, Ns);

    % ================================================================
    % Tier B/C : long-run grid of true exponents
    % ================================================================
    fprintf('\n[B/C] forced-pendulum Lyapunov + winding grid (MATLAB side)\n');
    Nf = 24;
    thf = linspace(-pi, pi, Nf);
    omf = linspace(-4, 4, Nf);
    LAMf = zeros(Nf, Nf);
    Wf   = zeros(Nf, Nf);
    t0 = tic;
    for i = 1:Nf
        for j = 1:Nf
            [v, info] = fp_lyap(thf(j), omf(i), struct('F',1.5,'gamma',0.2, ...
                             'Omega',2/3,'dt',0.01,'periods',300,'transient',0.3));
            LAMf(i,j) = v;
            Wf(i,j)   = info.winding;
        end
    end
    fprintf('    computed %dx%d in %.1f s\n', Nf, Nf, toc(t0));
    save(fullfile(outdir, 'matlab_fp_lyap.mat'), 'LAMf', 'Wf', 'thf', 'omf', 'Nf');

    % ================================================================
    % hand off to Python
    % ================================================================
    fprintf('\n[running Python reference and comparing...]\n');
    py = fullfile(here, 'crosscheck_ref.py');
    [st, out] = system(sprintf('python "%s" "%s"', py, outdir));
    disp(out);

    rf = fullfile(outdir, 'crosscheck_result.mat');
    if st ~= 0 || ~exist(rf, 'file')
        fprintf('    FAIL: python reference failed (exit %d)\n', st);
        fails = fails + 1;
    else
        S = load(rf);
        if ~S.pass
            fprintf('    FAIL: cross-check did not pass\n');
            fails = fails + 1;
        end
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_cross:failed', 'cross-validation failed');
    end
end
