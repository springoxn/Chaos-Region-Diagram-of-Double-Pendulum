function sp_energy_study(varargin)
%% SP_ENERGY_STUDY  Evidence for the symplectic integrator: bounded energy
%%                  oscillation versus secular drift, and what that costs.
%%
%%   sp_energy_study()
%%   sp_energy_study('system','double', 'T',2000)
%%
%%   Produces a figure and prints the numbers that justify replacing RK4 with a
%%   symplectic method for long integrations.  The decisive quantity is NOT the
%%   size of the energy error -- a good RK4 step can be more accurate than a
%%   second-order symplectic step at the same h -- it is the error's BEHAVIOUR IN
%%   TIME.  A symplectic method keeps H on a bounded band whose width scales like
%%   h^order; a non-symplectic one drifts, so its error keeps growing with the
%%   integration length no matter how small h is.
%%
%%   WHAT IS PLOTTED
%%   ---------------
%%   Left:   |H(t) - H(0)| against t for RK4 and for Yoshida 2/4/6.
%%   Right:  the max |dH| over the first half versus the second half, i.e. the
%%           drift ratio.  A bounded oscillation gives ~1; drift gives more.
%%
%%   WHICH SYSTEM
%%   ------------
%%     'coupled'  the paper's autonomous two-degree-of-freedom pendulum: the
%%                honest test, because its H is genuinely conserved.
%%     'double'   the double pendulum, whose H is conserved but whose Hamiltonian
%%                is NOT separable, so this uses the implicit stepper against
%%                RK4.  This is the case the project's README documents as
%%                "dt = 0.05 gives 16% energy drift at t = 10 s".
%%     'pendulum' a single conservative pendulum (F = 0, gamma = 0).
%%
%%   A DELIBERATE OMISSION
%%   ---------------------
%%   The FORCED pendulum (F > 0) is not offered here.  Its Hamiltonian
%%   H = p^2/2 - cos q - F q cos(Omega t) contains a term linear in q, so along a
%%   circulating orbit H grows without bound.  That is correct physics, not an
%%   integrator defect, and it makes H useless as a conservation check; a first
%%   draft of this project's scratch test read the resulting 1e3 "drift" as a
%%   failure.  Symplecticity is the right check for that system, and
%%   test_symplectic.m performs it.
%%
%%   See also sp_step, dp_imp_step, dp_hamiltonian, test_symplectic, test_implicit.

    o = struct('system','coupled', 'T',2000, 'dt',0.02, 'fig',true, ...
               'outdir',fullfile(fileparts(mfilename('fullpath')),'..','gallery'));
    if nargin == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for i = 1:numel(f), o.(f{i}) = varargin{1}.(f{i}); end
    else
        for i = 1:2:numel(varargin)
            if ~isfield(o, varargin{i})
                error('sp_energy_study:opt','unknown option "%s"', varargin{i});
            end
            o.(varargin{i}) = varargin{i+1};
        end
    end

    fprintf('=== symplectic vs RK4: energy behaviour ===\n');
    fprintf('system = %s,  T = %g,  dt = %g\n\n', o.system, o.T, o.dt);

    switch lower(o.system)
        case 'coupled'
            sys = sp_sys('coupled','a',4,'b',1);
            y0 = [1.0; 0.5; 0.0; 0.0];
            E0 = sys.energy(y0, 0);
            methods = {'Yoshida2','Yoshida4','Yoshida6','RK4'};
            [curves, stats] = run_all(sys, y0, o.T, o.dt, E0, sys.energy, false);
        case 'pendulum'
            sys = sp_sys('pendulum','F',0,'gamma',0,'Omega',2/3);
            y0 = [0.5; 0.0];
            E0 = sys.energy(y0, 0);
            methods = {'Yoshida2','Yoshida4','Yoshida6','RK4'};
            [curves, stats] = run_all(sys, y0, o.T, o.dt, E0, sys.energy, false);
        case 'double'
            p = struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81);
            y0 = [2.5; 0; 2.5; 0];
            E0 = dp_hamiltonian(y0, p);
            methods = {'midpoint (order 2)','Gauss (order 4)','RK4'};
            [curves, stats] = run_double(y0, o.T, o.dt, E0, p);
        otherwise
            error('sp_energy_study:system','unknown system "%s"', o.system);
    end

    fprintf('%-22s %14s %14s %10s\n', 'method', 'max|dE| 1st half', 'max|dE| 2nd half', 'ratio');
    for i = 1:numel(methods)
        s = stats(i);
        fprintf('%-22s %14.3e %14.3e %10.2f\n', methods{i}, s.h1, s.h2, s.h2/max(s.h1,realmin));
    end
    fprintf('\nRelative to |E0| = %.6g\n', abs(E0));
    fprintf(['A symplectic method gives ratio ~ 1 (bounded band); a non-symplectic one\n' ...
             'gives ratio > 1 and growing with T.  That is the property that matters,\n' ...
             'not the absolute size of the error.\n']);

    if o.fig
        f = figure('Visible','off','Position',[100 100 1100 460]);
        subplot(1,2,1);
        hold on;
        for i = 1:numel(methods)
            plot(curves(i).t, abs(curves(i).dE)/abs(E0), 'LineWidth', 1.1);
        end
        hold off; grid on; set(gca,'YScale','log');
        xlabel('t'); ylabel('|H(t) - H(0)| / |H(0)|');
        title('energy error in time');
        legend(methods, 'Location','best');

        subplot(1,2,2);
        r = zeros(1,numel(methods));
        for i = 1:numel(methods)
            r(i) = stats(i).h2/max(stats(i).h1,realmin);
        end
        bar(r); grid on;
        set(gca,'XTickLabel',methods,'XTick',1:numel(methods));
        ylabel('max|dE| in 2nd half / max|dE| in 1st half');
        title('drift ratio (1 = bounded)');
        if exist('sgtitle','file'), sgtitle(sprintf('symplectic vs RK4, %s, T=%g, dt=%g', ...
                o.system, o.T, o.dt)); end

        if ~exist(o.outdir,'dir'), mkdir(o.outdir); end
        fn = fullfile(o.outdir, sprintf('sp_energy_%s.png', o.system));
        exportgraphics(f, fn, 'Resolution', 140);
        close(f);
        fprintf('\nfigure written to %s\n', fn);
    end
end


% =========================================================================
function [curves, stats] = run_all(sys, y0, T, dt, E0, efun, ~)
    n = round(T/dt);
    orders = [2 4 6];
    curves = struct('t',{},'dE',{});
    stats  = struct('h1',{},'h2',{});
    for k = 1:3
        [tt, dE, h1, h2] = walk_sp(sys, y0, n, dt, orders(k), E0, efun);
        curves(k) = struct('t',tt,'dE',dE);
        stats(k)  = struct('h1',h1,'h2',h2);
    end
    [tt, dE, h1, h2] = walk_rk4_pend(sys, y0, n, dt, E0, efun);
    curves(4) = struct('t',tt,'dE',dE);
    stats(4)  = struct('h1',h1,'h2',h2);
end


function [tt, dE, h1, h2] = walk_sp(sys, y0, n, dt, order, E0, efun)
    y = y0; t = 0;
    tt = zeros(1,n); dE = zeros(1,n);
    half = floor(n/2); h1 = 0; h2 = 0;
    for k = 1:n
        [y, ~, ~, t] = sp_step(y, [], t, dt, sys, order);
        e = abs(efun(y,t) - E0);
        tt(k) = t; dE(k) = e;
        if k <= half, h1 = max(h1,e); else, h2 = max(h2,e); end
    end
end


function [tt, dE, h1, h2] = walk_rk4_pend(sys, y0, n, dt, E0, efun)
%% Classical RK4 for a separable system of ANY dimension, so that the 1-dof
%% pendulum and the 2-dof coupled pendulum share one implementation.
%%
%%   The state is [q ; p] with unit mass, so the field is [p ; force(q,t)].  A
%%   first version of this helper hard-coded a 2-component state and indexing
%%   yy(2) as the momentum, which is correct only for nq = 1 and fails with a
%%   dimension error on the coupled pendulum.
    nq = sys.nq;
    y = y0; t = 0;
    tt = zeros(1,n); dE = zeros(1,n);
    half = floor(n/2); h1 = 0; h2 = 0;
    for k = 1:n
        k1 = sep_field(y, sys, t);
        k2 = sep_field(y + dt/2*k1, sys, t+dt/2);
        k3 = sep_field(y + dt/2*k2, sys, t+dt/2);
        k4 = sep_field(y + dt*k3,   sys, t+dt);
        y = y + dt/6*(k1 + 2*k2 + 2*k3 + k4);
        t = t + dt;
        e = abs(efun(y,t) - E0);
        tt(k) = t; dE(k) = e;
        if k <= half, h1 = max(h1,e); else, h2 = max(h2,e); end
    end
    if nq == 0, error('unreachable'); end
end


function dy = sep_field(y, sys, t)
%% dy = [q' ; p'] = [p ; force(q,t)] for a unit-mass separable system.
    nq = sys.nq;
    dy = [y(nq+1:end); sys.force(y(1:nq), t)];
end


function [curves, stats] = run_double(y0, T, dt, E0, p)
    n = round(T/dt);
    curves = struct('t',{},'dE',{});  stats = struct('h1',{},'h2',{});
    for k = 1:2
        order = 2*(k);            % 2 then 4
        y = y0; t = 0;
        tt = zeros(1,n); dE = zeros(1,n);
        half = floor(n/2); h1 = 0; h2 = 0;
        for m = 1:n
            [y, ~, ~, t] = dp_imp_step(y, [], t, dt, p, order);
            e = abs(dp_hamiltonian(y,p) - E0);
            tt(m) = t; dE(m) = e;
            if m <= half, h1 = max(h1,e); else, h2 = max(h2,e); end
        end
        curves(k) = struct('t',tt,'dE',dE);
        stats(k)  = struct('h1',h1,'h2',h2);
    end
    % RK4 with the same vector field
    y = y0; t = 0;
    tt = zeros(1,n); dE = zeros(1,n);
    half = floor(n/2); h1 = 0; h2 = 0;
    dt2 = 0.5*dt; dt6 = dt/6;
    for m = 1:n
        k1 = dp_field_dyn(y,p);
        k2 = dp_field_dyn(y + dt2*k1, p);
        k3 = dp_field_dyn(y + dt2*k2, p);
        k4 = dp_field_dyn(y + dt*k3, p);
        y = y + dt6*(k1+2*k2+2*k3+k4); t = t + dt;
        e = abs(dp_hamiltonian(y,p) - E0);
        tt(m) = t; dE(m) = e;
        if m <= half, h1 = max(h1,e); else, h2 = max(h2,e); end
    end
    curves(3) = struct('t',tt,'dE',dE);
    stats(3)  = struct('h1',h1,'h2',h2);
end
