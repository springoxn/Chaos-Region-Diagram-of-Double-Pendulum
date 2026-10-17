function diag_ofli2()
%% DIAG_OFLI2  Verify the OFLI2 implementation. ASCII only.
%
%   Checks:
%     A  d2force of both systems vs central differences of dforce
%     B  OFLI2 on a harmonic oscillator, where the variation is EXACTLY the
%        flow direction plus a constant, so the projected combination stays
%        bounded and OFLI2 must NOT grow exponentially
%     C  OFLI2 on the integrable coupled pendulum (b=0) vs the chaotic case
%        (b=1) -- the paper's Fig. 6 / 4 contrast
    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    rng(5);

    fprintf('--- A: d3 V (d2force) vs central differences of dforce ---\n');
    eps = 1e-5;
    systems = { sp_sys('pendulum','F',1.5,'gamma',0,'Omega',2/3), ...
                sp_sys('coupled','a',4,'b',1) };
    for s = 1:numel(systems)
        sys = systems{s};
        nq = sys.nq;
        q0 = (rand(nq,1) - 0.5) * 3;
        H2 = sys.d2force(q0, 0);
        err = 0;
        for k = 1:nq
            for l = 1:nq
                e = zeros(nq,1);
                e(l) = eps;
                fd = (sys.dforce(q0 + e, 0) - sys.dforce(q0 - e, 0)) / (2*eps);
                % fd is nq x nq; column k of dforce is d(force)/dq_k
                for j = 1:nq
                    a = H2(j,k,l);
                    if ndims(H2) == 4
                        a = H2(j,k,l,1);
                    end
                    err = max(err, abs(a - fd(j,k)));
                end
            end
        end
        fprintf('  %-28s max|d2force - FD(dforce)| = %.2e\n', sys.name, err);
    end

    fprintf('\n--- B: harmonic oscillator OFLI2 must stay bounded ---\n');
    sysH = harm_sys();
    for T = [50 100 200]
        [v, inf] = sp_ofli2(sysH, [1.0; 0.0], struct('T',T,'dt',0.005,'order',4));
        fprintf('  T=%4d : OFLI2 = %+.5f  (must not grow with T)\n', T, v(1));
    end

    fprintf('\n--- C: coupled pendulum, integrable vs chaotic ---\n');
    sysI = sp_sys('coupled','a',4,'b',0);
    sysC = sp_sys('coupled','a',4,'b',1);
    Y = [0.9, -3.0, 1.7; 1.3, 1.3, 1.3; 0.0, 0.0, 0.0; 0.0, 0.2, 0.2];
    for T = [100 200 400]
        [vi, ~] = sp_ofli2(sysI, Y(:,1), struct('T',T,'dt',0.01,'order',4));
        [vc, ~] = sp_ofli2(sysC, Y(:,2), struct('T',T,'dt',0.01,'order',4));
        fprintf('  T=%4d : integrable OFLI2 = %8.3f   chaotic OFLI2 = %8.3f\n', ...
                T, vi(1), vc(1));
    end

    fprintf('\n--- D: is the growth exponential for chaos? ---\n');
    % The slope of OFLI2 vs t should approach lambda_1 for a chaotic orbit if
    % OFLI2 is behaving as a Lyapunov-type indicator.  Measured, not assumed.
    sysC2 = sp_sys('coupled','a',4,'b',1);
    y0 = Y(:,2);
    T = 400; dt = 0.01;
    ofli = zeros(1, T/dt);
    % manual loop so the time series is available
    nq = sysC2.nq;
    [~, f0] = fp(y0, sysC2, 0);
    Nm = f0/norm(f0); Dm = zeros(4,1); Yc = y0; t = 0;
    for k = 1:(T/dt)
        [Yc, Nm, Dm, t] = aug(Yc, Nm, Dm, t, dt, sysC2, 4);
        [fc, ~] = fp(Yc, sysC2, t);
        comb = Nm + 0.5*Dm;
        nf = norm(fc);
        if nf > 0, comb = comb - (comb'*fc/nf^2)*fc; end
        if norm(comb) > 0, ofli(k) = log(norm(comb)); end
    end
    tt = (1:numel(ofli))*dt;
    idx = ofli > 0;
    if sum(idx) > 50
        ii = find(idx);
        i2 = ii(round(numel(ii)/4):round(numel(ii)*3/4));
        pp = polyfit(tt(i2), ofli(i2), 1);
        fprintf('  fitted d(OFLI2)/dt = %.4f   (lambda_1 of this orbit ~ 0.70)\n', pp(1));
    end
end


function sys = harm_sys()
    sys = struct();
    sys.name   = 'harmonic oscillator';
    sys.nq     = 1;
    sys.gamma  = 0;
    sys.params = struct();
    sys.force   = @(q,t) -q;
    sys.dforce  = @(q,t) reshape(-ones(1, numel(q)), 1, 1, numel(q));
    sys.d2force = @(q,t) zeros(1,1,1,numel(q));
    sys.energy  = @(y,t) 0.5*(y(1,:).^2 + y(2,:).^2);
    sys.ndof   = 2;
end


function [F, Fq] = fp(Y, sys, t)
    nq = sys.nq;
    F = [Y(nq+1:end); sys.force(Y(1:nq,:), t)];
    Fq = F;
end


function [Y, Nm, Dm, t] = aug(Y, Nm, Dm, t, h, sys, order)
    w = sp_weights(order); m = numel(w); nq = sys.nq;
    [Y,Nm,Dm] = hk(Y,Nm,Dm,t,(w(1)/2)*h,sys);
    for i = 1:m
        c = w(i);
        Y(1:nq)  = Y(1:nq)  + (c*h)*Y(nq+1:end);
        Nm(1:nq) = Nm(1:nq) + (c*h)*Nm(nq+1:end);
        Dm(1:nq) = Dm(1:nq) + (c*h)*Dm(nq+1:end);
        t = t + c*h;
        if i < m, ck = (w(i)+w(i+1))/2; else, ck = w(m)/2; end
        [Y,Nm,Dm] = hk(Y,Nm,Dm,t,ck*h,sys);
    end
end


function [Y, Nm, Dm] = hk(Y, Nm, Dm, t, c, sys)
    nq = sys.nq;
    q = Y(1:nq);
    Y(nq+1:end) = Y(nq+1:end) + c*sys.force(q,t);
    J = sys.dforce(q,t);
    J = reshape(J, nq, nq);
    Nm(nq+1:end) = Nm(nq+1:end) + c*(J*Nm(1:nq));
    H2 = sys.d2force(q,t);
    Q = zeros(nq,1);
    for j = 1:nq
        acc = 0;
        for k = 1:nq
            for l = 1:nq
                acc = acc + H2(j,k,l,1)*Nm(k)*Nm(l);
            end
        end
        Q(j) = acc;
    end
    Dm(nq+1:end) = Dm(nq+1:end) + c*(J*Dm(1:nq) + Q);
end
