function diag_shadow()
% Why does the two-trajectory (shadow) method disagree with the variational
% method for the forced pendulum, when it agrees for the double pendulum?
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));

    fprintf('=== A) shadow method on the analytic damped cases ===\n');
    for gam = [3.0 0.5]
        if gam > 2
            exact = max(real(roots([1 gam 1])));
        else
            exact = -gam/2;
        end
        ls = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                        'dt',0.002,'periods',150,'transient',0.3,'method','shadow'));
        lt = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                        'dt',0.002,'periods',150,'transient',0.3,'method','tangent'));
        fprintf('    gamma=%.1f exact=%+.6f  tangent=%+.6f  shadow=%+.6f\n', ...
                gam, exact, lt, ls);
    end

    fprintf('\n=== B) forced case: shadow vs perturbation size d0 ===\n');
    for d0 = [1e-6 1e-8 1e-10 1e-12]
        ls = fp_lyap(1.0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',0.002,'periods',600,'transient',0.3, ...
                        'method','shadow','d0',d0));
        fprintf('    d0=%.0e  shadow lambda = %+.6f\n', d0, ls);
    end
    lt = fp_lyap(1.0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                    'dt',0.002,'periods',600,'transient',0.3,'method','tangent'));
    fprintf('    tangent lambda = %+.6f\n', lt);

    fprintf('\n=== C) shadow vs run length (does it converge to tangent?) ===\n');
    for per = [100 300 600 1200]
        ls = fp_lyap(1.0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',0.002,'periods',per,'transient',0.3,'method','shadow'));
        fprintf('    periods=%4d  shadow=%+.6f\n', per, ls);
    end

    fprintf('\n=== D) does the perturbation direction matter? ===\n');
    fprintf('    (shadow perturbs th only, which lies close to the FLOW\n');
    fprintf('     direction -- the neutral direction -- for a rotating orbit)\n');
    ths = [1.0, 2.5];
    for i = 1:numel(ths)
        ls = fp_lyap(ths(i), 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',0.002,'periods',600,'transient',0.3,'method','shadow'));
        lt = fp_lyap(ths(i), 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',0.002,'periods',600,'transient',0.3,'method','tangent'));
        fprintf('    th0=%.1f  tangent=%+.6f  shadow=%+.6f  ratio=%.2f\n', ...
                ths(i), lt, ls, ls/lt);
    end

    fprintf('\n=== E) finite-time Lyapunov as a function of the window ===\n');
    fprintf('    (is the tangent value itself window-dependent here?)\n');
    for per = [100 300 600 1200 2400]
        lt = fp_lyap(1.0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                        'dt',0.005,'periods',per,'transient',0.3,'method','tangent'));
        fprintf('    periods=%4d  tangent=%+.6f\n', per, lt);
    end
end
