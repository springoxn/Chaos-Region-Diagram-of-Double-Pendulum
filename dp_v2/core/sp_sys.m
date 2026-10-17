function sys = sp_sys(kind, varargin)
%% SP_SYS  Separable Hamiltonian systems for the explicit symplectic family.
%%
%%   sys = sp_sys('pendulum', 'F',1.5, 'gamma',0.2, 'Omega',2/3)
%%   sys = sp_sys('coupled',  'a',4,   'b',1)
%%   sys = sp_sys('henonheiles')
%%
%%   Returns a struct describing  H = T(p) + V(q)  with UNIT mass, so the
%%   kinetic term is exactly  T = |p|^2/2  and the equations of motion are
%%
%%       q' = p ,      p' = -grad V(q)   [+ damping]
%%
%%   The struct carries everything the symplectic stepper needs, so sp_step.m
%%   never has to know which physical problem it is running:
%%
%%     nq        number of coordinates
%%     force     @(q,t) -> -grad V        (acceleration, nq x N)
%%     dforce    @(q,t) -> -hess V        (nq x nq x N)
%%     d2force   @(q,t) -> d2(force)      (nq x nq x nq x N, indices (j,k,l))
%%     energy    @(y,t) -> H              (1 x N)
%%     gamma     damping coefficient (0 = conservative)
%%
%%   WHY d2force EXISTS
%%   ------------------
%%   The second-order variational equations -- needed by OFLI2 (sp_ofli2.m) --
%%   contain the term  sum_{k,l} n_k (d2 f_j / dq_k dq_l) n_l , which is the
%%   second derivative of the VECTOR FIELD, not of the potential.  A note in a
%%   first draft of sp_ofli2.m claimed the Hessian of V sufficed "because f is
%%   linear in p"; that is wrong in general.  f_p = -grad V(q) depends only on
%%   q, so d2 f_p = -d3 V, i.e. THIRD derivatives of the potential.  For the two
%%   systems here those have simple closed forms, so they are supplied
%%   analytically and cross-checked against central differences in
%%   tests/test_indicators.m, consistent with the project's rule that nothing in
%%   the derivative pipeline is differenced.
%%
%%   WHY ANALYTIC DERIVATIVES ARE PASSED IN RATHER THAN DIFFERENCED
%%   -----------------------------------------------------------
%%   `dforce` is the linearisation of the kick map and therefore feeds the
%%   tangent flow that produces every variational chaos indicator.  A finite
%%   difference here would inject an O(eps) error straight into the deviation
%%   vectors -- the same mistake the double-pendulum Jacobian avoids (see
%%   dp_jacobian.m).  Both systems below have closed-form Hessians; they are
%%   written out and cross-checked against central differences in
%%   test_symplectic.m.
%%
%%   THE THREE SYSTEMS
%%   -----------------
%%   'pendulum'  the forced damped pendulum of the project,
%%
%%                   theta'' + gamma*theta' + sin(theta) = F*cos(Omega*t)
%%
%%               Hamiltonian part  H = p^2/2 - cos(q) - F*q*cos(Omega*t).
%%               The last term is the standard trick for a linear-in-q drive:
%%               -d/dq [ -F q cos(Omega t) ] = +F cos(Omega t), which is the
%%               forcing, while the equation itself stays second order in q.
%%               Verified in test_symplectic.m by differencing the generated
%%               acceleration against the right-hand side used by fp_lyap.m.
%%
%%               NOTE ON DAMPING: for gamma > 0 the system is NOT Hamiltonian
%%               and no symplectic integrator exists for it.  sp_step.m splits
%%               the damping off as an exactly solvable contraction, so the
%%               conservative part keeps its symplectic structure and the
%%               gamma -> 0 limit is exactly symplectic.  See sp_step.m.
%%
%%   'coupled'   the two-degree-of-freedom coupled pendulum that Barrio,
%%               Borczyk & Breiter use as their test problem,
%%               Chaos Solitons Fractals 40 (2009) 1697, Eq. (18):
%%
%%                   H = (X^2+Y^2)/2 - (1+a*b)cos x - a cos y + a*b cos x cos y
%%
%%               Autonomous and genuinely non-integrable, so it is the right
%%               vehicle for reproducing their spurious-structure figures.  The
%%               paper integrates it with the same fourth-order symplectic
%%               composition implemented here (their ref. [35] = Yoshida 1990).
%%
%%   'henonheiles'  the classical Henon-Heiles Hamiltonian, their Eq. (20):
%%
%%                   H = (X^2+Y^2+x^2+y^2)/2 + x^2 y - y^3/3
%%
%%               Included because the paper uses it as the SECOND test bed for
%%               the initial-variation and integration-time artefacts
%%               (their Figs. 10-12): it has TWO degrees of freedom, so unlike
%%               the planar pendulum it has room for a genuine gradient
%%               direction distinct from the flow, which is exactly what
%%               their Fig. 11 compares.
%%
%%               CAVEAT: V is UNBOUNDED BELOW along y -> +inf, so orbits above
%%               the escape energy E_esc = 1/6 leave the well and their
%%               Lyapunov exponent diverges.  The paper's slices are E = 1/12
%%               and E = 1/8, both safely below E_esc.  The initial-condition
%%               builder sp_henon_heiles_ic.m reports escaped points instead of
%%               hiding them.

    switch lower(kind)
        case 'pendulum'
            o = sp_optset(struct('F',1.5, 'gamma',0.2, 'Omega',2/3), varargin{:});

            sys = struct();
            sys.name   = sprintf('forced damped pendulum (F=%.4g, gamma=%.4g, Omega=%.6g)', ...
                                 o.F, o.gamma, o.Omega);
            sys.nq     = 1;
            sys.gamma  = o.gamma;
            sys.params = o;

            % V(q,t)   = -cos q - F q cos(Omega t)
            % dV/dq    =  sin q - F cos(Omega t)      -> force = -sin q + F cos(Omega t)
            % d2V/dq2  =  cos q                        -> dforce = -cos q
            % d3V/dq3  = -sin q                        -> d2force = +sin q
            sys.force   = @(q,t) -sin(q) + o.F*cos(o.Omega*t);
            sys.dforce  = @(q,t) reshape(-cos(q), 1, 1, numel(q));
            sys.d2force = @(q,t) reshape(sin(q), 1, 1, 1, numel(q));
            sys.energy  = @(y,t) 0.5*y(2,:).^2 - cos(y(1,:)) ...
                                 - o.F*y(1,:).*cos(o.Omega*t);

        case 'coupled'
            o = sp_optset(struct('a',4, 'b',1), varargin{:});

            sys = struct();
            sys.name   = sprintf('coupled pendulum (a=%.6g, b=%.6g)', o.a, o.b);
            sys.nq     = 2;
            sys.gamma  = 0;
            sys.params = o;

            % V(x,y)   = -(1+ab)cos x - a cos y + ab cos x cos y
            % grad V   = [ (1+ab) sin x - ab sin x cos y ;  a sin y - ab cos x sin y ]
            % -grad V  = [ -(1+ab) sin x + ab sin x cos y ; -a sin y + ab cos x sin y ]
            % which is exactly Eq. (19) of the paper,
            %   x'' = -(1 + ab - ab cos y) sin x ,  y'' = -a(1 - b cos x) sin y .
            % hess V   = [ (1+ab)cos x - ab cos x cos y ,  ab sin x sin y ;
            %              ab sin x sin y               ,  a cos y - ab cos x cos y ]
            %
            % THIRD derivatives, needed only by OFLI2 (d2force = -d3 V):
            %   V_xxx = +(1+ab) sin x - ab sin x cos y
            %   V_xxy = V_xyx = V_yxx = +ab cos x sin y
            %   V_xyy = V_yxy = V_yyx = +ab sin x cos y
            %   V_yyy = -a sin y + ab cos x sin y
            % (each is -d/dq of the corresponding Hessian entry above).
            sys.force   = @(q,t) coupled_force(q, o);
            sys.dforce  = @(q,t) coupled_dforce(q, o);
            sys.d2force = @(q,t) coupled_d2force(q, o);
            sys.energy  = @(y,t) 0.5*(y(3,:).^2 + y(4,:).^2) ...
                                 - (1+o.a*o.b)*cos(y(1,:)) - o.a*cos(y(2,:)) ...
                                 + o.a*o.b*cos(y(1,:)).*cos(y(2,:));

        case 'henonheiles'
            % Barrio, Borczyk & Breiter (2009), Eq. (20):
            %
            %     H = (X^2 + Y^2 + x^2 + y^2)/2 + x^2 y - y^3/3
            %
            %   V(x,y)   = (x^2 + y^2)/2 + x^2 y - y^3/3
            %   grad V   = [ x + 2 x y ;  y + x^2 - y^2 ]
            %   force    = -grad V
            %
            % Hessian of V:
            %   V_xx = 1 + 2y        V_xy = 2x        V_yy = 1 - 2y
            %
            % Third derivatives (needed by OFLI2, d2force = -d3 V):
            %   V_xxx = 0   V_xxy = 2   V_xyy = 0   V_yyy = -2
            % so the only nonzero second derivative of the force is
            %   d2(force_x)/dy dx = d2(force_x)/dx dy = -2
            %   d2(force_y)/dy dy = +2
            %
            % THE POTENTIAL IS UNBOUNDED BELOW along the y^3 escape direction
            % (V -> -inf as y -> +inf), so an orbit that escapes has no
            % conserved energy to check against and its 'Lyapunov exponent'
            % diverges.  The maps are drawn at fixed energy E, and the standard
            % E = 1/12 and E = 1/8 are both WELL BELOW the escape threshold
            % E_esc = 1/6, so on those slices the motion is bounded.  Any caller
            % using a higher energy must expect escapes; sp_henon_heiles_ic.m
            % reports the escaped fraction rather than hiding it.
            sys = struct();
            sys.name    = sprintf('Henon-Heiles (E_esc = 1/6)');
            sys.nq      = 2;
            sys.gamma   = 0;
            sys.params  = struct();
            sys.force   = @(q,t) henon_force(q);
            sys.dforce  = @(q,t) henon_dforce(q);
            sys.d2force = @(q,t) henon_d2force(q);
            sys.energy  = @(y,t) 0.5*(y(3,:).^2 + y(4,:).^2 + y(1,:).^2 + y(2,:).^2) ...
                                 + y(1,:).^2.*y(2,:) - y(2,:).^3/3;

        otherwise
            error('sp_sys:kind', 'unknown system "%s" (use pendulum | coupled | henonheiles)', kind);
    end

    sys.ndof = 2*sys.nq;
end


% =========================================================================
function f = coupled_force(q, p)
%% F = -grad V, evaluated for all columns of q at once (2 x N).
    x = q(1,:);   y = q(2,:);
    sx = sin(x);  sy = sin(y);
    cx = cos(x);  cy = cos(y);
    ab = p.a*p.b;
    fx = -(1 + ab)*sx + ab*sx.*cy;
    fy = -p.a*sy + ab*cx.*sy;
    f = [fx; fy];
end


function J = coupled_dforce(q, p)
%% J = -hess V, returned as 2 x 2 x N so the tangent kick is a page-multiply.
    x = q(1,:);   y = q(2,:);
    sx = sin(x);  sy = sin(y);
    cx = cos(x);  cy = cos(y);
    ab = p.a*p.b;
    n  = numel(x);

    hxx = (1 + ab)*cx - ab*cx.*cy;
    hxy = ab*sx.*sy;
    hyy = p.a*cy - ab*cx.*cy;

    J = zeros(2, 2, n);
    J(1,1,:) = -reshape(hxx, 1, 1, n);
    J(1,2,:) = -reshape(hxy, 1, 1, n);
    J(2,1,:) = -reshape(hxy, 1, 1, n);
    J(2,2,:) = -reshape(hyy, 1, 1, n);
end


% =========================================================================
function J = coupled_d2force(q, p)
%% J = -d3 V, returned as 2 x 2 x 2 x N with indices (j, k, l).
%
%%   d2force(j,k,l) = d2(force_j) / dq_k dq_l = -V_jkl .
%%
%%   Because the Hessian of V is symmetric, only four distinct entries occur;
%%   they are written out rather than generated, and cross-checked against
%%   central differences of sys.dforce in tests/test_indicators.m.
    x = q(1,:);   y = q(2,:);
    sx = sin(x);  sy = sin(y);
    cx = cos(x);  cy = cos(y);
    ab = p.a*p.b;
    n  = numel(x);

    % V_xxx, V_xxy, V_xyy, V_yyy
    vxxx = (1 + ab)*sx - ab*sx.*cy;
    vxxy = ab*cx.*sy;
    vxyy = ab*sx.*cy;
    vyyy = -p.a*sy + ab*cx.*sy;

    J = zeros(2, 2, 2, n);
    % j = 1 (x-component of the force): d2(force_1)/dq_k dq_l = -V_1kl
    %   force_1 = -V_x = -[(1+ab)sin x - ab sin x cos y]
    %   d2(force_1)/dx2 = (1+ab)sin x - ab sin x cos y = +vxxx   <- note the sign
    %   (V_xxx = -vxxx, so -V_xxx = +vxxx; getting this backwards is easy and the
    %    cross-check in tests/test_indicators.m is what pins it.)
    J(1,1,1,:) = reshape(vxxx, 1, 1, 1, n);
    J(1,1,2,:) = -reshape(vxxy, 1, 1, 1, n);
    J(1,2,1,:) = -reshape(vxxy, 1, 1, 1, n);
    J(1,2,2,:) = -reshape(vxyy, 1, 1, 1, n);
    % j = 2 (y-component): d2(force_2)/dq_k dq_l = -V_2kl
    J(2,1,1,:) = -reshape(vxxy, 1, 1, 1, n);
    J(2,1,2,:) = -reshape(vxyy, 1, 1, 1, n);
    J(2,2,1,:) = -reshape(vxyy, 1, 1, 1, n);
    J(2,2,2,:) = -reshape(vyyy, 1, 1, 1, n);
end


% =========================================================================
function f = henon_force(q)
%% F = -grad V for the Henon-Heiles potential, evaluated for all columns.
%%   V(x,y) = (x^2+y^2)/2 + x^2 y - y^3/3
%%   grad V = [ x + 2xy ; y + x^2 - y^2 ]
    x = q(1,:);   y = q(2,:);
    f = [ -(x + 2*x.*y) ; -(y + x.^2 - y.^2) ];
end


% =========================================================================
function J = henon_dforce(q)
%% J = -hess V, returned as 2 x 2 x N.
%%   hess V = [ 1 + 2y ,  2x  ;
%%              2x     , 1 - 2y ]
    x = q(1,:);   y = q(2,:);
    n = numel(x);
    J = zeros(2, 2, n);
    J(1,1,:) = reshape(-(1 + 2*y), 1, 1, n);
    J(1,2,:) = reshape(-2*x,       1, 1, n);
    J(2,1,:) = reshape(-2*x,       1, 1, n);
    J(2,2,:) = reshape(-(1 - 2*y), 1, 1, n);
end


% =========================================================================
function J = henon_d2force(q)
%% J = -d3 V, returned as 2 x 2 x 2 x N with indices (j, k, l).
%%
%%   d2(force_j)/dq_k dq_l = -V_jkl.  Writing the derivatives out:
%%
%%     force_1 = -V_x = -(x + 2xy)
%%         d2(force_1)/dx dy = d2(force_1)/dy dx = -2
%%     force_2 = -V_y = -(y + x^2 - y^2)
%%         d2(force_2)/dx dx = -2
%%         d2(force_2)/dy dy = +2
%%
%%   THE d2(force_2)/dx dx = -2 TERM IS EASY TO MISS.  It comes from
%%   d(force_2)/dx = -2x, whose x-derivative is -2 -- a pure second derivative
%%   with no cross term in it.  A first version of this function listed only the
%%   mixed entries plus V_yyy, and the finite-difference cross-check in
%%   tests/test_henon_heiles.m caught it at once (residual exactly 2.0, the size
%%   of the missing entry).  This is the derivative sp_ofli2.m consumes, so an
%%   error here corrupts OFLI2 with no other symptom.
    n = numel(q(1,:));
    J = zeros(2, 2, 2, n);
    % j = 1 (x-force): the two mixed entries, (k,l) = (2,1) and (1,2)
    J(1,2,1,:) = -2;
    J(1,1,2,:) = -2;
    % j = 2 (y-force): the xx entry and the yy entry
    J(2,1,1,:) = -2;
    J(2,2,2,:) = +2;
end


function o = sp_optset(defaults, varargin)
%% SP_OPTSET  Merge name-value pairs into a defaults struct, rejecting typos.
%%
%%   Unknown names raise an error instead of being silently dropped: a typo
%%   like 'gam' would otherwise leave the default in place and quietly produce
%%   a different physical system than the caller asked for.
    o = defaults;
    if isempty(varargin), return; end
    if numel(varargin) == 1 && isstruct(varargin{1})
        f = fieldnames(varargin{1});
        for k = 1:numel(f)
            o = set_one(o, f{k}, varargin{1}.(f{k}));
        end
        return
    end
    if mod(numel(varargin), 2) ~= 0
        error('sp_sys:opt', 'options must come in name-value pairs');
    end
    for k = 1:2:numel(varargin)
        o = set_one(o, varargin{k}, varargin{k+1});
    end
end


function o = set_one(o, nm, val)
    if ~isfield(o, nm)
        error('sp_sys:opt', 'unknown option "%s"', nm);
    end
    o.(nm) = val;
end
