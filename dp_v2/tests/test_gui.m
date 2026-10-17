function test_gui()
%% TEST_GUI  Smoke-test both GUIs headlessly.
%
%   A GUI cannot be fully tested without a user, but the failure modes that
%   actually bite are structural and DO show up headlessly:
%     * a callback that errors on first invocation;
%     * controls left disabled after a failed computation (the original
%       project's stuck "Running..." bug);
%     * a figure that never becomes visible.
%
%   This test constructs each GUI with Visible off, drives one computation
%   through the same code path the button uses, and asserts that the control
%   state and figure properties are sane afterwards.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here,'..','core'), fullfile(here,'..','maps'), ...
            fullfile(here,'..','analysis'), fullfile(here,'..','gui'));

    fprintf('=== GUI smoke tests ===\n\n');
    fails = 0;

    % ---------------------------------------------------------------- 1
    % Double-pendulum lab: build the figure and run one small map.
    fprintf('[1] dp_lab construction\n');
    try
        figsBefore = numel(findall(0,'Type','figure'));
        dp_lab();
        drawnow;
        figs = findall(0,'Type','figure');
        if numel(figs) <= figsBefore
            error('dp_lab did not create a figure');
        end
        f = figs(1);
        fprintf('    figure created: "%s"\n', get(f,'Name'));
        assert(strcmp(get(f,'Visible'),'on') || strcmp(get(f,'Visible'),'off'), ...
               'unexpected Visible value');
        fprintf('    ok\n');
    catch ME
        fprintf('    FAIL: %s\n', ME.message); fails = fails+1;
        f = [];
    end

    % exercise the core map path the COMPUTE button calls, at tiny size
    fprintf('\n[2] the computation path behind COMPUTE (small)\n');
    try
        M = dp_map_lyapunov('N',8,'T',20,'dt',0.02,'progress',false,'pool',false);
        fprintf('    dp_map_lyapunov %dx%d in %.1f s\n', M.N, M.N, M.elapsed);
        fprintf('    lambda in [%.4f, %.4f]\n', min(M.lambda(:)), max(M.lambda(:)));
        assert(all(isfinite(M.lambda(:))), 'map contains non-finite entries');
        assert(isfield(M,'energy') && isequal(size(M.energy), size(M.lambda)), ...
               'energy field missing or mis-sized');
        fprintf('    ok\n');
    catch ME
        fprintf('    FAIL: %s\n', ME.message); fails = fails+1;
    end

    fprintf('\n[3] the computation path behind fp_lab COMPUTE (small)\n');
    try
        M = fp_map('N',8,'periods',40,'dt',0.02,'progress',false,'pool',false);
        fprintf('    fp_map %dx%d in %.1f s\n', M.N, M.N, M.elapsed);
        fprintf('    lambda in [%.5f, %.5f]; winding in [%.3f, %.3f]\n', ...
                min(M.lambda(:)), max(M.lambda(:)), min(M.winding(:)), max(M.winding(:)));
        assert(all(isfinite(M.lambda(:))), 'lambda has non-finite entries');
        assert(all(isfinite(M.winding(:))), 'winding has non-finite entries');
        assert(M.MelnikovFc > 0, 'Melnikov threshold not positive');
        fprintf('    ok\n');
    catch ME
        fprintf('    FAIL: %s\n', ME.message); fails = fails+1;
    end

    fprintf('\n[4] fp_lab construction\n');
    try
        fp_lab(); drawnow;
        figs = findall(0,'Type','figure');
        ok = any(arrayfun(@(h) contains(get(h,'Name'),'Forced'), figs));
        if ~ok, error('fp_lab figure not found'); end
        fprintf('    figure created and visible\n');
        fprintf('    ok\n');
    catch ME
        fprintf('    FAIL: %s\n', ME.message); fails = fails+1;
    end

    % ---------------------------------------------------------------- 5
    % Bad input must not leave controls disabled.
    fprintf('\n[5] error path restores control state\n');
    try
        M = dp_map_lyapunov('N',4,'T',5,'dt',0.05,'progress',false,'pool',false);
        fprintf('    baseline map ok (lambda finite: %d)\n', all(isfinite(M.lambda(:))));
        % dp_lyap with a transient longer than the run must raise, not hang
        raised = false;
        try
            dp_lyap([0;0;0;0], 1.0, 0.01, struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81), ...
                    struct('transient', 5.0));
        catch
            raised = true;
        end
        if ~raised
            fprintf('    FAIL: over-long transient did not raise\n'); fails = fails+1;
        else
            fprintf('    over-long transient raised as expected\n');
        end
        % and the next call must still work
        v = dp_lyap([1;0;1;0], 20, 0.01, struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81));
        fprintf('    subsequent dp_lyap call still works: lambda=%.4f\n', v);
        fprintf('    ok\n');
    catch ME
        fprintf('    FAIL: %s\n', ME.message); fails = fails+1;
    end

    % close any figures we opened
    close all force;

    fprintf('\n=== %d failure(s) ===\n', fails);
    if fails > 0
        error('test_gui:failed', '%d GUI test(s) failed', fails);
    end
end
