function bench_parallel()
% Does the row-based sweep parallelise better than the old point-based one?
%
% The baseline measurement showed only 1.6x on 12 workers for the old
% per-point sweep, because each parfor iteration did very little work.  With
% whole rows as the parfor unit the granularity is N times coarser, so the
% parallel efficiency should improve substantially.  This measures it.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'));
    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));

    N = 24; T = 60; dt = 0.01;
    th = linspace(-pi,pi,N);

    fprintf('=== parallel scaling, row-based sweep ===\n');
    fprintf('    N=%d, T=%d s, dt=%.3f\n\n', N, T, dt);

    % serial
    t0 = tic;
    for i = 1:N
        dp_lyap_row(th, th(i)*ones(1,N), T, dt, p, struct('transient',0.3*T));
    end
    tSer = toc(t0);
    fprintf('    serial           : %7.2f s\n', tSer);

    % parallel
    try
        if isempty(gcp('nocreate')), parpool; end
        nw = gcp('nocreate').NumWorkers;
        t0 = tic;
        L = nan(N,N);
        parfor i = 1:N
            L(i,:) = dp_lyap_row(th, th(i)*ones(1,N), T, dt, p, ...
                                 struct('transient',0.3*T));
        end
        tPar = toc(t0);
        fprintf('    parfor (%2d workers): %7.2f s\n', nw, tPar);
        fprintf('    speedup          : %7.2fx  (efficiency %.0f%%)\n', ...
                tSer/tPar, 100*(tSer/tPar)/nw);
    catch ME
        fprintf('    parfor unavailable: %s\n', ME.message);
    end

    fprintf('\n    baseline for comparison: the OLD per-point sweep reached only\n');
    fprintf('    1.6x on 12 workers, because each parfor iteration was one point.\n');
    fprintf('    A whole row per iteration is %dx more work per task.\n', N);
end
