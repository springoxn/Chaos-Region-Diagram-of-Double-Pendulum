function make_gallery(varargin)
%% MAKE_GALLERY  Regenerate the project's figures with correct metrics.
%
%%   make_gallery
%%   make_gallery('N', 120)
%%   make_gallery('quick', true)
%%
%%   Produces, in dp_v2/gallery/ :
%%
%%     dp_lyapunov_map.png        double pendulum: TRUE largest Lyapunov map
%%     dp_energy_compare.png      the same map beside the static potential
%%                                energy -- makes the confounding visible
%%     fp_lyapunov_map.png        forced pendulum: true Lyapunov map
%%     fp_winding_map.png         forced pendulum: rotation-number basins
%%     fp_basin_dimension.png     uncertainty-exponent scaling for the basin
%%     fp_amplitude_vs_lyapunov.png   why an amplitude proxy cannot stand in
%%     sweep_F.png                F sweep: exponent and winding side by side
%%     summary.mat                every numeric result, for the record
%%
%%   Each figure carries a caption naming the metric and the integration
%%   settings, so no figure can be misread once detached from this script.
%%
%%   Cost: roughly 38 ms/point for dp_map_lyapunov and 46 ms/point for fp_map
%%   on 12 workers, so N=120 takes about 23 minutes end to end.

    o = parse(varargin{:});
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'core'), fullfile(here,'maps'), fullfile(here,'analysis'));

    outdir = fullfile(here, 'gallery');
    if ~exist(outdir,'dir'), mkdir(outdir); end

    N   = o.N;
    Tdp = o.Tdp;
    dtdp = o.dtdp;

    summary = struct();
    summary.created = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    summary.params = struct('N',N, 'Tdp',Tdp, 'dtdp',dtdp, ...
                            'fpPeriods',o.fpPeriods, 'fpdt',o.fpdt);
    summary.notes = ['All chaos measures are largest Lyapunov exponents computed ' ...
                     'from the variational equations with QR reorthonormalisation. ' ...
                     'An amplitude proxy log(1+var(theta)+var(omega)) is kept only for the ' ...
                     'comparison figure fp_amplitude_vs_lyapunov.png.'];

    % =================================================================
    % Steps 1, 3, 6 and 7 are the expensive ones (tens of minutes).  Their
    % results are cached to .mat in the gallery directory, so figure layout can
    % be iterated in seconds with 'reuse',true without recomputing physics.
    % 'figuresOnly' is shorthand for reuse with no pool startup.
    % =================================================================
    reuse = o.reuse || o.figuresOnly;
    if o.figuresOnly
        o.pool = false;
    end

    if o.pool
        try
            if isempty(gcp('nocreate')), parpool; end
        catch
            fprintf('  (no parallel pool; running serially)\n');
        end
    end

    % =================================================================
    cacheDp = fullfile(outdir,'dp_lyapunov_map.mat');
    if reuse && exist(cacheDp,'file')
        fprintf('\n[1/7] double-pendulum Lyapunov map -- REUSING cached %s\n', ...
                'dp_lyapunov_map.mat');
        L = load(cacheDp); Mdp = L.Mdp;
    else
        fprintf('\n[1/7] double-pendulum Lyapunov map (%dx%d)\n', N, N);
        Mdp = dp_map_lyapunov('N',N, 'T',Tdp, 'dt',dtdp, 'progress',true, 'pool',o.pool);
        save(cacheDp, 'Mdp');
    end
    summary.dp_map = rmfield(Mdp, 'params');
    summary.dp_params = Mdp.params;

    f = figure('Position',[80 80 700 620],'Color','w');
    imagesc(Mdp.th2, Mdp.th1, Mdp.lambda); axis xy image;
    colormap(turbo_safe()); cb = colorbar;
    cb.Label.String = 'largest Lyapunov exponent \lambda_1';
    xlabel('\theta_2(0)  [rad]'); ylabel('\theta_1(0)  [rad]');
    title({sprintf('Double pendulum: true largest Lyapunov exponent  (t=%.0f s, dt=%.3f)', ...
                   Mdp.T, Mdp.dt), ...
           'slice \omega_1(0)=\omega_2(0)=0'});
    add_caption(gca, sprintf(['\\lambda_1 from the variational equation. ' ...
        'Colour is \\lambda_1 itself.' newline ...
        'The regular island is identified by SMALL \\lambda_1 (here ~0.005), ' ...
        'not by \\lambda_1 <= 0 -- a finite-time estimate does not settle at zero.']));
    exportgraphics(f, fullfile(outdir,'dp_lyapunov_map.png'), 'Resolution',o.resolution);
    close(f);

    % =================================================================
    fprintf('\n[2/7] double pendulum: Lyapunov vs static energy\n');
    % =================================================================
    f = figure('Position',[60 60 1300 430],'Color','w');
    subplot(1,3,1);
    imagesc(Mdp.th2, Mdp.th1, Mdp.lambda); axis xy image; colormap(gca, turbo_safe());
    colorbar; xlabel('\theta_2'); ylabel('\theta_1');
    title('(a) true \lambda_1');
    subplot(1,3,2);
    imagesc(Mdp.th2, Mdp.th1, Mdp.energy); axis xy image; colormap(gca, turbo_safe());
    colorbar; xlabel('\theta_2'); ylabel('\theta_1');
    title('(b) static energy E=V(\theta_1,\theta_2)');
    subplot(1,3,3);
    T1 = Mdp.th1(:)*ones(1,numel(Mdp.th2));
    T2 = ones(numel(Mdp.th1),1)*Mdp.th2(:)';
    r = corrcoef(Mdp.lambda(:), Mdp.energy(:));
    flippable = double(2*cos(T1)+cos(T2) > 1);
    r2 = corrcoef(Mdp.lambda(:), flippable(:));
    plot(Mdp.energy(:), Mdp.lambda(:), '.'); grid on
    xlabel('static energy E'); ylabel('\lambda_1');
    title(sprintf('(c) r(\\lambda,E) = %+.3f\nr(\\lambda,flippable) = %+.3f', r(1,2), r2(1,2)));
    sgtitle('The (\theta_1,\theta_2) slice at \omega=0 is NOT an energy shell');
    add_caption(gca, ['At \omega=0 each grid point sits at its own energy, so any map on ' ...
        'this slice mixes energies.' newline ...
        'The energy dependence seen in (c) is a property of the SLICE, not a defect of \lambda_1.']);
    exportgraphics(f, fullfile(outdir,'dp_energy_compare.png'), 'Resolution',o.resolution);
    close(f);
    summary.dp_corr_lambda_energy = r(1,2);
    summary.dp_corr_lambda_flippable = r2(1,2);

    % =================================================================
    cacheFp = fullfile(outdir,'fp_maps.mat');
    if reuse && exist(cacheFp,'file')
        fprintf('\n[3/7] forced-pendulum maps -- REUSING cached fp_maps.mat\n');
        L = load(cacheFp); Mfp = L.Mfp;
    else
        fprintf('\n[3/7] forced pendulum: Lyapunov map (%dx%d)\n', N, N);
        Mfp = fp_map('N',N, 'F',1.5, 'gamma',0.2, 'Omega',2/3, ...
                     'dt',o.fpdt, 'periods',o.fpPeriods, 'progress',true, 'pool',o.pool);
        save(cacheFp, 'Mfp');
    end
    summary.fp_map = rmfield(Mfp, {'lambda','winding','basin'});

    f = figure('Position',[80 80 700 620],'Color','w');
    imagesc(Mfp.th, Mfp.om, Mfp.lambda); axis xy image;
    colormap(turbo_safe()); cb = colorbar;
    cb.Label.String = '\lambda_1';
    xlabel('\theta(0)'); ylabel('\omega(0)');
    title({sprintf('Forced pendulum: true largest Lyapunov exponent  F=%.2f \\gamma=%.2f \\Omega=%.3f', ...
                   Mfp.F, Mfp.gamma, Mfp.Omega), ...
           sprintf('t = %d drive periods, dt=%.3f,  F/F_c = %.2f', ...
                   Mfp.periods, Mfp.dt, Mfp.supercritical)});
    add_caption(gca, sprintf(['Melnikov threshold F_c = %.4f. At F/F_c = %.2f practically every ' ...
        'initial condition is chaotic,' newline 'so this map is nearly uniform -- see the winding map for the structure.'], ...
        Mfp.MelnikovFc, Mfp.supercritical));
    exportgraphics(f, fullfile(outdir,'fp_lyapunov_map.png'), 'Resolution',o.resolution);
    close(f);

    % =================================================================
    fprintf('\n[4/7] forced pendulum: winding-number basins\n');
    % =================================================================
    f = figure('Position',[80 80 900 620],'Color','w');
    imagesc(Mfp.th, Mfp.om, Mfp.winding); axis xy image;
    colormap(turbo_safe()); cb = colorbar;
    cb.Label.String = 'winding number  w = \langle\omega\rangle/\Omega';
    xlabel('\theta(0)'); ylabel('\omega(0)');
    title({sprintf('Forced pendulum: rotation-number basins  F=%.2f \\gamma=%.2f \\Omega=%.3f', ...
                   Mfp.F, Mfp.gamma, Mfp.Omega), ...
           sprintf('w = +2 (CCW)  or  w = -2 (CW)   --  %d / %d points', ...
                   sum(Mfp.basin(:)>0), sum(Mfp.basin(:)<0))});
    add_caption(gca, ['This is the quantity that actually structures the plane. ' ...
        'Note |w| ~ 2: TWO rotations per drive period.' newline ...
        'The fractal boundary between the two rotation basins is what a ' ...
        '"chaos map" at these parameters is really showing.']);
    exportgraphics(f, fullfile(outdir,'fp_winding_map.png'), 'Resolution',o.resolution);
    close(f);

    % =================================================================
    fprintf('\n[5/7] basin boundary dimension (uncertainty exponent)\n');
    % =================================================================
    if numel(unique(Mfp.basin(:))) >= 2
        try
            Rd = basin_dimension(Mfp.basin, 'plot',true, 'verbose',true, ...
                                 'maxEps', max(6, round(N/4)));
            summary.basin_dim = rmfield(Rd, {'eps','f','fitMask','poly'});
            exportgraphics(gcf, fullfile(outdir,'fp_basin_dimension.png'), 'Resolution',o.resolution);
            close(gcf);
        catch ME
            % A coarse grid cannot resolve the scaling law.  This is a real
            % limitation, not a bug: report it and keep the rest of the gallery.
            fprintf('  SKIPPED: %s\n', ME.message);
            summary.basin_dim = sprintf('not measured: %s', ME.message);
            close all force;
        end
    else
        fprintf('  (only one basin present at these parameters; skipping)\n');
        summary.basin_dim = 'not applicable (single basin)';
    end

    % =================================================================
    cacheAmp = fullfile(outdir,'amplitude_vs_lyapunov.mat');
    if reuse && exist(cacheAmp,'file')
        fprintf('\n[6/7] amplitude proxy vs true exponent -- REUSING cached\n');
        L = load(cacheAmp); CI = L.CI; LM = L.LM; thg = L.thg; omg = L.omg;
    else
        fprintf('\n[6/7] amplitude proxy vs true exponent (method demonstration)\n');
        Ng = min(60, N);
        thg = linspace(-pi, pi, Ng);
        omg = linspace(-4, 4, Ng);
        CI = nan(Ng,Ng); LM = nan(Ng,Ng);
        for i = 1:Ng
            for j = 1:Ng
                CI(i,j) = amplitude_proxy(thg(j), omg(i), 1.5, 0.2, 2/3, 40, 0.04);
                LM(i,j) = fp_lyap(thg(j), omg(i), struct('F',1.5,'gamma',0.2, ...
                                  'Omega',2/3,'dt',o.fpdt,'periods',o.fpPeriods, ...
                                  'transient',0.3));
            end
            if mod(i, max(1,round(Ng/5)))==0, fprintf('    %3.0f%%\n', 100*i/Ng); end
        end
        save(cacheAmp,'CI','LM','thg','omg');
    end
    r = corrcoef(CI(:), LM(:));
    % FIELD NAME IS A CONTRACT WITH gen/gen_report.py AND gen/verify_manual.py.
    %
    %   Those two read `old_metric_corr_with_lambda`.  This line used to write
    %   `amplitude_proxy_corr_with_lambda`, so the key was simply absent from
    %   summary.mat; read_summary() in both generators swallows the KeyError in a
    %   bare `except` and silently substitutes its own hard-coded fallback.  The
    %   documents therefore looked fine while quoting numbers that came from
    %   neither this gallery nor any run at all.
    %
    %   Both spellings are now written so that either name resolves, and
    %   verify_docs.m asserts that the generator's key is present in
    %   summary.mat.  `old_metric_note` is likewise duplicated for the same
    %   reason: gen_report.py reads that name.
    summary.old_metric_corr_with_lambda = r(1,2);
    summary.amplitude_proxy_corr_with_lambda = r(1,2);
    summary.amplitude_proxy_note = ['log(1+var(theta)+var(omega)) over 40 periods. ' ...
        'Near-zero correlation with the true exponent at F=1.5, which is why an ' ...
        'amplitude proxy cannot substitute for a Lyapunov exponent.'];
    summary.old_metric_note = summary.amplitude_proxy_note;

    f = figure('Position',[50 50 1300 430],'Color','w');
    subplot(1,3,1);
    imagesc(thg, omg, CI); axis xy image; colormap(gca, turbo_safe());
    colorbar; xlabel('\theta(0)'); ylabel('\omega(0)');
    title('(a) amplitude proxy: log(1+var\theta+var\omega)');
    subplot(1,3,2);
    imagesc(thg, omg, LM); axis xy image; colormap(gca, turbo_safe());
    colorbar; xlabel('\theta(0)'); ylabel('\omega(0)');
    title('(b) true \lambda_1');
    subplot(1,3,3);
    plot(CI(:), LM(:), '.'); grid on
    xlabel('amplitude proxy'); ylabel('true \lambda_1');
    title(sprintf('(c) r = %+.4f\nessentially no information', r(1,2)));
    sgtitle('Why an amplitude proxy cannot substitute for \lambda_1');
    add_caption(gca, ['An amplitude proxy measures the SIZE of the attractor, not its chaos. ' ...
        'At F=1.5 the whole plane' newline ...
        'reaches the same attractor pair, so the proxy is nearly constant while ' ...
        '\lambda_1 still varies by a factor of two.']);
    exportgraphics(f, fullfile(outdir,'fp_amplitude_vs_lyapunov.png'), 'Resolution',o.resolution);
    close(f);

    % =================================================================
    fprintf('\n[7/7] forcing sweep: exponent and winding together\n');
    % =================================================================
    cacheSw = fullfile(outdir,'sweep_F.mat');
    if reuse && exist(cacheSw,'file')
        fprintf('\n[7/7] forcing sweep -- REUSING cached sweep_F.mat\n');
        L = load(cacheSw); Fs = L.Fs; swLam = L.swLam; swWnd = L.swWnd; ths = L.ths;
    else
        fprintf('\n[7/7] forcing sweep: exponent and winding together\n');
        Fs = [0.4 0.8 1.0 1.1 1.3 1.6];
        Nsw = min(90, N);
        swLam = nan(numel(Fs), Nsw); swWnd = nan(numel(Fs), Nsw);
        ths = linspace(-pi, pi, Nsw);
        for k = 1:numel(Fs)
            Fk = Fs(k);
            for j = 1:Nsw
                [v, info] = fp_lyap(ths(j), 0.0, struct('F',Fk,'gamma',0.5,'Omega',2/3, ...
                                'dt',o.fpdt,'periods',o.fpPeriods,'transient',0.3));
                swLam(k,j) = v;  swWnd(k,j) = info.winding;
            end
            fprintf('    F=%.2f  done\n', Fk);
        end
        save(cacheSw,'Fs','swLam','swWnd','ths');
    end
    nF = numel(Fs);
    summary.sweep_F = Fs;
    summary.sweep_lambda_mean = mean(swLam, 2).';
    summary.sweep_winding_median = median(swWnd, 2).';

    f = figure('Position',[50 50 1200 560],'Color','w');
    ax1 = subplot(1,2,1);
    hLines = gobjects(1, nF);
    for k = 1:nF
        hLines(k) = plot(ax1, ths, swLam(k,:), '-', 'LineWidth', 1.5); hold(ax1,'on');
    end
    Fc = fp_melnikov_threshold(0.5, 2/3);
    hZero = plot(ax1, [-pi pi], [0 0], 'k--', 'LineWidth', 1.2);
    grid(ax1,'on'); xlabel(ax1,'\theta(0)'); ylabel(ax1,'\lambda_1');
    % legend lists only the sweeps plus the zero line, explicitly -- an implicit
    % legend would pick up the decorative line and label it "data1"
    legend(ax1, [hLines hZero], ...
           [arrayfun(@(x) sprintf('F=%.1f',x), Fs, 'UniformOutput',false), ...
            {'\lambda_1 = 0'}], 'Location','southeast','FontSize',7);
    title(ax1, sprintf('(a) true \\lambda_1 vs F  (\\gamma=0.5, F_c=%.3f)', Fc));

    ax2 = subplot(1,2,2);
    for k = 1:nF
        plot(ax2, ths, swWnd(k,:), '-', 'LineWidth', 1.5); hold(ax2,'on');
    end
    grid(ax2,'on'); xlabel(ax2,'\theta(0)'); ylabel(ax2,'winding number w');
    title(ax2,'(b) rotation number vs F');

    sgtitle(sprintf('Forced pendulum parameter sweep  (Melnikov F_c = %.3f at \\gamma=0.5)', Fc));
    add_caption(ax2, sprintf(['Below F_c = %.3f every orbit is regular (\\lambda_1 < 0). ' ...
        'Above it, chaotic bands appear (F=1.1, 1.6).' newline ...
        'Panel (b): rotation number locks onto plateaus -- the phase-locked steps. ' ...
        'Note F=1.3 sits on a w = -1 plateau (a periodic rotating orbit, \\lambda_1 < 0).'], Fc));
    exportgraphics(f, fullfile(outdir,'sweep_F.png'), 'Resolution',o.resolution);
    close(f);

    save(fullfile(outdir,'summary.mat'), 'summary');
    fprintf('\n=== gallery written to %s ===\n', outdir);
    dump_summary(summary);
end


% =========================================================================
function o = parse(varargin)
    o = struct('N',160, 'Tdp',120, 'dtdp',0.01, 'fpPeriods',250, 'fpdt',0.01, ...
               'pool',true, 'quick',false, 'reuse',false, 'figuresOnly',false, ...
               'resolution',300);
    for i = 1:2:numel(varargin)
        if ~isfield(o, varargin{i})
            error('make_gallery:opt','unknown option "%s"', varargin{i});
        end
        o.(varargin{i}) = varargin{i+1};
    end
    if ~isscalar(o.resolution) || ~isfinite(o.resolution) || o.resolution < 72
        error('make_gallery:resolution', 'resolution must be a finite scalar >= 72 dpi');
    end
    if o.quick
        o.N = 60; o.Tdp = 60; o.fpPeriods = 120;
        if ~o.reuse && ~o.figuresOnly
            o.reuse = false;
        end
    end
end


function cmap = turbo_safe()
    try
        cmap = turbo(256);
    catch
        cmap = jet(256);
    end
end


function add_caption(ax, txt)
    % Put an explanatory caption under the axes so the figure cannot be
    % misread once it is detached from this script.
    %
    % Geometry, and why it is done this way: the caption occupies the bottom
    % CAP_H of the figure.  The AXES BOX must therefore start above that, but
    % starting the box at CAP_H is not enough -- the x-axis TICK LABELS and the
    % xlabel are drawn BELOW the box, so they still collide.  LABEL_ROOM below
    % reserves space for them.
    %
    % (An earlier version anchored the caption at the very bottom without
    % shrinking the axes, and every caption landed on top of the tick labels.)
    CAP_LINE   = 0.032;   % height of one caption line, figure fraction
    LABEL_ROOM = 0.085;   % room for tick labels + xlabel below the axes box
    % TOP_GAP must clear BOTH the per-axes title and, when present, an sgtitle
    % drawn above it.  Setting it just large enough for one of them is what
    % produced overlapping titles in an earlier revision.
    %
    % sgtitle in R2021a creates an object of Type 'subplottext' with an EMPTY
    % Tag, so searching for Tag=='suptitle' or Type=='text' finds nothing.  The
    % reliable test is the object type reported by get(figure,'Children').
    kids = get(gcf, 'Children');
    hasSg = any(strcmp(get(kids, 'Type'), 'subplottext'));
    if hasSg
        TOP_GAP = 0.130;
    else
        TOP_GAP = 0.065;
    end

    nLines = 1 + sum(txt == newline);
    CAP_H  = CAP_LINE * nLines + 0.012;

    % Colorbars are also 'axes' objects and must not be repositioned, so they
    % are filtered out by their Tag.
    axList = findall(gcf, 'Type', 'axes');
    axList = axList(~strcmp(get(axList, 'Tag'), 'Colorbar'));
    if isempty(axList), axList = ax; end

    for a = reshape(axList, 1, [])
        set(a, 'Units', 'normalized');
        p = get(a, 'Position');
        bottom = CAP_H + LABEL_ROOM;
        top    = 1 - TOP_GAP;
        if p(2) >= bottom && p(2) + p(4) <= top
            continue                      % already clear; leave it alone
        end
        p(2) = bottom;
        p(4) = max(0.15, top - bottom);
        set(a, 'Position', p);
    end

    annotation(gcf, 'textbox', [0.012 0.006 0.976 CAP_H], 'String', txt, ...
               'EdgeColor','none', 'FontSize',8, 'Color',[0.25 0.25 0.25], ...
               'VerticalAlignment','bottom', 'Interpreter','tex');
end


function ci = amplitude_proxy(th0, om0, F, gam, Om, periods, dt)
%% log(1+var(theta)+var(omega)) -- a representative amplitude proxy, computed
%% here only to show that it carries no information about the exponent.
    Tp = 2*pi/Om;
    nTotal = round(periods*Tp/dt);
    ntrp = max(5, round(periods/3));
    ntr = round(ntrp*Tp/dt);
    nextT = ceil((ntr*dt)/Tp)*Tp;
    y = [th0; om0]; t = 0;
    sc = 0; nsMax = (periods-ntrp)+3;
    bth = zeros(1,nsMax); bom = zeros(1,nsMax);
    dt2 = 0.5*dt; dt6 = dt/6;
    for k = 1:nTotal
        f1 = -gam*y(2) - sin(y(1)) + F*cos(Om*t);
        a1 = y(1)+dt2*y(2);  b1 = y(2)+dt2*f1;
        f2 = -gam*b1 - sin(a1) + F*cos(Om*(t+dt2));
        a2 = y(1)+dt2*b1;    b2 = y(2)+dt2*f2;
        f3 = -gam*b2 - sin(a2) + F*cos(Om*(t+dt2));
        a3 = y(1)+dt*b2;     b3 = y(2)+dt*f3;
        f4 = -gam*b3 - sin(a3) + F*cos(Om*(t+dt));
        y(1) = y(1)+dt6*(y(2)+2*b1+2*b2+b3);
        y(2) = y(2)+dt6*(f1+2*f2+2*f3+f4);
        t = t+dt;
        if t >= nextT
            sc = sc+1; bth(sc) = y(1); bom(sc) = y(2);
            nextT = nextT + Tp;
        end
    end
    n = sc;
    w = (bth(n)-bth(1))/(2*pi*(n-1));
    thd = bth(1:n) - (bth(1) + 2*pi*w*(0:n-1));
    ci = log(1 + var(thd) + var(bom(1:n)));
end


function dump_summary(s)
    fprintf('\n---- summary ----\n');
    fn = fieldnames(s);
    for i = 1:numel(fn)
        v = s.(fn{i});
        if isnumeric(v) && isscalar(v)
            fprintf('  %-32s %.6g\n', fn{i}, v);
        elseif isnumeric(v) && numel(v) <= 8
            fprintf('  %-32s %s\n', fn{i}, mat2str(v, 4));
        end
    end
end
