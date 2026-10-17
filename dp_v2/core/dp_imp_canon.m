function [z, Qz, g, t] = dp_imp_canon(z, Qz, t, h, p, order, renorm)
%% DP_IMP_CANON  One Gauss-Legendre implicit symplectic step of the double
%%               pendulum in CANONICAL variables.
%%
%%   [z, Qz, g, t] = dp_imp_canon(z, Qz, t, h, p, order, renorm)
%%
%%   z   4xN canonical state, rows = [th1; th2; p1; p2]
%%   Qz  4xkxN deviation vectors ([] to skip the tangent)
%%   h   step
%%   p   parameter struct m1, m2, L1, L2, g
%%   order 2 (implicit midpoint) or 4 (two-stage Gauss-Legendre)
%%   renorm (optional, default true) rescale deviation vectors to unit norm
%%
%%   This is the actual integrator; dp_imp_step.m is the wrapper that converts
%%   to and from the project's (theta, omega) layout.
%%
%%   WHY IMPLICIT, AND WHY CANONICAL
%%   ------------------------------
%%   H = 1/2 p' M(q)^-1 p + V(q) is not separable, so no explicit symplectic
%%   method exists.  Symmetric Gauss-Legendre collocation is symplectic for any
%%   Hamiltonian.  It must be applied in (q,p): the project's (q,omega) are
%%   not canonical, and a symplectic method composed with a nonlinear change of
%%   variables is no longer symplectic.
%%
%%   STAGE EQUATIONS
%%   ---------------
%%       Z_i = z_n + h sum_j a_ij F(Z_j) ,   z_{n+1} = z_n + h sum_i b_i F(Z_i)
%%
%%   solved by Newton iteration on  R_i = Z_i - z_n - h sum_j a_ij F(Z_j)  with
%%   iteration matrix  M_ij = delta_ij I - h a_ij J(Z_j) , using the ANALYTIC
%%   Jacobian from dp_canon_rhs.m.  A differenced Jacobian would degrade Newton
%%   to linear convergence and bias the tangent every chaos indicator reads.
%%
%%   THE TANGENT: SAME MATRIX, NO SECOND DERIVATIVE
%%   ---------------------------------------------
%%   Differentiating the stage equations and applying the implicit function
%%   theorem gives the same M acting on the deviation vectors,
%%
%%       M dZ = Q_n ,        Q_{n+1} = Q_n + h sum_i b_i J(Z_i) dZ_i .
%%
%%   For one stage this is the Cayley transform
%%
%%       Q_{n+1} = (I - h/2 J)^-1 (I + h/2 J) Q_n ,
%%
%%   symplectic for every J -- which is why the midpoint rule needs only first
%%   derivatives.  M is the matrix Newton already factored, so the tangent
%%   costs one back-substitution per vector and no extra factorisation.
%%
%%   See also dp_imp_step, dp_canon_rhs, dp_mass.

    if nargin < 6 || isempty(order), order = 2; end
    if nargin < 7 || isempty(renorm), renorm = true; end
    if isempty(t), t = 0; end   %#ok<NASGU>  autonomous

    [A, B] = gl_coeffs(order);
    s  = size(A, 1);
    n  = size(z, 2);
    nd = 4;
    ns = nd * s;

    % ---- Newton iteration on the stacked stages ----
    Z  = repmat(z, s, 1);
    M  = [];
    for it = 1:50
        Fstack = zeros(ns, n);
        for i = 1:s
            Fi = zeros(nd, n);
            for j = 1:s
                if A(i,j) ~= 0
                    Fi = Fi + A(i,j) * dp_canon_rhs(Z((j-1)*nd+1:j*nd, :), p);
                end
            end
            Fstack((i-1)*nd+1:i*nd, :) = Fi;
        end
        R = Z - repmat(z, s, 1) - h*Fstack;

        % iteration matrix, assembled per page
        M = repmat(eye(ns), 1, 1, n);
        for i = 1:s
            for j = 1:s
                if A(i,j) ~= 0
                    [~, Jblk] = dp_canon_rhs(Z((j-1)*nd+1:j*nd, :), p);
                    rr = (i-1)*nd+1:i*nd;
                    cc = (j-1)*nd+1:j*nd;
                    M(rr,cc,:) = M(rr,cc,:) - h*A(i,j)*Jblk;
                end
            end
        end

        % The RHS is made explicitly 3-D for mldiv_page, and the result is
        % reshaped back before the update.  Without the reshape, Z (ns x n) plus
        % dZ (ns x 1 x n) triggers MATLAB implicit expansion to ns x n x n --
        % which does not error, it silently corrupts the iteration.  It only
        % shows up for n > 1, i.e. only on the vectorised grid path.
        dZpage = mldiv_page(M, reshape(-R, ns, 1, n));
        dZ  = reshape(dZpage, ns, n);
        Z   = Z + dZ;

        if max(abs(dZ(:))) <= 1e-14 * max(1, max(abs(Z(:))))
            break
        end
    end

    % ---- state update ----
    znew = z;
    for i = 1:s
        znew = znew + (h*B(i)) * dp_canon_rhs(Z((i-1)*nd+1:i*nd, :), p);
    end
    z = znew;

    % ---- tangent update, reusing M ----
    if isempty(Qz)
        g = [];
    else
        k   = size(Qz, 2);
        % The stage equations differentiate to  (I - hA J) dZ = 1_s (x) Q_n ,
        % i.e. EVERY stage block gets the same right-hand side Q_n.  For s = 1
        % this is the Cayley transform
        %   Q_{n+1} = Q_n + h J (I - h/2 J)^-1 Q_n = (I - h/2 J)^-1 (I + h/2 J) Q_n
        % which was verified by expanding the right-hand side by hand.
        % Passing the bare 4 x k block here instead of the stacked ns x k one
        % is a dimension error that only shows up at order 4 (s = 2).
        Qstack = repmat(Qz, s, 1);
        dZ  = mldiv_page(M, Qstack);

        Qnew = Qz;
        for i = 1:s
            [~, Ji] = dp_canon_rhs(Z((i-1)*nd+1:i*nd, :), p);
            dZi = dZ((i-1)*nd+1:i*nd, :, :);
            Qnew = Qnew + (h*B(i)) * page_mul(Ji, dZi);
        end
        Qz = Qnew;

        g = ones(k, n);
        for j = 1:k
            nj = reshape(sqrt(sum(Qz(:,j,:).^2, 1)), 1, n);
            nz = nj > 0;
            g(j, nz) = nj(nz);
            if renorm
                Qz(:,j,:) = Qz(:,j,:) ./ reshape(max(nj, realmin), 1, 1, n);
            end
        end
    end
end


% =========================================================================
function [A, B] = gl_coeffs(order)
%% GL_COEFFS  Gauss-Legendre Butcher tableau: order 2 -> 1 stage, 4 -> 2.
    if order == 2
        A = 1/2;
        B = 1;
    elseif order == 4
        r3 = sqrt(3);
        A = [1/4,         1/4 - r3/6;
             1/4 + r3/6,  1/4       ];
        B = [1/2, 1/2];
    else
        error('dp_imp_canon:order', 'order must be 2 or 4 (got %g)', order);
    end
end


% =========================================================================
function X = mldiv_page(M, R)
%% MLDIV_PAGE  Solve M X = R pagewise by Gaussian elimination with pivoting.
%
%   M  ns x ns x n,  R  ns x k x n,  X  ns x k x n.  ns is at most 8, so a
%   hand-written elimination is cheap and -- unlike a loop of backslash calls --
%   stays vectorised over the n grid pages, which is the point of the row-wise
%   layout used throughout dp_v2.
%
%   Both inputs are forced to 3-D before elimination.  The Newton correction
%   arrives as ns x 1 x n already, but a caller may hand in an ns x k x n with
%   k = 1 that MATLAB has squeezed to ns x n; indexing R(col,:,c) then writes
%   into the wrong slot and raises an out-of-bounds error.  That happened only
%   for n > 1, so every single-point test passed while the vectorised path was
%   broken.
    [ns, ~, n] = size(M);
    if ndims(R) < 3                      %#ok<ISMAT>  ns x k, no page index
        R = reshape(R, ns, [], 1);
    end
    if size(R, 3) == 1 && n > 1
        R = repmat(R, 1, 1, n);
    end
    for col = 1:ns
        for c = 1:n
            [~, piv] = max(abs(M(col:ns, col, c)));
            piv = piv + col - 1;
            if piv ~= col
                tmp = M(col,:,c); M(col,:,c) = M(piv,:,c); M(piv,:,c) = tmp;
                tmp = R(col,:,c); R(col,:,c) = R(piv,:,c); R(piv,:,c) = tmp;
            end
        end
        for j = col+1:ns
            for c = 1:n
                f = M(j,col,c) / M(col,col,c);
                M(j,col:ns,c) = M(j,col:ns,c) - f*M(col,col:ns,c);
                R(j,:,c)      = R(j,:,c)      - f*R(col,:,c);
            end
        end
    end
    X = R;
    for col = ns:-1:1
        for c = 1:n
            X(col,:,c) = X(col,:,c) / M(col,col,c);
        end
        for j = 1:col-1
            for c = 1:n
                X(j,:,c) = X(j,:,c) - M(j,col,c)*X(col,:,c);
            end
        end
    end
end


% =========================================================================
function P = page_mul(A, X)
%% PAGE_MUL  A is 4 x 4 x n, X is 4 x k x n; returns A*X pagewise.
    [nd, ~, n] = size(A);
    k = size(X, 2);
    P = zeros(nd, k, n);
    for a = 1:nd
        for b = 1:nd
            P(a,:,:) = P(a,:,:) + A(a,b,:) .* X(b,:,:);
        end
    end
end
