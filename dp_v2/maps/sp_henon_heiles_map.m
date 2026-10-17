function M = sp_henon_heiles_map(varargin)
%% SP_HENON_HEILES_MAP  Chaos-indicator maps for Henon-Heiles (paper Eq. 20).
%%
%%   M = sp_henon_heiles_map()
%%   M = sp_henon_heiles_map('indicator','ofli2', 'T',500, 'E',1/8)
%%   M = sp_henon_heiles_map('indicator','fli', 'dev0','grad')
%%
%%   Reproduces the settings of Barrio, Borczyk & Breiter (2009), Secs. 4.2-4.3:
%%
%%     Fig. 11  FLI maps on the y vs Y plane (x = 0) with FOUR choices of the
%%              initial variation vector eta0, showing that a careless eta0
%%              manufactures structure that the dynamics does not warrant, and
%%              that eta0 = grad H is the one that avoids it.
%%     Fig. 12  OFLI2 maps on the same plane at four FINAL TIMES
%%              tf = 50, 100, 500, 1000, showing that a too-short integration
%%              gives a qualitatively WRONG picture ("especially with the first
%%              one that in fact is not symmetric in spite of the symmetry of
%%              the problem").
%%
%%   WHY THIS SYSTEM IS WORTH THE CODE
%%   --------------------------------
%%   Henon-Heiles has TWO degrees of freedom, so unlike the planar pendulum it
%%   has room for a gradient direction that is genuinely distinct from the flow
%%   tangent.  That is exactly what makes the eta0 comparison of Fig. 11
%%   meaningful here and degenerate there.  It is the paper's second, more
%%   demanding test bed.
%%
%%   THE TWO CLAIMS THIS FILE EXISTS TO MAKE MEASURABLE
%%   --------------------------------------------------
%%   1. TIME.  Convergence is monotone in tf: the tf = 50 map disagrees strongly
%%      with a converged reference, and tf >= 500 agrees with tf = 1000.  The
%%      paper's rule of thumb -- "start with preliminary simulations until the
%%      final picture does not change significantly" -- is a statement about
%%      exactly this, and tests/test_henon_heiles.m turns it into numbers.
%%   2. INITIAL VECTOR.  eta0 = grad H must produce a SMOOTHER map (smaller
%%      spatial scatter) than a fixed careless eta0.  This is the paper's
%%      Fig. 11a vs 11c.
%%
%%   Options
%%     indicator 'ofli2'  'ofli2' | 'fli'
%%     E         1/8      energy of the slice (paper uses 1/12 and 1/8)
%%     N         120      grid points per axis
%%     T         500      final time tf
%%     dt        0.02     step
%%     order     4        Yoshida order
%%     dev0      'grad'   for 'fli': 'grad' | 'flow' | 'fixed' | 'bad'
%%                        for 'ofli2' this is ignored: OFLI2 defines its own
%%                        initial variations (n0 = f/||f||, n0' = 0)
%%     x0        0        the held coordinate (paper uses x = 0)
%%     fig       false    write gallery/sp_henon_heiles_<indicator>.png
%%     verbose   true
%%
%%   Output M fields
%%     values, x, y, indicator, dev0, E, T, dt, order, N, escaped, nEscaped,
%%     settings, elapsed, sys
%%
%%   See also sp_henon_heiles_ic, sp_sys, sp_ofli2, sp_run, test_henon_heiles.

    o = struct('indicator','ofli2', 'E',1/8, 'N',120, 'T',500, 'dt',0.02, ...
               'order',4, 'dev0','grad', 'x0',0, 'fig',false, 'verbose',true);
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_henon_heiles_map:opt', 'unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    sys = sp_sys('henonheiles');
    [Y0, ic] = sp_henon_heiles_ic('E',o.E, 'N',o.N, 'plane','yY', 'x0',o.x0);

    % The grid axes, for the returned struct and for plotting.  These mirror
    % sp_henon_heiles_ic's own ranges; the IC builder is the single source of
    % truth for them, so they are recovered from the generated points rather
    % than recomputed here.
    yy = unique(Y0(2,:));
    YY = unique(Y0(4,:));

    nSteps = round(o.T/o.dt);

    t0 = tic;
    if strcmpi(o.indicator,'ofli2')
        % OFLI2 is vectorised over the whole grid in one call, so the cost is
        % one integration of the augmented system -- not N^2 of them.
        Vlin = sp_ofli2(sys, Y0, struct('T',o.T,'dt',o.dt,'order',o.order));
        V = reshape(Vlin, o.N, o.N);
    elseif strcmpi(o.indicator,'fli')
        Vlin = fli_dev0(sys, Y0, o.T, o.dt, o.order, o.dev0);
        V = reshape(Vlin, o.N, o.N);
    else
        error('sp_henon_heiles_map:indicator', ...
              'indicator must be ''ofli2'' or ''fli'' (got "%s")', o.indicator);
    end
    elapsed = toc(t0);

    % Points that start outside the classically allowed region have no orbit;
    % they are masked rather than filled with a value that would read as a
    % dynamical result.
    V(ic.escaped) = NaN;

    M = struct('values',V, 'x',yy, 'y',YY, 'indicator',o.indicator, ...
               'dev0',o.dev0, 'E',o.E, 'T',o.T, 'dt',o.dt, 'order',o.order, ...
               'N',o.N, 'escaped',ic.escaped, 'nEscaped',ic.nEscaped, ...
               'settings',o, 'elapsed',elapsed, 'sys',sys.name, ...
               'nSteps',nSteps);

    if o.verbose
        fprintf('  Henon-Heiles %s: %dx%d, E=%.5g, T=%g, dt=%g, %.1f s\n', ...
                upper(o.indicator), o.N, o.N, o.E, o.T, o.dt, elapsed);
        fprintf('    %d of %d points outside the allowed region (masked)\n', ...
                ic.nEscaped, ic.nPoints);
        fprintf('    values in [%.4g, %.4g], median %.4g\n', ...
                min(V(~isnan(V))), max(V(~isnan(V))), median(V(~isnan(V)),'omitnan'));
    end

    if o.fig
        outdir = fullfile(fileparts(mfilename('fullpath')),'..','gallery');
        if ~exist(outdir,'dir'), mkdir(outdir); end
        f = figure('Visible','off','Position',[60 60 640 560]);
        imagesc(M.x, M.y, M.values); axis xy image;
        colormap(turbo_safe_()); cb = colorbar;
        cb.Label.String = sprintf('%s (log-scale growth)', upper(o.indicator));
        xlabel('y(0)'); ylabel('Y(0)');
        if strcmpi(o.indicator,'fli')
            ttl = sprintf('Henon-Heiles FLI, E=%.4g, T=%g, \\eta_0 = %s', ...
                          o.E, o.T, o.dev0);
        else
            ttl = sprintf('Henon-Heiles OFLI2, E=%.4g, T=%g', o.E, o.T);
        end
        title({ttl, sprintf('x(0)=%g, X(0) from the energy integral', o.x0)});
        fn = fullfile(outdir, sprintf('sp_henon_heiles_%s.png', lower(o.indicator)));
        exportgraphics(f, fn, 'Resolution',140);
        close(f);
        if o.verbose, fprintf('    figure written to %s\n', fn); end
    end
end


% =========================================================================
function V = fli_dev0(sys, Y0, T, dt, order, which)
%% FLI with a CALLER-CHOSEN initial variation vector.
%%
%%   sp_run.m seeds the standard basis (V(j,j,:) = 1), which is the choice the
%%   paper shows to be CARELESS for a first-order indicator: it can lie along
%%   the flow and manufacture spurious structure.  Reproducing Fig. 11 needs
%%   the freedom to choose, so this driver exists here for that purpose only.
%%
%%   'grad'   eta0 = grad H / ||grad H||   -- the paper's recommended choice
%%   'flow'   eta0 = f / ||f||             -- along the flow tangent
%%   'fixed'  eta0 = (1,1,1,1)/2           -- a fixed vector (their Fig. 11a)
%%   'bad'    eta0 = (-f4,-f3,f2,f1)/||f|| -- their Fig. 11b
%%
%%   RENORMALISATION IS REQUIRED, AND IT IS EXACTLY EQUIVALENT.
%%
%%   A first version of this file passed renorm = false, on the reasoning that
%%   "FLI is the sup over the raw norm, so rescaling would change it".  That
%%   reasoning is wrong, and the numbers said so immediately: the map came back
%%   with values around 4.5e4.
%%
%%   Without renormalisation the vector overflows to Inf within a few hundred
%%   steps, so the quantity being maximised is not ln||n(t)|| at all.  WITH
%%   renormalisation the accumulated sum is still exactly the FLI:
%%
%%       sum_k ln g_k  =  ln||n(t)|| - ln||n(0)|| ,
%%
%%   because every factor divided out is added back.  Maximising that cumulative
%%   sum is therefore identical to maximising ln||n(t)||, just without the
%%   overflow.  That is the standard Benettin convention and it is what
%%   sp_step.m does by default.
%%
%%   The distinction that DOES matter is against sp_ofli2.m, which also avoids
%%   rescaling: it can afford to, because it tracks a projected combination over
%%   a much shorter normalisation window and never lets the raw norm run away.
%%   Here the run is the paper's tf = 500, so the accumulated-log form is the
%%   only workable one.
    ndof = sys.ndof;
    N = size(Y0,2);

    % THREE-DIMENSIONAL (ndof x 1 x N), not ndof x N.  sp_step's tangent path
    % indexes V(:,j,:) and dmul returns nq x k x N; handing it a 2-D matrix
    % makes dmul broadcast to nq x N x N instead of erroring, which surfaced as
    % a dimension mismatch deep inside apply_kick.  k = 1 here because FLI
    % tracks a single vector.
    n0 = zeros(ndof, 1, N);
    q = Y0(1:sys.nq,:);
    f = [Y0(sys.nq+1:end,:); sys.force(q, 0)];
    for c = 1:N
        fc = f(:,c);
        switch lower(which)
            case 'grad'
                g = grad_H(Y0(:,c));
                if norm(g) > 0, n0(:,1,c) = g/norm(g); end
            case 'flow'
                if norm(fc) > 0, n0(:,1,c) = fc/norm(fc); end
            case 'fixed'
                n0(:,1,c) = [1;1;1;1]/2;
            case 'bad'
                v = [-fc(4); -fc(3); fc(2); fc(1)];
                if norm(v) > 0, n0(:,1,c) = v/norm(v); end
            otherwise
                error('fli_dev0:which', 'unknown dev0 "%s"', which);
        end
        if norm(n0(:,1,c)) == 0
            error('fli_dev0:zero', 'eta0 came out zero at point %d', c);
        end
    end

    nSteps = round(T/dt);
    lSum = zeros(1,N);
    fli = -inf(1,N);
    y = Y0; t = 0;
    for step = 1:nSteps
        % RENORM = TRUE (the default).  See the long note above: the cumulative
        % sum of the divided-out logs is exactly ln||n(t)|| - ln||n(0)||, so
        % taking the running supremum of that sum IS the FLI -- while the raw
        % vector would have overflowed long before tf = 500.
        [y, n0, g, t] = sp_step(y, n0, t, dt, sys, order);
        lSum = lSum + log(g(1,:));
        fli = max(fli, lSum);
    end
    V = fli;
end


function gv = grad_H(y)
%% grad H = [x + 2xy ; y + x^2 - y^2 ; X ; Y] for the Henon-Heiles Hamiltonian.
    x = y(1); yy = y(2);
    gv = [ x + 2*x*yy ; yy + x^2 - yy^2 ; y(3) ; y(4) ];
end


function cmap = turbo_safe_()
    try
        cmap = turbo(256);
    catch
        cmap = jet(256);
    end
end
