function [g, info] = sp_gali(V)
%% SP_GALI  Generalized Alignment Index (GALI) from a set of deviation vectors.
%%
%%   [g, info] = sp_gali(V)
%%
%%   V   ndof x k x N deviation vectors, ALREADY advanced by the flow.
%%       k is the number of vectors supplied.
%%   g   1 x N   GALI_k, one value per grid point
%%   info  struct with k, the per-order values and the orthonormalised flags
%%
%%   DEFINITION
%%   ----------
%%   For k deviation vectors the Generalized Alignment Index is the norm of
%%   their wedge (exterior) product,
%%
%%       GALI_k = || v_1 ^ v_2 ^ ... ^ v_k || .
%%
%%   Computed from a thin QR factorisation of V as |det R|, i.e. the product of
%%   the diagonal entries of R -- which is the volume of the parallelepiped the
%%   vectors span.  Using QR rather than explicitly forming wedge products keeps
%%   the cost O(ndof k^2) and is numerically stable when the vectors are nearly
%%   dependent, which is exactly the regime GALI detects.
%%
%%   For k = 2 this reduces to the Smallest Alignment Index up to a factor,
%%       SALI = || v1/||v1|| - v2/||v2|| || ,   GALI_2 = SALI^2 / 2
%%   so the two carry the same information and GALI_k generalises SALI to
%%   k > 2.  sp_sali.m is provided separately because the literature reports
%%   SALI directly and the two use different scalings.
%%
%%   WHAT IT MEASURES, AND WHY IT IS PREFERRED TO A FIRST-ORDER INDICATOR
%%   -------------------------------------------------------------------
%%   GALI_k decaying exponentially to zero signals chaos; on a regular orbit it
%%   oscillates/quasi-periodically rather than decaying.  Its advantage over
%%   first-order variational indicators (FLI, MEGNO, and Lyapunov exponents)
%%   appears exactly where those fail: on a REGULAR orbit in a system with
%%   more than one degree of freedom, two or more Lyapunov exponents are
%%   identically zero, and Barrio, Borczyk & Breiter (Chaos Solitons Fractals
%%   40 (2009) 1697, Sec. 4.2.1) show that first-order methods then produce
%%   spurious structures that depend only on the initial deviation direction.
%%   GALI uses higher-order information and is free of that artefact.
%%
%%   APPLICABILITY IN TWO DIMENSIONS -- WHAT WAS MEASURED, NOT ASSUMED
%%   -----------------------------------------------------------------
%%   The GALI literature states the method discriminates regular from chaotic
%%   motion when the tangent space is at least 4-dimensional.  This project
%%   needed to know what GALI_2 actually does in the 2-dimensional forced damped
%%   pendulum, so it was measured rather than assumed, and the answer is more
%%   interesting than a simple "it degenerates".
%%
%%   For a flow with exponents lambda_1 >= lambda_2, GALI_2 decays at the rate
%       Gamma = lambda_1 - lambda_2 .
%%   A damped pendulum has constant divergence div f = -gamma, so
%%   lambda_1 + lambda_2 = -gamma and therefore
%%       Gamma = 2*lambda_1 + gamma .
%%
%%   Measurement (tests/diag_gali_rate.m and diag_gali2d_sweep.m):
%%
%%     * On a regular orbit that settles to a FIXED POINT, lambda_1 = lambda_2 =
%%       -gamma/2, so Gamma = 0 and GALI_2 does NOT decay.  Measured: F = 0 and
%%       F = 0.3 at gamma = 0.2 give Gamma = 1e-5, GALI_2 stays ~0.94-1.00.
%%     * On a chaotic orbit it decays exponentially at the predicted rate.
%%       Measured fit vs prediction: 0.324/0.297, 0.801/0.730, 0.357/0.391
%%       (9% agreement, R^2 ~ 0.96) for three (F, gamma) pairs.
%%     * BUT on regular orbits that do NOT sit at a fixed point -- phase-locked
%%       periodic rotations -- Gamma > 0 and GALI_2 collapses anyway.  Measured
%%       at gamma = 0.5: F = 1.3 has lambda_1 = -0.250 (regular) yet GALI_2
%%       falls to 2.4e-5; F = 1.4 has lambda_1 = -0.045 (regular) yet GALI_2
%%       reaches 1.7e-16.
%%
%%   Those last cases are FALSE POSITIVES: a purely regular orbit reported as
%%   chaotic.  The mechanism is visible in the definition: sp_step.m
%%   renormalises both vectors every step, so GALI_2 measures the ANGLE between
%%   two unit vectors.  On a strongly contracting regular orbit both normalised
%%   vectors converge onto the slowest-decaying direction, the angle closes and
%%   GALI_2 -> 0 with no chaos involved.  This is not a numerical defect; it is
%%   what a 2-dimensional tangent space without a positive exponent does.
%%
%%   RATE OVER A GRID.  diag_gali2d_sweep.m classifies an 8x5 (F, gamma) grid
%%   by the true exponent and by GALI_2 independently, with thresholds
%%   lambda < 1e-3 (regular) and GALI_2 < 1e-6 (collapsed).  Measured result:
%%
%%       40 points -> 11 FALSE POSITIVES (regular called chaotic), 0 false
%%       negatives.
%%
%%   A 27% false-positive rate, on orbits whose regularity is established by the
%%   Lyapunov exponent.  That number is the reason for the rule below.
%%
%%   CONSEQUENCE FOR THIS PROJECT
%%   ---------------------------
%%   GALI / SALI are used for the DOUBLE PENDULUM, whose tangent space is
%%   4-dimensional and where the method works as advertised.  The forced damped
%%   pendulum is analysed with MEGNO, OFLI2 and the IACF, and any GALI_2 number
%%   computed for it is reported only alongside those.  Re-run
%%   diag_gali2d_sweep.m to reproduce the count.
%%
%%   See also sp_sali, sp_megno_formula, sp_ofli2, sp_iacf.

    if isempty(V)
        error('sp_gali:empty', 'no deviation vectors supplied');
    end
    ndof = size(V, 1);
    k    = size(V, 2);
    N    = size(V, 3);

    if k > ndof
        error('sp_gali:count', ...
              'GALI_%d needs at most ndof = %d vectors', k, ndof);
    end

    g = zeros(1, N);
    for c = 1:N
        Vc = V(:,:,c);
        [~, R] = qr(Vc, 0);
        d = diag(R);
        if numel(d) < k
            % rank deficient: the wedge product is exactly zero
            g(c) = 0;
        else
            g(c) = abs(prod(d(1:k)));
        end
    end

    if nargout > 1
        info = struct('k', k, 'ndof', ndof, 'nPoints', N);
    end
end
