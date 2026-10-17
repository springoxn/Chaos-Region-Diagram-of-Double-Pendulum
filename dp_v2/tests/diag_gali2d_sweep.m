function diag_gali2d_sweep()
%% DIAG_GALI2D_SWEEP  Quantify where GALI_2 misclassifies in the 2-dimensional
%%                    forced damped pendulum.
%
%   Grid over (F, gamma).  At each point compute the true largest Lyapunov
%   exponent (the reference) and the final GALI_2, then classify each by a
%   threshold on each and count the DISAGREEMENTS.
%
%   This is the evidence behind the applicability statement in sp_gali.m.
%   The expected mechanism for a false positive: both deviation vectors are
%   renormalised every step (sp_step.m), so GALI_2 measures the ANGLE between
%   two unit vectors.  On a strongly contracting regular orbit both normalised
%   vectors converge onto the slowest-decaying direction, so the angle closes
%   and GALI_2 -> 0 even though the orbit is regular.  A false positive is
%   therefore not a numerical defect; it is what a 2-dimensional tangent space
%   with no positive exponent does.
%
%   ASCII only.
    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    rng(3);

    Fs  = 0.2:0.4:3.0;
    gs  = [0.05 0.1 0.2 0.3 0.5];
    lamThr = 1e-3;      % |lambda| below this counts as "regular"
    gThr   = 1e-6;      % GALI_2 below this counts as "collapsed"

    fprintf('forced pendulum sweep: %d x %d points\n', numel(Fs), numel(gs));
    fprintf('classify regular if lambda < %.0e ; collapsed if GALI_2 < %.0e\n\n', lamThr, gThr);

    nFP = 0; nFN = 0; nTot = 0;
    fprintf('%-6s %-6s %11s %11s %10s\n', 'F', 'gamma', 'lambda', 'GALI2', 'verdict');
    for F = Fs
        for g = gs
            sp = sp_sys('pendulum', 'F', F, 'gamma', g, 'Omega', 2/3);
            tau = 2*pi/sp.params.Omega;
            R = sp_run(sp, [0.5; 0.0], struct('T', 400*tau, 'dt', 0.01, ...
                            'order', 4, 'nGali', 2, 'sample', 200, ...
                            'transient', 0.3));
            lam = R.lambda(1);
            g2  = R.gali(1);
            regular_by_lam = lam < lamThr;
            collapsed      = g2 < gThr;
            nTot = nTot + 1;

            if regular_by_lam && collapsed
                verdict = 'FALSE POS';      % says chaotic, is regular
                nFP = nFP + 1;
            elseif ~regular_by_lam && ~collapsed
                verdict = 'false neg';      % says regular, is chaotic
                nFN = nFN + 1;
            elseif regular_by_lam
                verdict = 'ok reg';
            else
                verdict = 'ok chaos';
            end
            fprintf('%-6.2f %-6.2f %11.5f %11.3e %10s\n', F, g, lam, g2, verdict);
        end
    end

    fprintf('\n%d points: %d false positives (regular called chaotic), %d false negatives\n', ...
            nTot, nFP, nFN);
    fprintf(['\nCONCLUSION: GALI_2 is not a reliable regular/chaotic classifier in a\n' ...
             '2-dimensional flow.  It is used for the DOUBLE pendulum (4-d) in this\n' ...
             'project, and the forced pendulum is analysed with MEGNO, OFLI2 and the\n' ...
             'IACF instead.  See sp_gali.m.\n']);
end
