function diag_bias()
% Diagnose the renormalisation bias: does the measured exponent depend on the
% reorthonormalisation interval h = reortho*dt even as dt -> 0 ?
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));
    fprintf('undriven damped pendulum, analytic lambda = -gamma/2\n\n');
    gam = 0.5; exact = -gam/2;
    fprintf('gamma = %.2f, exact = %.6f\n', gam, exact);
    fprintf('%10s %10s %14s %12s\n', 'dt', 'reortho', 'lambda', 'err');
    for dt = [0.01 0.002 0.0005]
        for ro = [1 5 10 20 50]
            lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                            'dt',dt,'periods',100,'transient',0.3,'reortho',ro));
            fprintf('%10.4f %10d %14.7f %12.2e\n', dt, ro, lam, lam-exact);
        end
        fprintf('\n');
    end

    fprintf('--- same scan for the over-damped case gamma=2 ---\n');
    gam = 2.0; exact = -1.0;
    fprintf('%10s %10s %14s %12s\n', 'dt', 'reortho', 'lambda', 'err');
    for dt = [0.01 0.002]
        for ro = [1 5 10 20]
            lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                            'dt',dt,'periods',100,'transient',0.3,'reortho',ro));
            fprintf('%10.4f %10d %14.7f %12.2e\n', dt, ro, lam, lam-exact);
        end
    end
end
