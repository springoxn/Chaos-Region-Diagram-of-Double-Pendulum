"""Cross-check the numbers quoted in verified_report.html against summary.mat."""
import os
import scipy.io as sio

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
s = sio.loadmat(os.path.join(ROOT, 'gallery', 'summary.mat'),
                squeeze_me=True, struct_as_record=False)['summary']
h = open(os.path.join(ROOT, 'docs', 'verified_report.html'), encoding='utf-8').read()

fails = []


def check(cond, label, detail=''):
    print(('  OK   ' if cond else '  FAIL ') + label
          + (('  ' + detail) if detail and not cond else ''))
    if not cond:
        fails.append(label)


print('=== report numbers vs gallery/summary.mat ===')
check('0.9116' in h, 'corr(lambda, energy) = +0.9116',
      'true %.4f' % float(s.dp_corr_lambda_energy))
check('0.5526' in h, 'corr(lambda, flippable) = -0.5526',
      'true %.4f' % float(s.dp_corr_lambda_flippable))
check('0.0199' in h, 'amplitude proxy corr = -0.0199',
      'true %.4f' % float(s.old_metric_corr_with_lambda))
check('0.1953' in h, 'basin alpha = 0.1953',
      'true %.4f' % float(s.basin_dim.alpha))
check('1.8047' in h, 'basin D = 1.8047',
      'true %.4f' % float(s.basin_dim.D))
check('0.9645' in h, 'basin R2 = 0.9645',
      'true %.4f' % float(s.basin_dim.R2))
check('58.96' in h, 'boundaryFrac = 58.96%',
      'true %.2f' % (100 * float(s.basin_dim.boundaryFrac)))

# sweep F table.  Negative values are rendered with the HTML entity &minus;,
# not an ASCII hyphen, so the comparison must normalise first -- the first
# version of this checker searched for "-0.2500" and reported a false failure.
hn = h.replace('&minus;', '-')


def has(v):
    """True if the numeric value appears, allowing the report's rounding.

    Tries several renderings (full precision and 2/3/4-dp) because the report
    rounds each table differently.  `v` is passed as a string here, so only the
    string forms are tried.
    """
    cands = {v}
    try:
        f = float(v)
        for nd in (2, 3, 4):
            cands.add(('%.*f' % (nd, f)))
            cands.add(('%+.*f' % (nd, f)))
    except ValueError:
        pass
    return any(c in hn for c in cands)


lam = [float(x) for x in s.sweep_lambda_mean]
check(has('-0.2500') and has('-0.1339'), 'sweep lambda endpoints',
      'true %s' % [round(x, 4) for x in lam])
check(has('-1.000'), 'sweep winding plateau at F=1.3',
      'true %.4f' % float(s.sweep_winding_median[4]))

print('\n%s' % ('ALL CONSISTENT' if not fails else 'MISMATCH: %s' % fails))
raise SystemExit(0 if not fails else 1)
