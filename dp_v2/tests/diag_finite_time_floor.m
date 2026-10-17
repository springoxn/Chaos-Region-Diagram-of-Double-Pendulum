function diag_finite_time_floor()
% How does the finite-time Lyapunov estimate behave for a REGULAR orbit?
%
% This matters for reading the maps.  A regular (quasiperiodic) orbit has true
% lambda = 0, but any finite-time estimate fluctuates about zero and converges
% slowly.  If that fluctuation is positive, then classifying map points by
% "lambda > 0" would label the entire regular island as chaotic.  The map is
% still perfectly readable by COLOUR (small vs large lambda), but a binary
% threshold at zero would be wrong.
%
% Measure the estimate at the island centre as a function of averaging window,
% and compare with a chaotic point.
    addpath(fullfile(fileparts(mfilename('fullpath')),'..','core'));
    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));

    fprintf('island centre (th1,th2) = (0,0)  -- true lambda = 0\n');
    fprintf('%8s %8s %14s %14s\n', 'T', 'dts', 'lambda', 'lambda*sqrt(T)');
    for T = [20 50 100 200 400 800]
        dt = 0.005;
        v = dp_lyap_row(0, 0, T, dt, p, struct('transient',0.3*T));
        fprintf('%8d %8.3f %14.6f %14.4f\n', T, dt, v, v*sqrt(T));
    end
    fprintf('\n(if lambda*sqrt(T) is roughly constant, the residual is a\n');
    fprintf(' 1/sqrt(T) finite-time fluctuation, not a systematic offset)\n');

    fprintf('\nchaotic reference (th1,th2) = (2.5,2.5)  -- true lambda ~ 1.3\n');
    for T = [20 50 100 200]
        v = dp_lyap_row(2.5, 2.5, T, 0.005, p, struct('transient',0.3*T));
        fprintf('  T=%4d  lambda=%8.5f\n', T, v);
    end

    fprintf('\nisland interior scan at T=400, dt=0.005 (should all be small)\n');
    for a = [0 0.3 0.6 0.9 1.2]
        v = dp_lyap_row(a, a, 400, 0.005, p, struct('transient',120));
        fprintf('  theta1=theta2=%.2f  lambda=%+.5f\n', a, v);
    end

    fprintf('\nCONCLUSION FOR READING MAPS\n');
    fprintf('  The regular island is identified by SMALL lambda, not by lambda<=0.\n');
    fprintf('  A binary threshold at 0 is not meaningful for finite-time estimates.\n');
end
