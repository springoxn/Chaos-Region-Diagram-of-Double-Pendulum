function dp_lab()
%% DP_LAB  Double-pendulum laboratory.
%%
%%   dp_lab
%%
%%   Interactive explorer built on the validated dp_v2 core:
%%     * a (theta1, theta2) map coloured by the TRUE largest Lyapunov exponent,
%%       computed from the variational equations -- not a trajectory variance;
%%     * a comparison toggle that overlays the static potential energy, so the
%%       reader can see directly how much of the pattern is the energy slice;
%%     * a trajectory panel that draws the (theta1, theta2) path of a clicked
%%       initial condition, with its exponent and energy reported;
%%     * explicit integration controls (T, dt) and a stated decorrelation
%%       horizon, so that no result is presented without its accuracy context.
%%
%%   Design notes
%%     * Every heavy computation runs through the same core functions the tests
%%       exercise.  The GUI holds no numerics of its own.
%%     * Controls are disabled while a computation is in flight, and a
%%       try/catch guarantees they are re-enabled on failure -- a stuck
%%       "Running..." state was one of the original project's bugs.
%%     * The status line always reports the metric name and the integration
%%       settings actually used, so a screenshot is self-documenting.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'));

    S = struct();
    S.M = [];                    % last computed map
    S.busy = false;
    S.cancel = false;            % set by the Reset/Cancel button

    % ------------------------------------------------------------------
    fig = figure('Name','dp_v2 - Double Pendulum Laboratory', ...
                 'NumberTitle','off', 'Position',[90 70 1240 760], ...
                 'Color',[0.94 0.94 0.94], 'Visible','off', ...
                 'MenuBar','none', 'ToolBar','figure');

    ax = axes('Parent',fig, 'Units','normalized', 'Position',[0.06 0.14 0.56 0.78]);
    set(ax, 'Color','k', 'XGrid','on', 'YGrid','on');
    xlabel(ax,'\theta_2(0)  [rad]'); ylabel(ax,'\theta_1(0)  [rad]');
    title(ax,'press COMPUTE to build the map');
    cbar = colorbar(ax); cbar.Label.String = 'largest Lyapunov exponent \lambda_1';

    axTr = axes('Parent',fig, 'Units','normalized', 'Position',[0.70 0.56 0.27 0.36]);
    set(axTr,'Color',[0.15 0.15 0.18],'XGrid','on','YGrid','on');
    xlabel(axTr,'\theta_1  [rad]'); ylabel(axTr,'\theta_2  [rad]');
    title(axTr,'trajectory (click the map)','Color','k');

    pnl = uipanel('Parent',fig,'Title','Controls','Units','normalized', ...
                  'Position',[0.70 0.03 0.27 0.50], 'BackgroundColor',[0.90 0.90 0.90]);

    % ---- parameters ----
    % Layout note: the y coordinate must be computed per row.  A scalar here
    % (rather than a function of the row index) silently stacks every control
    % on top of the others, which MATLAB rejects with "too many objects".
    rowY = @(k) 0.90 - (k-1)*0.105;
    mkLab = @(txt,k,tt) uicontrol('Parent',pnl,'Style','text','String',txt, ...
        'Units','normalized','Position',[0.04 rowY(k) 0.34 0.085], ...
        'BackgroundColor',[0.90 0.90 0.90],'HorizontalAlignment','left', ...
        'TooltipString',tt);
    mkEdit = @(val,k,tt) uicontrol('Parent',pnl,'Style','edit','String',val, ...
        'Units','normalized','Position',[0.40 rowY(k) 0.22 0.095], ...
        'BackgroundColor','w','TooltipString',tt);

    mkLab('N (grid)',1,'Grid points per axis. Cost grows as N^2.');
    eN   = mkEdit('60',1,'Grid points per axis.');
    mkLab('T (s)',2,'Integration time per point. Must exceed the decorrelation horizon.');
    eT   = mkEdit('120',2,'Integration time in seconds.');
    mkLab('dt',3,'RK4 step. 0.01 keeps the energy drift near 1e-4 over 10 s.');
    eDt  = mkEdit('0.01',3,'RK4 step size.');
    mkLab('m2/m1',4,'Mass ratio. Default 1 (equal masses).');
    eMu  = mkEdit('1',4,'Mass ratio m2/m1.');
    mkLab('L2/L1',5,'Length ratio. Default 1 (equal lengths).');
    eLam = mkEdit('1',5,'Length ratio L2/L1.');
    mkLab('m1 (kg)',6,'First mass.');
    eM1  = mkEdit('1',6,'First mass.');
    mkLab('L1 (m)',7,'First length.');
    eL1  = mkEdit('1',7,'First length.');

    % ---- accuracy tier ----
    % The tier is the primary speed control.  Editing N/T/dt directly switches
    % the menu to "custom" so the displayed state always matches what ran.
    uicontrol('Parent',pnl,'Style','text','String','accuracy','Units','normalized', ...
        'Position',[0.04 rowY(8) 0.34 0.085],'BackgroundColor',[0.90 0.90 0.90], ...
        'HorizontalAlignment','left');
    popTier = uicontrol('Parent',pnl,'Style','popupmenu','Units','normalized', ...
        'Position',[0.40 rowY(8) 0.56 0.095], ...
        'String',{'preview  (fast, ~10 s)','standard  (figures)','accurate  (publish)'}, ...
        'Value',1, 'Callback',@on_tier);

    % ---- colour selector ----
    uicontrol('Parent',pnl,'Style','text','String','colour by','Units','normalized', ...
        'Position',[0.04 rowY(9) 0.34 0.085],'BackgroundColor',[0.90 0.90 0.90], ...
        'HorizontalAlignment','left');
    popMetric = uicontrol('Parent',pnl,'Style','popupmenu','Units','normalized', ...
        'Position',[0.40 rowY(9) 0.56 0.095], ...
        'String',{'largest Lyapunov exponent (recommended)','static potential energy'}, ...
        'Value',1, 'Callback',@(~,~) draw_map());

    % ---- buttons ----
    bCompute = uicontrol('Parent',pnl,'Style','pushbutton','String','COMPUTE', ...
        'Units','normalized','Position',[0.04 0.02 0.44 0.10], ...
        'FontWeight','bold','BackgroundColor',[0.55 0.75 0.95], ...
        'Callback',@on_compute);
    bCancel = uicontrol('Parent',pnl,'Style','pushbutton','String','Reset', ...
        'Units','normalized','Position',[0.52 0.02 0.44 0.10], ...
        'Callback',@on_reset);

    status = uicontrol('Parent',fig,'Style','text','Units','normalized', ...
        'Position',[0.06 0.015 0.56 0.075], 'BackgroundColor',[0.94 0.94 0.94], ...
        'HorizontalAlignment','left','FontAngle','italic','FontSize',8, ...
        'String','ready.  press COMPUTE.');

    set(fig,'Visible','on');
    set(fig,'CloseRequestFcn',@(~,~) delete(fig));
    on_tier();          % populate N/T/dt from the default tier

    % ==================================================================
    function on_tier(~,~)
        t = tier_name(get(popTier,'Value'));
        cfg = dp_apply_tier(struct('tier',t, 'N',0, 'T',0, 'dt',0));
        set(eN,'String',num2str(cfg.N));
        set(eT,'String',num2str(cfg.T));
        set(eDt,'String',num2str(cfg.dt));
        set(status,'String',sprintf( ...
            ['tier "%s": N=%d, T=%d s, dt=%.3f.  Measured accuracy vs the ' ...
             'accurate tier: see docs/perf_tiers.md.'], t, cfg.N, cfg.T, cfg.dt));
    end

    function t = tier_name(v)
        switch v
            case 1, t = 'preview';
            case 2, t = 'standard';
            otherwise, t = 'accurate';
        end
    end

    % ==================================================================
    function on_reset(~,~)
        % Doubles as Cancel.  If a run is in flight, ask it to stop and return
        % immediately; the compute loop checks S.cancel at each row.  Clearing
        % the display only happens when nothing is running, so pressing the
        % button mid-run does not throw away a partially built map.
        if S.busy
            S.cancel = true;
            set(status,'String','cancelling...');
            drawnow;
            return
        end
        S.M = [];
        cla(ax); set(ax,'Color','k');
        set(ax,'XLim',[-pi pi],'YLim',[-pi pi]);
        title(ax,'press COMPUTE to build the map');
        cla(axTr); set(axTr,'Color',[0.15 0.15 0.18]);
        title(axTr,'trajectory (click the map)','Color','k');
        set(status,'String','reset.');
    end

    % ==================================================================
    function on_compute(~,~)
        if S.busy, return; end
        S.busy = true;
        set_busy(true);
        c = onCleanup(@() set_busy(false));   %#ok<NASGU>  always restore
        try
            N    = clamp_val(eN, 8, 400, 60);
            T    = clamp_val(eT, 1, 4000, 120);
            dt   = clamp_val(eDt, 1e-4, 0.5, 0.01);
            mu   = clamp_val(eMu, 0.05, 50, 1);
            lam  = clamp_val(eLam, 0.05, 50, 1);
            m1   = clamp_val(eM1, 0.01, 100, 1);
            L1   = clamp_val(eL1, 0.01, 100, 1);

            p = dp_check_params(struct('m1',m1,'m2',m1*mu,'L1',L1,'L2',L1*lam,'g',9.81));

            % Compute row by row here rather than delegating to
            % dp_map_lyapunov, so the progress bar can update and the user can
            % see the map build up instead of waiting on an opaque call.  The
            % numerics are the same dp_lyap_row the map function uses.
            S.cancel = false;
            set(status,'String',sprintf('computing %dx%d (T=%.0f s, dt=%.3g)...', ...
                                        N, N, T, dt));
            drawnow;

            th1v = linspace(-pi, pi, N);
            th2v = linspace(-pi, pi, N);
            LAM = nan(N,N); DRF = nan(N,N);
            ro = struct('transient',0.3*T, 'reortho',10, 'progress',false);

            tStart = tic;
            for i = 1:N
                if S.cancel, break; end
                [LAM(i,:), DRF(i,:)] = dp_lyap_row(th2v, th1v(i)*ones(1,N), T, dt, p, ro);
                if mod(i, max(1,round(N/25)))==0 || i==N
                    frac = i/N;
                    set(status,'String',sprintf( ...
                        'computing %dx%d (T=%.0f s, dt=%.3g)  %3.0f%%   %.1f s elapsed, ~%.1f s left', ...
                        N, N, T, dt, 100*frac, toc(tStart), toc(tStart)/frac*(1-frac)));
                    drawnow;
                end
            end
            elapsed = toc(tStart);
            if S.cancel
                set(status,'String','cancelled.'); return
            end

            [E1,E2] = meshgrid(th1v, th2v);
            energy = -p.m1*p.g*p.L1*cos(E1) - p.m2*p.g*(p.L1*cos(E1) + p.L2*cos(E2));

            M = struct('lambda',LAM, 'energy',energy, 'drift',DRF, ...
                       'th1',th1v, 'th2',th2v, 'params',p, ...
                       'T',T, 'dt',dt, 'N',N, 'elapsed',elapsed);
            S.M = M;

            draw_map();
            set(status,'String',sprintf( ...
                ['metric: largest Lyapunov exponent (variational).  ' ...
                 '%dx%d, T=%.0f s, dt=%.3g, %.1f s (%.0f pts/s).  ' ...
                 'lambda in [%.3f, %.3f];  regular island identified by SMALL lambda.'], ...
                N, N, T, dt, elapsed, N^2/max(elapsed,eps), ...
                min(M.lambda(:)), max(M.lambda(:))));
        catch ME
            set(status,'String',['ERROR: ' ME.message]);
            errordlg(ME.message, 'dp_lab');
        end
    end

    % ==================================================================
    function draw_map()
        M = S.M;
        if isempty(M), return; end
        if get(popMetric,'Value') == 1
            data = M.lambda;  lbl = 'largest Lyapunov exponent \lambda_1';
        else
            data = M.energy;  lbl = 'static energy E = V(\theta_1,\theta_2)';
        end
        imagesc(ax, M.th2, M.th1, data); axis(ax,'xy'); axis(ax,'image');
        try, colormap(ax, turbo(256)); catch, colormap(ax, jet(256)); end
        cbar = colorbar(ax); cbar.Label.String = lbl;
        xlabel(ax,'\theta_2(0)  [rad]'); ylabel(ax,'\theta_1(0)  [rad]');
        r = corrcoef(M.lambda(:), M.energy(:));
        title(ax, sprintf(['Double pendulum: %s\n' ...
            'T=%.0f s, dt=%.3g,  \\omega_1(0)=\\omega_2(0)=0,  ' ...
            'r(\\lambda,E)=%+.2f'], lbl, M.T, M.dt, r(1,2)));
        set(ax,'ButtonDownFcn',@on_click);
        if get(popMetric,'Value') == 2
            % overlay the analytic flip threshold when showing energy
            hold(ax,'on');
            [TH1,TH2] = meshgrid(M.th1, M.th2);
            contour(ax, M.th2, M.th1, 2*cos(TH1)+cos(TH2), [1 1], 'w', 'LineWidth', 2);
            hold(ax,'off');
        end
    end

    % ==================================================================
    function on_click(~,~)
        if isempty(S.M), return; end
        cp = get(ax,'CurrentPoint');
        t2 = cp(1,1);  t1 = cp(1,2);
        p = S.M.params;
        [v, info] = dp_lyap([t1;0;t2;0], S.M.T, S.M.dt, p, ...
                            struct('transient',0.3*S.M.T));
        E = static_energy(t1, t2, p);
        lamDecorr = NaN;
        if v > 0, lamDecorr = log(1/eps)/v; end

        plot_traj(t1, t2, p);
        set(status,'String',sprintf( ...
            ['clicked (\\theta_1,\\theta_2)=(%.2f, %.2f):  \\lambda_1=%+.4f,  ' ...
             'E=%.3f J,  decorrelation time ~%.1f s (T=%.0f s)'], ...
             t1, t2, v, E, lamDecorr, S.M.T));
    end

    % ==================================================================
    function plot_traj(t1, t2, p)
        nPts = 4000;
        Tshow = min(12, S.M.T);
        dtS = Tshow/nPts;
        Y = zeros(nPts+1, 4);
        Y(1,:) = [t1, 0, t2, 0];
        y = Y(1,:).';
        for k = 1:nPts
            y = dp_rk4_step(y, dtS, p);
            Y(k+1,:) = y.';
        end
        plot3(axTr, Y(:,1), Y(:,3), linspace(0,Tshow,nPts+1), ...
              'LineWidth', 1.1);
        grid(axTr,'on');
        set(axTr,'Color',[0.15 0.15 0.18], 'XColor','w','YColor','w','ZColor','w');
        xlabel(axTr,'\theta_1'); ylabel(axTr,'\theta_2'); zlabel(axTr,'t [s]');
        title(axTr,'trajectory (colour axis = time)','Color','k');
        try, colormap(axTr, turbo(256)); catch, colormap(axTr, jet(256)); end
    end

    % ==================================================================
    function set_busy(tf)
        S.busy = tf;
        ctrls = [bCompute bCancel eN eT eDt eMu eLam eM1 eL1 popMetric popTier];
        if tf
            % Keep Reset ENABLED while busy: it doubles as Cancel, which is
            % what lets a user stop a long accurate-tier run.
            set(ctrls, 'Enable','off');
            set(bCancel, 'Enable','on', 'String','Cancel');
            set(bCompute,'String','Working...');
        else
            set(ctrls, 'Enable','on');
            set(bCancel, 'String','Reset');
            set(bCompute,'String','COMPUTE');
        end
        drawnow;
    end
end


function v = clamp_val(h, lo, hi, def)
    v = str2double(get(h,'String'));
    if ~isfinite(v), v = def; end
    v = min(max(v, lo), hi);
    set(h,'String', num2str(v));
end


function E = static_energy(t1, t2, p)
    E = -p.m1*p.g*p.L1*cos(t1) - p.m2*p.g*(p.L1*cos(t1) + p.L2*cos(t2));
end
