function test_tiers()
%% TEST_TIERS  Measure what each accuracy tier actually costs you.
%
%   Stage-appropriate settings are only defensible if the resulting error is
%   KNOWN.  This test measures it, on a grid, against the 'accurate' tier taken
%   as reference, and reports three things that matter for real use:
%
%     * the error in lambda itself (magnitude);
%     * the MISCLASSIFICATION RATE -- the fraction of points where the tier
%       puts a point on the wrong side of the regular/chaotic threshold.  For a
%       map whose whole purpose is to show where chaos is, this is the number
%       that matters, not the RMS error in lambda;
%     * where the mistakes are.  Nearly all of them should sit on the island
%       boundary, where lambda passes through zero and NO finite-time estimate
%       can be reliable at any price.
%
%   A tier is acceptable if the bulk is classified correctly and the errors are
%   concentrated at the boundary.  That is the claim being tested here.
%
%   IMPORTANT: WHY THE THRESHOLD IS NOT ZERO
%   ----------------------------------------
%   A finite-time Lyapunov estimate of a genuinely REGULAR (quasiperiodic)
%   orbit does not come out at zero or below -- it fluctuates about zero and
%   converges only like 1/sqrt(T).  Measured at the centre of the regular
%   island (theta1=theta2=0, where the true exponent is 0):
%
%       T= 50   lambda = -0.0243
%       T=100   lambda = -0.0038
%       T=200   lambda = -0.0013
%       T=400   lambda = +0.0011
%       T=800   lambda = +0.0011
%
%   So at T >= 400 the island sits at POSITIVE lambda, and a binary test
%   "lambda > 0 => chaotic" would label the entire regular island as chaotic.
%   That would be a numerical artefact masquerading as physics.
%
%   The correct reading is by MAGNITUDE: the two populations are separated by
%   nearly two orders of magnitude (island ~0.005, chaotic sea ~1.35), so the
%   map is never ambiguous in colour -- only a naive zero-crossing test is.
%   See diag_finite_time_floor.m for the measurement and README for how this
%   is stated to users.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'));
    fprintf('=== accuracy tier calibration ===\n\n');

    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));

    % A common grid so the tiers are compared point by point.  N=40 keeps the
    % accurate reference affordable while still spanning the island.
    N = 40;
    th = linspace(-pi, pi, N);
    [T1, T2] = meshgrid(th, th);

    % ---- reference: the accurate tier, computed with the fast row path ----
    fprintf('computing reference (tier=accurate settings, fast path)...\n');
    oAcc = struct('N',N, 'T',400, 'dt',0.005, 'periods',0);
    oAcc = dp_apply_tier(struct('tier','accurate','N',N,'T',0,'dt',0));
    t0 = tic;
    LAMref = zeros(N, N);
    for i = 1:N
        LAMref(i,:) = dp_lyap_row(th, th(i)*ones(1,N), oAcc.T, oAcc.dt, p, ...
                                  struct('transient',0.3*oAcc.T));
    end
    tRef = toc(t0);
    fprintf('  N=%d T=%d dt=%.3f : %.1f s (%.1f ms/point)\n\n', ...
            N, oAcc.T, oAcc.dt, tRef, 1000*tRef/N^2);

    % ---- candidate tiers ----
    cases = {
        'preview  ', 'preview'
        'standard ', 'standard'
    };

    fprintf('%-11s %8s %10s %10s %12s %12s\n', ...
            'tier', 'sec', 'rms dlam', 'max dlam', 'misclass %', 'off-bound %');
    fprintf('%s\n', repmat('-', 1, 78));

    for c = 1:size(cases,1)
        name = cases{c,1};
        t = cases{c,2};
        cfg = dp_apply_tier(struct('tier',t, 'N',N, 'T',0, 'dt',0));

        t0 = tic;
        LAM = zeros(N, N);
        for i = 1:N
            LAM(i,:) = dp_lyap_row(th, th(i)*ones(1,N), cfg.T, cfg.dt, p, ...
                                   struct('transient',0.3*cfg.T));
        end
        el = toc(t0);

        dlam = LAM - LAMref;
        rms = sqrt(mean(dlam(:).^2));
        mx = max(abs(dlam(:)));

        % Classification threshold.  NOT zero: a finite-time estimate of a
        % genuinely regular orbit fluctuates about zero and, at T=400, sits
        % at +0.001..+0.006 (measured in diag_finite_time_floor.m).  Zero is
        % therefore inside the noise band and would label the whole regular
        % island as chaotic.
        %
        % The two populations are separated by nearly two orders of magnitude
        % (island ~0.005, chaotic ~1.35), so the exact cut is not critical;
        % LAM_THR sits in the middle of that gap on a log scale.
        LAM_THR = 0.1;
        creg = LAMref <= LAM_THR;  ccan = LAM <= LAM_THR;
        mis = (creg ~= ccan);
        misRate = mean(mis(:));

        % distance of each misclassified point from the reference boundary,
        % in grid cells, to check that the errors are boundary-localised
        B = boundary_mask(creg);
        if any(mis(:))
            dmis = dist_to_true(B);
            offB = mean(dmis(mis)) > 1.5;   % >1.5 cells from the boundary
        else
            offB = false;
        end

        fprintf('%-11s %8.1f %10.4f %10.4f %11.2f%% %12s\n', ...
                name, el, rms, mx, 100*misRate, ternary(offB, 'YES', 'no'));
    end

    fprintf('\nclassification threshold lambda = %.2f (see the note in this file:\n', 0.1);
    fprintf('a finite-time estimate of a REGULAR orbit is not <= 0)\n');
    fprintf('reference: %.1f%% of points are chaotic (lambda > %.2f)\n', ...
            100*mean(~creg(:)), 0.1);

    % ---- explicit acceptance criteria ----
    fprintf('\nacceptance: a tier passes if misclassification < 5%% AND the\n');
    fprintf('            mistakes sit within 1.5 grid cells of the boundary\n\n');

    fails = 0;
    LAM_THR = 0.1;
    for c = 1:size(cases,1)
        t = cases{c,2};
        cfg = dp_apply_tier(struct('tier',t, 'N',N, 'T',0, 'dt',0));
        for i = 1:N
            LAM(i,:) = dp_lyap_row(th, th(i)*ones(1,N), cfg.T, cfg.dt, p, ...
                                   struct('transient',0.3*cfg.T));
        end
        creg = LAMref <= LAM_THR;  ccan = LAM <= LAM_THR;
        mis = (creg ~= ccan);
        B = boundary_mask(creg);
        dmis = dist_to_true(B);
        if any(mis(:))
            localised = mean(dmis(mis)) <= 1.5;
        else
            localised = true;
        end
        ok = mean(mis(:)) < 0.05 && localised;
        fprintf('  %-11s %s  (misclass %.2f%%, mean boundary distance %.2f cells)\n', ...
                cases{c,1}, ternary(ok,'PASS','FAIL'), 100*mean(mis(:)), ...
                ternary(any(mis(:)), mean(dmis(mis)), 0));
        if ~ok, fails = fails + 1; end
    end

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_tiers:failed', '%d tier(s) outside tolerance', fails);
    end
end


% =========================================================================
function B = boundary_mask(reg)
%% Pixels adjacent to a difference in the boolean map.
    B = false(size(reg));
    dx = reg(:,1:end-1) ~= reg(:,2:end);
    B(:,1:end-1) = B(:,1:end-1) | dx;
    B(:,2:end)   = B(:,2:end)   | dx;
    dy = reg(1:end-1,:) ~= reg(2:end,:);
    B(1:end-1,:) = B(1:end-1,:) | dy;
    B(2:end,:)   = B(2:end,:)   | dy;
end


function d = dist_to_true(B)
%% Chebyshev distance (in cells) from every pixel to the nearest true-boundary
%% pixel.  Uses an iterative dilation, which is fine at this grid size and
%% avoids a toolbox dependency.
    [n, m] = size(B);
    d = inf(n, m);
    d(B) = 0;
    maxIter = max(n, m);
    for it = 1:maxIter
        prev = d;
        cur = d;
        cur(1:end-1,:) = min(cur(1:end-1,:), d(2:end,:) + 1);
        cur(2:end,:)   = min(cur(2:end,:),   d(1:end-1,:) + 1);
        cur(:,1:end-1) = min(cur(:,1:end-1), d(:,2:end) + 1);
        cur(:,2:end)   = min(cur(:,2:end),   d(:,1:end-1) + 1);
        cur(1:end-1,1:end-1) = min(cur(1:end-1,1:end-1), d(2:end,2:end) + 1);
        cur(2:end,2:end)     = min(cur(2:end,2:end),     d(1:end-1,1:end-1) + 1);
        cur(1:end-1,2:end)   = min(cur(1:end-1,2:end),   d(2:end,1:end-1) + 1);
        cur(2:end,1:end-1)   = min(cur(2:end,1:end-1),   d(1:end-1,2:end) + 1);
        d = cur;
        if isequal(d, prev), break; end
    end
end


function s = ternary(c, a, b)
    if c, s = a; else, s = b; end
end
