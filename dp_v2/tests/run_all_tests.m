function run_all_tests()
%% RUN_ALL_TESTS  Run the complete dp_v2 validation suite.
%%
%%   run_all_tests
%%
%%   Order matters only for reporting; each file is self-contained.
%%
%%   The suite is deliberately adversarial.  Every assertion is against a value
%%   that is known independently -- a closed-form eigenvalue, a Melnikov
%%   threshold, a Cantor-set dimension, an analytic decay rate, or a second
%%   implementation -- rather than against previously generated output.  A test
%%   that merely re-runs the code and compares to its own earlier answer proves
%%   nothing.

    here = fileparts(mfilename('fullpath'));
    addpath(here, fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'), fullfile(here,'..','gui'));

    suites = {'test_core','test_fp','test_speed','test_speed_fp', ...
              'test_analysis','test_tex_lint','verify_docs','test_gui', ...
              'test_cross', ...
              'test_symplectic','test_implicit','test_indicators', ...
              'test_paper_figures','test_mathieu','test_henon_heiles', ...
              'test_comparison'};
    results = struct('name',{}, 'pass',{}, 'seconds',{}, 'msg',{});

    fprintf('\n');
    fprintf('##########################################################\n');
    fprintf('#  dp_v2 validation suite                                #\n');
    fprintf('##########################################################\n');

    for i = 1:numel(suites)
        nm = suites{i};
        fprintf('\n===== %s =====\n', nm);
        t0 = tic;
        ok = true; msg = '';
        try
            feval(nm);
        catch ME
            ok = false;
            msg = ME.message;
        end
        results(end+1) = struct('name',nm, 'pass',ok, 'seconds',toc(t0), 'msg',msg); %#ok<AGROW>
    end

    fprintf('\n');
    fprintf('##########################################################\n');
    fprintf('#  SUMMARY                                               #\n');
    fprintf('##########################################################\n');
    nPass = 0;
    for i = 1:numel(results)
        r = results(i);
        if r.pass
            nPass = nPass + 1;
            fprintf('  PASS  %-16s %7.1f s\n', r.name, r.seconds);
        else
            fprintf('  FAIL  %-16s %7.1f s   %s\n', r.name, r.seconds, r.msg);
        end
    end
    fprintf('\n  %d / %d suites passed\n', nPass, numel(results));
    fprintf('##########################################################\n\n');

    if nPass < numel(results)
        error('run_all_tests:failed', '%d suite(s) failed', numel(results)-nPass);
    end
end
