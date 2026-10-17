"""
Shared HTML building blocks for the dp_v2 documents.

Both gen_manual.py (API reference) and gen_report.py (project report) need the
same stylesheet, code highlighter, table and callout helpers.  Keeping them here
rather than importing one generator from the other avoids the side effect of
re-running the entire manual build just to borrow a function.
"""
import base64
import os
import re

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
GAL = os.path.join(ROOT, 'gallery')


CSS = """
:root{
  --bg:#fbfbfd; --card:#fff; --ink:#1c2024; --muted:#6b7280; --line:#e3e6ea;
  --accent:#1d5fa8; --accent-soft:#eaf2fb; --warn:#b45309; --warn-soft:#fef6e7;
  --bad:#b42318; --bad-soft:#fdf0ee; --ok:#1a7f4b; --ok-soft:#eaf7ef;
  --mono:"Cascadia Mono","Consolas","SF Mono",Menlo,monospace;
  --serif:"Noto Serif SC","Source Han Serif SC",Georgia,serif;
  --sans:"Noto Sans SC","Segoe UI",system-ui,-apple-system,sans-serif;
}
*{box-sizing:border-box}
html{scroll-behavior:smooth}
body{margin:0;background:var(--bg);color:var(--ink);font:16px/1.75 var(--sans)}
.wrap{display:grid;grid-template-columns:264px minmax(0,1fr);max-width:1500px;margin:0 auto}
nav{position:sticky;top:0;align-self:start;height:100vh;overflow-y:auto;
  padding:26px 18px 40px;border-right:1px solid var(--line);background:#fff}
nav h2{font-size:.74rem;letter-spacing:.13em;text-transform:uppercase;
  color:var(--muted);margin:20px 0 7px;font-weight:700}
nav h2:first-child{margin-top:0}
nav a{display:block;padding:4px 9px;border-radius:6px;color:#374151;
  text-decoration:none;font-size:.875rem;line-height:1.45}
nav a:hover{background:var(--accent-soft);color:var(--accent)}
main{padding:38px 46px 110px;min-width:0}
header.top{border-bottom:2px solid var(--accent);padding-bottom:20px;margin-bottom:32px}
h1{font:700 1.95rem/1.3 var(--serif);margin:0 0 8px}
.sub{color:var(--muted);font-size:.95rem}
h2.sec{font:700 1.32rem/1.4 var(--serif);margin:52px 0 14px;
  padding-bottom:8px;border-bottom:2px solid var(--accent)}
h3{font:600 1.06rem/1.5 var(--sans);margin:30px 0 10px;color:var(--accent)}
h4{font:600 .96rem/1.5 var(--sans);margin:22px 0 8px;color:#374151}
p{margin:11px 0}
ul,ol{margin:11px 0;padding-left:24px}
li{margin:5px 0}
code{background:#f1f3f6;padding:1.5px 6px;border-radius:4px;
  font:.875em/1.4 var(--mono);color:#8a2b52;word-break:break-word}
pre{background:#1e2530;color:#e6edf3;padding:15px 18px;border-radius:9px;
  overflow-x:auto;font:13.2px/1.62 var(--mono);margin:14px 0;
  border-left:3px solid var(--accent)}
pre code{background:none;color:inherit;padding:0;font-size:inherit}
pre .c{color:#8b98a8;font-style:italic}
pre .s{color:#a5d6ff}
table{border-collapse:collapse;width:100%;margin:15px 0;font-size:.9rem;
  background:#fff;border-radius:8px;overflow:hidden;
  box-shadow:0 1px 3px rgba(16,24,40,.06)}
th,td{border:1px solid var(--line);padding:8px 12px;text-align:left;vertical-align:top}
th{background:#f5f7fa;font-weight:600;font-size:.85rem;
  text-transform:uppercase;letter-spacing:.03em;color:#48505b}
tr:nth-child(even) td{background:#fcfcfd}
td code{font-size:.85em}
figure{margin:22px 0;background:#fff;border:1px solid var(--line);
  border-radius:10px;padding:14px;box-shadow:0 1px 4px rgba(16,24,40,.05)}
figure img{width:100%;height:auto;display:block;border-radius:6px}
figcaption{font-size:.86rem;color:#4b5563;margin-top:11px;line-height:1.65;
  padding-top:10px;border-top:1px dashed var(--line)}
figure.missing .ph{background:var(--bad-soft);color:var(--bad);
  padding:28px;text-align:center;border-radius:6px;font-family:var(--mono);font-size:.85rem}
.box{border-radius:9px;padding:14px 18px;margin:17px 0;font-size:.925rem;
  border-left:4px solid}
.box p:first-child{margin-top:0} .box p:last-child{margin-bottom:0}
.box table{margin:10px 0}
.box .t{font-weight:700;display:block;margin-bottom:5px}
.note{background:var(--accent-soft);border-color:var(--accent)} .note .t{color:var(--accent)}
.warn{background:var(--warn-soft);border-color:var(--warn)} .warn .t{color:var(--warn)}
.bad{background:var(--bad-soft);border-color:var(--bad)} .bad .t{color:var(--bad)}
.ok{background:var(--ok-soft);border-color:var(--ok)} .ok .t{color:var(--ok)}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:16px 0}
.kv{background:#fff;border:1px solid var(--line);border-radius:8px;padding:13px 16px}
.kv h5{margin:0 0 6px;font-size:.9rem;color:var(--accent)}
.kv p{margin:0;font-size:.87rem;color:#4b5563}
.sig{font:12.8px/1.6 var(--mono);background:#f6f8fa;border:1px solid var(--line);
  border-left:3px solid var(--accent);border-radius:6px;padding:11px 15px;
  margin:12px 0;white-space:pre-wrap;word-break:break-word}
hr{border:0;border-top:1px solid var(--line);margin:38px 0}
.foot{color:var(--muted);font-size:.84rem;text-align:center;margin-top:60px;
  padding-top:22px;border-top:1px solid var(--line)}
a.ref{color:var(--accent)}
@media print{
  nav{display:none} .wrap{display:block} main{padding:0}
  pre{background:#f6f8fa;color:#111;border-left-color:#999}
  pre .c,pre .s{color:#111}
  figure{break-inside:avoid} h2.sec{break-before:page}
}
@media (max-width:900px){
  .wrap{display:block} nav{position:static;height:auto;border-right:0;
    border-bottom:1px solid var(--line)} main{padding:24px 18px 70px}
  .grid2{grid-template-columns:1fr}
}
"""


def code(txt):
    """Escape and lightly highlight a MATLAB/console code block.

    Ordering matters.  A '%' inside a single-quoted string is NOT a comment, and
    MATLAB format strings routinely contain them ('%.4f', '%d').  Strings are
    therefore stashed first, comments matched only on the remaining text, and
    the strings restored afterwards.  Doing it the other way round spliced a
    comment span into the middle of a format string and produced nested,
    visually broken markup.
    """
    t = txt.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

    strings = []

    def stash(m):
        strings.append(m.group(0))
        return '\x00%d\x00' % (len(strings) - 1)

    t = re.sub(r"'(?:[^'\n]|'')*'", stash, t)

    out = []
    for ln in t.split('\n'):
        m = re.search(r'%[^\n]*$', ln)
        if m:
            out.append(ln[:m.start()] + '<span class="c">' + ln[m.start():] + '</span>')
        else:
            out.append(ln)
    t = '\n'.join(out)

    def restore(m):
        return '<span class="s">%s</span>' % strings[int(m.group(1))]

    t = re.sub(r'\x00(\d+)\x00', restore, t)
    return '<pre><code>%s</code></pre>' % t


def tbl(headers, rows):
    h = ''.join('<th>%s</th>' % x for x in headers)
    body = ''.join('<tr>' + ''.join('<td>%s</td>' % c for c in r) + '</tr>'
                   for r in rows)
    return '<table><thead><tr>%s</tr></thead><tbody>%s</tbody></table>' % (h, body)


def box(kind, title, html):
    return '<div class="box %s"><span class="t">%s</span>%s</div>' % (kind, title, html)


def fig(name, alt, caption, required=True):
    """Embed a gallery figure as base64 so the document is self-contained."""
    p = os.path.join(GAL, name)
    if not os.path.exists(p):
        if required:
            return ('<figure class="missing"><div class="ph">[missing: %s]</div>'
                    '</figure>' % name)
        return ''
    b = base64.b64encode(open(p, 'rb').read()).decode('ascii')
    return ('<figure><img alt="%s" src="data:image/png;base64,%s">'
            '<figcaption>%s</figcaption></figure>' % (alt, b, caption))


def build_toc(toc):
    out = []
    for head, items in toc:
        out.append('<h2>%s</h2>' % head)
        for anc, label in items:
            out.append('<a href="#%s">%s</a>' % (anc, label))
    return '\n'.join(out)


def page(title, toc, body_parts):
    html = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
<style>%s</style>
</head>
<body>
<div class="wrap">
<nav>%s</nav>
<main>
%s
</main>
</div>
</body>
</html>
""" % (title, CSS, build_toc(toc), '\n'.join(body_parts))
    return html


def selfcheck(html, out_path, required_figs=()):
    """Report structure problems instead of shipping a broken document."""
    problems = []
    missing = re.findall(r'\[missing: ([^\]]+)\]', html)
    if missing:
        problems.append('missing figures: %s' % ', '.join(missing))
    for t in ['div', 'table', 'figure', 'pre', 'nav', 'main', 'span', 'code',
              'ol', 'ul']:
        o = len(re.findall(r'<%s[\s>]' % t, html))
        c = html.count('</%s>' % t)
        if o != c:
            problems.append('unbalanced <%s>: %d open / %d close' % (t, o, c))
    ids = set(re.findall(r'id="([^"]+)"', html))
    anchors = set(re.findall(r'<a href="#([^"]+)"', html))
    dangling = anchors - ids
    if dangling:
        problems.append('dangling anchors: %s' % sorted(dangling))
    unused = sorted(i for i in ids - anchors if i.startswith('s-'))
    if unused:
        problems.append('sections not in TOC: %s' % unused)
    # highlighter integrity
    nested = 0
    for m in re.finditer(r'<span[^>]*>', html):
        rest = html[m.end():]
        a, b = rest.find('<span'), rest.find('</span>')
        if a != -1 and (b == -1 or a < b):
            nested += 1
    if nested:
        problems.append('%d nested spans (highlighter bug)' % nested)
    bad_comments = [x for x in re.findall(r'<span class="c">([^<]{0,24})', html)
                    if not x.startswith('%')]
    if bad_comments:
        problems.append('comment spans not starting with %%: %s' % bad_comments[:3])
    if '\x00' in html:
        problems.append('leftover highlighter placeholders')

    size = os.path.getsize(out_path) / 1e6
    print('  size      : %.2f MB' % size)
    print('  figures   : %d' % html.count('data:image/png;base64'))
    print('  sections  : %d   tables: %d   code blocks: %d' % (
        html.count('class="sec"'), html.count('<table>'), html.count('<pre>')))
    if problems:
        print('  PROBLEMS:')
        for p in problems:
            print('    - %s' % p)
        return 1
    print('  structure : OK (tags balanced, anchors resolve, highlighter clean)')
    return 0
