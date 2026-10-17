function run_gallery()
%% Driver for the A-phase gallery rerun (docs/rerun_plan.md section A).
%%
%%   Runs make_gallery at the publication resolution recorded in the existing
%%   summary.mat (N = 200), with a parallel pool, and logs to
%%   tests/gallery_run.log.
%%
%%   Kept as a file rather than a one-liner so the exact settings that produced
%%   gallery/ are on the record and can be repeated.
    here = fileparts(mfilename('fullpath'));
    cd(here);
    addpath(fullfile(here,'core'), fullfile(here,'maps'), ...
            fullfile(here,'analysis'), fullfile(here,'gui'));

    N = 200;   % matches the dp_N/fp_N already recorded in gallery/summary.mat

    fprintf('=== gallery rerun, N = %d ===\n', N);
    fprintf('started %s\n', datestr(now));

    % A pool is worth it here: the map steps are the whole cost and they are
    % embarrassingly parallel over rows.
    try
        pp = gcp('nocreate');
        if isempty(pp)
            pp = parpool('Processes');
        end
        fprintf('parallel pool: %d workers\n', pp.NumWorkers);
    catch ME
        fprintf('no pool (%s); running serially\n', ME.message);
    end

    t0 = tic;
    make_gallery('N', N, 'pool', true);
    fprintf('\n=== gallery done in %.1f min ===\n', toc(t0)/60);
    fprintf('finished %s\n', datestr(now));

    % Rebuild both documents from the fresh summary.mat.  These raise if a field
    % the prose quotes is missing, which is the contract that was silently
    % broken before (see make_gallery.m).
    fprintf('\n=== regenerating documents ===\n');
    py = py_path();
    here_gen = fullfile(here,'gen');
    for s = {'gen_report.py','gen_manual.py','verify_manual.py'}
        cmd = sprintf('%s "%s"', py, fullfile(here_gen, s{1}));
        fprintf('--- %s\n', s{1});
        [st, out] = system(cmd);
        disp(out);
        if st ~= 0
            fprintf('*** %s exited %d\n', s{1}, st);
        end
    end
end


% =========================================================================
function py = py_path()
%% The interpreter that has scipy (the generators import scipy.io).
    cands = {'python', 'python3', 'py'};
    for i = 1:numel(cands)
        [st, ~] = system(sprintf('%s -c "import scipy"', cands{i}));
        if st == 0
            py = cands{i};
            return
        end
    end
    py = 'python';
end
