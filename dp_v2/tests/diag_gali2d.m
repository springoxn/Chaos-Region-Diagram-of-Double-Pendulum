function diag_gali2d()
%% DIAG_GALI2D  What does GALI_2 actually do in a 2-dimensional flow?
%
%   Determining this by measurement, because a first draft of sp_gali.m
%   asserted "GALI_2 collapses for the forced pendulum" and the measurement in
%   test_indicators did not support it.  ASCII only.
%
%   The relevant theory: for a 2-d flow the two Lyapunov exponents satisfy
%   lambda_1 + lambda_2 = div f = -gamma (the constant divergence of a damped
%   pendulum).  GALI_2 decays at rate |lambda_1 - lambda_2| = |2 lambda_1 + gamma|.
%   When lambda_1 ~ -gamma/2 the two exponents COINCIDE and that rate goes to
%   zero -- so GALI_2 should stall rather than decay.  That is a testable
%   prediction, so it is tested here.
    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    rng(7);

    cases = { ...
        'damped regular   F=0.0 g=0.2', 0.0, 0.2; ...
        'subcritical      F=0.3 g=0.2', 0.3, 0.2; ...
        'supercritical    F=1.5 g=0.2', 1.5, 0.2; ...
        'strong damping   F=1.5 g=0.5', 1.5, 0.5; ...
        'very weak damp   F=1.5 g=0.02', 1.5, 0.02 };

    fprintf('%-32s %10s %10s %10s %10s %10s\n', ...
        'case', 'lambda', 'pred_rate', 'GALI2(0)', 'GALI2(T)', 'ratio');
    for i = 1:size(cases,1)
        F = cases{i,2};  gam = cases{i,3};
        sp = sp_sys('pendulum', 'F', F, 'gamma', gam, 'Omega', 2/3);
        tau = 2*pi/sp.params.Omega;

        % integrate with 4 vectors so GALI_4 is also available, long horizon
        T = 800*tau;
        R = sp_run(sp, [0.5; 0.0], struct('T', T, 'dt', 0.01, 'order', 4, ...
                        'nGali', 4, 'sample', 500, 'transient', 0.05));
        lam = R.lambda(1);
        pred = abs(2*lam + gam);
        g0 = R.galiSeries(1,1);
        gT = R.gali(1);
        fprintf('%-32s %10.5f %10.5f %10.4f %10.3e %10.3f\n', ...
            cases{i,1}, lam, pred, g0, gT, gT/g0);
    end

    fprintf('\n--- does a longer horizon change the verdict? (F=0.3, g=0.2) ---\n');
    sp = sp_sys('pendulum', 'F', 0.3, 'gamma', 0.2, 'Omega', 2/3);
    tau = 2*pi/sp.params.Omega;
    for nper = [200 800 3000 10000]
        R = sp_run(sp, [0.5; 0.0], struct('T', nper*tau, 'dt', 0.01, ...
                        'order', 4, 'nGali', 2, 'sample', 200, 'transient', 0.05));
        gs = R.galiSeries(:,1);
        fprintf('  %6d periods : lambda=%+.6f  GALI2 final=%.3e  min=%.3e\n', ...
            nper, R.lambda(1), R.gali(1), min(gs));
    end

    fprintf('\n--- the SAME test on a genuinely 4-d system (coupled pendulum) ---\n');
    sc = sp_sys('coupled', 'a', 4, 'b', 1);
    for x0 = [-3.0, 0.9, 1.7]
        R = sp_run(sc, [x0; 1.3; 0.0; 0.2], struct('T', 400, 'dt', 0.02, ...
                        'order', 4, 'nGali', 4, 'sample', 200, 'transient', 0.05));
        fprintf('  x0=%+.1f : lambda=%+.5f  GALI4(0)=%.3e  GALI4(T)=%.3e\n', ...
            x0, R.lambda(1), R.galiSeries(1,1), R.gali(1));
    end
end
