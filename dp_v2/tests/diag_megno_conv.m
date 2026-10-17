function diag_megno_conv()
%% DIAG_MEGNO_CONV  Does MEGNO converge to 2 on an integrable system, and how
%%                  fast?  ASCII only.
%
%   Two analytic anchors make this decisive:
%
%     * Harmonic oscillator.  With delta q = cos t and delta v = -sin t the
%       deviation norm is CONSTANT, so ln r = 0 every step and MEGNO -> 0.  The
%       reference paper states this explicitly ("harmonic oscillations where Y
%       tends to 0").  A correct implementation must reproduce it.
%
%     * Non-isochronous libration (a pendulum at moderate amplitude).
%       The deviation grows like t, so k ln r_k -> 1 and MEGNO -> 2.  The
%       reference paper states Y -> 2 asymptotically for ordered motion.
%
%   The point of the scan in T is to separate "the implementation is wrong"
%   from "2 is the asymptote and T = 400 is not asymptotic".  The paper itself
%   warns that MEGNO needs a long integration to settle (its Sec. 4.2.1 notes
%   MEGNO "needs more integration time in order to correct some rotations").
    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);

    fprintf('=== anchor 1: harmonic oscillator (H = (p^2+q^2)/2) ===\n');
    sysH = harm_sys();
    for T = [100 400 1600]
        R = sp_run(sysH, [1.0; 0.0], struct('T', T, 'dt', 0.01, 'order', 4, ...
                        'nGali', 2, 'transient', 0.0));
        fprintf('  T=%5d : MEGNO = %+.5f   (theory 0)   lambda = %+.2e\n', ...
                T, R.mega(1), R.lambda(1));
    end

    fprintf('\n=== anchor 2: integrable coupled pendulum b=0, libration ===\n');
    sysI = sp_sys('coupled', 'a', 4, 'b', 0);
    for T = [100 200 400 800 1600 3200]
        for doTrans = [0 1]
            R = sp_run(sysI, [0.9; 1.3; 0; 0], struct('T', T, 'dt', 0.02, ...
                            'order', 4, 'nGali', 2, 'transient', 0.3*doTrans));
            if doTrans == 0
                fprintf('  T=%5d : MEGNO(Y) = %7.4f  Ybar = %7.4f  (transient 0.0)\n', ...
                        T, R.mega(1), R.megabar(1));
            else
                fprintf('             (transient 0.3) MEGNO(Y) = %7.4f  Ybar = %7.4f\n', ...
                        R.mega(1), R.megabar(1));
            end
        end
    end

    fprintf('\n=== anchor 3: single pendulum, various amplitudes ===\n');
    sysP = sp_sys('pendulum', 'F', 0, 'gamma', 0, 'Omega', 2/3);
    for amp = [0.1 0.5 1.0 1.5 3.0]
        R = sp_run(sysP, [amp; 0.0], struct('T', 3200, 'dt', 0.02, 'order', 4, ...
                        'nGali', 2, 'transient', 0.0));
        fprintf('  amp=%.1f : MEGNO = %7.4f  Ybar = %7.4f  lambda = %+.2e\n', ...
                amp, R.mega(1), R.megabar(1), R.lambda(1));
    end
end


function sys = harm_sys()
%% H = (p^2 + q^2)/2, written in the sp_sys contract (force = -q, dforce = -1).
    sys = struct();
    sys.name   = 'harmonic oscillator';
    sys.nq     = 1;
    sys.gamma  = 0;
    sys.params = struct();
    sys.force  = @(q,t) -q;
    sys.dforce = @(q,t) reshape(-ones(1, numel(q)), 1, 1, numel(q));
    sys.energy = @(y,t) 0.5*(y(1,:).^2 + y(2,:).^2);
    sys.ndof   = 2;
end
