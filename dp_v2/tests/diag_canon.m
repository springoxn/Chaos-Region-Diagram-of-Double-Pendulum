function diag_canon()
%% DIAG_CANON  Verify the canonical-variable machinery in isolation. ASCII only.
%
%   Checks, in order of increasing strength:
%     A  dp_mass inverse and positive determinant
%     B  dp_canon_convert round trip
%     C  dp_canon_jac vs central differences of dp_canon_convert
%     D  dp_canon_rhs reproduces the project's equations of motion
%     E  dp_canon_rhs Jacobian vs central differences
%     F  symplecticity of one implicit step, w.r.t. the CANONICAL form
%     G  convergence order in canonical variables
    core = fullfile(fileparts(mfilename('fullpath')), '..', 'core');
    addpath(core);
    p = struct('m1',1, 'm2',1, 'L1',1, 'L2',1, 'g',9.81);

    fprintf('--- A: mass matrix ---\n');
    for th = [0.7, 2.1, 0.0]
        for t2 = [0.9, -0.6, pi]
            [M, A, detM] = dp_mass(th, t2, p);
            fprintf('  th=(%.1f,%.1f) det=%.6f  |M*A - I|=%.2e\n', th, t2, detM, ...
                max(max(abs(M*A - eye(2)))));
        end
    end

    fprintf('\n--- B: convert round trip ---\n');
    y = [0.7; -0.4; 0.9; 0.3];
    z = dp_canon_convert(y, p, 'to_canon');
    yb = dp_canon_convert(z, p, 'from_canon');
    fprintf('  max|y - roundtrip| = %.2e\n', max(abs(y - yb)));
    fprintf('  z = %s\n', mat2str(z', 8));

    fprintf('\n--- C: dp_canon_jac vs central differences ---\n');
    eps = 1e-7; Jnum = zeros(4,4);
    for j = 1:4
        e = zeros(4,1); e(j) = eps;
        Jnum(:,j) = (dp_canon_convert(y+e,p,'to_canon') - dp_canon_convert(y-e,p,'to_canon'))/(2*eps);
    end
    [Jz, Tinv] = dp_canon_jac(y, p);
    fprintf('  max|Jz - Jnum| = %.2e\n', max(max(abs(Jz - Jnum))));
    fprintf('  max|Jz*Tinv - I| = %.2e\n', max(max(abs(Jz*Tinv - eye(4)))));

    fprintf('\n--- D: dp_canon_rhs vs dp_field_dyn ---\n');
    F = dp_canon_rhs(z, p);
    fproj = dp_field_dyn(y, p);
    % convert the canonical field back to the (q, omega) field
    [~, Ty] = dp_canon_jac(y, p);
    fback = Ty * F;
    fprintf('  max|Ty*F_canon - f_project| = %.2e\n', max(abs(fback - fproj)));

    fprintf('\n--- E: dp_canon_rhs Jacobian vs central differences ---\n');
    [~, Jc] = dp_canon_rhs(z, p);
    Jfd = zeros(4,4);
    for j = 1:4
        e = zeros(4,1); e(j) = eps;
        Jfd(:,j) = (dp_canon_rhs(z+e,p) - dp_canon_rhs(z-e,p))/(2*eps);
    end
    fprintf('  max|J_canon - J_fd| = %.2e\n', max(max(abs(Jc - Jfd))));
    fprintf('  (scale: max|J_canon| = %.3f)\n', max(max(abs(Jc))));

    fprintf('\n--- F: symplecticity of one canonical midpoint step ---\n');
    Jn = zeros(4,4); Jn(1:2,3:4) = eye(2); Jn(3:4,1:2) = -eye(2);
    h = 0.05;
    Phi = zeros(4,4);
    for j = 1:4
        e = zeros(4,1); e(j) = 1;
        [~, Qj] = dp_imp_canon(z, reshape(e,4,1,1), 0, h, p, 2, false);
        Phi(:,j) = Qj(:,1,1);
    end
    fprintf('  order2 max|Phi''JPhi - J| = %.2e\n', max(max(abs(Phi'*Jn*Phi - Jn))));
    Phi4 = zeros(4,4);
    for j = 1:4
        e = zeros(4,1); e(j) = 1;
        [~, Qj] = dp_imp_canon(z, reshape(e,4,1,1), 0, h, p, 4, false);
        Phi4(:,j) = Qj(:,1,1);
    end
    fprintf('  order4 max|Phi''JPhi - J| = %.2e\n', max(max(abs(Phi4'*Jn*Phi4 - Jn))));

    fprintf('\n--- G: canonical convergence order ---\n');
    z0 = dp_canon_convert([1.0; 0.5; 0.0; 0.0], p, 'to_canon');
    zref = stepn(z0, 20, 1e-4, p, 4);
    for o = [2 4]
        errs = zeros(1,3); kk = 0;
        for hh = [0.04 0.02 0.01]
            kk = kk + 1;
            errs(kk) = max(abs(stepn(z0, 20, hh, p, o) - zref));
        end
        fprintf('  order %d: errs = %.2e %.2e %.2e  ratios = %.1f %.1f\n', ...
            o, errs, errs(1)/errs(2), errs(2)/errs(3));
    end

    fprintf('\n--- H: wrapper dp_imp_step fixes the (q,omega) symplecticity? ---\n');
    yy = [0.7; -0.4; 0.9; 0.3];
    yref2 = [1.0; 0.5; 0.0; 0.0];
    za = dp_canon_convert(yy, p, 'to_canon');
    zb = stepn(za, 20, 0.01, p, 2);
    yb2 = dp_canon_convert(zb, p, 'from_canon');
    fprintf('  |canonical vs wrapper| at T=20 h=0.01 = %.3e\n', max(abs(yb2 - stepn_proj(yref2, 20, 0.01, p, 2))));
end


function z = stepn(z0, tend, h, p, order)
    n = round(tend/h); z = z0;
    for k = 1:n
        [z, ~, ~, ~] = dp_imp_canon(z, [], 0, h, p, order);
    end
end


function y = stepn_proj(y0, tend, h, p, order)
    n = round(tend/h); y = y0;
    for k = 1:n
        [y, ~, ~, ~] = dp_imp_step(y, [], 0, h, p, order);
    end
end
