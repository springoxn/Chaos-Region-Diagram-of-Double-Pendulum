function diag_megno()
%% DIAG_MEGNO  Measure what the MEGNO accumulation actually does. ASCII only.
%
%   Three candidate accumulations are compared on the SAME deviation-vector
%   growth record, so the difference between them is isolated from the
%   integration:
%
%     A  Eq.(4)-(5) as written:  Y(k) = (1/k) sum_j j ln r_j ; Ybar = mean_k Y(k)
%     B  the "standard" MEGNO:   Y = (2/n) sum_{j<=n} j ln r_j,  reported directly
%     C  the plain mean of 2 ln r_j  (no weight)
%
%   The paper's Eq. (6) claims to be a running form of (4)-(5); the factor 2 and
%   the placement of the weights decide whether regular motion converges to 2 or
%   to 0.6, so this is settled by measurement.
    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);

    fprintf('=== candidate A: paper Eq.(4)-(5) literally ===\n');
    fprintf('  Y(k) = (1/k) sum_{j=1..k} j*ln r_j ;  Ybar(n) = (1/n) sum_{k<=n} Y(k)\n');
    test_case('integrable  b=0', sp_sys('coupled','a',4,'b',0), [0.9;1.3;0;0]);
    test_case('chaotic      b=1', sp_sys('coupled','a',4,'b',1), [-3.0;1.3;0;0.2]);

    fprintf('\n=== candidate B: Y = (2/n) sum_{j<=n} j*ln r_j  (running, factor 2) ===\n');
    test_case2('integrable  b=0', sp_sys('coupled','a',4,'b',0), [0.9;1.3;0;0]);
    test_case2('chaotic      b=1', sp_sys('coupled','a',4,'b',1), [-3.0;1.3;0;0.2]);

    fprintf('\n=== candidate C: mean of 2*ln r_j  (no weight) ===\n');
    test_case3('integrable  b=0', sp_sys('coupled','a',4,'b',0), [0.9;1.3;0;0]);
    test_case3('chaotic      b=1', sp_sys('coupled','a',4,'b',1), [-3.0;1.3;0;0.2]);

    fprintf('\n=== is the growth per step really 1/k for a regular orbit? ===\n');
    % Theory: for regular motion ln||n(t)|| ~ ln t + const, so over a step at
    % time t the increment is ~ h/t, i.e. ln r_j ~ 1/j.  Then j*ln r_j ~ 1 and
    % the running mean of 2*j*ln r_j tends to 2.  This is the mechanism; verify
    % it directly rather than inferring it from the indicator.
    sys = sp_sys('coupled','a',4,'b',0);
    y = [0.9;1.3;0;0]; V = reshape([1;0;0;0],4,1,1); t = 0;
    dt = 0.02; n = 20000;
    jl = zeros(1,n);
    for k = 1:n
        [y, V, g, t] = sp_step(y, V, t, dt, sys, 4);
        jl(k) = log(g(1));
    end
    idx = [100 500 2000 8000 20000];
    fprintf('    step j    ln r_j      j*ln r_j    2*j*ln r_j\n');
    for j = idx
        fprintf('    %6d  %10.3e %10.4f %10.4f\n', j, jl(j), j*jl(j), 2*j*jl(j));
    end
    fprintf('    mean of 2*j*ln r_j over the last half = %.4f\n', ...
            mean(2*(round(n/2):n).*jl(round(n/2):n)));
end


function test_case(name, sys, y0)
    [Ybar, Yend] = megno_variant(sys, y0, 1);
    fprintf('  %-18s Ybar = %10.4f   Y(n) = %10.4f\n', name, Ybar, Yend);
end
function test_case2(name, sys, y0)
    [~, Yend] = megno_variant(sys, y0, 2);
    fprintf('  %-18s Y = %10.4f\n', name, Yend);
end
function test_case3(name, sys, y0)
    [~, Yend] = megno_variant(sys, y0, 3);
    fprintf('  %-18s Y = %10.4f\n', name, Yend);
end


function [Ybar, Ylast] = megno_variant(sys, y0, which)
    dt = 0.02; T = 400; n = round(T/dt);
    y = y0; V = reshape([1;0;0;0],4,1,1); t = 0;
    ntr = round(0.1*n);
    Ybar = 0; Ylast = 0; nk = 0;
    YsumW = 0; nW = 0; accC = 0;
    for k = 1:n
        [y, V, g, t] = sp_step(y, V, t, dt, sys, 4);
        if k <= ntr, continue; end
        lr = log(g(1));
        switch which
            case 1
                % Eq.(5): Y(k) = (1/k) sum_{j<=k} j ln r_j, then mean over k
                nk = nk + 1;
                YsumW = YsumW + k*lr;
                Yk = YsumW / k;
                Ybar = ((nk-1)*Ybar + Yk)/nk;
                Ylast = Yk;
            case 2
                nW = nW + 1;
                YsumW = YsumW + k*lr;
                Ylast = 2*YsumW/nW;
            case 3
                accC = accC + 2*lr;  nW = nW + 1;
                Ylast = accC/nW;
        end
    end
end
