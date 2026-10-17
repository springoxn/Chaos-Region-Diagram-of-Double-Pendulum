"""Verify docs/verified_report.html is self-contained and structurally sound."""
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
REP = os.path.join(ROOT, 'docs', 'verified_report.html')

h = open(REP, encoding='utf-8').read()
fails = []


def check(cond, label, detail=''):
    print(('  OK   ' if cond else '  FAIL ') + label + (('  ' + detail) if detail and not cond else ''))
    if not cond:
        fails.append(label)


print('=== self-containment ===')
check(h.startswith('<!DOCTYPE html>'), 'starts with doctype')
check('<meta charset="UTF-8">' in h, 'declares UTF-8')

# no external references of any kind
ext = re.findall(r'(?:src|href)\s*=\s*"(?!data:|#)([^"]+)"', h)
check(not ext, 'no external src/href', 'found: %s' % sorted(set(ext))[:5])
check('src="gallery/' not in h, 'no relative image paths')
check('http://' not in h and 'https://' not in h, 'no URLs anywhere')
check('<script' not in h.lower(), 'no scripts')
check('<link' not in h.lower(), 'no external stylesheets')

nimg = h.count('data:image/png;base64')
check(nimg == 8, 'expected 8 embedded figures', 'found %d' % nimg)

print('\n=== structure ===')
for tag in ['div', 'table', 'figure', 'nav', 'ol', 'ul', 'tr', 'td', 'th',
            'p', 'h1', 'h2', 'h3', 'style']:
    o = len(re.findall(r'<%s[\s>]' % tag, h))
    c = h.count('</%s>' % tag)
    check(o == c, '<%s> balanced (%d/%d)' % (tag, o, c))

ids = set(re.findall(r'id="([^"]+)"', h))
anchors = set(re.findall(r'href="#([^"]+)"', h))
check(not (anchors - ids), 'no dangling anchors',
      'dangling: %s' % sorted(anchors - ids))

print('\n=== content requirements ===')
# 无时间性: no narrative sequencing language
time_bad = ['本轮', '上次', '下一步', '之前我们', '后来', '接下来我们', '首先我们做了',
            '最后我们做了', '待办', '未完成', 'TODO', 'handoff', 'rerun']
found = [w for w in time_bad if w in h]
check(not found, 'no time/process narrative words', 'found: %s' % found)

# 无联系性: no references to external files
ref_bad = ['.md', '.m<', 'README', 'handoff', 'rerun_plan', 'report.html',
           'manual.html', 'perf_tiers', 'summary.mat', 'dp_v2/', 'gallery/']
found = [w for w in ref_bad if w in h]
check(not found, 'no external file references', 'found: %s' % found)

# 科普性: derivation chain present
chain = ['&theta;&Prime; = &minus; sin&theta;', '&delta;&Prime;',
         'Mathieu', '&xi; = k/2', '&Omega; = 4/k', '&Phi;<sup>T</sup> J &Phi; = J',
         'GALI', 'MEGNO', 'Lyapunov']
missing = [c for c in chain if c not in h]
check(not missing, 'derivation chain present', 'missing: %s' % missing)

print('\n=== sizes ===')
check(len(h.encode('utf-8')) < 6e6, 'file under 6 MB',
      '%.2f MB' % (len(h.encode('utf-8')) / 1e6))

print('\n%d/%d checks passed' % (
    sum(1 for _ in []) or (0), 0)) if False else None
print('\n%s' % ('ALL CHECKS PASSED' if not fails else 'FAILURES: %s' % fails))
raise SystemExit(0 if not fails else 1)
