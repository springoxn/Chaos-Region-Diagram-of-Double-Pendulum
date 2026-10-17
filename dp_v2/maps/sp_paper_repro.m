function [M, p] = sp_paper_repro(varargin)
%% SP_PAPER_REPRO  Reproduce the spurious structures of Barrio, Borczyk &
%%                 Breiter (2009), "Spurious structures in chaos indicators
%%                 maps", Chaos Solitons Fractals 40 (2009) 1697.
%%
%%   M = sp_paper_repro()
%%   M = sp_paper_repro('N',300, 'T',500, 'dev0',[1 1], 'indicator','megno')
%%
%%   THE CASE REPRODUCED
%%   -------------------
%%   Section 4 of the paper: the PLANAR case y = Y = 0 of their coupled
%%   pendulum, Eq. (18), where the system reduces to the classical pendulum
%%
%%       x'' = -sin x                (their Eq. 21)
%%
%%   This is INTEGRABLE -- every orbit is periodic -- so any structure seen in a
%%   chaos indicator map here is spurious by construction.  That is the whole
%%   point of the test: the ground truth is known analytically, so the map can be
%%   graded rather than merely inspected.
%%
%%   WHAT THE PAPER PREDICTS
%%   -----------------------
%%   With a first-order variational method (FLI, MEGNO) and a FIXED initial
%%   deviation vector eta0 = (dx0, dX0), the indicator is anomalously LOW on the
%%   curve where eta0 happens to be TANGENT to the flow.  Tangency is
%
%%       X0 * dX0 = -sin(x0) * dx0      =>      X0 = -(dx0/dX0) sin(x0)
%%                                           = -sin(x0)   for eta0 = (1,1)
%%
%%   which is their Fig. 7a: a sine curve overlaid on the spurious band of
%%   Fig. 6b.  The mechanism is their Sec. 4.2.1: where the initial vector is
%%   tangent to the flow, the variation grows only linearly (a zero Lyapunov
%%   exponent direction) instead of the algebraic growth a regular orbit
%%   normally shows, so the indicator reads "hyperstable".
%%
%%   WHY OFLI2 AND THE GRADIENT VECTOR DO NOT SHOW IT
%%   ------------------------------------------------
%%   OFLI2 evolves SECOND-order variations with n(0) = f/||f|| and projects the
%%   combination orthogonal to the flow, so the tangent component is removed by
%%   construction rather than by a lucky choice of eta0.  Using
%%   eta0 = grad H/||grad H|| avoids the tangent direction too, which is why the
%%   paper's Fig. 9 and Fig. 11c are clean.
%%
%%   Options
%%     N       200      grid points per axis
%%     xRange  [-pi pi]
%%     XRange  [-3 3]
%%     T       500      integration time (paper uses tf = 500)
%%     dt      0.02
%%     dev0    [1 1]    initial deviation vector for the first-order indicators
%%     indicator 'fli' | 'megno' | 'ofli2'
%%     order   4        Yoshida order
%%
%%   M fields
%%     values, x, X, indicator, dev0, T, dt, predictedCurve, N, elapsed
%%
%%   See also sp_run, sp_ofli2, test_paper_figures, sp_fig_spurious.

    o = struct('N',200, 'xRange',[-pi pi], 'XRange',[-3 3], 'T',500, ...
               'dt',0.02, 'dev0',[1 1], 'indicator','fli', 'order',4, ...
               'progress',true);
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_paper_repro:opt', 'unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    xv = linspace(o.xRange(1), o.xRange(2), o.N);
    Xv = linspace(o.XRange(1), o.XRange(2), o.N);

    % The planar pendulum as a separable system: H = X^2/2 - cos x.
    sys = sp_sys('pendulum', 'F', 0, 'gamma', 0, 'Omega', 2/3);

    V = nan(o.N, o.N);
    t0 = tic;
    for i = 1:o.N
        Yrow = [xv; Xv(i)*ones(1,o.N)];
        switch lower(o.indicator)
            case 'fli'
                R = sp_run_dev0(sys, Yrow, o.T, o.dt, o.order, o.dev0, false);
                V(i,:) = R.fli;
            case 'megno'
                R = sp_run_dev0(sys, Yrow, o.T, o.dt, o.order, o.dev0, true);
                V(i,:) = R.mega;
            case 'ofli2'
                V(i,:) = sp_ofli2(sys, Yrow, struct('T',o.T,'dt',o.dt,'order',o.order));
            otherwise
                error('sp_paper_repro:ind', 'unknown indicator "%s"', o.indicator);
        end
        if o.progress && mod(i, max(1,round(o.N/10))) == 0
            fprintf('    %s: %3.0f%%  (%.1f s)\n', o.indicator, 100*i/o.N, toc(t0));
        end
    end
    elapsed = toc(t0);

    % The paper's Fig. 7a prediction: where eta0 is tangent to the flow.
    Xpred = -(o.dev0(1)/o.dev0(2)) * sin(xv);

    M = struct('values', V, 'x', xv, 'X', Xv, 'indicator', o.indicator, ...
               'dev0', o.dev0, 'T', o.T, 'dt', o.dt, 'order', o.order, ...
               'predictedCurve', Xpred, 'N', o.N, 'elapsed', elapsed, ...
               'sys', sys.name);
    p = o;
end


% =========================================================================
function R = sp_run_dev0(sys, Y0, T, dt, order, dev0, wantMegno)
%% SP_RUN_DEV0  FLI (and optionally MEGNO) with a CALLER-SUPPLIED initial
%%              deviation vector.
%%
%%   sp_run.m always starts from the standard basis, which is what the GALI
%%   literature uses.  Reproducing the paper's spurious structures requires the
%%   freedom to choose eta0, because the artefact is a function of that choice:
%%   their Fig. 7b shows a DIFFERENT spurious curve for each eta0.
%%
%%   This driver is deliberately separate from sp_run.m so that the mainstream
%%   path has no option that could be misused: the artefact being reproduced is
%%   exactly what happens when eta0 is chosen carelessly.
    N = size(Y0,2);
    ndof = sys.ndof;
    nSteps = round(T/dt);

    if numel(dev0) ~= ndof
        error('sp_run_dev0:dev0', ...
              'dev0 must have %d components for this system (got %d)', ndof, numel(dev0));
    end

    y = Y0;
    q = zeros(ndof, 1, N);            % explicit 3-D: one vector per grid point
    for c = 1:N
        q(:,1,c) = dev0(:);
    end

    acc = zeros(1,N); nAcc = 0;
    lSum = zeros(1,N);
    fli = -inf(1,N);
    Ysum = zeros(1,N); nMeg = 0; Ymeg = zeros(1,N);

    t = 0;
    for step = 1:nSteps
        [y, q, g, t] = sp_step(y, q, t, dt, sys, order);
        lSum = lSum + log(g(1,:));
        fli = max(fli, lSum);
        if wantMegno
            nMeg = nMeg + 1;
            Ysum = Ysum + nMeg*log(g(1,:));
            Ymeg = 2*Ysum/nMeg;
        end
        acc = acc + log(g(1,:)); nAcc = nAcc + 1;
    end

    R = struct();
    R.fli = fli;
    R.mega = Ymeg;
    R.lambda = acc/(nAcc*dt);
    R.dev0 = dev0;
end
