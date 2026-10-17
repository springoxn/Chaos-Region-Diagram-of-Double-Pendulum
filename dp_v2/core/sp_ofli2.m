function [ofli2, info] = sp_ofli2(sys, Y0, opts)
%% SP_OFLI2  Orthogonal Fast Lyapunov Indicator of second order (OFLI2_TT).
%%
%%   [ofli2, info] = sp_ofli2(sys, Y0, opts)
%%
%%   sys  struct from sp_sys: a SEPARABLE Hamiltonian, unit mass
%%   Y0   ndof x N initial conditions [q ; p]
%%   opts
%%     T       100      integration time
%%     dt      0.01     step
%%     order   4        Yoshida order for the reference trajectory
%%
%%   ofli2  1 x N  OFLI2 at the final time
%%
%%   DEFINITION (Barrio, Chaos Solitons Fractals 25 (2005) 711; and Eq. (8) of
%%   Barrio, Borczyk & Breiter, Chaos Solitons Fractals 40 (2009) 1697)
%%
%%       OFLI2(tf) = sup_{0<t<tf} ln || n(t) + (1/2) dn(t) ||_perp
%%
%%   where n is the first-order variation, dn the second-order one, and the
%%   subscript denotes the component ORTHOGONAL to the flow.
%%
%%   The normalised initial conditions are part of the definition and are the
%%   reason this indicator is robust:
%%
%%       n(0)  = f(0,q0) / ||f(0,q0)||        (along the flow)
%%       dn(0) = 0
%%
%%   BUT the orthogonality projection is applied to  n + dn/2  as a whole, and
%%   the paper's Fig. 11 shows the projection is what makes the difference:
%%   their "bad" FLI map used a fixed initial vector, and only the choices
%%   orthogonal to the flow (or the natural n(0) = f/||f|| here) avoided the
%%   spurious structures.
%%
%%   WHY IT IS INCLUDED
%%   ------------------
%%   Sec. 4.2.1 of the reference paper argues that methods built on FIRST-order
%%   variational equations (MEGNO, FLI) are the ones that generate spurious
%%   direction-dependent patterns, and that methods using second- or higher-order
%%   variations (OFLI2) and higher-order alignment indices (GALI) do not.  OFLI2
%%   is therefore the paper's recommended variational counterpart to GALI, and
%%   reproducing their Fig. 6 (spurious) against Fig. 4 / 11d (clean) is part of
%%   this project's validation.  See tests/test_paper_figures.m.
%%
%%   THE SECOND-ORDER VARIATIONAL EQUATION
%%   -------------------------------------
%%   For q' = f(q) the second variation obeys
%%
%%       dn'_j = sum_k (df_j/dq_k) dn_k + sum_{k,l} n_k (d2f_j/dq_k dq_l) n_l .
%%
%%   Only the second term needs anything beyond the Jacobian.  For the systems
%%   used here f = [p ; -grad V(q)] with unit mass, so f is LINEAR in p and the
%%   only nonzero second derivatives are
%%
%%       d2 f_p / dq_k dq_l = -d2V/dq_k dq_l   (the Hessian, already available)
%%
%%   Consequently the second-order term for the momentum block is
%%   -hess V(n_q, n_q) and is IDENTICAL in form to the first-order term.  This
%%   is why sp_sys already carries `dforce` (the Hessian) and no extra third
%%   derivatives are needed -- for a unit-mass separable system the second
%%   variation has exactly the same structure as the first.  That is a real
%%   simplification, and it does NOT extend to the double pendulum, whose
%%   equations are nonlinear in the velocities: OFLI2 is therefore provided for
%%   the forced and coupled pendulums and deliberately NOT for the double
%%   pendulum (which uses 4-dimensional GALI instead).
%%
%%   The augmented state (q, p, n, dn) is evolved with the same Yoshida
%%   composition as the trajectory, by adding the variational parts to the
%%   force evaluation.  The deviation vector n is NOT renormalised: OFLI2 is a
%%   sup over the raw norm, so rescaling would change the indicator.  This is
%%   the opposite convention to sp_step.m's renormalisation and is why OFLI2
%%   has its own driver instead of reusing sp_run.m.
%%
%%   See also sp_run, sp_gali, sp_sys, test_paper_figures.

    if nargin < 3, opts = struct(); end
    o = struct('T',100, 'dt',0.01, 'order',4);
    if isstruct(opts)
        f = fieldnames(opts);
        for i = 1:numel(f), o.(f{i}) = opts.(f{i}); end
    else
        for i = 1:2:numel(opts)
            if ~isfield(o, opts{i}), error('sp_ofli2:opt','unknown option "%s"',opts{i}); end
            o.(opts{i}) = opts{i+1};
        end
    end

    nq = sys.nq;
    ndof = sys.ndof;
    if size(Y0,1) ~= ndof
        error('sp_ofli2:size', 'Y0 must be %d x N', ndof);
    end
    N = size(Y0,2);
    nSteps = round(o.T / o.dt);

    % ---- normalised initial variations and zero second variations ----
    [~, f0] = field_parts(Y0, sys, 0);
    Nmat = zeros(ndof, N);
    Dmat = zeros(ndof, N);
    for c = 1:N
        nrm = norm(f0(:,c));
        if nrm > 0
            Nmat(:,c) = f0(:,c)/nrm;
        end
    end

    ofli2 = -inf(1, N);
    t = 0;
    for step = 1:nSteps
        [Y0, Nmat, Dmat, t] = aug_step(Y0, Nmat, Dmat, t, o.dt, sys, o.order);

        % ---- orthogonality projection and the sup over the run ----
        [fq, ~] = field_parts(Y0, sys, t);
        for c = 1:N
            comb = Nmat(:,c) + 0.5*Dmat(:,c);
            fc = fq(:,c);
            nf = norm(fc);
            if nf > 0
                comb = comb - (comb'*fc/nf^2)*fc;      % remove the flow direction
            end
            v = norm(comb);
            if v > 0
                lv = log(v);
                if lv > ofli2(c), ofli2(c) = lv; end
            end
        end
    end

    info = struct('T', o.T, 'dt', o.dt, 'order', o.order, 'nSteps', nSteps, ...
                  'sys', sys.name);
end


% =========================================================================
function [Y, Nm, Dm, t] = aug_step(Y, Nm, Dm, t, h, sys, order)
%% AUG_STEP  One Yoshida step of the augmented (q,p,n,dn) system.
%
%%   The drift and kick of the TRAJECTORY are as in sp_step.m.  The variations
%%   ride along: the drift advances q and n_q, the kick advances p, n_p and dn_p.
%%
%%   Second-variation term: for f = [p ; -grad V] with unit mass the only
%%   nonzero second derivative is d2f_p/dq dq = -hess V, so the dn_p update gets
%%   the extra term  c*h * ( -hess V(n_q, n_q) )  -- the same Hessian already
%%   used by the first variation, evaluated on the FIRST variation's q-block.
    w = sp_weights(order);
    m = numel(w);
    nq = sys.nq;

    [Y, Nm, Dm] = half_kick(Y, Nm, Dm, t, (w(1)/2)*h, sys);
    for i = 1:m
        c = w(i);
        Y(1:nq,:)      = Y(1:nq,:)      + (c*h)*Y(nq+1:end,:);
        Nm(1:nq,:)     = Nm(1:nq,:)     + (c*h)*Nm(nq+1:end,:);
        Dm(1:nq,:)     = Dm(1:nq,:)     + (c*h)*Dm(nq+1:end,:);
        t = t + c*h;
        if i < m
            ck = (w(i)+w(i+1))/2;
        else
            ck = w(m)/2;
        end
        [Y, Nm, Dm] = half_kick(Y, Nm, Dm, t, ck*h, sys);
    end
end


function [Y, Nm, Dm] = half_kick(Y, Nm, Dm, t, c, sys)
%% HALF_KICK  The kick sub-step for the trajectory and both variations.
%%
%%   Trajectory:  p <- p + c f(q,t)
%%   First variation:  n_p <- n_p + c J(q) n_q
%%   Second variation: dn_p <- dn_p + c [ J(q) dn_q + Q(q; n_q, n_q) ]
%%
%%   where Q_j = sum_{k,l} n_k n_l * d2 f_j/dq_k dq_l is the QUADRATIC form in
%%   the first variation built from the field's second derivative.  Writing the
%%   second-order term as J*n (as a first draft of this file did) is wrong: the
%%   second-order term is order n^2, not order n, and using J*n conflates it with
%%   the first-order piece.
    nq = sys.nq;
    q = Y(1:nq,:);
    F = sys.force(q, t);
    Y(nq+1:end,:) = Y(nq+1:end,:) + c*F;

    J = sys.dforce(q, t);                    % nq x nq x N

    % first variation
    Nm(nq+1:end,:) = Nm(nq+1:end,:) + c*pmul(J, Nm(1:nq,:));

    % second variation: quadratic form from d2force (only for the momentum rows,
    % since f is linear in p so d2f has no p derivatives)
    Qf = zeros(nq, size(Y,2));
    if isfield(sys, 'd2force') && ~isempty(sys.d2force)
        H2 = sys.d2force(q, t);              % nq x nq x nq x N
        nqvec = Nm(1:nq,:);
        for j = 1:nq
            acc = zeros(1, size(Y,2));
            for k = 1:nq
                for l = 1:nq
                    acc = acc + reshape(H2(j,k,l,:), 1, []) .* nqvec(k,:) .* nqvec(l,:);
                end
            end
            Qf(j,:) = acc;
        end
    else
        error('sp_ofli2:d2force', ...
              'system "%s" does not supply d2force, required by OFLI2', sys.name);
    end
    Dm(nq+1:end,:) = Dm(nq+1:end,:) + c*( pmul(J, Dm(1:nq,:)) + Qf );
end


function P = pmul(A, X)
%% A is nq x nq x N, X is nq x N; returns A*X pagewise.
%
%   The result is reshaped to nq x N explicitly.  A(a,b,:) .* X(b,:) can come
%   back as nq x 1 x N depending on the release, and the subsequent assignment
%   then broadcasts against an (nq x N) left-hand side.  Forcing the shape
%   avoids a failure that only appears when N and nq differ.
    [nq, ~, N] = size(A);
    P = zeros(nq, N);
    for a = 1:nq
        for b = 1:nq
            P(a,:) = P(a,:) + reshape(A(a,b,:), 1, []) .* X(b,:);
        end
    end
end


function [F, Fq] = field_parts(Y, sys, t)
%% FIELD_PARTS  The full vector field, and specifically the part needed to
%%              define the flow direction for the orthogonal projection.
%
%%   The flow direction at a point is  (q', p') = (p, force(q,t)) .  A first
%%   version of this helper returned only the momentum block, which made the
%%   projection remove the wrong direction and left OFLI2 measuring the full
%%   norm rather than the orthogonal one.
    nq = sys.nq;
    F = [Y(nq+1:end,:); sys.force(Y(1:nq,:), t)];
    Fq = F;
end
