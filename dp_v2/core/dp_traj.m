function yEnd = dp_traj(y0, T, dt, p)
%% DP_TRAJ  Integrate the double pendulum for time T and return the final state.
%%
%%   yEnd = dp_traj(y0, T, dt, p)
%%
%%   Thin wrapper over dp_rk4_step.  Exists so that scripts and tests that only
%%   need a trajectory do not have to re-implement the loop -- and so that the
%%   integration scheme has exactly one definition in the codebase.

    p = dp_check_params(p);
    yEnd = y0(:);
    n = round(T / dt);
    for k = 1:n
        yEnd = dp_rk4_step(yEnd, dt, p);
    end
end
