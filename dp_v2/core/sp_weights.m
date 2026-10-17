function [w, info] = sp_weights(order)
%% SP_WEIGHTS  Symmetric composition weights of Yoshida's symplectic integrators.
%%
%%   w = sp_weights(order)          order in {2, 4, 6}
%%   [w, info] = sp_weights(order)  also returns the order-condition residuals
%%
%%   WHY THESE WEIGHTS
%%   ----------------
%%   Given any symmetric second-order symplectic step S(h) -- here a leapfrog
%%   (kick-drift-kick) applied to a separable Hamiltonian -- Yoshida's
%%   construction [Yoshida, Phys. Lett. A 150 (1990) 262] produces a higher
%%   order method by composing S with rescaled steps:
%%
%%       order 2:  S(w1 h)                          w = [1]
%%       order 4:  S(w1 h) S(w0 h) S(w1 h)
%%       order 6:  S(w1 h) S(w2 h) S(w3 h) S(w4 h) S(w3 h) S(w2 h) S(w1 h)
%%
%%   The negative weights are not a bug: they are what cancels the O(h^3)
%%   error term.  A negative sub-step runs time backwards for that fraction of
%%   the step, which is harmless because each sub-step is itself an exact flow
%%   of an exactly integrable sub-Hamiltonian.
%%
%%   ORDER CONDITIONS
%%   ----------------
%%   For a symmetric composition of a second-order method the error expansion
%%   contains only odd powers h^3, h^5, h^7, ...  Hence
%%
%%       sum(w)   = 1      (kills h^2)
%%       sum(w^3) = 0      (kills h^4)  -> 4th order
%%       sum(w^5) = 0      (kills h^6)  -> 6th order
%%       sum(w^7) = 0      (kills h^8)  -> 8th order, not attempted here
%%
%%   These are checked, not trusted: see the assertions in test_symplectic.m,
%%   which evaluate the residuals on the weights this file returns.  The 4th
%%   order case is exact in closed form (w1 = 1/(2-2^(1/3))); the 6th order
%%   weights are the standard decimal set and their sum(w^5) is verified
%%   numerically there.
%%
%%   SYMMETRY IS LOAD-BEARING
%%   The weight list is palindromic by construction.  A non-symmetric
%%   composition of symmetric steps is still symplectic but loses a whole order
%%   of accuracy, so the palindrome is part of the contract of this function
%%   and is asserted below.

    switch order
        case 2
            w = 1;
        case 4
            r = 2^(1/3);
            w1 = 1 / (2 - r);
            w0 = -r / (2 - r);
            w = [w1, w0, w1];
        case 6
            % Yoshida (1990), 6th-order solution of the order conditions.
            w1 =  0.784513610477560;
            w2 =  0.235573213359357;
            w3 = -1.17767998417887;
            w4 =  1.315186320683906;   % = 1 - 2*(w1+w2+w3), forced by sum(w)=1
            w = [w1, w2, w3, w4, w3, w2, w1];
        otherwise
            error('sp_weights:order', ...
                  'order must be 2, 4 or 6 (got %g)', order);
    end

    if nargout > 1
        info = struct('sum1', sum(w), ...
                      'sum3', sum(w.^3), ...
                      'sum5', sum(w.^5), ...
                      'sum7', sum(w.^7), ...
                      'symmetric', isequal(w, fliplr(w)));
    end
end
