function varargout = dp_canon_convert(y, p, direction)
%% DP_CANON_CONVERT  Convert between the project's (theta, omega) layout and
%%                   canonical (theta, p) variables.
%%
%%   z = dp_canon_convert(y, p, 'to_canon')
%%   y = dp_canon_convert(z, p, 'from_canon')
%%
%%   Layouts
%%   -------
%%     y = [th1; om1; th2; om2]     used by dp_field_dyn.m, dp_rk4_step.m and
%%                                  the whole existing dp_v2 kernel
%%     z = [th1; th2; p1;  p2 ]     canonical; p = M(q) omega
%%
%%   Both are 4 x N, so a whole grid row converts in one call.
%%
%%   WHY BOTH LAYOUTS EXIST
%%   ----------------------
%%   (q, omega) is the natural way to write the double pendulum's equations and
%%   is what the existing kernel uses.  (q, p) is the only layout in which the
%%   naive symplectic form [[0,I],[-I,0]] is correct, because omega is NOT the
%%   canonical momentum.  dp_imp_step.m integrates in (q,p) and
%%   dp_imp_step_project.m wraps it back to (q, omega) for callers that want
%%   the project layout.
%%
%%   The transformation is a diffeomorphism, so the two descriptions have
%%   conjugate tangent dynamics.  GALI and SALI are invariant under an
%%   invertible linear map applied to all deviation vectors, so the alignment
%%   indices are IDENTICAL in either layout; the Lyapunov exponents are too,
%%   being asymptotic growth rates.  Only the raw vector components differ.
%%
%%   See also dp_imp_step, dp_mass.

    switch lower(direction)
        case 'to_canon'
            % p = M(q) * omega
            th1 = y(1,:);  om1 = y(2,:);
            th2 = y(3,:);  om2 = y(4,:);
            z = zeros(4, size(y,2));
            z(1,:) = th1;
            z(2,:) = th2;
            for c = 1:size(y,2)
                M = dp_mass(th1(c), th2(c), p);
                z(3:4,c) = M * [om1(c); om2(c)];
            end
            varargout{1} = z;

        case 'from_canon'
            % omega = M(q)^-1 * p
            th1 = y(1,:);  th2 = y(2,:);
            p1  = y(3,:);  p2  = y(4,:);
            w = zeros(4, size(y,2));
            w(1,:) = th1;
            w(3,:) = th2;
            for c = 1:size(y,2)
                [~, A] = dp_mass(th1(c), th2(c), p);
                w(2:2:4,c) = A * [p1(c); p2(c)];
            end
            varargout{1} = w;

        otherwise
            error('dp_canon_convert:dir', ...
                  'direction must be ''to_canon'' or ''from_canon''');
    end
end
