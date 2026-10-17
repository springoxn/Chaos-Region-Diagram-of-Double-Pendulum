function diag_drift()
% What energy drift does the row integrator actually produce, and does it
% scale as dt^4?  Absolute thresholds are meaningless without the energy scale,
% since the (theta1,theta2) grid spans E from -30 to +30 J.
    addpath(fullfile(fileparts(mfilename('fullpath')),'..','core'));
    p = dp_check_params(struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));
    th = linspace(-pi,pi,16);
    fprintf('grid spans |E| up to %.1f J\n\n', abs(-9.81*(2*cos(0)+cos(pi))));

    fprintf('%8s %14s %14s %10s\n','dt','max |dE|','max rel dE','scaling');
    prevAbs = NaN; prevDt = NaN;
    for dt = [0.04 0.02 0.01 0.005 0.0025]
        [~, drift] = dp_lyap_row(th, th, 30, dt, p, struct('transient',9));
        E0 = -9.81*(2*cos(th) + cos(th));
        rel = drift ./ abs(E0);
        sc = NaN;
        if ~isnan(prevAbs)
            sc = log(prevAbs/max(drift)) / log(prevDt/dt);
        end
        fprintf('%8.4f %14.3e %14.3e %10s\n', dt, max(drift), max(rel), ...
                ternary(isnan(sc), '-', sprintf('%.2f', sc)));
        prevAbs = max(drift); prevDt = dt;
    end
    fprintf('\n(4th-order RK4 => scaling should approach 4)\n');
end

function s = ternary(c,a,b)
    if c, s=a; else, s=b; end
end
