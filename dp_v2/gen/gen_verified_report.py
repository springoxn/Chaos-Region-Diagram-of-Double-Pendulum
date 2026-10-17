"""Generate docs/verified_report.html -- a self-contained popular-science report.

Self-contained means: every figure is embedded as base64 and no external file,
URL, stylesheet or script is referenced.  The document can be opened alone.

Run:  python gen/gen_verified_report.py
"""
import base64
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
GAL = os.path.join(ROOT, 'gallery')
OUT = os.path.join(ROOT, 'docs', 'verified_report.html')

_figcount = [0]


def img(name, caption):
    """Embed a PNG as base64 and return a <figure> block."""
    path = os.path.join(GAL, name)
    with open(path, 'rb') as fh:
        b64 = base64.b64encode(fh.read()).decode('ascii')
    _figcount[0] += 1
    return ('<figure><img alt="figure" src="data:image/png;base64,' + b64 +
            '"><figcaption>' + caption + '</figcaption></figure>')


B = []
A = B.append

A('''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>混沌指标：从单摆到双摆的可验证报告</title>
<style>
:root{
  --ink:#1a1d21; --mid:#5a6472; --faint:#8b95a3;
  --line:#dfe4ea; --bg:#fbfcfd; --card:#ffffff;
  --accent:#1d5fa8; --accent-soft:#eaf2fb;
  --warn:#b45309; --warn-soft:#fef6e7;
  --bad:#b91c1c; --bad-soft:#fdecec;
  --ok:#15803d; --ok-soft:#eefaf1;
}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{
  margin:0; background:var(--bg); color:var(--ink);
  font-family:Georgia,"Songti SC","Source Han Serif SC",serif;
  font-size:17px; line-height:1.78;
}
.wrap{max-width:900px; margin:0 auto; padding:0 26px 90px}
header.top{
  border-bottom:3px double var(--line); padding:54px 0 26px; margin-bottom:34px;
}
header.top h1{
  font-size:2.05em; line-height:1.3; margin:0 0 12px; letter-spacing:-.01em;
}
header.top p.sub{color:var(--mid); margin:0; font-size:1.02em}
h2.sec{
  font-family:-apple-system,"Segoe UI","PingFang SC",sans-serif;
  font-size:1.42em; margin:62px 0 18px; padding-bottom:9px;
  border-bottom:1px solid var(--line); letter-spacing:-.005em;
}
h2.sec .num{color:var(--accent); font-weight:600; margin-right:.5em}
h3{
  font-family:-apple-system,"Segoe UI","PingFang SC",sans-serif;
  font-size:1.1em; margin:34px 0 10px; color:#2b3138;
}
p{margin:0 0 15px}
.eq{
  margin:18px 0; padding:14px 18px; background:var(--card);
  border-left:3px solid var(--accent); overflow-x:auto;
  font-family:"Cambria Math",Cambria,Georgia,serif; font-size:1.06em;
}
.eq .lbl{float:right; color:var(--faint); font-size:.85em; font-family:sans-serif}
code{
  font-family:"Cascadia Mono",Consolas,monospace; font-size:.87em;
  background:#f0f3f7; padding:.1em .4em; border-radius:3px; color:#1f2937;
}
table{
  width:100%; border-collapse:collapse; margin:20px 0; font-size:.9em;
  font-family:-apple-system,"Segoe UI","PingFang SC",sans-serif;
  background:var(--card);
}
th,td{border:1px solid var(--line); padding:8px 11px; text-align:left; vertical-align:top}
th{background:#f3f6f9; font-weight:600; white-space:nowrap}
td.num,th.num{text-align:right; font-variant-numeric:tabular-nums;
  font-family:"Cascadia Mono",Consolas,monospace; white-space:nowrap}
tr.hi td{background:var(--accent-soft)}
figure{margin:26px 0; text-align:center}
figure img{max-width:100%; height:auto; border:1px solid var(--line);
  border-radius:4px; background:#fff}
figcaption{color:var(--mid); font-size:.87em; margin-top:10px;
  font-family:-apple-system,"Segoe UI","PingFang SC",sans-serif; line-height:1.6}
.box{margin:22px 0; padding:15px 18px; border-left:4px solid; border-radius:3px;
  font-size:.95em}
.box .t{display:block; font-weight:700; margin-bottom:5px;
  font-family:-apple-system,"Segoe UI","PingFang SC",sans-serif}
.box p:last-child{margin-bottom:0}
.note{background:var(--accent-soft); border-color:var(--accent)} .note .t{color:var(--accent)}
.warn{background:var(--warn-soft); border-color:var(--warn)} .warn .t{color:var(--warn)}
.bad{background:var(--bad-soft); border-color:var(--bad)} .bad .t{color:var(--bad)}
.ok{background:var(--ok-soft); border-color:var(--ok)} .ok .t{color:var(--ok)}
nav.toc{background:var(--card); border:1px solid var(--line); border-radius:5px;
  padding:20px 26px; margin:30px 0 10px}
nav.toc h2{font-size:.95em; margin:0 0 10px; color:var(--mid);
  font-family:-apple-system,"Segoe UI","PingFang SC",sans-serif;
  text-transform:uppercase; letter-spacing:.06em}
nav.toc ol{margin:0; padding-left:1.4em; columns:2; column-gap:34px}
nav.toc li{margin:3px 0; font-size:.92em}
nav.toc a{color:var(--ink); text-decoration:none; border-bottom:1px solid transparent}
nav.toc a:hover{border-bottom-color:var(--accent); color:var(--accent)}
.kv{font-family:"Cascadia Mono",Consolas,monospace; font-size:.9em}
.small{color:var(--mid); font-size:.9em}
hr.soft{border:0; border-top:1px solid var(--line); margin:44px 0}
</style>
</head>
<body>
<div class="wrap">
<header class="top">
<h1>混沌指标：从单摆到双摆的可验证报告</h1>
<p class="sub">一个动力系统是不是混沌的？这个问题看似可以直接回答，实际上充满陷阱。
本文从一个单摆的运动方程出发，逐步构造出判断混沌的量化指标，
并给出每个结论的数值证据与校验方式。</p>
</header>
''')

# ---------------------------------------------------------------- TOC
A('''<nav class="toc">
<h2>目录</h2>
<ol>
<li><a href="#s1">一个单摆，两行方程</a></li>
<li><a href="#s2">混沌的判据：Lyapunov 指数</a></li>
<li><a href="#s3">五个指标的构造</a></li>
<li><a href="#s4">数值积分：为什么必须"辛"</a></li>
<li><a href="#s5">陷阱一：指标依赖初始方向</a></li>
<li><a href="#s6">陷阱二：线性方程也会指数增长</a></li>
<li><a href="#s7">陷阱三：积分时间不够</a></li>
<li><a href="#s8">陷阱四：振幅不等于混沌</a></li>
<li><a href="#s9">地图与分形盆地</a></li>
<li><a href="#s10">全部校验数据</a></li>
</ol>
</nav>''')

# ================================================================ 1
A('<h2 class="sec" id="s1"><span class="num">1</span>一个单摆，两行方程</h2>')

A('''<p>一切从牛顿第二定律 <code>F = ma</code> 开始。考虑一个质量 <code>m</code>
用长 <code>L</code> 的无质量细杆悬挂，只能在竖直平面内摆动，偏离竖直向下方向的
夹角记为 <code>&theta;</code>。</p>''')

A('''<p>质点沿圆弧运动，弧长位移是 <code>s = L&theta;</code>，所以切向加速度是
<code>L&theta;&Prime;</code>。沿切向的回复力来自重力分量 <code>&minus;mg sin&theta;</code>。
于是</p>''')

A('<div class="eq">m L &theta;&Prime; = &minus; m g sin&theta;'
  '<span class="lbl">(1)</span></div>')

A('''<p>约掉质量，并取单位使 <code>g/L = 1</code>，得到本文反复使用的方程：</p>''')

A('<div class="eq">&theta;&Prime; = &minus; sin&theta;'
  '<span class="lbl">(2)</span></div>')

A('''<p>当 <code>&theta;</code> 很小时 <code>sin&theta; &asymp; &theta;</code>，
方程退化为 <code>&theta;&Prime; = &minus;&theta;</code>，即简谐振动，
周期 <code>2&pi;</code> 与振幅无关。但振幅一大，<code>sin&theta;</code>
就明显小于 <code>&theta;</code>，回复力变弱，周期随振幅变长。
这个「周期依赖振幅」的性质叫<strong>非等时性</strong>，后文会用到。</p>''')

A('''<h3>能量守恒，以及为什么单摆永不混沌</h3>
<p>把 (2) 式两边乘以 <code>&theta;&prime;</code> 就能积分：</p>''')

A('<div class="eq">&theta;&prime;&theta;&Prime; = &minus; sin&theta; &middot; &theta;&prime;'
  '&nbsp;&nbsp;&rArr;&nbsp;&nbsp;'
  'd/dt [ &frac12;&theta;&prime;&sup2; &minus; cos&theta; ] = 0'
  '<span class="lbl">(3)</span></div>')

A('''<p>括号里的量沿轨迹不变，它就是哈密顿量（能量）：</p>''')

A('<div class="eq">H = &frac12; p&sup2; &minus; cos&theta; ,'
  '&nbsp;&nbsp;&nbsp; p &equiv; &theta;&prime;'
  '<span class="lbl">(4)</span></div>')

A('''<p><code>H</code> 的取值把相平面分成三类：</p>
<ul>
<li><code>&minus;1 &le; H &lt; 1</code>：<strong>摆动</strong>（libration），
摆来回振荡，不越过最高点；</li>
<li><code>H = 1</code>：<strong>分界线</strong>（separatrix），
恰好以无限长的时间趋近倒立位置；</li>
<li><code>H &gt; 1</code>：<strong>转动</strong>（circulation），
摆持续朝一个方向转，角度不断累加。</li>
</ul>''')

A('''<p>关键点是：<strong>单摆是完全可积的</strong>。一个自由度配一个守恒量
<code>H</code>，就已经把运动定死了 —— 每条轨道都落在相平面的一条闭合曲线上，
永远不会出现混沌。这给了一个干净的"基准真值"：任何指标若在单摆上报告混沌，
那一定是指标的问题，不是系统的问题。</p>''')

A('''<p>数值上可以验证这一点。用后文第 4 节的积分器跑一条单摆轨道，
有限时间 Lyapunov 指数的绝对值不超过 <code>0.0019</code>；
而同参数下换一条已知混沌的轨道，同一指标给出 <code>0.7540</code> ——
两者相差约 400 倍，判别毫不含糊。</p>''')

# ================================================================ 2
A('<h2 class="sec" id="s2"><span class="num">2</span>混沌的判据：Lyapunov 指数</h2>')

A('''<p>混沌的物理特征是<strong>对初值的敏感依赖</strong>：两条起始时差之毫厘的轨道，
会以指数速度分开。量化这个分离速度，就是 Lyapunov 指数。</p>''')

A('''<p>设真实轨道为 <code>&theta;(t)</code>，邻近轨道为
<code>&theta;(t) + &delta;(t)</code>。把 (2) 式在真实轨道上线性化
（把 <code>sin(&theta;+&delta;) &asymp; sin&theta; + &delta; cos&theta;</code>
代入并只保留一阶项）：</p>''')

A('<div class="eq">&delta;&Prime; = &minus; cos&theta;(t) &middot; &delta;'
  '<span class="lbl">(5)</span></div>')

A('''<p>(5) 式叫<strong>变分方程</strong>。注意它是一个<em>线性</em>方程，
但系数 <code>cos&theta;(t)</code> 随时间变化，所以解的行为由
<code>&theta;(t)</code> 决定。定义</p>''')

A('<div class="eq">&lambda; = lim<sub>t&rarr;&infin;</sub>'
  ' (1/t) &middot; ln( |&delta;(t)| / |&delta;(0)| )'
  '<span class="lbl">(6)</span></div>')

A('''<p><code>&lambda; &gt; 0</code> 意味着分离量按 <code>e<sup>&lambda;t</sup></code>
增长，即混沌；<code>&lambda; = 0</code> 意味着分离量只按幂次增长，即规则运动。
单摆的 <code>&lambda;</code> 严格为零，与"完全可积"一致。</p>''')

A('''<h3>一个免费的校验：四个指数之和必为零</h3>
<p>对哈密顿系统，相空间体积守恒（Liouville 定理），而体积变化率是
<code>&sum;&lambda;<sub>i</sub></code>。因此四个 Lyapunov 指数必须满足</p>''')

A('<div class="eq">&lambda;<sub>1</sub> + &lambda;<sub>2</sub> +'
  ' &lambda;<sub>3</sub> + &lambda;<sub>4</sub> = 0'
  '<span class="lbl">(7)</span></div>')

A('''<p>这是一个不依赖任何指标的独立约束，可以用它检验积分代码是否正确。
对双摆的一个混沌初值，实测四个指数为</p>''')

A('''<table>
<tr><th>&lambda;<sub>1</sub></th><th>&lambda;<sub>2</sub></th>
<th>&lambda;<sub>3</sub></th><th>&lambda;<sub>4</sub></th>
<th>和</th></tr>
<tr><td class="num">+1.31906</td><td class="num">+0.00186378</td>
<td class="num">&minus;0.00376126</td><td class="num">&minus;1.31647</td>
<td class="num">+6.909e&minus;04</td></tr>
</table>''')

A('''<p>和相对单值 <code>1.32</code> 只有 <code>7&times;10<sup>&minus;4</sup></code>
的残差，而两个零指数（<code>&lambda;<sub>2</sub>, &lambda;<sub>3</sub></code>）
确实在零附近。这两件事同时成立，说明切空间的积分是可信的。</p>''')

A('''<h3>指数很难算准</h3>
<p>(6) 式是一个 <code>t&rarr;&infin;</code> 的极限。用有限时间 <code>T</code>
估计它，涨落量级约为 <code>1/&radic;(&lambda;T)</code>。这个"有限时间地板"
有一个直接后果：<strong>规则轨道的有限时间 <code>&lambda;</code> 估计并不趋于 0，
而是在 0 附近来回摆</strong>。实测双摆在规则岛中心（真值 <code>&lambda;=0</code>）：</p>''')

A('''<table>
<tr><th>积分时间 T</th><th class="num">50</th><th class="num">100</th>
<th class="num">200</th><th class="num">400</th><th class="num">800</th></tr>
<tr><td>实测 &lambda;</td><td class="num">&minus;0.0243</td>
<td class="num">&minus;0.0038</td><td class="num">&minus;0.0013</td>
<td class="num">+0.0011</td><td class="num">+0.0011</td></tr>
</table>''')

A('''<p><code>T &ge; 400</code> 时规则轨道的 <code>&lambda;</code> 已经是<strong>正数</strong>。
所以"<code>&lambda; &gt; 0</code> 即混沌"这种二值判据会把整个规则岛判成混沌区 ——
这是数值假象伪装成物理结论。</p>''')

A('''<div class="box warn"><span class="t">读图纪律</span>
<p>有限时间估计必须<strong>按量级</strong>读，不能按符号读。双摆地图上规则岛约
<code>0.005</code>、混沌海约 <code>1.35</code>，相差近两个数量级，
颜色上从不含糊。只有天真地看正负号才会出错。</p></div>''')

# ================================================================ 3
A('<h2 class="sec" id="s3"><span class="num">3</span>五个指标的构造</h2>')

A('''<p>既然 <code>&lambda;</code> 慢且吵，就需要更灵敏的替代品。它们大多不是新信息，
而是<strong>同一批偏差向量的不同泛函</strong>——所以一次积分可以同时算出全部。</p>''')

A('''<h3>3.1 MEGNO：绝对指标，不需要标定轨道</h3>
<p>MEGNO 把分离量的对数增长率按时间加权再平均：</p>''')

A('<div class="eq">Y(t) = (2/t) &int;<sub>0</sub><sup>t</sup>'
  ' s &middot; d(ln &delta;)/ds &nbsp; ds'
  '<span class="lbl">(8)</span></div>')

A('''<p>它的价值在于<strong>有一个与系统无关的绝对标度</strong>：
规则运动趋近 <code>2</code>，混沌运动线性增长。因此不需要预先知道哪条轨道是规则的。</p>''')

A('''<p>两个解析锚点可以把它钉死。对谐振子 <code>H = (p&sup2;+q&sup2;)/2</code>，
偏差量大小恒定（<code>&delta;<sub>q</sub>=cos t</code>、
<code>&delta;<sub>v</sub>=&minus;sin t</code>），所以每一项 <code>ln r</code> 都是 0，
MEGNO 必须<strong>严格等于 0</strong>。实测 <code>+0.00000</code>。</p>''')

A('''<p>对可积的有序运动，MEGNO 趋于 2，但收敛很慢：</p>''')

A('''<table>
<tr><th>T</th><th class="num">100</th><th class="num">400</th>
<th class="num">1600</th><th class="num">3200</th></tr>
<tr><td>MEGNO</td><td class="num">1.7488</td><td class="num">1.8272</td>
<td class="num">2.0567</td><td class="num">1.9993</td></tr>
</table>''')

A('''<p>直到 <code>T = 3200</code> 才落到 <code>1.9993</code>。</p>''')

A('''<div class="box bad"><span class="t">MEGNO 的时间门槛</span>
<p>上表意味着：<strong>任何 <code>T &lt; 1000</code> 的 MEGNO 定量结论都不可信</strong>。
地图上尤其容易踩这个坑，因为默认设置常常只有一两百个周期。</p></div>''')

A('''<h3>3.2 GALI 与 SALI：用"对齐"代替"增长"</h3>
<p>GALI 的思路完全不同。它不问偏差向量长得多快，而问<strong>几个偏差向量是否
塌缩到同一个方向上</strong>。取 <code>k</code> 个单位偏差向量，定义它们的楔积范数：</p>''')

A('<div class="eq">GALI<sub>k</sub> = | v<sub>1</sub> &and; v<sub>2</sub>'
  ' &and; &hellip; &and; v<sub>k</sub> |'
  '<span class="lbl">(9)</span></div>')

A('''<p>这个量在数值上就是这 <code>k</code> 个向量张成的平行体的体积：
互相正交时为 1（体积最大），互相平行时为 0。混沌时所有方向都被
最强拉伸方向吞并，于是 <code>GALI<sub>k</sub> &rarr; 0</code>；
规则运动时它不衰减，只是振荡。</p>''')

A('''<p><code>k = 2</code> 时有一个更常见的等价量 <strong>SALI</strong>：</p>''')

A('<div class="eq">SALI = min( |u + w| , |u &minus; w| ) ,'
  '&nbsp;&nbsp;&nbsp; u = v<sub>1</sub>/|v<sub>1</sub>| ,'
  '&nbsp; w = v<sub>2</sub>/|v<sub>2</sub>|'
  '<span class="lbl">(10)</span></div>')

A('''<p>两个单位向量的和与差，恰好对应"同向"与"反向"两种平行方式，
取最小值就覆盖了两种情形。由 <code>|u&minus;w|&sup2; = 2&minus;2u&middot;w</code>
可以解析地推出两者的关系：</p>''')

A('<div class="eq">GALI<sub>2</sub> = SALI &middot; &radic;(4 &minus; SALI&sup2;) / 2'
  '<span class="lbl">(11)</span></div>')

A('''<p>这是一个纯几何恒等式，与动力学无关，因此可以逐点校验。
在 200 组随机向量对上，实测最大偏差 <code>4.44&times;10<sup>&minus;16</sup></code>，
即机器精度。</p>''')

A('''<p>GALI 描述的是<strong>相空间维数</strong>。
四维相空间（双摆）里，混沌轨道有一个正指数、规则轨道有两个零指数，
这种退化结构正是 GALI 需要的；二维流（单摆）里没有这个结构，
GALI<sub>2</sub> 会失效。实测：在受迫阻尼摆上扫 40 个参数点，
GALI<sub>2</sub> 把 <strong>11 个规则轨道误判为混沌</strong>（27%），
假阴性为 0。</p>''')

A('''<div class="box note"><span class="t">指标选择取决于系统维数</span>
<p>这是本文一条硬结论：<strong>双摆（4 维）用 GALI / MEGNO，
受迫摆（2 维）用 MEGNO / OFLI2 / IACF</strong>。
把二维系统的结论照搬到四维，或者反过来，都会出错。</p></div>''')

A('''<h3>3.3 FLI 与 OFLI2</h3>
<p>FLI 取分离量对数的<strong>运行上确界</strong>：
<code>FLI(t) = sup<sub>s&le;t</sub> ln|&delta;(s)|</code>。
它计算最便宜，但只作相对比较用，需要一条已知规则的参考轨道。</p>''')

A('''<p>OFLI2 用<strong>二阶</strong>变分，并把偏差向量投影掉流的方向。
投影这一步是关键：一阶指标的全部麻烦都来自偏差向量里混入了"沿流"的分量，
而投影从构造上就把它去掉了。代价是需要势的二阶导数（Hessian）乃至三阶导数。</p>''')

A('''<h3>3.4 谱指标：完全不碰变分方程</h3>
<p>前面四个都是变分法。另有一类指标只看<strong>一条轨道的时序</strong>，
完全不碰变分方程。这类"谱指标"提供了独立的交叉检验。</p>''')

A('''<p><strong>积分自相关 W。</strong>设时序 <code>q<sub>i</sub></code>，
其自相关函数与积分量定义为</p>''')

A('<div class="eq">C<sub>j</sub> = &sum;<sub>i</sub>'
  ' (q<sub>i</sub>&minus;q&#772;)(q<sub>i+j</sub>&minus;q&#772;)'
  ' / &sum;<sub>i</sub>(q<sub>i</sub>&minus;q&#772;)&sup2; ,'
  '&nbsp;&nbsp;&nbsp; W(K) = (K+1) / &sum;<sub>j=0</sub><sup>K</sup> C<sub>j</sub>&sup2;'
  '<span class="lbl">(12)</span></div>')

A('''<p>它的标度同样是绝对的：常数序列给 <code>W=1</code>，
正弦给 <code>W=2</code>，白噪声给 <code>W=K</code>。实测：
常数 <code>1.000000</code>、采样正弦 <code>2.002779</code>、
白噪声落在 <code>[1, K]</code> 内。</p>''')

A('''<p><strong>谱峰计数 SN。</strong>对时序做 FFT，数出高于阈值的<em>局部极大</em>个数。
只数局部极大（而不是所有超标点）是为了避开谱泄漏：一条宽谱线会被
泄漏复制成许多相邻点，若全部计数就会产生摩尔纹假象。
实测单音给 <code>SN = 1</code>，双音给 <code>SN = 2</code>。</p>''')

# ================================================================ 4
A('<h2 class="sec" id="s4"><span class="num">4</span>数值积分：为什么必须"辛"</h2>')

A('''<p>上面所有指标都从偏差向量算出来，而偏差向量由积分器推进。
如果积分器本身在系统性地注入或耗散能量，测出来的指数就是积分器的性质，
不是系统的性质。</p>''')

A('''<p>从 (2) 式的哈密顿量出发，把它拆成"只含动量"和"只含坐标"两块：</p>''')

A('<div class="eq">H(q,p) = T(p) + V(q) ,'
  '&nbsp;&nbsp;&nbsp; T = p&sup2;/2 ,&nbsp;&nbsp; V = &minus;cos q'
  '<span class="lbl">(13)</span></div>')

A('''<p>两块各自都能精确求解。这给出最经济的<strong>蛙跳格式</strong>：先按
<code>T</code> 走半步（坐标平移），再按 <code>V</code> 踢一脚（动量更新），
再走半步。把半步合成整步，写成</p>''')

A('<div class="eq">p &larr; p + h&middot;F(q) ,&nbsp;&nbsp;&nbsp;'
  ' q &larr; q + h&middot;p'
  '<span class="lbl">(14)</span></div>')

A('''<p>这种"踢-漂-踢"结构有一个深刻的性质：它精确保持相空间的辛形式。</p>''')

A('''<h3>辛性：可检验的定义</h3>
<p>设一步的切映射（Jacobian）为 <code>&Phi;</code>，
<code>J</code> 是标准辛矩阵。辛性等价于</p>''')

A('<div class="eq">&Phi;<sup>T</sup> J &Phi; = J'
  '<span class="lbl">(15)</span></div>')

A('''<p>这个等式可以直接数值检验，不需要参照解。实测（含时间显式依赖的非自治情形）：</p>''')

A('''<table>
<tr><th>格式</th><th class="num">max |&Phi;<sup>T</sup>J&Phi; &minus; J|</th></tr>
<tr><td>显式辛 · Yoshida 2 阶</td><td class="num">0.00e+00</td></tr>
<tr><td>显式辛 · Yoshida 4 阶</td><td class="num">1.11e&minus;16</td></tr>
<tr><td>显式辛 · Yoshida 6 阶</td><td class="num">3.33e&minus;16</td></tr>
</table>''')

A('''<p>残差落在机器精度量级。作为对比，若把辛格式用在<strong>非正则变量</strong>上，
残差会变成 <code>0.78</code> 这个量级 —— 这正是下文双摆必须做变量变换的原因。</p>''')

A('''<h3>高阶格式：Yoshida 合成</h3>
<p>蛙跳本身是二阶的。要得到四阶、六阶，把蛙跳按特定权重首尾相接即可
（Yoshida 合成）。权重必须满足阶条件：</p>''')

A('<div class="eq">&sum;<sub>i</sub> w<sub>i</sub> = 1 ,&nbsp;&nbsp;'
  ' &sum;<sub>i</sub> w<sub>i</sub>&sup3; = 0 ,&nbsp;&nbsp;'
  ' &sum;<sub>i</sub> w<sub>i</sub><sup>5</sup> = 0'
  '<span class="lbl">(16)</span></div>')

A('''<p>实测残差：六阶格式下分别为 <code>2.22&times;10<sup>&minus;16</sup></code>、
<code>9.77&times;10<sup>&minus;15</sup></code>、
<code>4.93&times;10<sup>&minus;14</sup></code>，且权重序列回文对称
（对称性是时间可逆性的来源，也是偶数阶的前提）。</p>''')

A('''<p>收敛阶可以直接测量：固定总时间、逐次减半步长，看误差如何下降。
理论值是 <code>2<sup>n</sup></code>。</p>''')

A('''<table>
<tr><th>格式</th><th class="num">误差比 (h&rarr;h/2)</th>
<th class="num">理论值</th></tr>
<tr><td>Yoshida 2 阶</td><td class="num">4.0 &nbsp; 4.0</td><td class="num">4</td></tr>
<tr><td>Yoshida 4 阶</td><td class="num">16.0 &nbsp; 16.0</td><td class="num">16</td></tr>
<tr><td>Yoshida 6 阶</td><td class="num">63.9 &nbsp; 58.9</td><td class="num">64</td></tr>
</table>''')

A('''<h3>能量：有界振荡 vs 单调漂移</h3>
<p>辛格式的真正优势不在于误差更小，而在于误差的<strong>时间行为</strong>不同。
它保持能量在一个有界带来回振荡，带宽随步长按 <code>h<sup>n</sup></code> 收缩；
非辛格式（如 RK4）则单调漂移，误差随时间持续累积，步长再小也压不住。</p>''')

A('''<p>定量做法是把总时间切成前后两半，比较各自的最大能量误差：</p>''')

A('<div class="eq">比值 = max|&Delta;E|<sub>后半</sub> /'
  ' max|&Delta;E|<sub>前半</sub>'
  '<span class="lbl">(17)</span></div>')

A('''<p>有界振荡给 <code>&asymp; 1</code>，漂移给 <code>&gt; 1</code> 且随 T 增长。实测：</p>''')

A('''<table>
<tr><th>方法</th><th class="num">前半 max|&Delta;E|</th>
<th class="num">后半 max|&Delta;E|</th><th class="num">比值</th></tr>
<tr><td>Yoshida 2 阶</td><td class="num">1.199e&minus;03</td>
<td class="num">1.199e&minus;03</td><td class="num">1.00</td></tr>
<tr><td>Yoshida 4 阶</td><td class="num">1.579e&minus;05</td>
<td class="num">1.579e&minus;05</td><td class="num">1.00</td></tr>
<tr><td>Yoshida 6 阶</td><td class="num">3.637e&minus;08</td>
<td class="num">3.637e&minus;08</td><td class="num">1.00</td></tr>
<tr><td>RK4（非辛）</td><td class="num">9.789e&minus;04</td>
<td class="num">1.950e&minus;03</td><td class="num">1.99</td></tr>
</table>''')

A('''<p>辛格式三列的比值精确为 <code>1.00</code>，RK4 为 <code>1.99</code>
（即误差在后半段翻了一倍）。注意 RK4 在<em>前半段</em>的绝对误差
（<code>9.8&times;10<sup>&minus;4</sup></code>）其实比 Yoshida 2 阶
（<code>1.2&times;10<sup>&minus;3</sup></code>）还小 —— 决定性差别不在精度，
而在误差是否累积。</p>''')

A(img('sp_energy_coupled.png',
      '辛格式与 RK4 的能量行为对比。左：能量误差随时间。'
      '辛格式（2/4/6 阶）的误差落在各自的水平带内不增长；'
      'RK4 则持续爬升。右：前后半段误差比值，辛格式均为 1，RK4 约为 2。'))

A('''<h3>双摆为什么必须用隐式格式</h3>
<p>双摆的哈密顿量里，动能项含一个依赖坐标的质量矩阵 <code>M(q)</code>：</p>''')

A('<div class="eq">H = &frac12; p<sup>T</sup> M(q)<sup>&minus;1</sup> p + V(q)'
  '<span class="lbl">(18)</span></div>')

A('''<p>它是<strong>不可分</strong>的 —— <code>T</code> 里混着 <code>q</code>，
没法像 (13) 式那样拆成两块。因此<strong>不存在显式辛格式</strong>，
必须用隐式方法（隐式中点或两阶段 Gauss-Legendre），每步解一个非线性方程。</p>''')

A('''<p>还有第二个坑：（角度, 角速度）<code>(&theta;,&omega;)</code> 不是正则坐标，
真正的动量是 <code>p = M(q)&omega;</code>。辛格式必须在正则变量
<code>(q,p)</code> 里跑；若直接在 <code>(&theta;,&omega;)</code> 上跑，
非线性变量替换会破坏辛性。实测：变换后的辛性残差
<code>1.11&times;10<sup>&minus;16</sup></code>（2 阶）、
<code>2.22&times;10<sup>&minus;16</sup></code>（4 阶），
而不做变换会得到 <code>0.78</code> 量级。</p>''')

A('''<p>能量行为同样成立：双摆隐式格式的前后半段误差比为
<code>0.99</code>（2 阶）与 <code>0.94</code>（4 阶），
而同问题的 RK4 为 <code>2.02</code>。</p>''')

# ================================================================ 5
A('<h2 class="sec" id="s5"><span class="num">5</span>陷阱一：指标依赖初始方向</h2>')

A('''<p>第一个陷阱最反直觉：<strong>一个完全可积的系统，会被指标报告成混沌的。</strong></p>''')

A('''<p>把第 1 节的单摆拿来做指标计算。它的真值已知 ——
<code>&lambda; = 0</code>，绝不混沌。但若给变分方程一个<em>固定的</em>
初始偏差向量 <code>&eta;<sub>0</sub> = (1,1)</code>，
指标地图上会出现成片的"混沌"条纹。</p>''')

A('''<h3>机制：偏差向量落在流方向上</h3>
<p>偏差向量 <code>&eta;</code> 可以分解为两个分量：沿流方向的
（切向）和垂直流方向的（法向）。</p>''')

A('''<ul>
<li><strong>法向</strong>分量在规则轨道上按幂次增长，指标读出"正常"的值；</li>
<li><strong>切向</strong>分量永远只能按线性增长 ——
因为"沿流"就是轨道本身的移动，它不含任何指数信息。</li>
</ul>''')

A('''<p>于是当初始偏差向量恰好<em>落在切向</em>时，指标只能看到代数增长，
读出"异常规则"的值。这就在规则的地图上凿出了一条假的低值带。</p>''')

A('''<p>切向的条件可以解析写出来。单摆的能量是
<code>H = X&sup2;/2 &minus; cos x</code>，其梯度为
<code>&nabla;H = (&minus;sin x, X)</code>；
而流方向就是 <code>(X, &minus;sin x)</code>。两者正交，
所以"切向"等价于偏差向量与梯度平行。对
<code>&eta;<sub>0</sub> = (1,1)</code>，条件化为</p>''')

A('<div class="eq">X<sub>0</sub> &middot; 1 = &minus;sin(x<sub>0</sub>) &middot; 1'
  '&nbsp;&nbsp;&rArr;&nbsp;&nbsp; X<sub>0</sub> = &minus;sin(x<sub>0</sub>)'
  '<span class="lbl">(19)</span></div>')

A('''<p>这是一条正弦曲线。如果假低值带确实由这个机制产生，
那么它就应当与这条曲线重合。</p>''')

A('''<p>实测结果支持这个解释：低值偏离量与"到该曲线的距离"的相关系数为
<code>+0.302</code>；曲线<em>上</em>的平均偏离为 <code>&minus;0.9801</code>，
曲线<em>外</em>为 <code>&minus;0.1553</code> —— 相差约 6 倍。</p>''')

A('''<p>进一步的证据：换一个初始向量，假结构应当<strong>移动</strong>。
取 <code>&eta;<sub>0</sub> = (2,1)</code>，预测曲线变为
<code>X<sub>0</sub> = &minus;2 sin(x<sub>0</sub>)</code>，
相关系数 <code>+0.292</code>，曲线内外偏离为
<code>&minus;1.0118</code> / <code>&minus;0.1335</code>。
两条预测曲线的平均间距为 <code>0.6246</code>，确实不同。</p>''')

A('''<h3>解法：用梯度向量，或者用二阶指标</h3>
<p>既然切向分量是麻烦的来源，就选一个从构造上避开它的初始向量。
对哈密顿系统，<code>&nabla;H</code> 与流方向正交，是最好的选择。
实测把 <code>&eta;<sub>0</sub></code> 换成
<code>&nabla;H/|&nabla;H|</code> 后，相关系数从 <code>+0.302</code>
降到 <code>+0.271</code>，空间标准差从 <code>1.3795</code> 降到
<code>1.3639</code>。</p>''')

A('''<div class="box warn"><span class="t">诚实记录：改善是微弱的</span>
<p>相关系数只从 0.302 降到 0.271，标准差只降了约 1%。
不能宣称"梯度向量消除了伪结构"。真正干净的是二阶指标
（OFLI2），因为它通过<strong>投影</strong>从构造上移除了切向分量，
而不是靠"选一个好方向"。</p></div>''')

# ================================================================ 6
A('<h2 class="sec" id="s6"><span class="num">6</span>陷阱二：线性方程也会指数增长</h2>')

A('''<p>第二个陷阱更深刻：<strong>一个线性方程可以有正的 Lyapunov 指数，
而系统本身完全不混沌。</strong>这不是数值错误，是正确的物理。</p>''')

A('''<p>考虑两个耦合的单摆（一个摆的悬挂点挂在另一个摆上，
但只考虑小角度的横向耦合）：</p>''')

A('<div class="eq">H = &frac12;(X&sup2;+Y&sup2;) &minus; (1+ab)cos x &minus; a cos y'
  ' + ab cos x cos y'
  '<span class="lbl">(20)</span></div>')

A('''<p>由 <code>x&prime; = &part;H/&part;X</code>、
<code>X&prime; = &minus;&part;H/&part;x</code> 得到运动方程：</p>''')

A('<div class="eq">x&Prime; = &minus;(1 + ab &minus; ab cos y) sin x ,'
  '&nbsp;&nbsp;&nbsp; y&Prime; = &minus;a(1 &minus; b cos x) sin y'
  '<span class="lbl">(21)</span></div>')

A('''<h3>把横向模单独拿出来</h3>
<p>令 <code>y = Y = 0</code> 但给横向一个<em>非零的初始偏差</em>
<code>&delta;y(0) &ne; 0</code>。由 (21) 式，
<code>y &equiv; 0</code> 是一个不变子空间，此时
<code>x</code> 严格满足 <code>x&Prime; = &minus;sin x</code>（就是单摆），
而横向的小偏差满足</p>''')

A('<div class="eq">&delta;y&Prime; = &minus;a(1 &minus; b cos x) &middot; &delta;y'
  '<span class="lbl">(22)</span></div>')

A('''<p>注意这是<strong>线性</strong>方程 —— <code>&delta;y</code> 只以一次幂出现。
但系数 <code>cos x</code> 随时间变化。</p>''')

A('''<h3>参数共振：Mathieu 方程</h3>
<p>在转动区，<code>x</code> 持续单调增长，可以近似写作
<code>x &asymp; &Omega;t</code>，其中 <code>&Omega;</code> 是平均转速。
作变量替换 <code>u = &Omega;t</code>，则
<code>d/dt = &Omega; d/du</code>、<code>d&sup2;/dt&sup2; = &Omega;&sup2; d&sup2;/du&sup2;</code>，
代入 (22) 式：</p>''')

A('<div class="eq">d&sup2;(&delta;y)/du&sup2; ='
  ' &minus;&xi;&sup2;(1 &minus; b cos u) &middot; &delta;y ,'
  '&nbsp;&nbsp;&nbsp; &xi;&sup2; &equiv; a/&Omega;&sup2;'
  '<span class="lbl">(23)</span></div>')

A('''<p>这就是标准的 <strong>Mathieu 方程</strong>：一个振子的"弹簧刚度"
被周期性地调制。这类方程有著名的<strong>不稳定带</strong>（Arnold 舌），
落在</p>''')

A('<div class="eq">&xi; = k/2 ,&nbsp;&nbsp;&nbsp; k = 1, 2, 3, &hellip;'
  '<span class="lbl">(24)</span></div>')

A('''<p>把 <code>&xi;&sup2; = a/&Omega;&sup2;</code> 代回，
并用 <code>a = 4</code>，就得到转速的条件：</p>''')

A('<div class="eq">a/&Omega;&sup2; = k&sup2;/4'
  '&nbsp;&nbsp;&rArr;&nbsp;&nbsp; &Omega; = 2&radic;a / k'
  '&nbsp;&nbsp;&rArr;&nbsp;&nbsp; &Omega; = 4/k'
  '<span class="lbl">(25)</span></div>')

A('''<p>所以横向模在这些转速上指数增长。<strong>这是参数共振，不是混沌。</strong>
它完美解决了"单摆是混沌的"这个悖论：谱方法说运动是周期的，
变分方法说存在正的指数 —— 两者都对，描述的是不同的东西。
一个关于轨道是否重复，一个关于横向微扰是否被放大。</p>''')

A('''<h3>数值验证</h3>
<p>先用标准 Mathieu 方程本身检验。对 (23) 式积分一个周期，
计算 Floquet 乘子（转移矩阵的特征值）模的最大值 <code>&rho;</code>：
<code>|&rho;| = 1</code> 表示稳定，<code>|&rho;| &gt; 1</code> 表示指数增长。</p>''')

A('''<table>
<tr><th>k</th><th class="num">预测 &xi; = k/2</th>
<th class="num">实测带中心</th><th class="num">上移量</th>
<th class="num">带宽</th></tr>
<tr><td>1</td><td class="num">0.500</td><td class="num">0.5350</td>
<td class="num">+0.0350</td><td class="num">0.2550</td></tr>
<tr><td>2</td><td class="num">1.000</td><td class="num">1.1000</td>
<td class="num">+0.1000</td><td class="num">0.2650</td></tr>
<tr><td>3</td><td class="num">1.500</td><td class="num">1.6550</td>
<td class="num">+0.1550</td><td class="num">0.2650</td></tr>
<tr><td>4</td><td class="num">2.000</td><td class="num">2.2150</td>
<td class="num">+0.2150</td><td class="num">0.2700</td></tr>
</table>''')

A('''<p>带中心并不精确落在 <code>k/2</code> 上，而是<strong>系统性地上移</strong>，
位移随 <code>k</code> 增大。这不是理论失效：<code>&xi; = k/2</code>
是 <code>b &rarr; 0</code> 的极限结论，而这里 <code>b = 1</code> 并不小。
Mathieu 方程的特征值满足 <code>A<sub>n</sub> = n&sup2; + O(Q&sup2;)</code>，
二阶修正正是向上偏移。</p>''')

A('''<p>把 <code>b</code> 调小，预测就恢复精确：</p>''')

A('''<table>
<tr><th>b</th><th>实测带中心</th><th>是否包含 k/2</th></tr>
<tr><td class="num">0.05</td><td class="num">0.500</td><td>是</td></tr>
<tr><td class="num">0.10</td><td class="num">0.500</td><td>是</td></tr>
<tr><td class="num">0.20</td><td class="num">0.500 &nbsp; 1.005</td><td>是</td></tr>
</table>''')

A('''<p>另外两个定性性质也成立：带宽随 <code>b</code> 增大、随 <code>k</code> 减小。
实测（<code>b = 0.70</code>）带宽依次为
<code>0.175, 0.125, 0.090, 0.055, 0.020</code>，严格递减。</p>''')

A('''<h3>核验：带间必须是稳定的</h3>
<p>只验证"带中心不稳定"是不够的 —— 一个处处增长的函数也会有局部极大。
必须同时验证<strong>带与带之间是稳定的</strong>（<code>&rho; = 1</code>）。
实测三个间隙点全部给出 <code>&mu; = ln|&rho;| = 0.00e+00</code>，
而带中心给出 <code>&mu; &asymp; 0.8</code>。这条双向检验才排除了伪极大。</p>''')

A(img('sp_mathieu_bands.png',
      '左：标准 Mathieu 方程的 Floquet 增长量随 &xi;。'
      '虚线标出预测位置 &xi; = k/2，实线尖峰是实测的不稳定带，'
      '带之间严格为 0。右：真实耦合摆中横向模的 Lyapunov 指数随初速度 X 变化，'
      '红色标出定位到的共振带。'))

A('''<h3>在真实系统上验证</h3>
<p>把同样的测量搬到耦合摆上，播种<strong>横向</strong>偏差
<code>&delta;y</code>，用辛积分器算它的指数增长率。
预测是共振出现在 <code>&Omega; = 4/k</code>。</p>''')

A('''<p>这里有一个必须注意的细节：式 (25) 里的 <code>&Omega;</code> 是
<strong>实际转动角频率</strong>，不是初始角速度 <code>X</code>。
在快转极限下两者接近，但靠近分界线时轨道会在顶端滞留很久，
实际频率远低于 <code>X</code>。实测比值 <code>X/&Omega;</code>：</p>''')

A('''<table>
<tr><th class="num">X</th><th class="num">2.05</th><th class="num">2.50</th>
<th class="num">3.00</th><th class="num">4.00</th><th class="num">6.00</th></tr>
<tr><td>&Omega;</td><td class="num">1.100</td><td class="num">1.968</td>
<td class="num">2.604</td><td class="num">3.727</td><td class="num">5.827</td></tr>
<tr><td>X/&Omega;</td><td class="num">1.863</td><td class="num">1.270</td>
<td class="num">1.152</td><td class="num">1.073</td><td class="num">1.030</td></tr>
</table>''')

A('''<p>用实际频率 <code>&Omega;</code> 作为自变量，预测立刻变得锐利：</p>''')

A('''<table>
<tr><th>带</th><th class="num">峰值 X</th><th class="num">&Omega;</th>
<th class="num">&xi;</th><th class="num">推断 k</th>
<th class="num">&Omega; vs 4/k 偏差</th></tr>
<tr class="hi"><td>k = 2</td><td class="num">2.52</td><td class="num">1.9941</td>
<td class="num">1.0030</td><td class="num">2.01</td><td class="num">0.30 %</td></tr>
<tr class="hi"><td>k = 1</td><td class="num">4.33</td><td class="num">4.0776</td>
<td class="num">0.4905</td><td class="num">0.98</td><td class="num">1.94 %</td></tr>
</table>''')

A('''<p>最大偏差 <code>|&xi; &minus; k/2| = 0.0095</code>。
若改用初始速度 <code>X</code> 直接读带位，会残留 5–15% 的系统偏差，
很容易被误判成"理论失效"。</p>''')

A('''<h3>对照实验：这是横向模的性质</h3>
<p>最有力的证据是<strong>反证</strong>。同一条轨道上，
纵向模 <code>&delta;x</code> 应当完全规则（它就是单摆本身），
只有横向模 <code>&delta;y</code> 共振。</p>''')

A('''<table>
<tr><th class="num">X</th><th class="num">2.50</th><th class="num">3.00</th>
<th class="num">3.50</th><th class="num">4.00</th><th class="num">4.50</th>
<th class="num">5.00</th></tr>
<tr><td>&lambda;(&delta;x)</td><td class="num">&minus;0.0007</td>
<td class="num">&minus;0.0001</td><td class="num">+0.0002</td>
<td class="num">+0.0003</td><td class="num">&minus;0.0001</td>
<td class="num">&minus;0.0000</td></tr>
<tr class="hi"><td>&lambda;(&delta;y)</td><td class="num">0.2460</td>
<td class="num">&minus;0.0002</td><td class="num">0.1520</td>
<td class="num">0.4493</td><td class="num">0.4621</td>
<td class="num">0.2767</td></tr>
</table>''')

A('''<p>纵向模始终 <code>&le; 0.0003</code>，横向模在共振带上达到
<code>0.4621</code> —— 相差三个数量级。结论明确：
<strong>正指数属于横向线性模，不属于系统。</strong></p>''')

A('''<div class="box note"><span class="t">布局陷阱</span>
<p>状态向量按 <code>[x, y, X, Y]</code> 排布，即<strong>坐标在前</strong>。
所以横向偏差 <code>&delta;y</code> 是<strong>第 2 个</strong>分量，
第 3 个分量是动量 <code>X</code>。播种第 3 个分量量到的是规则的纵向模，
完全没有带 —— 这个错误会让人误以为理论失效。</p></div>''')

# ================================================================ 7
A('<h2 class="sec" id="s7"><span class="num">7</span>陷阱三：积分时间不够</h2>')

A('''<p>第三个陷阱最"物理"：<strong>指标地图的质量取决于积分时长，
而太短的时长会给出定性上错误的图。</strong></p>''')

A('''<p>用一个经典的非线性系统做例子（Hénon–Heiles 势）：</p>''')

A('<div class="eq">H = &frac12;(X&sup2; + Y&sup2; + x&sup2; + y&sup2;)'
  ' + x&sup2;y &minus; y&sup3;/3'
  '<span class="lbl">(26)</span></div>')

A('''<p>它有<strong>两个自由度</strong>，因此与单摆不同：
它容得下一个真正区别于流方向的梯度方向，
前面第 5 节的初始向量比较在这里才是非退化的。</p>''')

A('''<h3>先算一个解析事实：逃逸能量</h3>
<p>势能是 <code>V = (x&sup2;+y&sup2;)/2 + x&sup2;y &minus; y&sup3;/3</code>。
沿 <code>x = 0</code> 这条线：</p>''')

A('<div class="eq">V(0,y) = y&sup2;/2 &minus; y&sup3;/3 ,'
  '&nbsp;&nbsp;&nbsp; dV/dy = y(1 &minus; y)'
  '<span class="lbl">(27)</span></div>')

A('''<p>驻点在 <code>y = 1</code>，代入：</p>''')

A('<div class="eq">V(0,1) = &frac12; &minus; &#8531; = 1/6'
  '<span class="lbl">(28)</span></div>')

A('''<p>这是势能的鞍点。<code>&minus;y&sup3;/3</code> 项使势能沿
<code>y &rarr; +&infin;</code> 趋于 <code>&minus;&infin;</code>，
所以<strong>能量高于 <code>1/6</code> 的轨道会逃逸到无穷远</strong>，
此后能量不再守恒，指数发散，所有指标都读成"混沌"。
实测 <code>V(0,1) = 0.166667</code>，与 <code>1/6</code> 精确吻合。</p>''')

A('''<p>因此地图必须画在 <code>E &lt; 1/6</code> 的能量面上。
常用取值是 <code>E = 1/12</code> 与 <code>E = 1/8</code>。</p>''')

A('''<h3>把地图画在定能量面上</h3>
<p>固定能量意味着四个相空间坐标只有一个自由度可扫。
做法是<strong>解出其中一个动量</strong>。在 <code>x = 0</code> 的截面上，
对每个 <code>(y, Y)</code> 由 (26) 式反解 <code>X</code>：</p>''')

A('<div class="eq">X = &plusmn;&radic;( 2E &minus; Y&sup2; &minus; x&sup2;'
  ' &minus; y&sup2; &minus; 2x&sup2;y + 2y&sup3;/3 )'
  '<span class="lbl">(29)</span></div>')

A('''<p>根号内为负的点属于经典禁区（该初值在给定能量下不可达），
必须<strong>标记出来</strong>而不是悄悄填零。实测生成的初值
能量精确到 <code>2.78&times;10<sup>&minus;17</sup></code>。</p>''')

A('''<p>让指标随积分时长 <code>t<sub>f</sub></code> 变化，
并与一个长时参考（<code>t<sub>f</sub> = 2000</code>）作秩相关比较：</p>''')

A('''<table>
<tr><th class="num">t<sub>f</sub></th><th class="num">50</th>
<th class="num">100</th><th class="num">200</th><th class="num">500</th>
<th class="num">1000</th></tr>
<tr><td>秩相关</td><td class="num">0.563</td><td class="num">0.785</td>
<td class="num">0.872</td><td class="num">0.937</td><td class="num">0.972</td></tr>
<tr><td>中位相对差</td><td class="num">0.948</td><td class="num">0.917</td>
<td class="num">0.875</td><td class="num">0.725</td><td class="num">0.428</td></tr>
</table>''')

A('''<p>秩相关<strong>单调递增</strong>，中位相对差单调递减。
<code>t<sub>f</sub> = 50</code> 时与参考只有 <code>0.563</code> 的一致性，
基本是不可用的。</p>''')

A(img('sp_henon_fig12_tf.png',
      '同一能量面（E = 1/8）上的指标地图，四个积分时长。'
      't<sub>f</sub> = 50（左上）只看到一团弥散的结构；'
      't<sub>f</sub> = 500 与 1000 才显现出稳定的三岛结构。'
      '面板标题给出与 t<sub>f</sub> = 1000 的秩相关。'))

A('''<div class="box note"><span class="t">实用判据</span>
<p>没有先验的"正确时长"公式。可行的做法是先用少量初值试算，
逐步加长时长直到图像不再显著变化，再用这个时长计算正式地图。
上表的秩相关正是"是否还在变"的量化版本。</p></div>''')

A('''<h3>初始向量的影响在这里同样成立</h3>
<p>在同一系统上比较四种初始偏差向量（<code>E = 1/8</code>，
<code>t<sub>f</sub> = 500</code>），指标取平均值：</p>''')

A('''<table>
<tr><th>初始偏差向量</th><th class="num">均值</th>
<th class="num">标准差</th></tr>
<tr><td>&nabla;H / |&nabla;H|</td><td class="num">16.158</td>
<td class="num">12.062</td></tr>
<tr><td>固定 (1,1,1,1)/2</td><td class="num">15.869</td>
<td class="num">12.351</td></tr>
<tr><td>(&minus;f<sub>4</sub>,&minus;f<sub>3</sub>,f<sub>2</sub>,f<sub>1</sub>)/|f|</td>
<td class="num">15.875</td><td class="num">12.469</td></tr>
<tr class="hi"><td>沿流方向 f / |f|</td><td class="num">4.729</td>
<td class="num">6.868</td></tr>
</table>''')

A('''<p>沿流方向的结果被<strong>压制到约 4.7/16.2 &asymp; 29%</strong>。
这正是第 5 节的机制在第二个系统上的独立复现：
偏差向量落在流方向上时，一阶指标只能看到代数增长，于是读出偏低的假值。</p>''')

A(img('sp_henon_fig11_eta0.png',
      '四个初始偏差向量下的指标地图（E = 1/8，t<sub>f</sub> = 500）。'
      '(a)(b) 是两种"随意"的选择，(c) 用梯度方向。(d) 沿流方向，'
      '整体数值被显著压低 —— 这是伪结构的来源。'))

# ================================================================ 8
A('<h2 class="sec" id="s8"><span class="num">8</span>陷阱四：振幅不等于混沌</h2>')

A('''<p>第四个陷阱是一种常见的偷懒：用<strong>振幅的统计量</strong>冒充混沌判据。</p>''')

A('''<p>一个自然的想法是：混沌轨道跑得更"野"，所以角度和角速度的
方差应该更大。于是定义</p>''')

A('<div class="eq">ci = ln( 1 + var(&theta;) + var(&omega;) )'
  '<span class="lbl">(30)</span></div>')

A('''<p>这个量算起来很便宜。但它测的是<strong>吸引子的尺寸</strong>，
不是轨道的混沌程度。</p>''')

A('''<p>把它与真正的 Lyapunov 指数逐点对比，实测相关系数
<code>r = &minus;0.0199</code>，即<strong>基本无关</strong>。
更糟的是在另一个参数区间，它会给出<strong>反号</strong>的相关：</p>''')

A('''<table>
<tr><th>参数</th><th class="num">ci（振幅量）与 &lambda; 的相关</th>
<th class="num">MEGNO 与 &lambda; 的相关</th></tr>
<tr><td>F = 1.1, &gamma; = 0.5</td><td class="num">&minus;0.795</td>
<td class="num">+0.712</td></tr>
<tr><td>F = 1.5, &gamma; = 0.2</td><td class="num">&minus;0.088</td>
<td class="num">&minus;0.020</td></tr>
</table>''')

A('''<p>第一行里振幅量的相关是<strong>负的</strong> ——
符号与真值相反。它会把混沌轨道说成规则、规则轨道说成混沌。
根因很清楚：在那个参数下整个相平面都落到同一对吸引子上，
振幅几乎不变，而 <code>&lambda;</code> 仍在变化。</p>''')

A(img('fp_amplitude_vs_lyapunov.png',
      '左：振幅统计量的地图。中：真实的 Lyapunov 指数地图。'
      '右：两者的散点图 —— 没有可辨的关系。'
      '振幅量测的是吸引子大小，不是混沌。'))

A('''<p>换成正确的指标后，同一批数据上的相关就变成了正的大数：</p>''')

A('''<table>
<tr><th>系统</th><th class="num">ci</th><th class="num">MEGNO</th>
<th class="num">GALI<sub>4</sub></th><th class="num">IACF</th>
<th class="num">SN</th></tr>
<tr><td>双摆</td><td class="num">+0.641</td><td class="num">+0.948</td>
<td class="num">&minus;0.920</td><td class="num">—</td><td class="num">—</td></tr>
<tr><td>受迫摆 F=1.1 &gamma;=0.5</td><td class="num">&minus;0.795</td>
<td class="num">+0.712</td><td class="num">&minus;0.517</td>
<td class="num">+0.696</td><td class="num">+0.729</td></tr>
</table>''')

A('''<p>符号约定要留意：混沌对应 <code>&lambda; &gt; 0</code> 而
<code>GALI &rarr; 0</code>，所以<strong>能用的 GALI 必须与
<code>&lambda;</code> 负相关</strong>。<code>&minus;0.920</code> 是好结果。
反过来说，振幅量给正相关是因为它随指数一起上升，但机理是错的。</p>''')

A('''<div class="box ok"><span class="t">一个诚实的负面结果</span>
<p>在 <code>F = 1.5, &gamma; = 0.2</code> 这一行，<strong>所有指标都失效</strong>：
最强的一个也只有 <code>|&rho;| = 0.198</code>。原因不是指标选错了，
而是参考量本身没有动态范围 —— 该区间
<code>&lambda;</code> 只在 <code>[0.029, 0.070]</code> 内变动，仅 2.4 倍，
而有限时间涨落约为 <code>1/&radic;(&lambda;T)</code>，远大于这个跨度。
此时任何指标都无法工作，这是问题本身的性质。</p></div>''')

# ================================================================ 9
A('<h2 class="sec" id="s9"><span class="num">9</span>地图与分形盆地</h2>')

A('''<p>把上面所有工具组合起来，就在相空间的一定截面上画出指标地图。
一个重要的解读纪律：<strong>固定角速度为零的 (q<sub>1</sub>, q<sub>2</sub>)
截面不是等能量面</strong> —— 每个格点落在不同的能量上。</p>''')

A('''<p>实测证据：双摆的这个截面上，Lyapunov 指数与静态能量的相关系数达
<code>+0.9116</code>，与"能否翻转"的指示为 <code>&minus;0.5526</code>。
也就是说，地图上看到的结构里有相当一部分来自<em>能量</em>的差异，
而不是混沌程度的差异。这是截面的性质，不是指标的缺陷 ——
但读图时必须知道。</p>''')

A(img('dp_energy_compare.png',
      '左：双摆的 Lyapunov 指数地图。中：同一截面的静态势能。'
      '右：两者的散点图（相关系数 +0.912）。'
      '相似性说明该截面混合了能量，结构并非纯混沌信息。'))

A('''<h3>受迫阻尼摆：结构与旋转数</h3>
<p>加入驱动力与阻尼后，方程变为</p>''')

A('<div class="eq">&theta;&Prime; + &gamma;&theta;&prime; + sin&theta;'
  ' = F cos(&Omega;t)'
  '<span class="lbl">(31)</span></div>')

A('''<p>这个系统有一个解析的转变阈值（Melnikov 判据）：</p>''')

A('<div class="eq">F<sub>c</sub> = (4&gamma;/&pi;) &middot;'
  ' cosh(&Omega;&pi;/2)'
  '<span class="lbl">(32)</span></div>''')

A('''<p>取 <code>&Omega; = 2/3</code> 则 <code>cosh(&pi;/3) = 1.600287</code>，
于是 <code>F<sub>c</sub> = 2.037549&gamma;</code>。
这是一个可证伪的解析预测，实测数值（对多个 <code>&gamma;</code>）与它
吻合到 <code>10<sup>&minus;6</sup></code> 量级。</p>''')

A('''<p>在阈值附近扫描驱动力 <code>F</code>，可以看到转变：</p>''')

A('''<table>
<tr><th class="num">F</th><th class="num">0.80</th><th class="num">0.95</th>
<th class="num">1.00</th><th class="num">1.02</th><th class="num">1.10</th>
<th class="num">1.20</th></tr>
<tr><td>max &lambda;</td><td class="num">&minus;0.248</td>
<td class="num">&minus;0.126</td><td class="num">&minus;0.007</td>
<td class="num">&minus;0.070</td><td class="num">+0.075</td>
<td class="num">+0.157</td></tr>
<tr><td>&lambda;&gt;0 占比</td><td class="num">0.00</td><td class="num">0.00</td>
<td class="num">0.00</td><td class="num">0.00</td><td class="num">0.92</td>
<td class="num">1.00</td></tr>
</table>''')

A('''<p><code>F = 1.00</code>（即 <code>F/F<sub>c</sub> = 0.982</code>）时
最大指数为 <code>&minus;0.007</code>，几乎压在零上 —— 转变点确实在此。</p>''')

A('''<p>更细的结构来自<strong>旋转数</strong>（一个驱动周期内转过的圈数）。
它与 Lyapunov 指数互补：两个吸引子都可以是混沌的，
只有旋转数能区分它们。</p>''')

A('''<table>
<tr><th class="num">F</th><th class="num">0.4</th><th class="num">0.8</th>
<th class="num">1.0</th><th class="num">1.1</th><th class="num">1.3</th>
<th class="num">1.6</th></tr>
<tr><td>平均 &lambda;</td><td class="num">&minus;0.2500</td>
<td class="num">&minus;0.2497</td><td class="num">&minus;0.0070</td>
<td class="num">&minus;0.0504</td><td class="num">&minus;0.2502</td>
<td class="num">&minus;0.1339</td></tr>
<tr><td>旋转数中位数</td><td class="num">0</td><td class="num">0</td>
<td class="num">0</td><td class="num">0</td><td class="num">&minus;1.000</td>
<td class="num">&minus;0.006</td></tr>
</table>''')

A('''<p>注意 <code>F = 1.3</code>：<code>&lambda; = &minus;0.250</code>
（规则，因为阻尼把它拉到周期轨道），旋转数锁定在
<code>&minus;1</code> 这个整数台阶上 —— 典型的<strong>相锁定</strong>。
只看 <code>&lambda;</code> 会把这种现象整个漏掉。</p>''')

A('''<h3>盆地边界是分形的</h3>
<p>把初始条件按最终落到哪个吸引子染色，两种颜色的边界往往不是光滑曲线，
而是一个分形集。它的维数可以用<strong>不确定指数法</strong>测量。</p>''')

A('''<p>随机取一对距离为 <code>&epsilon;</code> 的点，问它们是否落在不同颜色里。
这个"跨越边界"的概率随 <code>&epsilon;</code> 按幂律下降：</p>''')

A('<div class="eq">f(&epsilon;) &sim; &epsilon;<sup>&alpha;</sup>'
  '&nbsp;&nbsp;&rArr;&nbsp;&nbsp; D = d &minus; &alpha;'
  '<span class="lbl">(33)</span></div>')

A('''<p>其中 <code>d = 2</code> 是相平面维数。<code>&alpha; = 1</code>
对应光滑边界（<code>D = 1</code>），<code>&alpha; = 0</code>
对应完全交错的"谜题"盆地（<code>D = 2</code>）。</p>''')

A('''<p>方法的可靠性可以先在解析已知的集合上检验：</p>''')

A('''<table>
<tr><th>测试边界</th><th class="num">实测 &alpha;</th>
<th class="num">实测 D</th><th class="num">期望</th></tr>
<tr><td>竖直直线</td><td class="num">1.000</td><td class="num">1.000</td>
<td class="num">1</td></tr>
<tr><td>斜直线</td><td class="num">0.989</td><td class="num">1.011</td>
<td class="num">1</td></tr>
<tr><td>Cantor 集</td><td class="num">0.3310</td><td class="num">1.6690</td>
<td class="num">&alpha;=0.3691, D=1.6309</td></tr>
<tr><td>白噪声（饱和）</td><td class="num">0.000</td><td class="num">2.000</td>
<td class="num">&alpha;&rarr;0</td></tr>
</table>''')

A('''<p>解析已知的 Cantor 集给出 <code>&alpha; = 0.3310</code>
对精确值 <code>0.3691</code>，误差 <code>0.038</code>；
白噪声被正确识别为饱和（<code>&alpha; = 0</code>）而不是返回一个假的维数。</p>''')

A('''<p>应用到受迫摆的盆地边界（200×200 网格，40 万次随机投点）：</p>''')

A('''<table>
<tr><th>量</th><th class="num">实测值</th></tr>
<tr class="hi"><td>不确定指数 &alpha;</td><td class="num">0.1953</td></tr>
<tr class="hi"><td>盆地维数 D = 2 &minus; &alpha;</td><td class="num">1.8047</td></tr>
<tr><td>拟合优度 R&sup2;</td><td class="num">0.9645</td></tr>
<tr><td>边界像素占比</td><td class="num">58.96 %</td></tr>
</table>''')

A('''<p><code>D &asymp; 1.80</code> 介于 1（光滑）与 2（完全交错）之间，
且 <code>R&sup2; = 0.965</code> 说明幂律拟合良好。
近六成的像素位于边界上，说明这个盆地边界极其复杂。</p>''')

A(img('fp_winding_map.png',
      '受迫阻尼摆的旋转数盆地。两个旋转方向（正负）之间是分形边界，'
      '其维数约为 1.80。这张图才是该参数下相平面的真实结构。'))

A(img('dp_lyapunov_map.png',
      '双摆的 Lyapunov 指数地图（200×200，T = 120 s，dt = 0.01）。'
      '规则岛与混沌海在颜色上区分明确，'
      '但读数须按量级（规则约 0.005、混沌约 1.35），不能按正负号。'))

# ================================================================ 10
A('<h2 class="sec" id="s10"><span class="num">10</span>全部校验数据</h2>')

A('''<p>下表汇总本报告引用的全部量化结果。
每一行的"校验依据"说明了该数字为何可信 ——
都是与<strong>独立已知</strong>的量对比（解析值、守恒律、
第二个算法实现、或纯几何恒等式），而不是与程序自己此前的输出对比。</p>''')

A('''<h3>数值积分器</h3>
<table>
<tr><th>检验项</th><th class="num">实测</th><th>校验依据</th></tr>
<tr><td>Yoshida 阶条件 &sum;w<sup>n</sup></td>
<td class="num">&le; 9.77e&minus;15</td><td>解析恒等式</td></tr>
<tr><td>收敛阶（显式 2/4/6 阶）</td>
<td class="num">4.0 / 16.0 / 63.9</td><td>理论 4 / 16 / 64</td></tr>
<tr><td>收敛阶（隐式 2/4 阶）</td>
<td class="num">4.0 / 18.6</td><td>理论 4 / 16</td></tr>
<tr><td>辛性 |&Phi;<sup>T</sup>J&Phi; &minus; J|</td>
<td class="num">0 &sim; 3.33e&minus;16</td><td>解析恒等式 (15)</td></tr>
<tr><td>辛性（隐式，正则变量）</td>
<td class="num">1.11e&minus;16 / 2.22e&minus;16</td><td>同上</td></tr>
<tr><td>能量误差前后半段比值（辛 vs RK4）</td>
<td class="num">1.00 vs 1.99</td><td>有界性判据 (17)</td></tr>
<tr><td>能量误差随步长的阶</td>
<td class="num">4.0 / 16.2 / 63.7</td><td>理论 4 / 16 / 64</td></tr>
<tr><td>矢量化推进 vs 逐点循环</td>
<td class="num">差 = 0</td><td>算法等价性</td></tr>
<tr><td>切映射 vs 数值微分</td>
<td class="num">1.48e&minus;11</td><td>独立差分</td></tr>
<tr><td>解析 Jacobian / Hessian vs 差分</td>
<td class="num">5.3e&minus;10 / 4.5e&minus;09</td><td>独立差分</td></tr>
<tr><td>双摆与 Python 独立实现（短时轨迹）</td>
<td class="num">2.9e&minus;14</td><td>第二实现</td></tr>
<tr><td>受迫摆与 Python 独立实现（短时轨迹）</td>
<td class="num">2.0e&minus;13</td><td>第二实现</td></tr>
</table>''')

A('''<h3>指标本身</h3>
<table>
<tr><th>检验项</th><th class="num">实测</th><th>校验依据</th></tr>
<tr><td>SALI &harr; GALI<sub>2</sub> 几何关系</td>
<td class="num">4.44e&minus;16</td><td>恒等式 (11)</td></tr>
<tr><td>MEGNO 谐振子锚点</td><td class="num">+0.00000</td>
<td>解析：偏差量恒定</td></tr>
<tr><td>MEGNO 可积 &rarr; 2（T = 3200）</td>
<td class="num">1.9993</td><td>解析渐近值</td></tr>
<tr><td>MEGNO 混沌增长（T = 100&rarr;400）</td>
<td class="num">68 &rarr; 299</td><td>线性增长律</td></tr>
<tr><td>IACF：常数 / 正弦 / 白噪</td>
<td class="num">1.000000 / 2.0028 / &isin;[1,K]</td><td>解析值</td></tr>
<tr><td>SN：单音 / 双音</td><td class="num">1 / 2</td><td>解析谱结构</td></tr>
<tr><td>GALI<sub>4</sub> 规则 vs 混沌</td>
<td class="num">9.5e&minus;05 vs 2.2e&minus;94</td><td>定性判据</td></tr>
<tr><td>&lambda; 变分法 vs 双轨法</td>
<td class="num">相对差 0.000</td><td>第二算法</td></tr>
<tr><td>Liouville：四指数之和</td>
<td class="num">+6.909e&minus;04</td><td>守恒律 (7)</td></tr>
<tr><td>GALI<sub>2</sub> 二维假阳性率</td>
<td class="num">11/40 = 27 %</td><td>对照真 &lambda;</td></tr>
<tr><td>受迫摆解析衰减率</td>
<td class="num">6.42e&minus;13（&gamma;=3）</td><td>解析特征值</td></tr>
<tr><td>Melnikov 阈值</td>
<td class="num">F<sub>c</sub> = 2.0375&gamma;</td><td>解析式 (32)</td></tr>
<tr><td>盆地维数（Cantor 解析对照）</td>
<td class="num">&alpha;=0.3310 vs 0.3691</td><td>解析维数</td></tr>
</table>''')

A('''<h3>伪结构与参数共振</h3>
<table>
<tr><th>检验项</th><th class="num">实测</th><th>校验依据</th></tr>
<tr><td>单摆可积性基准</td><td class="num">max|&lambda;| = 0.0019</td>
<td>对照混沌 0.7540</td></tr>
<tr><td>伪结构跟踪解析预测曲线 (19)</td>
<td class="num">&rho; = +0.302</td><td>曲线上 &minus;0.980 vs 曲线外 &minus;0.155</td></tr>
<tr><td>换初始向量后伪结构移动</td>
<td class="num">&rho; = +0.292</td>
<td>两曲线间距 0.6246</td></tr>
<tr><td>梯度初始向量的改善</td>
<td class="num">&rho; 0.302 &rarr; 0.271</td>
<td>如实记录为微弱</td></tr>
<tr><td class="num">Mathieu 带中心 vs &xi; = k/2</td>
<td class="num">max 偏差 0.0095</td><td>解析带位 (24)</td></tr>
<tr><td>&Omega; vs 4/k（真实耦合摆）</td>
<td class="num">0.30 % / 1.94 %</td><td>解析式 (25)</td></tr>
<tr><td>带宽随 b 增、随 k 减</td>
<td class="num">两向单调</td><td>定性预测</td></tr>
<tr><td>横向模共振 vs 纵向模规则</td>
<td class="num">0.4621 vs &le;0.0003</td><td>对照实验</td></tr>
<tr><td>逃逸能 V(0,1)</td><td class="num">0.166667</td>
<td>解析 1/6 = 0.166667</td></tr>
<tr><td>定能量初值精度</td><td class="num">2.78e&minus;17</td>
<td>守恒律 (26)</td></tr>
<tr><td>指标随 t<sub>f</sub> 单调收敛</td>
<td class="num">0.563 &rarr; 0.972</td><td>与长时参考对比</td></tr>
<tr><td>沿流初始向量被压制</td>
<td class="num">4.729 vs 16.158</td><td>对照四种选择</td></tr>
<tr><td>Hénon–Heiles 解析导数 vs 差分</td>
<td class="num">1.4e&minus;11 / 6.2e&minus;11 / 5.8e&minus;11</td>
<td>独立差分</td></tr>
</table>''')

A('''<h3>指标有效性的正面与负面结果</h3>
<table>
<tr><th>系统 / 参数</th><th class="num">ci</th><th class="num">MEGNO</th>
<th class="num">GALI<sub>4</sub></th><th class="num">IACF</th>
<th class="num">SN</th><th class="num">&lambda; 动态范围</th></tr>
<tr><td>双摆</td><td class="num">+0.641</td><td class="num">+0.948</td>
<td class="num">&minus;0.920</td><td class="num">—</td><td class="num">—</td>
<td class="num">[0.032, 3.049]</td></tr>
<tr><td>受迫摆 F=1.1 &gamma;=0.5</td><td class="num">&minus;0.795</td>
<td class="num">+0.712</td><td class="num">&minus;0.517</td>
<td class="num">+0.696</td><td class="num">+0.729</td>
<td class="num">[&minus;0.254, 0.087]</td></tr>
<tr><td>受迫摆 F=1.5 &gamma;=0.2</td><td class="num">&minus;0.088</td>
<td class="num">&minus;0.020</td><td class="num">+0.049</td>
<td class="num">+0.198</td><td class="num">+0.087</td>
<td class="num">[0.029, 0.070]</td></tr>
</table>''')

A('''<p>表中数值为 Spearman 秩相关系数（与真实 Lyapunov 指数）。
第三行是诚实的负面结果：动态范围只有 2.4 倍，所有指标都失效。</p>''')

A('''<h3>地图与全局量</h3>
<table>
<tr><th>量</th><th class="num">实测值</th><th>说明</th></tr>
<tr><td>双摆 &lambda; vs 静态能量</td><td class="num">+0.9116</td>
<td>说明该截面混合了能量</td></tr>
<tr><td>双摆 &lambda; vs 可翻转指示</td><td class="num">&minus;0.5526</td>
<td>同上</td></tr>
<tr><td>振幅统计量 vs 真 &lambda;</td><td class="num">&minus;0.0199</td>
<td>基本无关</td></tr>
<tr><td>盆地不确定指数 &alpha;</td><td class="num">0.1953</td>
<td>R&sup2; = 0.9645</td></tr>
<tr><td>盆地维数 D</td><td class="num">1.8047</td><td>D = 2 &minus; &alpha;</td></tr>
<tr><td>边界像素占比</td><td class="num">58.96 %</td><td>边界极其复杂</td></tr>
<tr><td>旋转数中位数 @ F=1.3</td><td class="num">&minus;1.000</td>
<td>相锁定台阶</td></tr>
</table>''')

# ================================================================ 结语
A('<h2 class="sec" id="s11"><span class="num">11</span>结论</h2>')

A('''<p>把全文压缩成几句话：</p>''')

A('''<ol>
<li><strong>混沌的判据是 Lyapunov 指数</strong>，定义为邻近轨道分离的对数增长率。
但它是一个 <code>t&rarr;&infin;</code> 的极限，有限时间估计有
<code>1/&radic;T</code> 量级的涨落，<strong>必须按量级读，不能按符号读</strong>。</li>

<li><strong>替代指标不是新物理，而是同一批偏差向量的不同泛函。</strong>
MEGNO 有绝对标度（规则趋 2），GALI 用楔积范数测"对齐"，
谱指标（IACF、SN）完全不碰变分方程，提供独立交叉检验。</li>

<li><strong>指标的选择依赖相空间维数。</strong>
四维的双摆适合 GALI，二维的受迫摆不适合（实测 27% 假阳性）。
把结论跨维数照搬会出错。</li>

<li><strong>三个可复现的陷阱</strong>：
初始偏差向量落在流方向上会产生伪结构（实测压低到 29%）；
线性方程的<em>参数共振</em>会给出正指数而系统并不混沌
（Mathieu 带在 <code>&Omega; = 4/k</code>，实测偏差 ≤1.94%）；
积分时间不足会给出定性错误的图（秩相关 0.563 → 0.972）。</li>

<li><strong>数值方法本身必须无偏。</strong>
哈密顿系统要用辛积分器，它保证能量误差有界（前后半段比 1.00 vs 1.99），
而不是单调漂移。不可分的哈密顿量必须用隐式格式，
且必须在正则变量里积分。</li>

<li><strong>振幅不等于混沌。</strong>
<code>ln(1+var)</code> 与真实指数的相关系数是 <code>&minus;0.0199</code>，
且在部分参数下符号相反。它测的是吸引子尺寸。</li>
</ol>''')

A('''<div class="box note"><span class="t">一条方法论</span>
<p>本报告引用的每个数字都与<strong>独立已知</strong>的量对比：
解析恒等式、守恒律、第二套算法、或纯几何关系。
一个只与自己此前输出对比的检验，什么也证明不了。
同样重要的是<strong>记录负面结果</strong> ——
"这个区间所有指标都失效"和"这个改善只有 1%" 与正面结果同样有用。</p></div>''')

A('''
<hr class="soft">
<p class="small">本文件为自包含单文件：全部图形以 base64 内嵌，
不引用任何外部资源，可单独打开或离线分发。</p>
</div>
</body>
</html>
''')

html = ''.join(B)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, 'w', encoding='utf-8') as fh:
    fh.write(html)

print('wrote %s' % OUT)
print('  size    : %.2f MB' % (len(html.encode('utf-8')) / 1e6))
print('  figures : %d (embedded base64)' % _figcount[0])
print('  sections: %d' % html.count('<h2 class="sec"'))
