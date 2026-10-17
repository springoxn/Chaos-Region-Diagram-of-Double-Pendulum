function [y, V, g, t] = sp_step(y, V, t, h, sys, order, renorm)
%% SP_STEP  One explicit symplectic step of a separable Hamiltonian,
%%          propagating the trajectory AND the deviation vectors.
%%
%%   [y, V, g, t] = sp_step(y, V, t, h, sys, order, renorm)
%%
%%   y    ndof x N   state, laid out as [q ; p]  (nq = ndof/2)
%%   V    ndof x k x N  deviation vectors (pass [] to skip the tangent)
%%   t    scalar     current time (the drive phase lives here)
%%   h    scalar     step
%%   sys  struct from sp_sys
%%   order 2 | 4 | 6, the Yoshida composition order
%%   renorm  (optional, default true) rescale each deviation vector to unit
%%           norm after the step.  Set FALSE to propagate the tangent exactly
%%           linearly -- required for the symplecticity check Phi' J Phi = J,
%%           which rescaling would destroy.  Every chaos indicator computed
%%           from these vectors (Lyapunov, MEGNO, FLI, GALI) is homogeneous of
%%           degree zero in them and is unaffected by the choice.
%%
%%   RETURNS, with V nonempty:
%%     V  the k deviation vectors after one step: rescaled to unit norm when
%%        renorm is true, otherwise their exact linear image (NOT orthogonalised
%%        -- see below)
%%     g  k x N the growth of each vector over this step (its norm before
%%        rescaling).  Raw material for the Lyapunov exponents (sum log g / T),
%%        for MEGNO, and for FLI.
%%
%%   THE COMPOSITION, AND A MISTAKE WORTH RECORDING
%%   --------------------------------------------
%%   Yoshida's order conditions assume the base method S is a SYMMETRIC
%%   second-order method.  The obvious-looking loop "for each weight w: drift
%%   w*h, then kick w*h" composes first-order, NON-symmetric D-K maps, and the
%%   resulting scheme is not fourth order at all -- it is worse than plain
%%   leapfrog, which is exactly what a first version of this file measured
%%   (Yoshida4 and Yoshida6 both drifting more than Yoshida2).
%%
%%   The correct object is a composition of symmetric leapfrogs
%%   S(c h) = K(c h/2) D(c h) K(c h/2).  Writing the composition out, the
%%   adjacent half-kicks merge and give the standard economical sequence
%%
%%       K(w1 h/2)  [ D(w_i h)  K((w_i + w_{i+1}) h / 2) ]_{i=1..m}
%%
%%   with w_{m+1} = 0, i.e. m drifts and m+1 kicks.  For m = 1 this is plain
%%   leapfrog; for m = 3 and m = 7 it is Yoshida 4 and 6.  That is what the
%%   loop below implements.  test_symplectic.m measures the convergence order
%%   and pins it down, so this cannot silently regress again.
%%
%%   TIME IN THE KICKS (the non-autonomous case)
%%   -------------------------------------------
%%   For a time-dependent Hamiltonian the kick is instantaneous and is
%%   evaluated at the running time.  The resulting sequence of kick times is
%%   {t0, t0+w1 h, t0+(w1+w0)h, ..., t0+h}, which is symmetric about the
%%   midpoint t0 + h/2 -- the same palindrome that makes the method
%%   time-reversible.  Assigning the times asymmetrically would break the
%%   symmetry and cost an order.
%%
%%   WHY THE TANGENT IS ADVANCED BY THE COMPOSITION ITSELF
%%   ----------------------------------------------------
%%   The discrete map that advances (q,p) has its own tangent map: compose the
%%   tangents of the sub-steps it is built from.  Advancing the tangent by a
%%   *different* scheme (RK4, say) would measure the Lyapunov exponents of a
%%   numerical system that is not the one being integrated, and the mismatch
%%   appears as a systematic bias in lambda that does not shrink as fast as the
%%   integration order.  Composing the tangents keeps the discretisation and
%%   its linearisation consistent by construction.
%%
%%       drift  q <- q + c h p        dq <- dq + c h dp ,   dp unchanged
%%       kick   p <- p + c h F(q,t)   dp <- dp + c h (dF/dq) dq , dq unchanged
%%
%%   dF/dq is the analytic Hessian supplied through sys.dforce.
%%
%%   WHY THE VECTORS ARE RESCALED BUT *NOT* ORTHOGONALISED
%%   ----------------------------------------------------
%%   Rescaling each vector to unit norm is required to keep long integrations
%%   from overflowing, and it is harmless for every indicator computed here
%%   because they are all homogeneous of degree zero in the vectors (GALI is a
%%   ratio of wedge products, SALI is a difference of unit vectors, MEGNO and
%%   the Lyapunov exponents use the log of the growth).  A Gram-Schmidt or QR
%%   step would be fatal: it forces the vectors orthogonal, which is precisely
%%   the alignment GALI is designed to measure, so GALI would come out constant.
%%   The vectors are therefore left to collapse on their own.
%%
%%   DAMPING
%%   -------
%%   For sys.gamma > 0 the system is not Hamiltonian and no symplectic method
%%   exists for it.  Damping is split off as the exactly solvable contraction
%%   p <- exp(-gamma h) p, applied as a symmetric Strang sandwich
%%
%%       exp(-gamma h/2) o Phi(h) o exp(-gamma h/2)
%%
%%   so the conservative part keeps its symplectic structure exactly and the
%%   gamma -> 0 limit recovers the symplectic method bit for bit.  The damping
%%   is not volume preserving -- it is a contraction, which is the physics --
%%   and its tangent map is the same scalar exp(-gamma h/2).
%%
%%   VECTORISATION
%%   -------------
%%   Every array carries the whole grid row in its last index, so one call
%%   advances N independent initial conditions.  test_symplectic.m checks the
%%   vectorised path against a scalar loop.

    if nargin < 7 || isempty(renorm), renorm = true; end
    if nargin < 6 || isempty(order), order = 4; end
    w = sp_weights(order);
    m = numel(w);
    nq = sys.nq;
    gam = sys.gamma;
    if isempty(gam), gam = 0; end

    wantV = ~isempty(V);

    % ---- symmetric damping: half contract at each end ----
    if gam > 0
        e = exp(-0.5*gam*h);
        y(nq+1:end,:) = y(nq+1:end,:) * e;
        if wantV, V(nq+1:end,:,:) = V(nq+1:end,:,:) * e; end
    end

    % ---- opening half kick: K(w1 h / 2) ----
    [y, V] = apply_kick(y, V, t, (w(1)/2)*h, sys, wantV);

    % ---- m drifts, each followed by its merged kick ----
    for i = 1:m
        c = w(i);
        y(1:nq,:) = y(1:nq,:) + (c*h) * y(nq+1:end,:);
        if wantV
            V(1:nq,:,:) = V(1:nq,:,:) + (c*h) * V(nq+1:end,:,:);
        end
        t = t + c*h;

        if i < m
            ck = (w(i) + w(i+1)) / 2;
        else
            ck = w(m) / 2;
        end
        [y, V] = apply_kick(y, V, t, ck*h, sys, wantV);
    end

    if gam > 0
        y(nq+1:end,:) = y(nq+1:end,:) * e;
        if wantV, V(nq+1:end,:,:) = V(nq+1:end,:,:) * e; end
    end

    % ---- rescale each deviation vector; report the growth removed ----
    if wantV
        k = size(V, 2);
        n = size(y, 2);
        g = ones(k, n);
        for j = 1:k
            nj = reshape(sqrt(sum(V(:,j,:).^2, 1)), 1, n);
            nz = nj > 0;
            g(j, nz) = nj(nz);
            if renorm
                V(:,j,:) = V(:,j,:) ./ reshape(max(nj, realmin), 1, 1, n);
            end
        end
    else
        g = [];
    end
end


% =========================================================================
function [y, V] = apply_kick(y, V, t, c, sys, wantV)
%% APPLY_KICK  p <- p + c*force(q,t), with its tangent map applied to V.
    nq = sys.nq;
    F = sys.force(y(1:nq,:), t);
    y(nq+1:end,:) = y(nq+1:end,:) + c * F;
    if wantV
        dF = sys.dforce(y(1:nq,:), t);              % nq x nq x N
        V(nq+1:end,:,:) = V(nq+1:end,:,:) + c * dmul(dF, V(1:nq,:,:));
    end
end


% =========================================================================
function P = dmul(A, X)
%% DMUL  A is nq x nq x N, X is nq x k x N; returns A*X pagewise.
%
%   An explicit loop over nq rather than pagemtimes: nq is 1 or 2 here, so the
%   loop is cheaper than the dispatch and it keeps the file runnable on
%   releases without pagemtimes.
%
%   The result is FORCED to nq x k x N.  When k = 1 MATLAB drops the singleton
%   dimension and the assignment  V(...) + c*P  then broadcasts against the
%   nq x N slice instead, which either errors or silently produces nq x N x N.
%   This was latent from the first version of the file and only surfaced when a
%   caller used a single deviation vector (sp_paper_repro's reproduction of the
%   paper's Fig. 6, which tracks exactly one).
    [nq, ~, n] = size(A);
    k = size(X, 2);
    P = zeros(nq, k, n);
    for a = 1:nq
        for b = 1:nq
            P(a,:,:) = P(a,:,:) + A(a,b,:) .* X(b,:,:);
        end
    end
    P = reshape(P, nq, k, n);
end
