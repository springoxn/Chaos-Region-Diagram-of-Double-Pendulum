function fp_lab()
%% FP_LAB  Forced damped pendulum laboratory.
%%
%%   fp_lab
%%
%%   theta'' + gamma*theta' + sin(theta) = F*cos(Omega*t)
%%
%%   The key idea this GUI is built around: at any forcing strength you must
%%   look at TWO things at once, and the original project looked at neither.
%%
%%     * the largest Lyapunov exponent tells you WHETHER the motion is chaotic;
%%     * the winding number tells you WHICH attractor an initial condition
%%       reaches.
%%
%%   At strongly supercritical forcing (F >> F_c) practically every initial
%%   condition is chaotic, so the exponent map is nearly uniform.  The structure
%%   that remains lives entirely in the winding number -- two counter-rotating
%%   attractors with a fractal basin boundary.  Showing only a "chaos map" there
%%   is what made the original project's figures look like noise.
%%
%%   The Melnikov threshold is displayed next to the parameters so that the
%%   regime is always visible: F/F_c < 1 means regular, F/F_c >> 1 means the
%%   exponent map cannot be informative.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'));

    S = struct('M',[], 'busy',false, 'cancel',false);

    fig = figure('Name','dp_v2 - Forced Damped Pendulum Laboratory', ...
                 'NumberTitle','off','Position',[90 70 1260 760], ...
                 'Color',[0.94 0.94 0.94],'Visible','off','MenuBar','none');

    ax = axes('Parent',fig,'Units','normalized','Position',[0.055 0.13 0.46 0.79]);
    set(ax,'Color','k');
    xlabel(ax,'\theta(0)'); ylabel(ax,'\omega(0)');
    title(ax,'press COMPUTE');
    cbar = colorbar(ax); cbar.Label.String = '\lambda_1';

    axB = axes('Parent',fig,'Units','normalized','Position',[0.565 0.13 0.40 0.79]);
    set(axB,'Color','k');
    xlabel(axB,'\theta(0)'); ylabel(axB,'\omega(0)');
    title(axB,'winding number (basins)');
    cbarB = colorbar(axB); cbarB.Label.String = 'w = \langle\omega\rangle/\Omega';

    pnl = uipanel('Parent',fig,'Title','Parameters','Units','normalized', ...
                  'Position',[0.055 0.86 0.91 0.13], 'BackgroundColor',[0.90 0.90 0.90]);

    uicontrol('Parent',pnl,'Style','text','String','N','Units','normalized', ...
        'Position',[0.010 0.55 0.03 0.35],'BackgroundColor',[0.90 0.90 0.90]);
    eN = uicontrol('Parent',pnl,'Style','edit','String','200','Units','normalized', ...
        'Position',[0.040 0.58 0.045 0.32],'BackgroundColor','w');
    eN.TooltipString = 'grid points per axis';

    uicontrol('Parent',pnl,'Style','text','String','F','Units','normalized', ...
        'Position',[0.095 0.55 0.02 0.35],'BackgroundColor',[0.90 0.90 0.90]);
    eF = uicontrol('Parent',pnl,'Style','edit','String','1.5','Units','normalized', ...
        'Position',[0.115 0.58 0.045 0.32],'BackgroundColor','w');
    eF.TooltipString = 'forcing amplitude';

    uicontrol('Parent',pnl,'Style','text','String','\gamma','Units','normalized', ...
        'Position',[0.170 0.55 0.035 0.35],'BackgroundColor',[0.90 0.90 0.90]);
    eG = uicontrol('Parent',pnl,'Style','edit','String','0.2','Units','normalized', ...
        'Position',[0.205 0.58 0.045 0.32],'BackgroundColor','w');
    eG.TooltipString = 'damping coefficient';

    uicontrol('Parent',pnl,'Style','text','String','\Omega','Units','normalized', ...
        'Position',[0.260 0.55 0.04 0.35],'BackgroundColor',[0.90 0.90 0.90]);
    eO = uicontrol('Parent',pnl,'Style','edit','String','0.6667','Units','normalized', ...
        'Position',[0.300 0.58 0.050 0.32],'BackgroundColor','w');
    eO.TooltipString = 'drive frequency';

    uicontrol('Parent',pnl,'Style','text','String','periods','Units','normalized', ...
        'Position',[0.360 0.55 0.050 0.35],'BackgroundColor',[0.90 0.90 0.90]);
    eP = uicontrol('Parent',pnl,'Style','edit','String','250','Units','normalized', ...
        'Position',[0.410 0.58 0.045 0.32],'BackgroundColor','w');
    eP.TooltipString = 'drive periods integrated per point';

    uicontrol('Parent',pnl,'Style','text','String','dt','Units','normalized', ...
        'Position',[0.465 0.55 0.025 0.35],'BackgroundColor',[0.90 0.90 0.90]);
    eDt = uicontrol('Parent',pnl,'Style','edit','String','0.01','Units','normalized', ...
        'Position',[0.490 0.58 0.045 0.32],'BackgroundColor','w');
    eDt.TooltipString = 'RK4 step';

    bGo = uicontrol('Parent',pnl,'Style','pushbutton','String','COMPUTE', ...
        'Units','normalized','Position',[0.560 0.55 0.10 0.36], ...
        'FontWeight','bold','BackgroundColor',[0.55 0.75 0.95],'Callback',@on_go);

    bPreset = uicontrol('Parent',pnl,'Style','popupmenu','Units','normalized', ...
        'Position',[0.675 0.55 0.31 0.36], ...
        'String',{'preset: supercritical rotation (F=1.5, g=0.2)', ...
                  'preset: regular/chaos coexistence (F=1.1, g=0.5)', ...
                  'preset: near Melnikov threshold (F=1.0, g=0.5)', ...
                  'preset: subcritical regular (F=0.8, g=0.5)'}, ...
        'Callback',@on_preset);

    regTxt = uicontrol('Parent',pnl,'Style','text','Units','normalized', ...
        'Position',[0.010 0.06 0.97 0.34],'BackgroundColor',[0.90 0.90 0.90], ...
        'HorizontalAlignment','left','FontSize',9, 'String','F_c = ...');

    status = uicontrol('Parent',fig,'Style','text','Units','normalized', ...
        'Position',[0.055 0.012 0.91 0.10],'BackgroundColor',[0.94 0.94 0.94], ...
        'HorizontalAlignment','left','FontAngle','italic','FontSize',9, ...
        'String','ready.');

    set(fig,'Visible','on');
    upd_region();
    set(eF,'Callback',@(~,~) upd_region());
    set(eG,'Callback',@(~,~) upd_region());
    set(eO,'Callback',@(~,~) upd_region());

    % ==================================================================
    function on_preset(~,~)
        if S.busy
            % acts as Cancel
            S.cancel = true;
            set(status,'String','cancelling...'); drawnow;
            return
        end
        switch get(bPreset,'Value')
            case 1, set(eF,'String','1.5');  set(eG,'String','0.2');
            case 2, set(eF,'String','1.1');  set(eG,'String','0.5');
            case 3, set(eF,'String','1.0');  set(eG,'String','0.5');
            case 4, set(eF,'String','0.8');  set(eG,'String','0.5');
        end
        upd_region();
        set(status,'String','preset loaded. press COMPUTE.');
    end

    % ==================================================================
    function upd_region()
        gam = str2double(get(eG,'String'));
        Om  = str2double(get(eO,'String'));
        F   = str2double(get(eF,'String'));
        if ~isfinite(gam) || ~isfinite(Om) || Om <= 0, return; end
        Fc = fp_melnikov_threshold(gam, Om);
        ratio = F/max(Fc, eps);
        if ratio < 0.9
            verdict = 'SUBCRITICAL: expect regular motion (lambda_1 < 0)';
        elseif ratio < 1.15
            verdict = 'NEAR THRESHOLD: mixed regular and chaotic';
        elseif ratio < 2.5
            verdict = 'SUPERCRITICAL: chaotic bands, structure in the winding number';
        else
            verdict = 'STRONGLY SUPERCRITICAL: nearly all ICs chaotic; read the winding map';
        end
        set(regTxt,'String', sprintf( ...
            ['Melnikov threshold  F_c = (4\\gamma/\\pi)cosh(\\Omega\\pi/2) = %.4f     ' ...
             'F/F_c = %.2f\n%s'], Fc, ratio, verdict));
    end

    % ==================================================================
    function on_go(~,~)
        if S.busy, return; end
        S.busy = true; set_busy(true);
        c = onCleanup(@() set_busy(false)); %#ok<NASGU>
        try
            N  = cl(eN, 10, 600, 200);
            F  = cl(eF, 0.01, 50, 1.5);
            gam= cl(eG, 0, 20, 0.2);
            Om = cl(eO, 0.05, 20, 2/3);
            per= cl(eP, 20, 4000, 250);
            dt = cl(eDt, 1e-4, 0.2, 0.01);

            p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));

            % Computed row by row so progress is visible and the run can be
            % cancelled.  Same numerics as fp_map (fp_lyap_row).
            S.cancel = false;
            thv = linspace(-pi, pi, N);
            omv = linspace(-4, 4, N);
            LAM = nan(N,N); WND = nan(N,N);
            ro = struct('F',F,'gamma',gam,'Omega',Om,'dt',dt, ...
                        'periods',per,'transient',0.3,'reortho',10);

            tStart = tic;
            for i = 1:N
                if S.cancel, break; end
                [LAM(i,:), WND(i,:)] = fp_lyap_row(thv, omv(i)*ones(1,N), ro);
                if mod(i, max(1,round(N/25)))==0 || i==N
                    frac = i/N;
                    set(status,'String',sprintf( ...
                        'computing %dx%d (%d periods, dt=%.3g)  %3.0f%%   %.1f s elapsed, ~%.1f s left', ...
                        N, N, per, dt, 100*frac, toc(tStart), toc(tStart)/frac*(1-frac)));
                    drawnow;
                end
            end
            elapsed = toc(tStart);
            if S.cancel
                set(status,'String','cancelled.'); return
            end

            BASIN = zeros(N,N);
            BASIN(WND >  0.5) =  1;
            BASIN(WND < -0.5) = -1;
            Fc = fp_melnikov_threshold(gam, Om);

            M = struct('lambda',LAM, 'winding',WND, 'basin',BASIN, ...
                       'th',thv, 'om',omv, 'F',F, 'gamma',gam, 'Omega',Om, ...
                       'dt',dt, 'periods',per, 'N',N, 'elapsed',elapsed, ...
                       'MelnikovFc',Fc, 'supercritical',F/Fc);
            S.M = M;

            imagesc(ax, M.th, M.om, M.lambda); axis(ax,'xy'); axis(ax,'image');
            try, colormap(ax, turbo(256)); catch, colormap(ax, jet(256)); end
            cb = colorbar(ax); cb.Label.String = '\lambda_1';
            title(ax, sprintf(['true largest Lyapunov exponent\n' ...
                'F=%.3f \\gamma=%.3f \\Omega=%.3f   (F/F_c = %.2f)'], ...
                M.F, M.gamma, M.Omega, M.supercritical));

            imagesc(axB, M.th, M.om, M.winding); axis(axB,'xy'); axis(axB,'image');
            try, colormap(axB, turbo(256)); catch, colormap(axB, jet(256)); end
            cb = colorbar(axB); cb.Label.String = 'w';
            title(axB, sprintf('rotation-number basins\n+w: %d   -w: %d', ...
                sum(M.basin(:)>0), sum(M.basin(:)<0)));

            set(status,'String',sprintf( ...
                ['metric: largest Lyapunov exponent (variational) and winding.  ' ...
                 '%d periods, dt=%.3g, %.1f s (%.0f pts/s).  ' ...
                 'lambda in [%.5f, %.5f];  note |w| = 2 (two rotations per drive period).'], ...
                per, dt, elapsed, N^2/max(elapsed,eps), ...
                min(M.lambda(:)), max(M.lambda(:))));
        catch ME
            set(status,'String',['ERROR: ' ME.message]);
            errordlg(ME.message,'fp_lab');
        end
    end

    % ==================================================================
    function set_busy(tf)
        S.busy = tf;
        ctrls = [bGo bPreset eN eF eG eO eP eDt];
        if tf
            % Preset stays enabled while busy and doubles as CANCEL, so a long
            % accurate run can be stopped without killing MATLAB.
            set(ctrls,'Enable','off');
            set(bPreset,'Enable','on','String','CANCEL running computation');
            set(bGo,'String','Working...');
        else
            set(ctrls,'Enable','on');
            set(bGo,'String','COMPUTE');
            set(bPreset,'String', preset_strings());
        end
        drawnow;
    end

    function s = preset_strings()
        s = {'preset: supercritical rotation (F=1.5, g=0.2)', ...
             'preset: regular/chaos coexistence (F=1.1, g=0.5)', ...
             'preset: near Melnikov threshold (F=1.0, g=0.5)', ...
             'preset: subcritical regular (F=0.8, g=0.5)'};
    end
end


function v = cl(h, lo, hi, def)
    v = str2double(get(h,'String'));
    if ~isfinite(v), v = def; end
    v = min(max(v, lo), hi);
    set(h,'String', num2str(v, '%.6g'));
end
