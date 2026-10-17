function diag_gali_rate()
%% DIAG_GALI_RATE  Test the quantitative prediction for GALI_2 decay in a
%%                 2-dimensional flow.
%
%   For a flow with Lyapunov exponents lambda_1 >= lambda_2, GALI_2 decays at
%   the rate
%
%       Gamma = lambda_1 - lambda_2 .
%
%   A damped pendulum has constant divergence div f = -gamma, so
%   lambda_1 + lambda_2 = -gamma and therefore
%
%       Gamma = 2*lambda_1 + gamma .
%
%   That is a sharp, falsifiable prediction: fit the GALI_2 decay rate and
%   compare.  It also explains the two regimes measured in diag_gali2d.m:
%
%     * regular orbit on a FIXED POINT: both exponents are -gamma/2, so
%       Gamma = 0 and GALI_2 does not decay at all;
%     * chaotic orbit: lambda_1 > 0 > lambda_2, so Gamma > 0 and GALI_2 decays.
%
%   ASCII only.
    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    rng(11);

    fprintf('%-28s %9s %11s %11s %8s\n', 'case', 'lambda1', 'pred Gamma', 'fit Gamma', 'relerr');
    cases = { ...
        'F=1.5 g=0.2', 1.5, 0.2; ...
        'F=1.5 g=0.5', 1.5, 0.5; ...
        'F=1.5 g=0.02', 1.5, 0.02; ...
        'F=2.5 g=0.2', 2.5, 0.2 };

    for i = 1:size(cases,1)
        F = cases{i,2};  gam = cases{i,3};
        sp = sp_sys('pendulum', 'F', F, 'gamma', gam, 'Omega', 2/3);
        tau = 2*pi/sp.params.Omega;
        T = 400*tau;
        % sample densely in TIME so the fit sees the exponential window
        R = sp_run(sp, [0.5; 0.0], struct('T', T, 'dt', 0.01, 'order', 4, ...
                        'nGali', 2, 'sample', 40, 'transient', 0.0));
        gs = R.galiSeries(:,1);
        ts = R.tSeries(:);
        % Fit ONLY the exponential window.  Using gs < 0.5 as the window (a
        % first attempt) drags in the roundoff floor at ~1e-17, which is flat
        % and dominated the fit, returning ~0 for every case.  The window is
        % therefore bounded below as well.
        ok = gs > 1e-14 & gs < 0.5 & isfinite(gs);
        if sum(ok) >= 10
            idx = find(ok);
            pp = polyfit(ts(idx), log(gs(idx)), 1);
            fitG = -pp(1);
            nfit = numel(idx);
            r2 = 1 - sum((log(gs(idx)) - polyval(pp, ts(idx))).^2) / ...
                     max(sum((log(gs(idx)) - mean(log(gs(idx)))).^2), realmin);
        else
            fitG = NaN; nfit = 0; r2 = NaN;
        end
        lam = R.lambda(1);
        predG = 2*lam + gam;
        fprintf('%-28s %9.5f %11.5f %11.5f %8.3f  (n=%d, R2=%.4f)\n', ...
            cases{i,1}, lam, predG, fitG, abs(fitG-predG)/max(predG,1e-9), nfit, r2);
    end

    fprintf('\n--- regular orbits: is Gamma really ~ 0? ---\n');
    for F = [0.0 0.3]
        sp = sp_sys('pendulum', 'F', F, 'gamma', 0.2, 'Omega', 2/3);
        tau = 2*pi/sp.params.Omega;
        R = sp_run(sp, [0.5; 0.0], struct('T', 600*tau, 'dt', 0.01, 'order', 4, ...
                        'nGali', 2, 'sample', 40, 'transient', 0.0));
        gs = R.galiSeries(:,1);
        lam = R.lambda(1);
        fprintf('  F=%.2f: lambda1=%+.6f  pred Gamma=%.6f  GALI2 min=%.4f final=%.4f\n', ...
            F, lam, 2*lam+0.2, min(gs), R.gali(1));
    end

    fprintf('\n--- THE ACTUAL LIMITATION: a stable LIMIT CYCLE ---\n');
    % A phase-locked periodic orbit has lambda_1 = 0 exactly, so Gamma = gamma > 0
    % and GALI_2 decays even though the motion is perfectly regular.  THAT is the
    % 2-d degeneracy, and it is why GALI alone is not sufficient for the forced
    % pendulum.  The project''s F-scan notes place such orbits at gamma = 0.5,
    % F = 1.3-1.4 (winding locked at -1); a first version of this diagnostic
    % instead used gamma = 0.2, F = 1.2-1.35, which the measurement shows are
    % CHAOTIC (lambda ~ +0.12..+0.15), not periodic.
    for F = [1.3 1.35 1.4]
        sp = sp_sys('pendulum', 'F', F, 'gamma', 0.5, 'Omega', 2/3);
        tau = 2*pi/sp.params.Omega;
        R = sp_run(sp, [0.5; 0.0], struct('T', 600*tau, 'dt', 0.01, 'order', 4, ...
                        'nGali', 2, 'sample', 40, 'transient', 0.3));
        fprintf('  gamma=0.5 F=%.2f: lambda1=%+.6f  pred Gamma=%.6f  GALI2 final=%.3e\n', ...
            F, R.lambda(1), 2*R.lambda(1)+0.5, R.gali(1));
    end
end
