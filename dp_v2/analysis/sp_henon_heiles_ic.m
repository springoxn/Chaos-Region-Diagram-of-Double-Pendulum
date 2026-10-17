function [Y0, info] = sp_henon_heiles_ic(varargin)
%% SP_HENON_HEILES_IC  Initial conditions for Henon-Heiles maps at FIXED ENERGY.
%%
%%   [Y0, info] = sp_henon_heiles_ic()
%%   [Y0, info] = sp_henon_heiles_ic('E',1/12, 'N',200, 'plane','yY')
%%   [Y0, info] = sp_henon_heiles_ic('E',1/8, 'x0',0, 'verbose',true)
%%
%%   Y0    4 x N, rows = [x; y; X; Y]
%%   info  struct: E, X, Y, escaped (logical), nEscaped, plane, x0
%%
%%   WHY A FIXED ENERGY, AND WHERE THE MOMENTUM COMES FROM
%%   ----------------------------------------------------
%%   Henon-Heiles is used for MAPS, and a map is only meaningful on ONE energy
%%   surface.  The paper states this explicitly for its Fig. 12: "on the y vs Y
%%   plane for x = 0 and X obtained from the constant value of the energy
%%   E = 1/8".
%%
%%   So one momentum is SOLVED for rather than gridded.  For a slice at fixed x:
%%
%%       X = +/- sqrt( 2E - Y^2 - x^2 - y^2 - 2 x^2 y + 2 y^3 / 3 )
%%
%%   The root is REAL only where the bracket is non-negative, which is exactly
%%   the classically allowed region.  Points outside it are NOT silently
%%   replaced with zero -- they come back marked in info.escaped, because a
%%   map that quietly substitutes an unreachable initial condition is worse than
%%   one that shows a hole.
%%
%%   THE ESCAPE ENERGY
%%   -----------------
%%   V is unbounded below along y -> +inf, so for E > E_esc = 1/6 the well is
%%   open and orbits escape to infinity; their Lyapunov exponent then diverges
%%   and every indicator reads "chaotic".  The paper's two slices, E = 1/12 and
%%   E = 1/8, are both below E_esc, so on those the motion is bounded.  A caller
%%   asking for E > 1/6 is warned rather than stopped: the escape is real
%%   physics, not a defect, and seeing it is occasionally the point.
%%
%%   THE TWO PLANES THE PAPER USES
%%   -----------------------------
%%     'yY'  y vs Y with x = 0        -- their Fig. 12 (the OFLI2/time study).
%%           The paper is explicit that this map must be SYMMETRIC, and uses
%%           that symmetry as the visual check that tf is long enough: the
%%           tf = 50 and tf = 100 panels are visibly NOT symmetric, while
%%           tf = 500 and tf = 1000 are.  test_henon_heiles.m asserts the
%%           asymmetry at short tf and its disappearance at long tf, which
%%           turns the paper's qualitative remark into a measured number.
%%     'xX'  x vs X with y = 0        -- the Poincare section used for Figs. 10-11.
%%
%%   Options
%%     E       1/12    energy of the slice (paper uses 1/12 and 1/8)
%%     N       200     grid points per axis
%%     plane   'yY'    'yY' (x = 0) | 'xX' (y = 0)
%%     x0      0       the held coordinate for the 'yY' plane
%%     y0      0       the held coordinate for the 'xX' plane
%%     branch  +1      +1 or -1: which root of the momentum to take
%%     verbose false
%%
%%   See also sp_sys, sp_run, sp_ofli2, sp_henon_heiles_map, test_henon_heiles.

    o = struct('E',1/12, 'N',200, 'plane','yY', 'x0',0, 'y0',0, ...
               'branch',+1, 'verbose',false);
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_henon_heiles_ic:opt', 'unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    switch lower(o.plane)
        case 'yy'
            % ---- the yY plane: x held at x0, grid over (y, Y), solve for X ----
            %
            % g(y) = 2E - 2V(x0, y) is a CUBIC in y, so its roots are found
            % exactly rather than by bracketing.  Bracketing with fzero was tried
            % first and FAILED for a real reason worth recording: V is unbounded
            % below along y -> +inf, so for E < 1/6 the allowed set has TWO
            % disconnected components -- the bounded well and the unbounded
            % escape region -- and a naive bracket spanning both has the same
            % sign at its ends, which fzero rejects.
            %
            % The map must use the WELL component, because that is where the
            % paper's orbits live, so the component containing y = 0 is selected
            % explicitly and the escape component is reported instead of being
            % silently folded into the grid.
            % The coefficients are read straight off the expanded polynomial
            % (verified with the symbolic toolbox):
            %     g(y) = (2/3) y^3 - y^2 - 2 x0^2 y + (2E - x0^2)
            % A first version had these in the wrong slots, which put the roots
            % in the wrong places; taking them from the expansion is what pins
            % them down.
            g = @(y) 2*o.E - (o.x0^2 + y.^2 + 2*o.x0^2.*y - 2*y.^3/3);
            cr = roots([2/3, -1, -2*o.x0^2, 2*o.E - o.x0^2]);
            cr = sort(real(cr(abs(imag(cr)) < 1e-9)));
            % build the candidate intervals from the real roots
            edges = [-inf, cr(:).', inf];
            [ylo, yhi] = pick_well(g, edges, 0);
            if ~(yhi > ylo)
                error('sp_henon_heiles_ic:empty', ...
                      'E = %g admits no motion at x = %g', o.E, o.x0);
            end
            yfine = linspace(ylo, yhi, 4001);
            Ymax = sqrt(max(g(yfine)));
            yv = linspace(ylo, yhi, o.N);
            Yv = linspace(-Ymax, Ymax, o.N);
            [Yg, yg] = meshgrid(Yv, yv);
            xg = o.x0*ones(size(yg));
            rhs = g(yg) - Yg.^2;
            Xg = o.branch*sqrt(max(rhs, 0));
        case 'xx'
            % ---- the xX plane: y held at y0, grid over (x, X), solve for Y ----
            % Here g(x) = 2E - 2V(x, y0) is QUADRATIC in x:
            %     g(x) = 2E - y0^2 + 2y0^3/3 - (1 + 2*y0) x^2
            A = 1 + 2*o.y0;
            B = 2*o.E - o.y0^2 + 2*o.y0^3/3;
            if ~(A > 0) || ~(B > 0)
                error('sp_henon_heiles_ic:empty', ...
                      'E = %g admits no motion at y = %g', o.E, o.y0);
            end
            xmax = sqrt(B/A);
            Xmax = sqrt(B);          % max of g over the slice is at x = 0
            xv = linspace(-xmax, xmax, o.N);
            Xv = linspace(-Xmax, Xmax, o.N);
            [Xg, xg] = meshgrid(Xv, xv);
            yg = o.y0*ones(size(xg));
            rhs = B - A*xg.^2 - Xg.^2;
            Yg = o.branch*sqrt(max(rhs, 0));
        otherwise
            error('sp_henon_heiles_ic:plane', ...
                  'plane must be ''yY'' or ''xX'' (got "%s")', o.plane);
    end

    escaped = (rhs < 0);
    Y0 = [xg(:).'; yg(:).'; Xg(:).'; Yg(:).'];

    info = struct('E', o.E, 'N', o.N, 'plane', o.plane, ...
                  'x0', o.x0, 'y0', o.y0, 'branch', o.branch, ...
                  'escaped', escaped(:).', 'nEscaped', sum(escaped(:)), ...
                  'nPoints', numel(xg));

    if o.verbose
        fprintf('  Henon-Heiles IC: plane=%s  E=%.6g  N=%d\n', ...
                o.plane, o.E, o.N);
        fprintf('    %d of %d points outside the classically allowed region\n', ...
                info.nEscaped, info.nPoints);
        if o.E > 1/6
            fprintf(['    WARNING: E = %.4f exceeds the escape energy 1/6; orbits\n' ...
                     '    will leave the well and their exponents diverge.\n'], o.E);
        end
    end
end


% =========================================================================
function [lo, hi] = pick_well(g, edges, yInside)
%% PICK_WELL  The connected allowed interval of g >= 0 that contains yInside.
%%
%%   g is the cubic 2E - 2V; its real roots split the line into intervals of
%%   constant sign.  V is unbounded below as y -> +inf, so for E < 1/6 exactly
%%   one of those intervals is the BOUNDED well and the rightmost is the
%%   unbounded escape region.  The map belongs on the well, which is the one
%%   containing yInside (the paper's slices are centred there).
%%
%%   Returning the well boundaries rather than a fixed box is what keeps the
%%   grid off the holes: a hard-coded +-0.7 box was tried first and left 73% of
%%   the points at E = 1/12 outside the classically allowed region.
    lo = NaN; hi = NaN;
    for k = 1:(numel(edges)-1)
        a = edges(k);   b = edges(k+1);
        if isinf(a) && isinf(b), continue; end
        ta = a; if isinf(ta), ta = b - 1; end
        tb = b; if isinf(tb), tb = a + 1; end
        if ~(tb > ta), continue; end
        if g(0.5*(ta + tb)) < 0, continue; end
        % An interval with an infinite end is the ESCAPE branch (the well is
        % always bounded for E < 1/6).  It is never the answer, and returning
        % inf would break linspace downstream, so it is skipped explicitly.
        if isinf(a) || isinf(b), continue; end
        if (yInside >= a) && (yInside <= b)
            lo = a; hi = b; return;
        end
    end
end
