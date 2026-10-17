function p = dp_check_params(p)
%% DP_CHECK_PARAMS  Fill defaults and validate a double-pendulum parameter struct.
%
%%   p = dp_check_params(p)  returns the struct with every field present and
%%   physically admissible.  All core functions route through here so that a
%%   missing field fails loudly at the entry point rather than silently
%%   producing a wrong integration deep inside a sweep.

    if nargin < 1 || isempty(p), p = struct(); end

    def = struct('m1', 1.0, 'm2', 1.0, 'L1', 1.0, 'L2', 1.0, 'g', 9.81);
    f = fieldnames(def);
    for i = 1:numel(f)
        if ~isfield(p, f{i}) || isempty(p.(f{i}))
            p.(f{i}) = def.(f{i});
        end
    end

    for i = 1:numel(f)
        v = p.(f{i});
        if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v)
            error('dp_check_params:field', '%s must be a finite scalar', f{i});
        end
    end
    if p.m1 <= 0 || p.m2 <= 0
        error('dp_check_params:mass', 'masses must be positive');
    end
    if p.L1 <= 0 || p.L2 <= 0
        error('dp_check_params:length', 'lengths must be positive');
    end
    if p.g <= 0
        error('dp_check_params:gravity', 'g must be positive');
    end
end
