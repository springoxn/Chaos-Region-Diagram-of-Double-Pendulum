function R = basin_dimension(basin, varargin)
%% BASIN_DIMENSION  Basin-boundary dimension by the uncertainty exponent.
%%
%%   R = basin_dimension(basin)
%%   R = basin_dimension(basin, 'nBalls',5e5, 'plot',true)
%%
%%   basin : NxN integer/real label map (e.g. M.basin from fp_map, where
%%           -1 and +1 are the two rotation directions and 0 is unassigned)
%%
%%   Returns R with fields
%%     alpha      uncertainty exponent, from  f(eps) ~ eps^alpha
%%     D          boundary dimension  =  d - alpha,  d = 2 (plane)
%%     eps, f     the measured scaling curve
%%     fitMask    which points entered the fit
%%     R2         goodness of the power-law fit
%%     boundaryFrac   fraction of the plane within one pixel of a boundary
%%
%%   WHY THIS REPLACES BOX COUNTING
%%   The original project counted boxes intersected by a boundary pixel set and
%%   fitted log N(eps) vs log(1/eps).  That estimator is biased by the arbitrary
%%   choice of boundary-pixel definition and saturates once the box size falls
%%   near the grid spacing.  The uncertainty exponent avoids both problems: it
%%   asks, for a randomly chosen point, what is the probability f(eps) that an
%%   eps-ball around it contains MORE THAN ONE basin.  That quantity is what
%%   actually controls predictability, and it obeys f ~ eps^alpha over a wide
%%   range with no arbitrary threshold.
%%
%%   Relation to the dimension (Grebogi, McDonald, Ott & Yorke,
%%   Phys. Lett. A 99, 415 (1983)):
%%
%%       alpha = d - D        =>        D = d - alpha,   d = 2 here.
%%
%%   Note the sign convention: D is the MINUEND side of the subtraction, i.e.
%%   D = d - alpha.  Writing "D = d - alpha" as "alpha = D - d" is equivalent;
%%   what is NOT correct is treating alpha as the larger quantity.  Since
%%   0 <= alpha <= 1 for a fractal boundary, D lies between d-1 and d.
%%
%%   alpha = 1  -> smooth boundary, D = d - 1
%%   alpha = 0  -> riddled/intermingled basins, D = d (boundary fills the plane)
%%
%%   This matters here: the forced damped pendulum at gamma = 0.2 is documented
%%   as having RIDDLED basins (Daza, Wagemakers & Sanjuan), i.e. alpha = 0 in
%%   the extreme.  A box-counting dimension near 1.8 is a finite-resolution
%%   shadow of that, not a contradiction of it.

    o = parse_opts(varargin{:});
    [Ny, Nx] = size(basin);
    if Ny ~= Nx
        error('basin_dimension:shape', 'basin must be square');
    end
    N = Ny;

    rng(o.seed);

    labels = unique(basin(:));
    nLab = numel(labels);
    if nLab < 2
        error('basin_dimension:uniform', ...
              'basin has a single label (%g) -- no boundary to measure', labels(1));
    end

    % --- sat (summed-area) table per label for O(1) box occupancy queries ---
    sat = zeros(nLab, (N+1)*(N+1));
    for c = 1:nLab
        m = double(basin == labels(c));
        S = zeros(N+1, N+1);
        S(2:end, 2:end) = cumsum(cumsum(m, 1), 2);
        sat(c, :) = S(:).';
    end

    % --- random sample points ---
    nB = min(o.nBalls, N*N*20);
    px = randi(N, nB, 1);
    py = randi(N, nB, 1);

    epss = unique(max(1, round(logspace(0, log10(o.maxEps), o.nEps))));
    f = zeros(size(epss));
    stride = N + 1;
    for k = 1:numel(epss)
        e = epss(k);
        x0 = max(px - e, 1);  x1 = min(px + e, N);
        y0 = max(py - e, 1);  y1 = min(py + e, N);
        present = zeros(nB, 1);
        % linear indices into the (N+1)x(N+1) summed-area table
        i11 = (x1)*stride + (y1 + 1);
        i01 = (x0 - 1)*stride + (y1 + 1);
        i10 = (x1)*stride + (y0);
        i00 = (x0 - 1)*stride + (y0);
        for c = 1:nLab
            s = sat(c, i11) - sat(c, i01) - sat(c, i10) + sat(c, i00);
            present = present + (s(:) > 0);
        end
        f(k) = mean(present > 1);
    end

    % --- fit the scaling range: drop saturated and sub-statistical points ---
    lo = o.fLo;  hi = o.fHi;
    mask = (f > lo) & (f < hi);
    if sum(mask) < 3
        mask = (f > 0.01) & (f < 0.99);   % fall back to a loose range
    end
    if sum(mask) < 3
        % No scaling range at all.  If f is saturated near 1 everywhere, the
        % boundary is filling the plane as fast as it can be resolved -- which
        % IS the alpha = 0 case, not a failure.  Report it as such.
        if all(f > 0.95)
            alpha = 0; D = 2; R2 = NaN; P = [0; log(mean(f))]; %#ok<NASGU>
            saturated = true;
        elseif all(f < 0.02)
            error('basin_dimension:fit', ...
                  'f(eps) is below 0.02 at every scale -- boundary is thinner\nthan one pixel at the smallest eps; increase the grid resolution.');
        else
            % Not enough points span the unsaturated range.  Almost always this
            % means the grid is too coarse: the boundary is thinner than one
            % pixel over most of the measurable eps range, or f jumps from ~1
            % straight to ~0 with no power-law region between.  Say so, with
            % the numbers, rather than emitting a bare failure.
            error('basin_dimension:resolution', ...
                ['only %d scale(s) lie in the fitting window (%.2f < f < %.2f); ' ...
                 'need at least 3.\n' ...
                 '  grid is %dx%d.  f(eps) = %s\n' ...
                 '  f(eps) = %s\n' ...
                 '  Most likely the basin map is too coarse to resolve the ' ...
                 'boundary scaling -- rebuild it with a larger N.'], ...
                 sum(mask), lo, hi, N, N, ...
                 mat2str(epss(:).', 6), mat2str(round(f(:).', 4)));
        end
    else
        lx = log(epss(mask));  ly = log(f(mask));
        P = polyfit(lx, ly, 1);
        alpha = P(1);
        pred = polyval(P, lx);
        ssRes = sum((ly - pred).^2);
        ssTot = sum((ly - mean(ly)).^2);
        R2 = 1 - ssRes/max(eps, ssTot);
        saturated = false;
    end

    % alpha must lie in [0,1] for a subset of the plane; clamp numerical overshoot
    alpha = min(max(alpha, 0), 1);
    D = 2 - alpha;

    % --- boundary pixel fraction, for reference only ---
    b = false(N, N);
    dx = basin(:,1:end-1) ~= basin(:,2:end);
    b(:,1:end-1) = b(:,1:end-1) | dx;
    b(:,2:end)   = b(:,2:end)   | dx;
    dy = basin(1:end-1,:) ~= basin(2:end,:);
    b(1:end-1,:) = b(1:end-1,:) | dy;
    b(2:end,:)   = b(2:end,:)   | dy;

    R = struct('alpha', alpha, 'D', D, 'eps', epss, 'f', f, ...
               'fitMask', mask, 'R2', R2, 'poly', P, ...
               'boundaryFrac', mean(b(:)), 'nLabels', nLab, ...
               'N', N, 'nBalls', nB, 'saturated', saturated);

    if o.verbose
        fprintf('  basin_dimension (uncertainty exponent method)\n');
        fprintf('    grid %dx%d, %d labels\n', N, N, nLab);
        fprintf('    alpha = %.4f   =>   D = 2 - alpha = %.4f   (R^2 = %.4f)\n', ...
                alpha, D, R2);
        fprintf('    boundary pixels: %.2f%%\n', 100*R.boundaryFrac);
        fprintf('    interpretation: ');
        if alpha > 0.95
            fprintf('essentially smooth boundary\n');
        elseif alpha < 0.05
            fprintf(['alpha ~ 0 -> RIDDLED/intermingled basins; the boundary\n' ...
                     '                    fills the plane and D is not the useful\n' ...
                     '                    descriptor (see the file header)\n']);
        else
            fprintf('fractal boundary\n');
        end
    end

    if o.plot
        % Build the colour map from the labels actually present.  A fixed
        % three-colour map would put a phantom class in the colorbar when the
        % map happens to contain only two labels.
        labs = unique(basin(:));
        cmap = zeros(numel(labs), 3);
        palette = [0.85 0.85 0.85; 0.85 0.20 0.20; 0.20 0.30 0.80; ...
                   0.20 0.65 0.35; 0.60 0.35 0.75; 0.90 0.60 0.10];
        for i = 1:numel(labs)
            cmap(i, :) = palette(mod(i-1, size(palette,1)) + 1, :);
        end

        % Plotting is wrapped separately from the measurement.  A failure to
        % draw must never invalidate a result that was already computed: the
        % caller asked for a measurement first and a picture second.  (An
        % earlier version let a version-specific plotting call throw out of the
        % whole function, so make_gallery recorded an error string where the
        % dimension should have been.)
        try
            figure('Name', sprintf('basin dimension: alpha=%.3f, D=%.3f', alpha, D), ...
                   'Position', [120 120 1080 460], 'Color', 'w');
            subplot(1,2,1);
            imagesc(basin); axis image; set(gca,'YDir','normal');
            colormap(gca, cmap);
            ca = [min(labs) max(labs)];
            if exist('clim','file') || exist('clim','builtin')
                clim(ca);
            else
                caxis(ca);            % R2021a and earlier
            end
            title(sprintf('basin labels (%d present: %s)', nLab, mat2str(labs(:).')));
            xlabel('index'); ylabel('index');
            cb = colorbar; cb.Ticks = labs(:).';
            subplot(1,2,2);
            loglog(epss, f, 'o-', 'LineWidth', 1.5, 'MarkerFaceColor',[0.2 0.4 0.7]);
            hold on;
            loglog(epss(mask), exp(polyval(P, log(epss(mask)))), 'r--', 'LineWidth', 2);
            grid on; xlabel('ball radius \epsilon (pixels)');
            ylabel('f(\epsilon) = P(ball spans >1 basin)');
            title(sprintf('f ~ \\epsilon^{\\alpha},  \\alpha = %.3f  \\Rightarrow  D = %.3f', ...
                          alpha, D));
            legend({'data','fit'}, 'Location','southwest');
            hold off;
        catch MEplot
            warning('basin_dimension:plot', ...
                    'measurement succeeded but plotting failed: %s', MEplot.message);
        end
    end
end


% =========================================================================
function o = parse_opts(varargin)
    o = struct('nBalls', 4e5, 'nEps', 26, 'maxEps', 40, ...
               'fLo', 0.02, 'fHi', 0.9, 'seed', 0, ...
               'plot', false, 'verbose', true);
    for i = 1:2:numel(varargin)
        if ~isfield(o, varargin{i})
            error('basin_dimension:opt', 'unknown option "%s"', varargin{i});
        end
        o.(varargin{i}) = varargin{i+1};
    end
end
