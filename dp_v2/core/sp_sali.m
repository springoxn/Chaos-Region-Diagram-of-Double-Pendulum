function [s, info] = sp_sali(V)
%% SP_SALI  Smallest Alignment Index (SALI) from TWO deviation vectors.
%%
%%   [s, info] = sp_sali(V)
%%
%%   V   ndof x 2 x N deviation vectors
%%   s   1 x N  SALI values
%%
%%   DEFINITION (Skokos, Physica D 159 (2001) 155)
%%
%%       SALI(t) = min( || v1/||v1|| + v2/||v2|| || ,
%%                      || v1/||v1|| - v2/||v2|| || )
%%
%%   The two combinations are the norms of the sum and the difference of the
%%   unit vectors, so SALI is small exactly when the two directions coincide
%%   (difference -> 0) or are opposite (sum -> 0).  For each unit vector the
%%   sum and difference are the two ways to be parallel, so the minimum over
%%   both covers alignment up to sign.
%%
%%   RELATION TO GALI_2
%%   ------------------
%%   For unit vectors u, w one has  ||u - w||^2 = 2 - 2 u.w  and the wedge norm
%%   is sqrt(1 - (u.w)^2) = sqrt((2-||u-w||^2)(2+||u-w||^2))/2 .  Hence
%%
%%       GALI_2 = SALI * sqrt(4 - SALI^2) / 2 ,
%%
%%   so SALI and GALI_2 are monotonically related and carry the same
%%   information; the project reports both because the literature quotes SALI
%%   while GALI_k extends cleanly to k > 2.  tests/test_indicators.m checks
%%   that relation numerically rather than taking it on faith.
%%
%%   APPLICABILITY -- READ THIS BEFORE USING SALI ON THE FORCED PENDULUM
%%   ------------------------------------------------------------------
%%   SALI is defined for any system, but it discriminates regular from chaotic
%%   motion only when the tangent space is at least 4-dimensional.  For a
%%   2-dimensional flow -- the forced damped pendulum here -- it is unreliable,
%%   and the failure was MEASURED rather than assumed:
%%
%%     * On a regular orbit at a fixed point (lambda_1 = lambda_2 = -gamma/2)
%%       GALI_2/SALI do not decay, because the decay rate is
%%       Gamma = lambda_1 - lambda_2 = 0.  Measured: F = 0, 0.3 at gamma = 0.2
%%       keep SALI near its initial value over 600 drive periods.
%%     * On a phase-locked periodic orbit (regular, but lambda_1 = -0.25 rather
%%       than -gamma/2) Gamma > 0 and SALI COLLAPSES anyway, reporting a regular
%%       orbit as chaotic.  Measured at gamma = 0.5: F = 1.3 gives SALI ~ 1e-5,
%%       F = 1.4 reaches 1e-16, both with lambda_1 < 0.
%%
%%   These false positives are quantified over an (F, gamma) grid by
%%   tests/diag_gali2d_sweep.m.  This project therefore uses SALI/GALI for the
%%   DOUBLE pendulum (4-dimensional) and MEGNO / OFLI2 / IACF for the forced
%%   pendulum.  See sp_gali.m for the derivation of the decay rate and the full
%%   measurement table.
%%
%%   See also sp_gali, sp_megno_formula, sp_ofli2, sp_iacf.

    s = zeros(1, size(V,3));
    k = size(V, 2);
    if k ~= 2
        error('sp_sali:count', 'SALI needs exactly 2 deviation vectors (got %d)', k);
    end

    ndof = size(V,1);
    N    = size(V,3);
    for c = 1:N
        v1 = V(:,1,c);  v2 = V(:,2,c);
        n1 = norm(v1);  n2 = norm(v2);
        if n1 == 0 || n2 == 0
            s(c) = 0;
            continue
        end
        u = v1/n1;  w = v2/n2;
        s(c) = min(norm(u + w), norm(u - w));
    end

    if nargout > 1
        info = struct('ndof', ndof, 'nPoints', N);
    end
end
