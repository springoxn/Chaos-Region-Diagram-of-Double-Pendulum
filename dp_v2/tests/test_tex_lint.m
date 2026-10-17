function test_tex_lint()
%% TEST_TEX_LINT  Find TeX escapes that MATLAB would render as missing glyphs.
%%
%%   MATLAB's default text Interpreter is 'tex', which supports only a subset
%%   of LaTeX.  An unsupported command renders as a missing-glyph box.  In this
%%   project '\approx' produced the literal "w □pprox +2" in a figure title.
%%
%%   The test has two independent halves:
%%
%%   1. DYNAMIC PROBE.  The authoritative way to know whether an escape is
%%      supported is to ask MATLAB: constructing a text object issues a
%%      warning naming the offending command.  This file probes every distinct
%%      escape it finds in the codebase against a real (offscreen) text object,
%%      so the supported set is measured rather than transcribed from docs.
%%
%%   2. STATIC SCAN.  Walk every .m file, extract backslash escapes inside
%%      single-quoted strings, and report any that the probe rejected.
%%
%%   Escapes that are genuinely string formatting (\n, \t, ...) are excluded by
%%   considering only letters that form a known TeX command shape -- but note
%%   the ambiguity: '\n' inside a format string is a newline, while '\nu' is the
%%   Greek letter.  The scan therefore reports the raw escape and relies on the
%%   probe for the verdict.

    here = fileparts(mfilename('fullpath'));
    root = fullfile(here, '..');

    files = dir(fullfile(root, '**', '*.m'));
    files = files(~contains({files.name}, 'test_tex_lint'));

    fprintf('=== TeX escape lint ===\n\n');
    fprintf('  scanning %d .m files under %s\n\n', numel(files), root);

    % ------------------------------------------------------------------
    % collect every distinct escape, with its first location
    % ------------------------------------------------------------------
    escFirst = containers.Map('KeyType','char','ValueType','char');
    nEsc = 0;
    for k = 1:numel(files)
        fpath = fullfile(files(k).folder, files(k).name);
        lines = strsplit(fileread(fpath), newline);
        for li = 1:numel(lines)
            code = strip_trailing_comment(lines{li});
            if isempty(code), continue; end
            toks = regexp(code, '''[^'']*''', 'match');
            for t = 1:numel(toks)
                escs = regexp(toks{t}, '\\([A-Za-z]+)', 'tokens');
                for e = 1:numel(escs)
                    nm = escs{e}{1};
                    nEsc = nEsc + 1;
                    if ~isKey(escFirst, nm)
                        escFirst(nm) = sprintf('%s:%d', files(k).name, li);
                    end
                end
            end
        end
    end
    names = keys(escFirst);
    fprintf('  found %d escapes, %d distinct\n\n', nEsc, numel(names));

    % ------------------------------------------------------------------
    % dynamic probe: let MATLAB itself judge each escape
    %
    % Two-stage, because a backslash sequence in MATLAB source can mean either
    % of two unrelated things:
    %
    %   * a STRING escape ('\n', '\t', '\0'), resolved by sprintf/fprintf;
    %   * a TeX command ('\lambda', '\approx'), resolved by the graphics
    %     interpreter and only if it survived sprintf untouched.
    %
    % Running sprintf first reproduces that split exactly.  '\nr' becomes
    % newline + 'r' and is therefore fine; '\lambda' is passed through unchanged
    % (with a warning) and then has to face the TeX interpreter.
    % ------------------------------------------------------------------
    probeFig = figure('Visible','off','HandleVisibility','off');
    warnState = warning('off','all');   %#ok<WNOFF>  we inspect lastwarn instead
    cleanupWarn = onCleanup(@() warning(warnState));

    bad = {};
    nStringEsc = 0;
    for i = 1:numel(names)
        nm = names{i};
        raw = ['\' nm];

        lastwarn('');
        resolved = sprintf(raw);
        [~, widS] = lastwarn;
        isStringEscape = isempty(widS) && ~strcmp(resolved, raw);
        if isStringEscape
            nStringEsc = nStringEsc + 1;
            continue        % consumed by sprintf -> never reaches TeX
        end

        lastwarn('');
        try
            h = text(0.5, 0.5, raw, 'Interpreter','tex');
            drawnow;
            [~, wid] = lastwarn;
            badFlag = ~isempty(wid);
            delete(h);
        catch
            badFlag = true;
        end
        if badFlag
            bad{end+1} = sprintf('\\%-12s at %-28s', nm, escFirst(nm)); %#ok<AGROW>
        end
    end
    close(probeFig);
    clear cleanupWarn;
    warning(warnState);

    fprintf('  %d are string escapes resolved by sprintf (\\n, \\t, ...)\n', nStringEsc);
    fprintf('  %d are TeX candidates\n\n', numel(names) - nStringEsc);

    if isempty(bad)
        fprintf('  all escapes render cleanly under the tex interpreter\n\n');
        fprintf('=== 0 problems ===\n');
        return
    end

    fprintf('  UNSUPPORTED (would render as a missing-glyph box):\n');
    for i = 1:numel(bad)
        fprintf('    %s\n', bad{i});
    end
    fprintf('\n');
    fprintf('  Fix: use a supported synonym or plain ASCII.\n');
    fprintf('  Note MATLAB only WARNS for these; it does not error, which is\n');
    fprintf('  exactly why silent label corruption survives review.\n\n');

    error('test_tex_lint:failed', '%d unsupported TeX escape(s)', numel(bad));
end


function code = strip_trailing_comment(ln)
%% Remove everything after an unquoted % on one line.
    inq = false;
    for c = 1:numel(ln)
        if ln(c) == ''''
            inq = ~inq;
        elseif ln(c) == '%' && ~inq
            code = ln(1:c-1);
            return
        end
    end
    code = ln;
end
