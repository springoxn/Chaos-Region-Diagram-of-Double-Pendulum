function varargout = fp_melnikov_threshold(gamma, Omega)
%% FP_MELNIKOV_THRESHOLD  Critical forcing for heteroclinic chaos.
%%
%%   Fc = fp_melnikov_threshold(gamma, Omega)
%%
%%   For  theta'' + gamma*theta' + sin(theta) = F*cos(Omega*t)  the Melnikov
%%   function of the unperturbed heteroclinic orbit is
%%
%%       M(t0) = -8*gamma + 2*pi*F*sech(Omega*pi/2)*cos(Omega*t0)
%%
%%   A simple zero of M (=> transverse intersection of the stable and unstable
%%   manifolds => Smale horseshoe chaos) exists iff
%%
%%       F > F_c = (4*gamma/pi) * cosh(Omega*pi/2)
%%
%%   Derivation of the two ingredients:
%%     * the heteroclinic orbit of the undamped pendulum is
%%           theta(t) = 2*arctan(sinh t),  theta'(t) = 2*sech(t)
%%       connecting theta = -pi to theta = +pi;
%%     * the damping term contributes  -gamma * integral(theta'^2) dt
%%                                              = -gamma * 8
%%       and the forcing term contributes
%%           F * integral(theta'(t) * cos(Omega*(t+t0))) dt
%%             = 2*pi*F*sech(Omega*pi/2) * cos(Omega*t0).
%%
%%   Sanity anchor: at Omega = 2/3, cosh(pi/3) = 1.600287, so F_c = 2.037549*gamma.
%%   The numerical transition observed in test_fp.m lands right there.
%%
%%   CAVEAT, stated plainly: Melnikov is a FIRST-ORDER perturbative result and
%%   is quantitatively reliable only for small gamma and F.  Above threshold it
%%   guarantees a horseshoe -- a transient/geometric statement -- not the
%%   existence of a chaotic ATTRACTOR, which is what a Lyapunov exponent
%%   measures.  Use it to locate the onset, then verify with fp_lyap.
%%
%%   [Fc, sechFactor] = fp_melnikov_threshold(...) also returns
%%   sech(Omega*pi/2), the frequency-dependent factor in the forcing integral.

    if nargin < 1 || isempty(gamma), gamma = 0.2; end
    if nargin < 2 || isempty(Omega), Omega = 2/3; end

    sh = sech(Omega*pi/2);
    Fc = (4*gamma/pi) * cosh(Omega*pi/2);

    % cross-check: (4/pi)*cosh = 4/(pi*sech)
    assert(abs(Fc - 4*gamma/(pi*sh)) < 1e-12*max(1,Fc), ...
           'fp_melnikov_threshold: sech/cosh identity violated');

    varargout{1} = Fc;
    if nargout > 1, varargout{2} = sh; end
end
