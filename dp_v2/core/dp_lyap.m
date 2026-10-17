function varargout = dp_lyap(y0, T, dt, p, opts)
%% DP_LYAP  Largest Lyapunov exponent of the double pendulum, plus diagnostics.
%%
%%   [lam, info] = dp_lyap(y0, T, dt, p)
%%   [lam, info] = dp_lyap(y0, T, dt, p, opts)
%%
%%   y0   - initial state 4x1 = [th1; om1; th2; om2]
%%   T    - total integration time (physical units)
%%   dt   - fixed RK4 step
%%   p    - struct with m1, m2, L1, L2, g
%%
%%   opts fields (all optional):
%%     transient    - time discarded before averaging            (default 0.3*T)
%%     reortho      - steps between Gram-Schmidt reorthonormalisations (default 10)
%%     method       - 'tangent' (variational, default) or 'shadow' (two-trajectory)
%%     d0           - initial separation for 'shadow'            (default 1e-10)
%%     nExponents   - 1..4, full spectrum when >1                (default 1)
%%     progress     - print progress                             (default false)
%%
%%   lam  - nExponents x 1, descending (lam(1) is the largest)
%%   info - struct: nSteps, nSamples, tTransient, energyDrift, method
%%
%%   METHOD NOTES
%%   -------------
%%   'tangent' integrates the variational equation with the machine-generated
%%   analytic Jacobian, using a QR factorisation at each reortho interval to
%%   keep the tangent basis well conditioned.  This is the Benettin algorithm
%%   and is what we use by default: it converges fast and gives the full
%%   spectrum when asked.
%%
%%   'shadow' integrates two nearby trajectories and renormalises their
%%   difference.  It needs no Jacobian and no tangent machinery, so it is a
%%   genuinely independent check on 'tangent'.  It is more sensitive to the
%%   renormalisation interval and converges more slowly, but agreement between
%%   the two is strong evidence that either is right.
%%
%%   Both were validated against analytically known cases before being trusted;
%%   see dp_v2/tests/test_lyapunov.m.

    if nargin < 5, opts = struct(); end
    opts = fill_defaults(opts, T);

    nSteps   = round(T / dt);
    nTrans   = round(opts.transient / dt);
    nTotal   = nSteps;

    p = dp_check_params(p);

    switch lower(opts.method)
        case 'tangent'
            [lam, info] = run_tangent(y0, dt, nTotal, nTrans, p, opts);
        case 'shadow'
            [lam, info] = run_shadow(y0, dt, nTotal, nTrans, p, opts);
        otherwise
            error('dp_lyap:method', 'unknown method "%s"', opts.method);
    end

    varargout{1} = lam;
    if nargout > 1, varargout{2} = info; end
end


% =========================================================================
function [lam, info] = run_tangent(y0, dt, nTotal, nTrans, p, opts)
    n = opts.nExponents;
    y = y0(:);
    Q = eye(4, 4);
    Q = Q(:, 1:n);                      % 4 x n orthonormal tangent basis

    acc = zeros(n, 1);
    nSamp = 0;
    k = 0;
    E0 = dp_energy(y, p);
    maxDrift = 0;

    for step = 1:nTotal
        % --- propagate state and tangent together ---
        [y, Q] = dp_rk4_step(y, dt, p, Q);

        % --- reorthonormalise ---
        if mod(step, opts.reortho) == 0
            [Q, R] = qr(Q, 0);
            % fix signs so the diagonal of R stays positive (keeps logs sane)
            s = sign(diag(R));  s(s == 0) = 1;
            Q = Q * diag(s);
            R = diag(s) * R;
            if step > nTrans
                acc = acc + log(abs(diag(R)));
                nSamp = nSamp + 1;
            end
        end

        if opts.progress && mod(step, max(1, round(nTotal/10))) == 0
            fprintf('   dp_lyap: %3.0f%%\n', 100*step/nTotal);
        end
        if mod(step, max(1, round(nTotal/50))) == 0
            maxDrift = max(maxDrift, abs(dp_energy(y, p) - E0));
        end
        k = step;
    end

    if nSamp == 0
        error('dp_lyap:transient', ...
              'transient (%g s) consumes the whole run (%g s)', ...
              opts.transient, nTotal*dt);
    end

    lam = acc / (nSamp * opts.reortho * dt);
    lam = sort(lam, 'descend');

    info = struct('nSteps', k, 'nSamples', nSamp, 'tTransient', nTrans*dt, ...
                  'tTotal', k*dt, 'reortho', opts.reortho, ...
                  'energyDrift', maxDrift, 'method', 'tangent');
end


% =========================================================================
function [lam, info] = run_shadow(y0, dt, nTotal, nTrans, p, opts)
    d0 = opts.d0;
    y  = y0(:);
    % perturb along th1; any generic direction works
    v  = zeros(4, 1);  v(1) = d0;

    yRef = y;
    yPert = y + v;

    acc = 0; nSamp = 0;
    E0 = dp_energy(yRef, p);
    maxDrift = 0;

    for step = 1:nTotal
        yRef  = dp_rk4_step(yRef,  dt, p);
        yPert = dp_rk4_step(yPert, dt, p);

        d = yPert - yRef;
        nr = norm(d);
        if nr > 0
            if step > nTrans
                acc = acc + log(nr / d0);
                nSamp = nSamp + 1;
            end
            yPert = yRef + d * (d0 / nr);
        end

        if opts.progress && mod(step, max(1, round(nTotal/10))) == 0
            fprintf('   dp_lyap(shadow): %3.0f%%\n', 100*step/nTotal);
        end
        if mod(step, max(1, round(nTotal/50))) == 0
            maxDrift = max(maxDrift, abs(dp_energy(yRef, p) - E0));
        end
    end

    lam = acc / (nSamp * dt);
    info = struct('nSteps', nTotal, 'nSamples', nSamp, ...
                  'tTransient', nTrans*dt, 'tTotal', nTotal*dt, ...
                  'd0', d0, 'energyDrift', maxDrift, 'method', 'shadow');
end


% =========================================================================
function opts = fill_defaults(opts, T)
    def = struct('transient', 0.3*T, 'reortho', 10, 'method', 'tangent', ...
                 'd0', 1e-10, 'nExponents', 1, 'progress', false);
    f = fieldnames(def);
    for i = 1:numel(f)
        if ~isfield(opts, f{i}) || isempty(opts.(f{i}))
            opts.(f{i}) = def.(f{i});
        end
    end
    if opts.nExponents < 1 || opts.nExponents > 4
        error('dp_lyap:nExponents', 'nExponents must be in 1..4');
    end
end


% =========================================================================
function E = dp_energy(y, p)
    th1 = y(1); om1 = y(2); th2 = y(3); om2 = y(4);
    v1sq = p.L1^2 * om1^2;
    v2sq = v1sq + p.L2^2 * om2^2 + 2*p.L1*p.L2*om1*om2*cos(th2 - th1);
    KE = 0.5*p.m1*v1sq + 0.5*p.m2*v2sq;
    PE = -p.m1*p.g*p.L1*cos(th1) - p.m2*p.g*(p.L1*cos(th1) + p.L2*cos(th2));
    E = KE + PE;
end
