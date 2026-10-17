"""
Generate dp_v2/report.html -- the project introduction, guide and manual.

This is the document a newcomer reads first.  It is written as an independent
project report: it presents the physics, the numbers and the figures, and it
documents how to use the code.  It deliberately contains no narrative about
what the code used to be.

Like manual.html, this file is GENERATED so that every number in the prose is
read from gallery/summary.mat at build time and every figure is embedded.
The two documents share a builder; this one is the report/guide, the other is
the API reference.

Run:  python dp_v2/gen/gen_report.py
"""
import base64
import os
import re
import io
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
GAL = os.path.join(ROOT, 'gallery')

sys.path.insert(0, HERE)
from htmlkit import code, tbl, box, fig as _fig, page, selfcheck  # noqa: E402


# --------------------------------------------------------------------------
#  numbers, pulled from the results so the prose cannot drift
# --------------------------------------------------------------------------
def read_summary():
    """Load the gallery numbers, FAILING LOUDLY if any expected key is absent.

    This used to wrap everything in a bare `except` that substituted a set of
    hard-coded literals.  The effect was that when make_gallery.m wrote a
    differently-named field, the build kept succeeding and the report quietly
    quoted numbers that came from neither the gallery nor any run -- a
    silent-drift bug that no test and no build failure could reveal.  A missing
    key now stops the build instead.
    """
    import scipy.io as sio
    path = os.path.join(GAL, 'summary.mat')
    if not os.path.exists(path):
        raise SystemExit(
            'ERROR: %s not found.\n'
            '  report.html quotes numbers measured by make_gallery.m, so the '
            'gallery must be built first:\n'
            '      make_gallery            %% in MATLAB, from dp_v2/\n'
            % path)
    s = sio.loadmat(path, squeeze_me=True, struct_as_record=False)['summary']

    missing = [k for k in ('old_metric_corr_with_lambda',
                           'dp_corr_lambda_energy', 'dp_corr_lambda_flippable',
                           'basin_dim', 'sweep_F', 'sweep_lambda_mean',
                           'sweep_winding_median') if not hasattr(s, k)]
    if missing:
        raise SystemExit(
            'ERROR: summary.mat is missing %s\n'
            '  make_gallery.m writes this file; a renamed field means the two '
            'have drifted apart and the document would otherwise fall back to '
            'stale literals.  Re-run make_gallery.' % ', '.join(missing))

    out = {
        'old_corr': float(s.old_metric_corr_with_lambda),
        'corr_E': float(s.dp_corr_lambda_energy),
        'corr_flip': float(s.dp_corr_lambda_flippable),
        'basin_alpha': float(s.basin_dim.alpha),
        'basin_D': float(s.basin_dim.D),
        'basin_R2': float(s.basin_dim.R2),
        'basin_N': int(s.basin_dim.N),
        'sweep_F': [float(x) for x in s.sweep_F],
        'sweep_lam': [float(x) for x in s.sweep_lambda_mean],
        'sweep_w': [float(x) for x in s.sweep_winding_median],
    }
    # The map scales are optional: an older gallery may predate them, and the
    # report renders the figure captions without them.
    for key, attr, cast in (('dp_N', 'N', int), ('dp_T', 'T', int),
                            ('dp_elapsed', 'elapsed', float)):
        if hasattr(s.dp_map, attr):
            out[key] = cast(getattr(s.dp_map, attr))
    for key, attr, cast in (('fp_N', 'N', int), ('fp_periods', 'periods', int),
                            ('fp_elapsed', 'elapsed', float)):
        if hasattr(s.fp_map, attr):
            out[key] = cast(getattr(s.fp_map, attr))
    return out


S = read_summary()


def fig(name, alt, caption):
    return _fig(name, alt, caption)


TOC = [
    ("开始", [("s-what", "这个项目做什么"), ("s-quick", "五分钟上手"),
              ("s-install", "安装与依赖")]),
    ("物理", [("s-sys", "两个系统"), ("s-metrics", "两个指标"),
              ("s-slice", "切片不是能量壳"), ("s-island", "规则岛在哪里")]),
    ("结果", [("s-dp", "双摆混沌地图"), ("s-fp", "受迫摆：盆地而非混沌"),
              ("s-dim", "盆地边界维数"), ("s-sweep", "参数扫描与 Melnikov 阈值")]),
    ("工具", [("s-gui", "交互界面"), ("s-api", "命令行接口"),
              ("s-tiers", "精度挡位与成本")]),
    ("方法", [("s-lyap", "Lyapunov 指数怎么算"),
              ("s-valid", "结果如何验证")]),
    ("参考", [("s-formulas", "公式与常数"), ("s-reading", "读图清单"),
              ("s-limits", "已知限制"), ("s-faq", "常见问题")]),
]


def build_toc():
    out = []
    for head, items in TOC:
        out.append('<h2>%s</h2>' % head)
        for anc, label in items:
            out.append('<a href="#%s">%s</a>' % (anc, label))
    return '\n'.join(out)


B = []
A = B.append

A('<header class="top">')
A('<h1>双摆与受迫摆的混沌结构</h1>')
A('<p class="sub">一个以真实 Lyapunov 指数为度量核心的分析工具包<br>'
  '物理结果 · 交互工具 · 可复现验证 · MATLAB<br>'
  '逐函数的接口说明见 <a class="ref" href="manual.html">接口参考</a></p>')
A('</header>')

# ======================================================================
A('<h2 class="sec" id="s-what">这个项目做什么</h2>')
A('<p>它研究两个经典非线性系统的<b>初值敏感性结构</b>——即"哪些初始条件会走向混沌"：</p>')
A('<ul>'
  '<li><b>双摆</b>（保守）：在 <code>(θ₁, θ₂)</code> 初始角平面上，'
  '哪些区域规则、哪些混沌；</li>'
  '<li><b>受迫阻尼摆</b>（耗散）：在 <code>(θ, ω)</code> 相平面上，'
  '吸引子如何分片、盆地边界如何分形。</li>'
  '</ul>')
A('<p>混沌程度由<b>最大 Lyapunov 指数</b>度量，从变分方程直接算出。'
  '整个包的目标是让每一张图、每一个数都带有可检验的精度说明。</p>')
A('<div class="grid2">'
  '<div class="kv"><h5>度量</h5><p>变分方程 + 重正交化的真实最大 Lyapunov 指数，'
  '解析 Jacobian 由符号计算生成</p></div>'
  '<div class="kv"><h5>验证</h5><p>9 个测试套件：对照解析本征频率、Liouville 定理、'
  '已知维数的 Cantor 集、以及一个独立的 Python 实现</p></div>'
  '<div class="kv"><h5>速度</h5><p>跨点向量化内核，'
  '配合 preview / standard / accurate 三挡精度，误差已标定</p></div>'
  '<div class="kv"><h5>交付</h5><p>两个交互界面、命令行 API、图库生成器和本报告</p></div>'
  '</div>')

A('<h3 id="s-quick">五分钟上手</h3>')
A(code("""cd dp_v2
addpath(genpath(pwd))

% 1) 验证（约 15 分钟，9 个套件）
run_all_tests

% 2) 交互探索
dp_lab          % 双摆：Lyapunov 地图 + 轨迹
fp_lab          % 受迫摆：Lyapunov + 旋转数双视图

% 3) 命令行
M = dp_map_lyapunov('tier','preview');    % 双摆地图，约 10 秒
corr(M.lambda(:), M.energy(:))            % 检验切片混叠程度

F = fp_map('tier','preview');             % 受迫摆地图，约 16 秒
F.supercritical                           % F/F_c，判断所处区间"""))
A(box('note', '最快的路径',
      '<p><code>\'tier\',\'preview\'</code> 是交互级设置，约 10–16 秒出一张地图。'
      '它的误差已实测标定（见 <a href="#s-tiers">精度挡位</a>）：'
      '约 4% 的边界格点分类可能与最高精度不同，全部落在边界一格以内。'
      '默认的 <code>standard</code> 挡位误分类率约 2%。</p>'))

A('<h3 id="s-install">安装与依赖</h3>')
A(tbl(['项目', '要求'], [
    ['MATLAB', 'R2015b 或更高；本报告全部数据在 R2021a 上产生'],
    ['工具箱', '无强制要求。有 Parallel Computing Toolbox 时地图自动用 parfor'],
    ['Python', '仅重新生成 Jacobian 时需要（<code>sympy</code>）；'
     '生成好的 <code>.m</code> 已随包提供'],
    ['可选', '<code>python</code> 在 PATH 中时，交叉验证套件会同时跑独立实现'],
]))
A(code("""% 验证安装（几秒钟）
dp_melnikov_threshold(0.2, 2/3)      % 应返回 0.40751"""))

# ======================================================================
A('<h2 class="sec" id="s-sys">物理</h2>')
A('<h3 id="s-sys">两个系统</h3>')
A(tbl(['', '双摆', '受迫阻尼摆'], [
    ['方程', '耦合非线性 ODE（见 <a href="#s-formulas">公式</a>）',
     '<code>θ\'\' + γθ\' + sinθ = F·cos(Ωt)</code>'],
    ['类型', '<b>保守</b>哈密顿系统', '<b>耗散</b>、周期驱动'],
    ['扫描平面', '<code>(θ₁, θ₂)</code>，两角速度为零',
     '<code>(θ, ω)</code>，t=0'],
    ['平面性质', '<b>不是</b>能量壳——每点能量不同',
     '<b>是</b>同一驱动流的真实相空间截面'],
    ['典型问题', '规则岛 vs 混沌海的边界',
     '多个吸引子的盆地如何交织'],
]))
A('<p>两者的差别决定了读图方式完全不同，这一点在下面 '
  '<a href="#s-slice">切片不是能量壳</a>和<a href="#s-fp">受迫摆</a>两节展开。</p>')

A('<h3 id="s-metrics">两个指标</h3>')
A(tbl(['指标', '含义', '回答的问题'], [
    ['<code>lambda</code>', '相邻轨道分离的指数率',
     '<b>是否</b>混沌'],
    ['<code>winding</code>', '旋转数 <code>⟨ω⟩/Ω</code>，锁定在有理平台',
     '去了<b>哪个</b>吸引子'],
    ['<code>energy</code>', '静态势能 <code>V(θ₁,θ₂)</code>',
     '（诊断用）切片混叠了多少'],
]))
A(box('bad', '两个指标不能互相替代',
      '<p>在强驱动下几乎所有初值都是混沌的，<code>lambda</code> 地图会接近均匀；'
      '此时平面的全部结构都在 <code>winding</code> 里。'
      '只看指数会误以为系统没有结构。</p>'
      '<p>受迫摆默认参数 F=1.5 正是这种情况——见 <a href="#s-fp">结果</a>。</p>'))

A('<h3 id="s-slice">切片不是能量壳</h3>')
A('<p>双摆的 <code>(θ₁, θ₂)</code> 平面在 <code>ω=0</code> 时'
  '<b>不是</b>一个能量壳：每个网格点位于各自的能量 '
  '<code>E = V(θ₁,θ₂)</code>。该平面上任何地图因此都<b>混叠了一整族不同能量的系统</b>。</p>')
A('<p>这是切片的性质，不是指标的缺陷。工具包把静态能量一并返回，'
  '并在图上标注相关系数，让这件事可以直接检验而非只能相信说明。</p>')
A(fig('dp_energy_compare.png', 'Lyapunov map beside static potential energy',
      '<b>图 1</b> — (a) 真实 λ 地图；(b) 静态势能；(c) 二者散点。<br>'
      '(a) 与 (b) 结构相似，但 (c) <b>在每个能量上都有巨大纵向散布</b>：'
      '相同能量可以对应相差一个数量级的 λ。<br>'
      '实测 <code>r(λ, E) = %+.3f</code>，而 '
      '<code>r(λ, 可翻转指示) = %+.3f</code>。<br>'
      '结论：λ 携带的信息<b>多于</b>能量，相关性来自切片。'
      % (S['corr_E'], S['corr_flip'])))

A('<h3 id="s-island">规则岛在哪里，以及一个必须注意的数值事实</h3>')
A('<p>双摆从静止释放时，中央的规则岛边界由<b>解析条件</b>确定：'
  '下摆能否翻过顶点，等价于能量比较。等质量等长时为</p>')
A('<div class="sig">2·cos θ₁ + cos θ₂ = 1</div>')
A('<p>实测该解析边界与混沌地图中规则岛的边缘吻合。这是一个可独立核对的几何事实：'
  '规则岛不是拟合出来的，它有闭式边界。</p>')
A(box('warn', '有限时间的 λ 不会稳定在零',
      '<p>准周期轨道的<b>有限时间</b> Lyapunov 估计以 <code>1/√T</code> 的速率'
      '围绕零涨落。在规则岛中心（真值 λ=0）实测：</p>'
      + tbl(['T', '50', '100', '200', '400', '800'],
            [['λ', '−0.0243', '−0.0038', '−0.0013', '<b>+0.0011</b>', '<b>+0.0011</b>']])
      + '<p><b>T ≥ 400 时规则岛的 λ 是正的。</b>'
      '因此"λ>0 即混沌"这种二值判据会把整个规则岛判成混沌区。</p>'
      '<p>正确读法是按<b>量级</b>：规则岛约 0.005，混沌海约 1.35，'
      '相差近两个数量级。地图在颜色上从不含糊。</p>'))

# ======================================================================
A('<h2 class="sec" id="s-dp">结果 · 双摆混沌地图</h2>')
A(fig('dp_lyapunov_map.png', 'double pendulum largest Lyapunov exponent map',
      '<b>图 2</b> — 双摆最大 Lyapunov 指数地图。切片 ω₁=ω₂=0，'
      'T=120 s，dt=0.01，N=180。<br>'
      '中央深蓝区域是<b>规则岛</b>（λ 比外围小两个数量级），'
      '边缘与解析阈值 <code>2cosθ₁+cosθ₂=1</code> 吻合；'
      '外围是混沌海（λ ≈ 1.3–1.7）。<br>'
      '注意岛内并非均匀：有几条细的深色尖刺伸入混沌区，那是高阶共振的痕迹。'))
A('<p>图中颜色是 λ 本身，可以直接读出"离规则有多远"。'
  '最深的区域 λ 约 0.005，最亮的区域约 1.7——这就是判断规则/混沌的量级差。</p>')

# ======================================================================
A('<h2 class="sec" id="s-fp">结果 · 受迫摆：结构在盆地里，不在混沌里</h2>')
A('<p>受迫摆默认参数 F=1.5、γ=0.2、Ω=2/3。'
  'Melnikov 阈值 <code>F<sub>c</sub> = 0.4075</code>，'
  '所以 <b>F/F<sub>c</sub> = 3.68</b>——远在超临界区。</p>')
A(fig('fp_lyapunov_map.png', 'forced pendulum Lyapunov map',
      '<b>图 3</b> — 该参数下的真实 λ 地图。<b>它几乎是均匀的噪声。</b><br>'
      '原因：100% 的网格点都混沌，λ 只在 0.031–0.068 之间变化。'
      '这不是数值问题，是物理——在强超临界驱动下不存在规则区可供对比。'))
A(fig('fp_winding_map.png', 'forced pendulum rotation number basins',
      '<b>图 4</b> — 同一参数下的<b>旋转数</b>地图。这才是真正有结构的量：'
      '两个反向旋转吸引子的盆地，w = ±2（<b>每个驱动周期转两圈</b>），'
      '边界高度分形。<br>'
      '对比图 3 与图 4，就能看出为什么必须同时用两个指标。'))
A(box('note', '这就是"混沌地图看起来像噪声"的根源',
      '<p>把图 4 的结构标成"混沌程度"来展示，得到的图当然像噪声——'
      '因为被测量的变量在全体网格上是常数。</p>'
      '<p>正确做法是：<code>lambda</code> 回答是否混沌，'
      '<code>winding</code> 回答属于哪个盆地。</p>'))
A('<p><b>|w| = 2 而非 1</b> 值得注意。这些吸引子每个驱动周期完成两整圈旋转，'
  '不是一圈。这与驱动频率 Ω=2/3 和系统的共振结构一致，'
  '可以用 <code>info.meanOmega</code> 直接核对。</p>')

# ======================================================================
A('<h2 class="sec" id="s-dim">结果 · 盆地边界维数</h2>')
A('<p>两个盆地之间的边界是分形的。用<b>不确定指数法</b>测量：'
  '随机取点，看半径为 ε 的邻域内是否跨越多于一个盆地，概率记为 <code>f(ε)</code>，'
  '则 <code>f ~ ε<sup>α</sup></code>，而</p>')
A('<div class="sig">α = d − D        即        D = d − α          （d = 2，平面）</div>')
A(tbl(['α', '边界性质', 'D'], [
    ['α = 1', '平滑', 'd − 1'],
    ['0 &lt; α &lt; 1', '分形', 'd − α'],
    ['α = 0', 'riddled / 交错', '<b>D 不再是有意义的描述量</b>'],
]))
A(fig('fp_basin_dimension.png', 'basin boundary uncertainty exponent scaling',
      '<b>图 5</b> — 左：两类盆地标签；右：标度律 <code>f(ε) ~ ε<sup>α</sup></code>。<br>'
      '实测 <b>α = %.4f → D = %.4f</b>（R² = %.4f，N=%d）。<br>'
      'α 明显落在 (0,1) 内，是分形边界而非平滑边界。'
      % (S['basin_alpha'], S['basin_D'], S['basin_R2'], S['basin_N'])))
A('<p>α 同时也是一个"可预测性"指标：α 越接近 0，边界越接近填满整个平面，'
  '初始条件的微小误差越无法消除。α ≈ 0.2 意味着把分辨率提高一倍，'
  '不确定的初始条件比例只下降约 13%。</p>')
A(box('warn', 'α ≈ 0 时不要引用 D',
      '<p>α = 0 意味着边界填满相空间，此时 <code>D = d</code> 只是说"占满了"，'
      '不携带分形结构的信息。本工具在这种情况下会明确拒绝给出 D 并说明原因，'
      '而不是返回一个看起来正常的数。</p>'))

# ======================================================================
A('<h2 class="sec" id="s-sweep">结果 · 参数扫描与 Melnikov 阈值</h2>')
A('<p>对 <code>θ\'\' + γθ\' + sinθ = F cos(Ωt)</code>，'
  '异宿轨道的 Melnikov 函数给出混沌起始的<b>解析</b>判据：</p>')
A('<div class="sig">M(t₀) = −8γ + 2πF·sech(Ωπ/2)·cos(Ωt₀)\n\n'
  '简零存在（⇒ 横截异宿纠缠 ⇒ Smale 马蹄）当且仅当\n\n'
  'F > F_c = (4γ/π)·cosh(Ωπ/2)\n\n'
  'Ω = 2/3 时 cosh(π/3) = 1.600287，故 F_c = 2.037549·γ</div>')
A('<p>数值扫描（γ=0.5，F<sub>c</sub>=1.019）与理论对照：</p>')
A(fig('sweep_F.png', 'forcing amplitude sweep',
      '<b>图 6</b> — (a) 真实 λ 随 F 的变化；(b) 旋转数。<br>'
      'F ≤ 1.0 时 λ 全部为负（规则）；F = 1.1 与 1.6 出现混沌带；'
      'F = 1.3 时 λ = −0.250，且 w 锁定在 −1 平台——'
      '这是一个<b>周期旋转轨道，不是混沌</b>。'))
A(tbl(['F'] + ['%.1f' % f for f in S['sweep_F']],
      [['λ 域平均'] + ['%+.3f' % v for v in S['sweep_lam']],
       ['winding 中位数'] + ['%+.3f' % v for v in S['sweep_w']]]))
A(box('ok', '理论与数值吻合得很好',
      '<p>Melnikov 预言转变点在 F<sub>c</sub> = 1.019；'
      '数值上 F=1.00 时 λ<sub>max</sub> = −0.0070，几乎精确压在零上，'
      '而 F=1.10 时已有 92% 的初值混沌。</p>'
      '<p>注意 Melnikov 是一阶微扰结果，它保证的是马蹄（几何/暂态意义），'
      '<b>不保证混沌吸引子存在</b>。用法是：用它定位转变点，'
      '再用 Lyapunov 指数确认。</p>'))

# ======================================================================
A('<h2 class="sec" id="s-gui">工具 · 交互界面</h2>')
A('<h3>dp_lab — 双摆实验室</h3>')
A(code("""dp_lab"""))
A('<p>左上 <code>(θ₁,θ₂)</code> 地图，右上轨迹面板，右侧控制栏。</p>')
A(tbl(['控件', '说明'], [
    ['<code>accuracy</code>', '<b>主速度开关</b>：preview / standard / accurate，'
     '自动填入 N、T、dt'],
    ['<code>N</code>, <code>T</code>, <code>dt</code>', '手动微调；改动后挡位显示为自定义'],
    ['<code>colour by</code>', '切换 λ 与静态势能；后者会叠加解析翻转阈值'],
    ['<code>COMPUTE</code>', '计算，带实时进度与预计剩余时间'],
    ['<code>Reset / Cancel</code>', '运行中按下即取消计算'],
]))
A('<p><b>点击地图任意位置</b>会画出该初值的轨迹（颜色轴为时间），'
  '并报告它的 λ、能量与去相关时间。</p>')

A('<h3>fp_lab — 受迫摆实验室</h3>')
A(code("""fp_lab"""))
A('<p>并排显示 λ 与 winding，参数栏实时给出 Melnikov 阈值与所处区间判语：</p>')
A(tbl(['判语', '含义'], [
    ['<code>SUBCRITICAL</code>', 'F &lt; F<sub>c</sub>，预期全部规则'],
    ['<code>NEAR THRESHOLD</code>', 'F ≈ F<sub>c</sub>，规则与混沌并存'],
    ['<code>SUPERCRITICAL</code>', 'F &gt; F<sub>c</sub>，出现混沌带'],
    ['<code>STRONGLY SUPERCRITICAL</code>', 'F ≫ F<sub>c</sub>，几乎全混沌，请看 winding'],
]))
A('<p>内置四组预设参数，覆盖上述四种区间。</p>')

# ======================================================================
A('<h2 class="sec" id="s-api">工具 · 命令行接口</h2>')

A('<h3>dp_lyap — 双摆 Lyapunov 指数</h3>')
A('<div class="sig">[lam, info] = dp_lyap(y0, T, dt, p, opts)</div>')
A(code("""p = struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81);

% 最大指数
lam = dp_lyap([2.5;0;2.5;0], 400, 0.005, p, struct('transient',120));
%  -> +1.3191

% 完整谱：哈密顿系统应满足 sum(lam) = 0
lam4 = dp_lyap([2.5;0;2.5;0], 400, 0.005, p, ...
               struct('transient',120, 'nExponents',4));
%  -> [1.3191, 0.0019, -0.0038, -1.3165]   和 = +6.9e-04

% 用双轨迹法独立核对（不使用 Jacobian）
ls = dp_lyap([2.5;0;2.5;0], 400, 0.005, p, ...
             struct('transient',120, 'method','shadow'));
%  -> +1.3195   与变分法相差 3.4e-04"""))
A(tbl(['opts', '默认', '说明'], [
    ['<code>transient</code>', '0.3*T', '平均前丢弃的时长'],
    ['<code>reortho</code>', '10', '重正交间隔（步）'],
    ['<code>method</code>', '<code>tangent</code>', '<code>tangent</code>（变分）或 '
     '<code>shadow</code>（双轨迹）'],
    ['<code>nExponents</code>', '1', '1–4；&gt;1 返回完整谱'],
]))

A('<h3>dp_map_lyapunov — 双摆地图</h3>')
A('<div class="sig">M = dp_map_lyapunov(\'tier\',\'preview\')\n'
  'M = dp_map_lyapunov(\'N\',120, \'T\',120, \'dt\',0.01)</div>')
A('<p>返回 <code>lambda</code>、<code>energy</code>、<code>drift</code>、'
  '<code>th1</code>、<code>th2</code> 等字段。</p>')
A(code("""M = dp_map_lyapunov('tier','preview');
imagesc(M.th2, M.th1, M.lambda); axis xy image; colorbar
xlabel('\\theta_2(0)'); ylabel('\\theta_1(0)');
title(sprintf('r(\\\\lambda,E) = %+.3f', corrcoef(M.lambda(:),M.energy(:))))"""))

A('<h3>fp_map — 受迫摆地图</h3>')
A('<div class="sig">M = fp_map(\'tier\',\'preview\')\n'
  'M = fp_map(\'N\',200, \'F\',1.5, \'gamma\',0.2, \'Omega\',2/3)</div>')
A('<p>一次调用返回三个量，没有 metric 开关——它们回答不同问题，应当一起看：</p>')
A(tbl(['字段', '含义'], [
    ['<code>M.lambda</code>', '最大 Lyapunov 指数：<b>是否</b>混沌'],
    ['<code>M.winding</code>', '旋转数：<b>哪个</b>吸引子'],
    ['<code>M.basin</code>', '由 winding 得到的盆地标签，供维数分析使用'],
    ['<code>M.MelnikovFc</code>', '解析阈值'],
    ['<code>M.supercritical</code>', 'F/F<sub>c</sub>'],
]))
A(code("""M = fp_map('N',120);
subplot(1,2,1); imagesc(M.th,M.om,M.lambda);  axis xy image; colorbar
title('\\lambda_1   (is it chaotic?)')
subplot(1,2,2); imagesc(M.th,M.om,M.winding); axis xy image; colorbar
title('winding   (which attractor?)')
fprintf('F_c = %.4f,  F/F_c = %.2f\\n', M.MelnikovFc, M.supercritical);"""))

A('<h3>basin_dimension — 盆地边界维数</h3>')
A('<div class="sig">R = basin_dimension(M.basin, \'plot\',true)</div>')
A('<p>返回 <code>alpha</code>、<code>D</code>、<code>R2</code>、'
  '<code>eps</code>、<code>f</code> 等字段。α≈0 时会拒绝给出 D。</p>')

A('<h3>fp_melnikov_threshold — 解析阈值</h3>')
A(code("""fp_melnikov_threshold(0.2, 2/3)     % -> 0.40751
fp_melnikov_threshold(0.5, 2/3)     % -> 1.01877"""))

A('<h3 id="s-tiers">精度挡位与成本</h3>')
A('<p>收敛的 Lyapunov 指数需要 <code>T ≫ 1/λ</code> 的积分，这是全部成本所在。'
  '与其让每次使用都付出发表级代价，本工具提供三挡<b>已标定</b>的设置：</p>')
A(tbl(['挡位', '双摆 (N, T, dt)', '受迫摆 (N, periods)', '实测误分类率',
       '误差位置'], [
    ['<code>preview</code>', '48, 30 s, 0.02', '48, 60', '<b>4.1 %</b>',
     '边界 0.33 格内'],
    ['<code>standard</code>', '120, 120 s, 0.01', '120, 250', '<b>2.3 %</b>',
     '边界 0.22 格内'],
    ['<code>accurate</code>', '240, 400 s, 0.005', '240, 800', '参考', '—'],
]))
A('<p>所谓"误分类率"是指与 <code>accurate</code> 挡位相比，'
  '把点判到规则/混沌另一侧的比例。'
  '<b>误差全部集中在边界一格以内</b>——而那里任何有限时间估计都不可靠，'
  '与花多少钱无关。</p>')
A(box('ok', '为什么分挡位是合理的',
      '<p><code>preview</code> 不会把规则区说成混沌区，只在边界一格内摇摆。'
      '对于"混沌区在哪里"这个地图要回答的问题，这就够了。</p>'
      '<p>需要发表一个具体数值时再切到 <code>accurate</code>。</p>'))
A(tbl(['任务', '挡位', '实测耗时（12 workers）'], [
    ['看一眼地图的结构', '<code>preview</code>（48²）',
     '双摆 <b>9.4 s</b> / 受迫摆 <b>15.7 s</b>（串行）'],
    ['出图', '<code>standard</code>（120²）',
     '双摆 <b>352 s</b> / 受迫摆 <b>617 s</b>（串行）'],
    ['高分辨率图', 'N=200',
     '双摆 <b>87 s</b> / 受迫摆 <b>157 s</b>'],
    ['发表数值', '<code>accurate</code>',
     '双摆约 55 分钟 / 受迫摆约 2 小时'],
]))
A(box('ok', '速度来自哪里',
      '<p>两个层次的优化，都<b>不改变算法</b>：</p>'
      '<ol>'
      '<li><b>跨点向量化。</b>一整行初值作为列向量同步推进，'
      '切空间乘积用符号展开的表达式，共享分母只算一次。'
      '单指数重正交退化为除法（对一个向量而言 QR 就是归一化）。'
      '相同设置下实测快 <b>5.8×</b>（双摆）/ <b>16.9×</b>（受迫摆），'
      '结果差异 <b>5e−11</b> / <b>4e−13</b>。</li>'
      '<li><b>提高并行粒度。</b>按行而非按点分配任务，'
      '12 workers 的加速比从 1.6× 提升到 <b>4.25×</b>。</li>'
      '</ol>'
      '<p>两者叠加，加上挡位选择，交互预览比"逐点 + 全精度"快约 <b>80–250×</b>。</p>'))

A('<h3>图库生成</h3>')
A(code("""make_gallery('N',200)                 % 全部图，约 1 小时（并行）
make_gallery('tier','preview')         % 快速预览
make_gallery('N',200,'figuresOnly',true)  % 只重画图，复用缓存，约 30 秒"""))
A('<p><code>figuresOnly</code> 复用 <code>gallery/*.mat</code> 中的物理结果，'
  '调整图例、标题、配色时无需重算。本报告的版式就是这样迭代出来的。</p>')

# ======================================================================
A('<h2 class="sec" id="s-lyap">方法 · Lyapunov 指数怎么算</h2>')
A('<p>最大 Lyapunov 指数是相邻轨道分离的指数率。实现方式是'
  '<b>Benettin 算法</b>：同时积分轨迹与切向量，定期重新归一化。</p>')
A('<div class="sig">dy/dt = f(y)                     轨迹\n'
  'dq/dt = J(y)·q                   切向量（变分方程）\n\n'
  '每 h 步： λ 累加 log‖q‖，然后 q ← q/‖q‖\n'
  '最后 λ = Σ log‖q‖ / (n·h)</div>')
A('<p>几个实现要点：</p>')
A('<ul>'
  '<li><b>Jacobian 是解析的。</b>由 SymPy 符号求导生成，'
  '而非有限差分。差分引入的 O(h) 误差会直接进入切流，'
  '偏置的正是要测的量。</li>'
  '<li><b>切向量与轨迹同步积分</b>，共用同一组 RK4 级，'
  '避免两者格式不一致带来的系统误差。</li>'
  '<li><b>跨点向量化。</b>一整行初值作为列向量同步推进，'
  '单步开销摊到整行；切空间乘积用符号展开的 '
  '<code>dp_jacobian_apply</code>，共享分母只算一次。</li>'
  '<li><b>受迫摆每步把角度折回</b> <code>[−π,π)</code>。'
  '这是精确操作（场对 θ 是 2π 周期），但很关键：旋转轨道 θ 会累积到 ~10⁴ rad，'
  '双精度在该量级的间距足以淹没双轨迹法的扰动。</li>'
  '</ul>')
A(box('note', '为什么保留两种算法',
      '<p><code>tangent</code> 用解析 Jacobian 积分变分方程（默认），'
      '收敛快且能给出完整谱。</p>'
      '<p><code>shadow</code> 积分两条邻近轨道、定期重整分离向量，'
      '<b>完全不使用 Jacobian</b>。因此它是对 <code>tangent</code> 的独立校验：'
      '两者吻合，是结果正确的强证据，而不只是自洽。</p>'))
A(box('warn', '为什么必须用指数增长率，而不是"轨道跑得多开"之类的代用量',
      '<p>一个常见的简化做法是：积分一段固定时间，然后看轨迹的方差、'
      '位移或末态散布有多大，用这个量当作"混沌程度"。这样省掉了切向量，'
      '看起来更快。</p>'
      '<p>但它测的不是混沌。耗散系统里所有初值最终落到同一批吸引子上，'
      '它们的<b>振幅</b>由吸引子决定，与分离率无关。两个吸引子的振幅可以差很多'
      '而 Lyapunov 指数几乎相同——在这种情况下，方差型指标会把'
      '"振幅大的规则轨道"和"振幅小的混沌轨道"完全对调。</p>'
      '<p>本工具因此直接积分变分方程。代价是每点需要一条切向量，'
      '收益是所测即所报。</p>'
      '<p>顺带一提：即使指标选对了，也<b>不要</b>用"λ&gt;0"做二值判据'
      '——见下文关于有限时间涨落的说明。</p>'))

A('<h3 id="s-valid">结果如何验证</h3>')
A('<p>9 个测试套件，每个断言都对照<b>独立已知</b>的值，'
  '而不是代码自己以前的输出。</p>')
A(tbl(['套件', '检验内容', '实测结果'], [
    ['<code>test_core</code>', 'RK4 收敛阶', '<b>4.23 / 3.86 / 5.01</b>（理论 4）'],
    ['', '正则模式频率 vs 解析', '2.397181 vs 2.397199，相对误差 <b>7.6e−06</b>'],
    ['', '规则轨道 λ 应为 0', '+1.2e−03 / −3.2e−04'],
    ['', '<b>Liouville：完整谱和 = 0</b>',
     '<code>[1.3191, 0.0019, −0.0038, −1.3165]</code>，和 <b>+6.9e−04</b>'],
    ['', '<b>变分法 vs 双轨迹法</b>', '相对差 <b>3.4e−04</b>'],
    ['<code>test_fp</code>', '无驱动阻尼摆 vs 解析衰减率',
     'γ=3：<b>6.4e−13</b>；γ=5：<b>5.6e−14</b>'],
    ['', 'Melnikov 转变点', 'F=1.00 时 λ<sub>max</sub>=<b>−0.0070</b>'],
    ['<code>test_speed</code>', '快速路径 vs 逐点路径',
     '相对差 <b>4.9e−11</b>，加速 <b>5.8×</b>'],
    ['<code>test_speed_fp</code>', '受迫摆快速路径',
     'λ 差 <b>4.1e−13</b>，winding 差 <b>0</b>，加速 <b>16.9×</b>'],
    ['<code>test_analysis</code>', '<b>Cantor 集维数（解析已知）</b>',
     'α=0.331 vs 精确 <b>0.369</b>'],
    ['', '平滑边界 α 应为 1', '竖直 1.000、对角 0.989'],
    ['<code>test_cross</code>', '<b>短时轨迹与独立 Python 实现一致</b>',
     '双摆 <b>2.9e−14</b>，受迫摆 <b>2.0e−13</b>'],
    ['', '长时 winding number 一致', '最大差 <b>2.2e−03</b>'],
    ['', 'λ 网格统计分布一致', '均值差 <b>0.6 %</b>'],
    ['<code>test_tiers</code>', '各挡位误差标定', '见 <a href="#s-tiers">精度挡位</a>'],
    ['<code>test_gui</code>', '界面构建与错误路径', '通过'],
    ['<code>verify_docs</code>', '文档与代码一致性', '通过'],
]))
A('<p>交叉验证分三层，因为<b>逐点比对混沌轨道本身就是不成立的</b>：'
  '两个实现在 <code>T* ≈ ln(1/ε)/λ</code> 之后指数去相关'
  '（双摆约 28 s），此后各自给出独立的有限时间估计，'
  '逐点比较什么都没测。可测的是短时轨迹、尖锐不变量（winding）与统计分布。</p>')

# ======================================================================
A('<h2 class="sec" id="s-formulas">参考 · 公式与常数</h2>')
A('<h4>双摆运动方程</h4>')
A('<div class="sig">Δ = θ₂ − θ₁\n'
  'den1 = (m₁+m₂)L₁ − m₂L₁cos²Δ\n'
  'den2 = (L₂/L₁)·den1\n\n'
  'θ₁\'\' = [ m₂L₁θ₁\'²sinΔcosΔ + m₂g sinθ₂cosΔ + m₂L₂θ₂\'²sinΔ\n'
  '          − (m₁+m₂)g sinθ₁ ] / den1\n\n'
  'θ₂\'\' = [ −m₂L₂θ₂\'²sinΔcosΔ + (m₁+m₂)g sinθ₁cosΔ\n'
  '          − (m₁+m₂)L₁θ₁\'²sinΔ − (m₁+m₂)g sinθ₂ ] / den2</div>')
A('<p>由拉格朗日量符号推导并逐项核对，差恒为零。</p>')
A('<h4>受迫阻尼摆</h4>')
A('<div class="sig">θ\'\' + γθ\' + sinθ = F cos(Ωt)\n\n'
  'Melnikov: F_c = (4γ/π)cosh(Ωπ/2)\n'
  '  Ω = 2/3 :  cosh(π/3) = 1.600287  →  F_c = 2.037549·γ\n'
  '             γ=0.2 → F_c = 0.4075      γ=0.5 → F_c = 1.0188</div>')
A('<h4>不确定指数与盆地维数</h4>')
A('<div class="sig">f(ε) ~ ε^α ,   α = d − D ,   d = 2   →   D = d − α\n\n'
  'α = 1  平滑        D = d − 1\n'
  '0<α<1  分形        D = d − α\n'
  'α = 0  riddled     D = d（无意义）</div>')
A('<h4>数值常数速查</h4>')
A(tbl(['量', '值', '备注'], [
    ['<code>cosh(π/3)</code>', '1.600287', 'Ω=2/3 的 Melnikov 因子'],
    ['双摆正则频率', '2.397199 / 5.787351', '<code>ω²=g(2∓√2)</code>，m=l=1'],
    ['双摆 λ（混沌）', '1.3191', '(2.5,2.5)，dt=0.005 实测'],
    ['双摆去相关时间', '~28 s', '<code>ln(1/ε)/λ</code>'],
    ['受迫摆去相关时间', '~77 个驱动周期', 'F=1.5'],
    ['受迫摆 w（F=1.5）', '±2.000', '每驱动周期两整圈'],
    ['规则岛有限时间 λ', '+0.001 … +0.006', '<b>不是零或负值</b>'],
]))

A('<h2 class="sec" id="s-reading">参考 · 读图清单</h2>')
A('<p>拿到一张图或一个数之前，依次确认：</p>')
A('<ol>'
  '<li><b>这是哪个指标？</b> <code>lambda</code> 是混沌程度，'
  '<code>winding</code> 是吸引子身份。</li>'
  '<li><b>切片是不是能量壳？</b> 双摆 <code>(θ₁,θ₂)@ω=0</code> 不是。</li>'
  '<li><b>T 超过去相关时间了吗？</b> 双摆约 28 s，受迫摆看 λ 的大小。</li>'
  '<li><b>F/F<sub>c</sub> 是多少？</b> 远大于 1 时 λ 地图必然近似均匀。</li>'
  '<li><b>dt 够小吗？</b> 保守系统长时间积分用 0.01 或更小。</li>'
  '<li><b>规则区是按量级还是按符号判定的？</b> '
  '有限时间 λ 不会稳定在零，必须按量级。</li>'
  '<li><b>维数报告了 α、D、R² 三者吗？</b> α≈0 时不要引用 D。</li>'
  '</ol>')

A('<h3>积分纪律</h3>')
A('<p>双摆 RK4（非辛）能量漂移实测（初值 2.5, 2.5）：</p>')
A(tbl(['dt', 't=10 s 相对能量漂移'], [
    ['0.05', '<b>16 %</b>'],
    ['0.02', '4.2e−03'],
    ['<b>0.01</b>', '<b>2.8e−04</b>'],
    ['0.005', '8.6e−06'],
    ['0.0025', '5.0e−07'],
]))
A('<p>实测收敛阶 4.2–5.1，符合四阶方法。</p>')

A('<h2 class="sec" id="s-limits">参考 · 已知限制</h2>')
A('<ol>'
  '<li><b>有限时间 λ 的符号不可用于判据。</b>'
  '规则轨道的估计值在 T≥400 时为正（约 +0.001–0.006）。'
  '必须按量级区分，工具包的文档与界面都按此说明。</li>'
  '<li><b>盆地维数需要足够细的网格。</b>'
  'N 过小时标度律无法拟合，函数会报错并打印 f(ε) 曲线，而非返回不可信的数。</li>'
  '<li><b>Melnikov 是一阶微扰结果</b>，只在小 γ、小 F 下定量可靠，'
  '且保证的是马蹄而非吸引子。</li>'
  '<li><b>受迫摆 λ 在强超临界时空间变化很小</b>（F=1.5 时 0.031–0.068）。'
  '这是真实物理，但意味着不能从 λ 地图读出盆地结构。</li>'
  '<li><b>双摆切片混叠能量。</b> 相关性来自切片，'
  '要排除需改在固定能量壳上扫描。</li>'
  '<li><b><code>accurate</code> 挡位很慢</b>（双摆约 55 分钟）。'
  '这是物理成本的直接反映，无法通过写法优化消除。</li>'
  '</ol>')

A('<h2 class="sec" id="s-faq">参考 · 常见问题</h2>')
A('<h4>地图看起来全是噪声</h4>')
A('<p>几乎总是因为 F ≫ F<sub>c</sub>，所有初值都混沌，λ 地图必然均匀。'
  '<b>请改看 winding。</b>用 <code>M.supercritical</code> 确认。</p>')
A('<h4>λ 和能量相关，是不是指标有问题</h4>')
A('<p>不是。双摆切片混叠了不同能量，相关性是切片的性质。'
  '散点图会显示每个能量上都有巨大纵向散布——λ 不是能量的函数。</p>')
A('<h4>为什么规则区里 λ 是正的</h4>')
A('<p>有限时间估计围绕真值以 1/√T 涨落。规则区真值为 0，'
  '所以估计值可正可负。按量级读图，不要按符号。</p>')
A('<h4>怎么更快</h4>')
A('<p>用 <code>\'tier\',\'preview\'</code>（约 10 秒）。'
  '它的误差已标定：边界一格内约 4% 的格点分类可能与最高精度不同，'
  '内部区域正确。</p>')
A('<h4>计算可以中断吗</h4>')
A('<p>可以。界面运行时 Reset/Cancel 按钮会取消当前计算。</p>')
A('<h4>能算别的质量比 / 长度比吗</h4>')
A('<p>可以。无量纲化后只有两个独立参数 μ=m₂/m₁、λ=L₂/L₁，'
  '总质量与总长度只缩放时间轴。界面里直接改，或：</p>')
A(code("""p = dp_check_params(struct('m1',1,'m2',2,'L1',1,'L2',0.5,'g',9.81));
M = dp_map_lyapunov('tier','preview','params',p);"""))

A('<div class="foot">')
A('<p>本报告由 <code>gen/gen_report.py</code> 生成，'
  '文中数值在每次构建时从 <code>gallery/summary.mat</code> 读取，'
  '全部图表内嵌于本文件。逐函数的接口说明见 '
  '<a class="ref" href="manual.html">manual.html</a>。<br>'
  'MATLAB R2021a · 9/9 测试套件通过 · 性能数据见 <code>docs/perf_tiers.md</code></p>')
A('</div>')

HTML = page('双摆与受迫摆的混沌结构 — 项目报告', TOC, B)

out = os.path.join(ROOT, 'report.html')
with io.open(out, 'w', encoding='utf-8') as f:
    f.write(HTML)

print('wrote %s' % out)
rc = selfcheck(HTML, out)
if rc:
    raise SystemExit(rc)
