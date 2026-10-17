function bench_t10()
% The user's reported case: "slower even at t=10s".
%
% At short T the per-point cost is dominated by fixed overhead, so this is
% exactly where the row path should help most.  Measure the crossover.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'));
    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));

    N = 24;
    th = linspace(-pi,pi,N);
    fprintf('=== short-integration cost: old vs new (serial) ===\n\n');
    fprintf('%8s %14s %14s %10s\n', 'T (s)', 'old ms/point', 'new ms/point', 'speedup');

    for T = [10 20 40 80 160]
        dt = 0.01;
        t0 = tic;
        for i = 1:N
            for j = 1:N
                dp_lyap([th(j);0;th(i);0], T, dt, p, struct('transient',0.3*T));
            end
        end
        tOld = toc(t0);
        t0 = tic;
        for i = 1:N
            dp_lyap_row(th, th(i)*ones(1,N), T, dt, p, struct('transient',0.3*T));
        end
        tNew = toc(t0);
        fprintf('%8d %14.2f %14.2f %9.1fx\n', T, ...
                1000*tOld/N^2, 1000*tNew/N^2, tOld/tNew);
    end

    fprintf('\nReading: the fixed per-call overhead the row path removes is a\n');
    fprintf('CONSTANT, so its relative benefit is largest at small T -- which is\n');
    fprintf('precisely the regime that felt slow.\n');
end
