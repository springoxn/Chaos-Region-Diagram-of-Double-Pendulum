"""
Structural and numerical verification of the generated documents.

report.html and manual.html are GENERATED: their numbers are read from
gallery/summary.mat at build time, their figures are embedded as base64, and
their code blocks are highlighted by a regex-based highlighter.  Each of those
can silently break -- a stale summary, a figure that failed to embed, a
highlighter that mis-parses a MATLAB comment.

This checks both documents.  It complements tests/verify_docs.m, which checks
the opposite direction (that the options documented in the HTML match what the
MATLAB functions actually accept).

Run:  python dp_v2/gen/verify_manual.py
Exit code 0 on success, 1 on any failure.
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
SUMMARY = os.path.join(ROOT, 'gallery', 'summary.mat')

fails = []


def check(cond, label, detail=''):
    print(('  OK   ' if cond else '  FAIL ') + label
          + (('  ' + detail) if detail and not cond else ''))
    if not cond:
        fails.append(label)


def load_summary():
    """Return the gallery numbers, or None to SKIP the numeric checks.

    A truly absent summary.mat (no scipy, no gallery) means the numeric half of
    this script cannot run, and None makes every comparison skip rather than
    fail -- that part is unchanged.  What is NOT swallowed any more is a key
    error: that means make_gallery.m and this file disagree about the field
    names, which is a real defect, so it is reported and counted as a failure
    instead of silently disabling every number check.
    """
    if not os.path.exists(SUMMARY):
        print('  (no summary.mat; numeric checks skipped)')
        return None
    try:
        import scipy.io as sio
        s = sio.loadmat(SUMMARY, squeeze_me=True, struct_as_record=False)['summary']
    except ImportError:
        print('  (scipy unavailable; numeric checks skipped)')
        return None
    except Exception as e:
        print('  (summary unreadable: %s)' % e)
        return None

    try:
        return {
            'old_corr': float(s.old_metric_corr_with_lambda),
            'corr_E': float(s.dp_corr_lambda_energy),
            'corr_flip': float(s.dp_corr_lambda_flippable),
            'alpha': float(s.basin_dim.alpha),
            'D': float(s.basin_dim.D),
            'R2': float(s.basin_dim.R2),
            'N': int(s.basin_dim.N),
        }
    except AttributeError as e:
        print('  FAIL summary.mat is missing a field the documents quote: %s' % e)
        fails.append('summary.mat field names')
        return None


def check_structure(name, h, expect_figs):
    print('\n[%s] structure' % name)
    check(h.startswith('<!DOCTYPE html>'), 'starts with doctype')
    check('<meta charset="UTF-8">' in h, 'declares UTF-8')
    for tag in ['div', 'table', 'figure', 'pre', 'nav', 'main', 'span',
                'code', 'ol', 'ul']:
        o = len(re.findall(r'<%s[\s>]' % tag, h))
        c = h.count('</%s>' % tag)
        check(o == c, '<%s> balanced (%d/%d)' % (tag, o, c))

    ids = set(re.findall(r'id="([^"]+)"', h))
    anchors = set(re.findall(r'<a href="#([^"]+)"', h))
    check(not (anchors - ids), 'no dangling anchors',
          'dangling: %s' % sorted(anchors - ids))

    n = h.count('data:image/png;base64')
    check(n == expect_figs, 'expected %d embedded figures' % expect_figs,
          'found %d' % n)
    check('<div class="ph">' not in h, 'no missing-figure placeholders')
    check('src="gallery/' not in h, 'no external image references (portable)')

    # highlighter integrity
    nested = 0
    for m in re.finditer(r'<span[^>]*>', h):
        rest = h[m.end():]
        a, b = rest.find('<span'), rest.find('</span>')
        if a != -1 and (b == -1 or a < b):
            nested += 1
    check(nested == 0, 'no nested spans', 'found %d' % nested)
    bad = [x for x in re.findall(r'<span class="c">([^<]{0,24})', h)
           if not x.startswith('%')]
    check(not bad, 'every comment span starts with %', 'offenders: %s' % bad[:3])
    fmtok = True
    for m in re.finditer(r'<span class="s">(.*?)</span>', h, re.S):
        if 'class="c"' in m.group(1):
            fmtok = False
            break
    check(fmtok, 'no comment span inside a string span')
    check('\x00' not in h, 'no leftover highlighter placeholders')


def check_numbers(name, h, S):
    print('\n[%s] numbers match gallery/summary.mat' % name)
    if S is None:
        print('  SKIP  scipy unavailable')
        return
    for txt, label in [
        ('%.4f' % S['alpha'], 'basin alpha'),
        ('%.4f' % S['D'], 'basin dimension'),
        ('%.4f' % S['R2'], 'basin R2'),
    ]:
        check(txt in h, '%s (%s)' % (label, txt))


def main():
    docs = [
        ('report.html', 6, True),
        ('manual.html', 1, False),
    ]

    missing = [d for d, _, _ in docs if not os.path.exists(os.path.join(ROOT, d))]
    if missing:
        print('missing %s -- run gen/gen_report.py and gen/gen_manual.py first'
              % ', '.join(missing))
        return 1

    S = load_summary()
    print('=== generated-document verification ===')

    for name, nfig, is_report in docs:
        p = os.path.join(ROOT, name)
        h = io.open(p, encoding='utf-8').read()
        print('\n' + '=' * 62)
        print('%s   %.2f MB' % (name, os.path.getsize(p) / 1e6))
        check_structure(name, h, nfig)
        check_numbers(name, h, S)

        if is_report:
            print('\n[%s] standalone project report' % name)
            # The report presents the project on its own terms; it must not
            # read as a changelog against some earlier version.
            leak = re.findall(r'(原项目|与原项目的对应|MIGRATION|superseded|重建版)', h)
            check(not leak, 'no migration/changelog language',
                  'found: %s' % sorted(set(leak)))
            check('manual.html' in h, 'links to the API reference')
            for kw in ['dp_map_lyapunov', 'fp_map', 'winding', 'Melnikov',
                       'Lyapunov']:
                check(kw in h, 'covers %s' % kw)

        print('\n[%s] content completeness' % name)
        check(h.count('class="sec"') >= 12, 'sections (%d)' % h.count('class="sec"'))
        check(h.count('<table>') >= 10, 'tables (%d)' % h.count('<table>'))
        check(h.count('<pre>') >= 8, 'code blocks (%d)' % h.count('<pre>'))
        check(h.count('class="box') >= 8, 'callouts (%d)' % h.count('class="box'))

    print('\n=== %d check(s) failed ===' % len(fails))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
