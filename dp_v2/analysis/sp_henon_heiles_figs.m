function sp_henon_heiles_figs(varargin)
%% SP_HENON_HEILES_FIGS  Reproduce the paper's Figs. 11 and 12 for Henon-Heiles.
%%
%%   sp_henon_heiles_figs()
%%   sp_henon_heiles_figs('N',120, 'T',500)
%%
%%   Writes two figures into dp_v2/gallery/ :
%%
%%     sp_henon_fig11_eta0.png   FLI maps on the y-Y plane at E = 1/8 for four
%%                               choices of the initial variation vector --
%%                               the paper's Fig. 11(a)-(d)
%%     sp_henon_fig12_tf.png     OFLI2 maps for tf = 50, 100, 500, 1000 -- the
%%                               paper's Fig. 12
%%
%%   WHAT THE PAPER CLAIMS, AND WHAT THE FIGURES SHOW
%%   ------------------------------------------------
%%   Fig. 11: a fixed or careless eta0 manufactures spurious structure, while
%%   eta0 = grad H is the clean one.  The mechanism is that the flow-tangent
%%   component of eta0 grows only algebraically, so where eta0 happens to lie
%%   along the flow the first-order indicator reads anomalously LOW.
%%
%%   Fig. 12: at short tf the map is qualitatively wrong.  Measured against a
%%   tf = 2000 reference the rank correlation rises 0.56 -> 0.97 monotonically
%%   in tf, which is the quantitative form of the paper's warning.  See
%%   tests/test_henon_heiles.m [4] for the asserted numbers.
%%
%%   Options
%%     E   1/8    slice energy (paper uses 1/12 and 1/8)
%%     N   120    grid points per axis
%%     T   500    final time for the Fig. 11 panel
%%     dt  0.02
%%     verbose true
%%
%%   See also sp_henon_heiles_map, sp_henon_heiles_ic, test_henon_heiles.

    o = struct('E',1/8, 'N',120, 'T',500, 'dt',0.02, 'verbose',true);
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_henon_heiles_figs:opt','unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    here = fileparts(mfilename('fullpath'));
    outdir = fullfile(here,'..','gallery');
    if ~exist(outdir,'dir'), mkdir(outdir); end

    % ==================================================================
    % Fig. 11: four eta0 choices
    % ==================================================================
    if o.verbose
        fprintf('=== paper Fig. 11: FLI vs the initial variation vector ===\n');
        fprintf('    E=%g, N=%d, T=%g\n', o.E, o.N, o.T);
    end
    devs = {'fixed','bad','grad','flow'};
    lbl  = {'(a) \eta_0 = (1,1,1,1)/2   [fixed]', ...
            '(b) \eta_0 = (-f_4,-f_3,f_2,f_1)/||f||', ...
            '(c) \eta_0 = \nablaH/||\nablaH||   [good]', ...
            '(d) \eta_0 = f/||f||   [along the flow]'};
    MV = cell(1,4);
    for i = 1:4
        MV{i} = sp_henon_heiles_map('indicator','fli', 'dev0',devs{i}, ...
                 'E',o.E, 'N',o.N, 'T',o.T, 'dt',o.dt, 'verbose',false);
        v = MV{i}.values(~isnan(MV{i}.values));
        if o.verbose
            fprintf('    %-10s mean %8.4f  std %8.4f\n', devs{i}, mean(v), std(v));
        end
    end

    f = figure('Visible','off','Position',[40 40 1180 900]);
    for i = 1:4
        subplot(2,2,i);
        imagesc(MV{i}.x, MV{i}.y, MV{i}.values); axis xy image;
        colormap(turbo_safe_()); colorbar;
        xlabel('y(0)'); ylabel('Y(0)');
        title(lbl{i}, 'Interpreter','tex');
    end
    if exist('sgtitle','file')
        sgtitle(sprintf(['Henon-Heiles FLI, x(0)=0, E=%.4g, tf=%g  ' ...
                         '(paper Fig. 11): the initial variation vector matters'], ...
                        o.E, o.T));
    end
    exportgraphics(f, fullfile(outdir,'sp_henon_fig11_eta0.png'), 'Resolution',130);
    close(f);

    % ==================================================================
    % Fig. 12: four final times
    % ==================================================================
    if o.verbose
        fprintf('\n=== paper Fig. 12: OFLI2 vs final time tf ===\n');
    end
    tfs = [50 100 500 1000];
    MT = cell(1,4);
    for i = 1:4
        MT{i} = sp_henon_heiles_map('indicator','ofli2', 'E',o.E, 'N',o.N, ...
                 'T',tfs(i), 'dt',o.dt, 'verbose',false);
    end
    % rank correlation of each panel against the longest, to label the panels
    Vref = MT{end}.values;  base = ~isnan(Vref);
    rs = zeros(1,4);
    for i = 1:4
        V = MT{i}.values;  ok = base & ~isnan(V);
        rs(i) = corr(V(ok), Vref(ok), 'type','Spearman');
    end
    if o.verbose
        fprintf('    rank corr vs tf=1000: %s\n', mat2str(rs, 4));
    end

    f = figure('Visible','off','Position',[40 40 1180 900]);
    for i = 1:4
        subplot(2,2,i);
        imagesc(MT{i}.x, MT{i}.y, MT{i}.values); axis xy image;
        colormap(turbo_safe_()); colorbar;
        xlabel('y(0)'); ylabel('Y(0)');
        title(sprintf('tf = %d   (rank corr vs tf=1000: %.2f)', tfs(i), rs(i)));
    end
    if exist('sgtitle','file')
        sgtitle(sprintf(['Henon-Heiles OFLI2, x(0)=0, E=%.4g  (paper Fig. 12): ' ...
                         'a too-short tf gives the wrong picture'], o.E));
    end
    exportgraphics(f, fullfile(outdir,'sp_henon_fig12_tf.png'), 'Resolution',130);
    close(f);

    if o.verbose
        fprintf('\nfigures written to %s\n', outdir);
    end
end


function cmap = turbo_safe_()
    try
        cmap = turbo(256);
    catch
        cmap = jet(256);
    end
end
