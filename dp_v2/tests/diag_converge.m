function diag_converge()
% Is the residual error in the analytic check a finite-time effect (should
% decay like 1/T) or a bug (plateaus)?
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'core'));

    fprintf('=== A) undriven damped pendulum, error vs averaging window ===\n');
    fprintf('    gamma=0.5 -> analytic -0.25 (underdamped: complex eigenvalues,\n');
    fprintf('    equal modulus => finite-time estimate oscillates)\n');
    gam = 0.5; exact = -0.25;
    dt = 0.0005;
    for per = [50 100 200 400 800]
        lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                        'dt',dt,'periods',per,'transient',0.5,'reortho',5));
        fprintf('    periods=%4d  T_avg=%8.1f s  lam=%+.7f  err=%+.2e\n', ...
                per, 0.5*per*2*pi/(2/3), lam, lam-exact);
    end

    fprintf('\n=== B) overdamped gamma=3 (distinct real eigenvalues) ===\n');
    gam = 3.0;
    lams_exact = roots([1 gam 1]);
    exact = max(real(lams_exact));
    fprintf('    analytic dominant lambda = %.7f\n', exact);
    for per = [50 100 200 400]
        lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                        'dt',dt,'periods',per,'transient',0.5,'reortho',5));
        fprintf('    periods=%4d  lam=%+.7f  err=%+.2e\n', per, lam, lam-exact);
    end

    fprintf('\n=== C) critically damped gamma=2 (repeated eigenvalue) ===\n');
    gam = 2.0; exact = -1.0;
    for per = [100 400]
        lam = fp_lyap(0.5, 0.0, struct('F',0,'gamma',gam,'Omega',2/3, ...
                        'dt',dt,'periods',per,'transient',0.5,'reortho',5));
        fprintf('    periods=%4d  lam=%+.7f  err=%+.2e\n', per, lam, lam-exact);
    end

    fprintf('\n=== D) linear system only: compare against the RK4 stability fn ===\n');
    % For y' = A y with A = [[0,1],[-1,-gamma]], RK4 applied with step h has
    % amplification R(hA) = I + hA + (hA)^2/2 + (hA)^3/6 + (hA)^4/24.
    % The order-4 method reproduces log|mu|/h to O(h^4).
    gam = 0.5;
    A = [0 1; -1 -gam];
    for h = [0.01 0.002 0.0005]
        z = h*A;
        R = eye(2) + z + z^2/2 + z^3/6 + z^4/24;
        mu = max(abs(eig(R)));
        fprintf('    h=%-8.4f  log|mu|/h = %+.8f   err vs -0.25 = %+.2e\n', ...
                h, log(mu)/h, log(mu)/h + 0.25);
    end
end
