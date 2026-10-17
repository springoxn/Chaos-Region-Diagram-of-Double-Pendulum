"""
Generate dp_v2/manual.html -- the API reference.

Companion to report.html:
  report.html  -- project introduction, physics, results, reading guidance
  manual.html  -- API reference: every function, every option, edge cases

Generated rather than hand-written so that:
  * every figure is embedded as base64 and the file is self-contained;
  * every numeric value quoted is read from gallery/summary.mat at build time;
  * option tables are checked against the code by tests/verify_docs.m.

Run:  python dp_v2/gen/gen_manual.py
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..'))
GAL = os.path.join(ROOT, 'gallery')

sys.path.insert(0, HERE)
from htmlkit import code, tbl, box, fig, page, selfcheck  # noqa: E402


def read_summary():
    """Load the basin-dimension numbers, FAILING LOUDLY on a missing key.

    The bare `except` that used to be here substituted hard-coded literals, so a
    renamed field in make_gallery.m silently produced a document quoting numbers
    from no run at all.  See gen_report.py for the same fix and the full
    rationale.
    """
    import scipy.io as sio
    path = os.path.join(GAL, 'summary.mat')
    if not os.path.exists(path):
        raise SystemExit(
            'ERROR: %s not found.  Run make_gallery in MATLAB first.' % path)
    s = sio.loadmat(path, squeeze_me=True, struct_as_record=False)['summary']
    if not hasattr(s, 'basin_dim'):
        raise SystemExit(
            'ERROR: summary.mat has no basin_dim.  make_gallery.m writes it; '
            're-run make_gallery.')
    return {
        'basin_alpha': float(s.basin_dim.alpha),
        'basin_D': float(s.basin_dim.D),
        'basin_R2': float(s.basin_dim.R2),
        'basin_N': int(s.basin_dim.N),
    }


S = read_summary()

TOC = [
    ("总览", [("m-start", "这个文档是什么"), ("m-conventions", "约定")]),
    ("核心", [("m-dplyap", "dp_lyap"), ("m-fplyap", "fp_lyap"),
              ("m-checkparams", "dp_check_params"),
              ("m-traj", "dp_traj / fp_traj"),
              ("m-rk4", "dp_rk4_step"), ("m-jac", "dp_jacobian")]),
    ("地图", [("m-dpmap", "dp_map_lyapunov"), ("m-fpmap", "fp_map"),
              ("m-tiers", "dp_apply_tier — 精度挡位")]),
    ("指标族", [("m-sp", "sp_* 总览"),
                ("m-sysstep", "sp_sys / sp_step"),
                ("m-sprun", "sp_run / sp_run_dp"),
                ("m-spind", "sp_gali / sp_sali / sp_ofli2"),
                ("m-spspec", "sp_iacf / sp_specnum"),
                ("m-spcmp", "sp_map_dp / sp_compare_*"),
                ("m-spmath", "sp_mathieu_bands"),
                ("m-sphenon", "sp_henon_heiles_*")]),
    ("分析", [("m-basin", "basin_dimension"),
              ("m-melnikov", "fp_melnikov_threshold")]),
    ("界面与图库", [("m-gui", "dp_lab / fp_lab"), ("m-gallery", "make_gallery")]),
    ("工程", [("m-tests", "测试套件"), ("m-layout", "文件布局"),
              ("m-pitfalls", "实现注意事项")]),
]

B = []
A = B.append

A('<header class="top">')
A('<h1>dp_v2 接口参考</h1>')
A('<p class="sub">双摆 / 受迫阻尼摆分析工具包 · 全部函数、选项与返回值<br>'
  '项目介绍与物理解读见 <a class="ref" href="report.html">report.html</a></p>')
A('</header>')

# ======================================================================
A('<h2 class="sec" id="m-start">总览</h2>')
A('<p>本文件是接口参考。物理背景、结果解读与读图纪律在 '
  '<a class="ref" href="report.html">report.html</a>。</p>')
A(tbl(['文档', '内容'], [
    ['<a class="ref" href="report.html">report.html</a>',
     '项目介绍、物理、结果与图、读图清单、常见问题'],
    ['<b>manual.html</b>（本文件）', 'API 参考：签名、选项、返回值、注意事项'],
    ['<code>README.md</code>', '速查与成本表'],
]))
A(code("""cd dp_v2
addpath(genpath(pwd))       % 所有子目录
run_all_tests               % 验证（约 15 分钟）"""))

A('<h3 id="m-conventions">约定</h3>')
A(tbl(['约定', '说明'], [
    ['角度单位', '<b>弧度</b>，不是度'],
    ['双摆状态', '<code>[th1; om1; th2; om2]</code>，θ 自竖直向下量起'],
    ['受迫摆角度', '每步折回 <code>[−pi, pi)</code>，精确操作'],
    ['时间单位', '双摆用秒；受迫摆用<b>驱动周期数</b>'],
    ['<code>tier</code>', '精度挡位，展开为 N/T/dt；显式给出的值优先'],
    ['<code>params</code>', '结构体 <code>m1, m2, L1, L2, g</code>'],
    ['默认 g', '9.81'],
    ['未知选项', '<b>直接 error</b>，不静默忽略'],
    ['并行', '有池时自动用 parfor；<code>\'pool\',false</code> 强制串行'],
]))

# ======================================================================
A('<h2 class="sec" id="m-dplyap">核心 · dp_lyap</h2>')
A('<p>双摆的最大 Lyapunov 指数，可选完整谱。数值核心。</p>')
A('<div class="sig">[lam, info] = dp_lyap(y0, T, dt, p)\n'
  '[lam, info] = dp_lyap(y0, T, dt, p, opts)</div>')
A(tbl(['参数', '类型', '说明'], [
    ['<code>y0</code>', '4×1', '初始状态 <code>[th1; om1; th2; om2]</code>'],
    ['<code>T</code>', '标量', '积分时长（秒）'],
    ['<code>dt</code>', '标量', '定步长 RK4 步长。长时间积分建议 ≤0.01'],
    ['<code>p</code>', 'struct', '<code>m1, m2, L1, L2, g</code>'],
    ['<code>opts</code>', 'struct', '见下，可省略'],
]))
A(tbl(['opts 字段', '默认', '说明'], [
    ['<code>transient</code>', '<code>0.3*T</code>', '平均前丢弃的时长（秒）'],
    ['<code>reortho</code>', '10', '重正交间隔（步）'],
    ['<code>method</code>', '<code>tangent</code>',
     '<code>tangent</code>（变分法）或 <code>shadow</code>（双轨迹法）'],
    ['<code>d0</code>', '1e-10', '双轨迹法的初始分离'],
    ['<code>nExponents</code>', '1', '1–4；&gt;1 返回完整谱'],
    ['<code>progress</code>', '<code>false</code>', '打印进度'],
]))
A(tbl(['返回', '说明'], [
    ['<code>lam</code>', '<code>nExponents</code>×1 降序；<code>lam(1)</code> 最大'],
    ['<code>info</code>', '<code>nSteps, nSamples, tTransient, tTotal, reortho, '
     'energyDrift, method</code>'],
]))
A(code("""p = struct('m1',1,'m2',1,'L1',1,'L2',1,'g',9.81);

lam = dp_lyap([2.5;0;2.5;0], 400, 0.005, p, struct('transient',120));
%  -> +1.3191

lam4 = dp_lyap([2.5;0;2.5;0], 400, 0.005, p, ...
               struct('transient',120,'nExponents',4));
%  -> [1.3191, 0.0019, -0.0038, -1.3165]    哈密顿系统，和 = 0

ls = dp_lyap([2.5;0;2.5;0], 400, 0.005, p, ...
             struct('transient',120,'method','shadow'));
%  -> +1.3195    与变分法相差 3.4e-04，独立校验"""))
A(box('note', '两种方法',
      '<p><code>tangent</code> 用机器生成的<b>解析</b> Jacobian 积分变分方程并定期 '
      'QR 重正交（Benettin 算法）。收敛快，能给出完整谱。</p>'
      '<p><code>shadow</code> 积分两条邻近轨道、定期重整分离向量，'
      '<b>不使用 Jacobian</b>。收敛较慢，对重正交间隔有 O(h) 偏差，'
      '只用做独立校验。</p>'))
A(box('warn', '完整谱需要真正的 QR',
      '<p>最大指数只需一个切向量，重正交就是归一化。'
      '但 <code>nExponents&gt;1</code> 时切基会退化，必须做真正的 QR 分解。'
      '<code>dp_lyap</code> 在两种情形下都用 QR，因为 n 很小、代价可忽略。</p>'))

# ======================================================================
A('<h2 class="sec" id="m-fplyap">核心 · fp_lyap</h2>')
A('<p>受迫阻尼摆的指数与旋转数。</p>')
A('<div class="sig">theta\'\' + gamma*theta\' + sin(theta) = F*cos(Omega*t)\n\n'
  '[lam, info] = fp_lyap(th0, om0)\n'
  '[lam, info] = fp_lyap(th0, om0, opts)</div>')
A(tbl(['opts 字段', '默认', '说明'], [
    ['<code>F</code>', '1.5', '驱动幅度'],
    ['<code>gamma</code>', '0.2', '阻尼'],
    ['<code>Omega</code>', '2/3', '驱动频率'],
    ['<code>dt</code>', '0.01', 'RK4 步长'],
    ['<code>periods</code>', '300', '<b>驱动周期数</b>，不是秒'],
    ['<code>transient</code>', '0.3', '丢弃比例（0–1）'],
    ['<code>reortho</code>', '10', '重正交间隔（步）'],
    ['<code>method</code>', '<code>tangent</code>', '<code>tangent</code> 或 <code>shadow</code>'],
    ['<code>d0</code>', '1e-10', '双轨迹法初始分离'],
]))
A('<p><b>返回</b> <code>info</code> 含 <code>winding</code>（<code>&lt;omega&gt;/Omega</code>）、'
  '<code>meanOmega</code>、<code>nSteps</code>、<code>tTotal</code>、<code>method</code>。</p>')
A(code("""% F=1.5, gamma=0.2：两个吸引子都混沌，靠 winding 区分
[v, info] = fp_lyap(1.0, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                                     'dt',0.01,'periods',250));
%  v = +0.0480,  info.winding = +2.0009

[v2, i2] = fp_lyap(2.5, 0.0, struct('F',1.5,'gamma',0.2,'Omega',2/3, ...
                                    'dt',0.01,'periods',250));
%  v2 = +0.0377,  i2.winding = -1.9999    反向旋转"""))
A(box('warn', '积分长度以驱动周期计，不是秒',
      '<p>固定<b>秒数</b>在不同 Omega 下意味着不同的驱动周期数，'
      '频率扫描会因此无法自比。<code>periods</code> 保证跨 Omega 可比；'
      '<code>info.tTotal</code> 同时给出物理秒数。</p>'))

# ======================================================================
A('<h2 class="sec" id="m-checkparams">核心 · 辅助函数</h2>')
A('<h3 id="m-checkparams">dp_check_params</h3>')
A('<div class="sig">p = dp_check_params(p)</div>')
A('<p>补全默认值（全 1，g=9.81）并校验物理合理性：质量、长度、g 必须为正。'
  '所有核心函数都经由它，因此缺字段会在入口处明确报错，'
  '而不是在扫描深处静默产生错误积分。</p>')

A('<h3 id="m-traj">dp_traj / fp_traj</h3>')
A('<div class="sig">yEnd            = dp_traj(y0, T, dt, p)\n\n'
  'thetaEnd        = fp_traj(th0, om0, T, dt, opts)\n'
  '[thetaEnd, omEnd]  = fp_traj(...)\n'
  '[theta, om, t]     = fp_traj(...)   % 三个输出时返回完整轨迹</div>')
A('<p><code>fp_traj</code> 的 <code>opts</code> 字段为 <code>F, gamma, Omega</code>。</p>')

A('<h3 id="m-rk4">dp_rk4_step</h3>')
A('<div class="sig">y_new         = dp_rk4_step(y, dt, p)\n'
  '[y_new, Phin] = dp_rk4_step(y, dt, p, Phi)</div>')
A('<p>单步 RK4。给出 <code>Phi</code> 时同时推进切空间矩阵 '
  '<code>Phi\' = J(y)·Phi</code>，共用同一组 RK4 级——切向量与轨迹必须用一致的格式积分，'
  '否则 Lyapunov 指数会继承格式不匹配带来的系统误差。</p>')

A('<h3 id="m-jac">dp_jacobian / dp_jacobian_apply</h3>')
A('<div class="sig">J = dp_jacobian(th1,om1,th2,om2, m1,m2,L1,L2,g)         % 4x4，单点\n'
  'A = dp_jacobian_apply(th1,om1,th2,om2, v1,v2,v3,v4, m1,m2,L1,L2,g)  % 4xN，批量</div>')
A('<p>两者都是<b>机器生成</b>的（<code>gen/gen_jacobian*.py</code>），勿手改。'
  '<code>dp_jacobian</code> 供单点使用；<code>dp_jacobian_apply</code> 直接展开 '
  '<code>J·v</code>，共享分母只算一次，是地图扫描快路径的关键。</p>')
A(box('warn', '为什么必须是解析 Jacobian',
      '<p>用有限差分近似 Jacobian 会把 O(h) 误差直接注入切流，'
      '偏置的正是要测量的量。生成脚本自带校验：'
      '与中心差分对比，两点误差 8.9e−10 / 1.9e−09；'
      '<code>test_speed</code> 另测 <code>apply</code> 与 '
      '<code>J*q</code> 的一致性（5.3e−15）。</p>'))

# ======================================================================
A('<h2 class="sec" id="m-dpmap">地图 · dp_map_lyapunov</h2>')
A('<div class="sig">M = dp_map_lyapunov\n'
  'M = dp_map_lyapunov(\'tier\',\'preview\')\n'
  'M = dp_map_lyapunov(\'N\',120, \'T\',120, \'dt\',0.01, \'params\',p)</div>')
A('<p>在 <code>(theta1, theta2)</code>、两角速度为零的平面上扫描，'
  '以真实最大 Lyapunov 指数着色。按行用 <code>dp_lyap_row</code> 计算，'
  '行之间用 parfor 分配。</p>')
A(tbl(['选项', '默认', '说明'], [
    ['<code>N</code>', '120', '每轴网格点数'],
    ['<code>T</code>', '120', '每点积分时长（秒）'],
    ['<code>dt</code>', '0.01', '步长'],
    ['<code>transient</code>', '0.3', '丢弃比例'],
    ['<code>reortho</code>', '10', '重正交间隔'],
    ['<code>params</code>', '全 1 / 9.81', '参数结构体'],
    ['<code>thRange</code>', '<code>[-pi pi]</code>', '两轴范围'],
    ['<code>tier</code>', '<code>\'\'</code>', '<code>preview</code> | <code>standard</code> | <code>accurate</code>'],
    ['<code>progress</code>', '<code>true</code>', '打印进度'],
    ['<code>pool</code>', '<code>true</code>', '有池时用 parfor'],
]))
A(tbl(['返回字段', '说明'], [
    ['<code>lambda</code>', 'N×N 最大 Lyapunov 指数'],
    ['<code>energy</code>', 'N×N 静态势能 <code>V(theta1,theta2)</code>（诊断用）'],
    ['<code>drift</code>', 'N×N 最大能量漂移（精度诊断）'],
    ['<code>th1, th2</code>', '两轴坐标'],
    ['<code>params, T, dt, N</code>', '实际使用的设置'],
    ['<code>elapsed, pointsPerSec</code>', '性能'],
    ['<code>tier, method, slice</code>', '元信息'],
]))
A(box('note', '<code>energy</code> 为什么存在',
      '<p>该切片在 <code>omega=0</code> 时<b>不是能量壳</b>，每点能量不同。'
      '返回它是为了让你能自己检验 '
      '<code>corr(M.lambda(:), M.energy(:))</code>，'
      '而不必只相信文档。详见 '
      '<a class="ref" href="report.html#s-slice">report.html</a>。</p>'))
A(code("""M = dp_map_lyapunov('tier','preview');      % 约 10 秒
imagesc(M.th2, M.th1, M.lambda); axis xy image; colorbar
r = corrcoef(M.lambda(:), M.energy(:));
title(sprintf('r(\\\\lambda,E) = %+.3f', r(1,2)));"""))

A('<h2 class="sec" id="m-fpmap">地图 · fp_map</h2>')
A('<div class="sig">M = fp_map\n'
  'M = fp_map(\'tier\',\'preview\')\n'
  'M = fp_map(\'N\',200, \'F\',1.5, \'gamma\',0.2, \'Omega\',2/3)</div>')
A('<p>在 <code>(theta, omega)</code> 相平面上扫描。与双摆切片不同，'
  '这是同一驱动流的真实相空间截面。</p>')
A(box('note', '一次调用返回三个量，没有 metric 开关',
      '<p>它们回答不同问题，应当一起看：</p>'
      + tbl(['字段', '回答'], [
          ['<code>M.lambda</code>', '<b>是否</b>混沌'],
          ['<code>M.winding</code>', '去了<b>哪个</b>吸引子'],
          ['<code>M.basin</code>', '离散盆地标签，供维数分析']])
      + '<p>强超临界时 λ 地图接近均匀，此时平面的结构全在 winding 里。</p>'))
A(tbl(['选项', '默认', '说明'], [
    ['<code>N</code>', '200', '每轴网格点数'],
    ['<code>F, gamma, Omega</code>', '1.5, 0.2, 2/3', '驱动参数'],
    ['<code>dt</code>', '0.01', '步长'],
    ['<code>periods</code>', '200', '每点驱动周期数'],
    ['<code>transient</code>', '0.3', '丢弃比例'],
    ['<code>reortho</code>', '10', '重正交间隔'],
    ['<code>thRange</code>', '<code>[-pi pi]</code>', 'theta 范围'],
    ['<code>omRange</code>', '<code>[-4 4]</code>', 'omega 范围'],
    ['<code>tier</code>', '<code>\'\'</code>', '精度挡位'],
    ['<code>progress, pool</code>', '<code>true</code>', '进度 / 并行'],
]))
A('<p><b>返回</b>：<code>lambda, winding, basin, th, om, F, gamma, Omega, dt, '
  'periods, N, elapsed, MelnikovFc, supercritical, periodsDone, tier, '
  'pointsPerSec</code>。其中 <code>supercritical</code> 是 '
  '<code>F/MelnikovFc</code>，可直接判断所处区间。</p>')
A(code("""M = fp_map('N',120);
subplot(1,2,1); imagesc(M.th,M.om,M.lambda);  axis xy image; colorbar
title('\\lambda_1   (is it chaotic?)')
subplot(1,2,2); imagesc(M.th,M.om,M.winding); axis xy image; colorbar
title('winding   (which attractor?)')
fprintf('F_c = %.4f,  F/F_c = %.2f\\n', M.MelnikovFc, M.supercritical);
fprintf('basins: +w %d, -w %d\\n', sum(M.basin(:)>0), sum(M.basin(:)<0));"""))

# ======================================================================
A('<h2 class="sec" id="m-tiers">地图 · 精度挡位 dp_apply_tier</h2>')
A('<div class="sig">o = dp_apply_tier(o)      % o.tier 展开为 N / T / dt / periods</div>')
A('<p>收敛的 Lyapunov 指数需要 <code>T &gt;&gt; 1/lambda</code>，这是全部成本。'
  '与其让每次使用都付出发表级代价，三挡<b>已标定</b>的设置被提供。'
  '<b>显式给出的值优先于挡位</b>，所以可以 '
  '<code>(\'tier\',\'preview\',\'N\',200)</code> 混用。</p>')
A(tbl(['挡位', '双摆 (N, T, dt)', '受迫摆 (N, periods)', '误分类率', '误差位置'], [
    ['<code>preview</code>', '48, 30, 0.02', '48, 60', '<b>4.1 %</b>', '边界 0.33 格内'],
    ['<code>standard</code>', '120, 120, 0.01', '120, 250', '<b>2.3 %</b>', '边界 0.22 格内'],
    ['<code>accurate</code>', '240, 400, 0.005', '240, 800', '参考', '—'],
]))
A('<p>"误分类率"是与 <code>accurate</code> 相比，把点判到规则/混沌另一侧的比例。'
  '误差全部集中在边界一格以内。标定脚本：<code>tests/test_tiers.m</code>；'
  '数据：<code>docs/perf_tiers.md</code>。</p>')
A(code("""dp_apply_tier(struct('tier','preview','N',0,'T',0,'dt',0))
%  -> N=48, T=30, dt=0.02

% 挡位 + 覆盖
M = dp_map_lyapunov('tier','preview','N',200);   % N=200，其余按 preview"""))
A(box('warn', '不要把 preview 的结果当作数值结论',
      '<p><code>preview</code> 用于判断"混沌区在哪里"，不是用来引用 λ 的具体数值。'
      '需要数值时用 <code>accurate</code>。</p>'))

# ======================================================================
A('<h2 class="sec" id="m-basin">分析 · basin_dimension</h2>')
A('<p>盆地边界维数，用<b>不确定指数法</b>。</p>')
A('<div class="sig">R = basin_dimension(basin)\n'
  'R = basin_dimension(basin, \'nBalls\',5e5, \'plot\',true)</div>')
A('<p>输入是整数/实数标签矩阵，例如 <code>M.basin</code>。</p>')
A(tbl(['选项', '默认', '说明'], [
    ['<code>nBalls</code>', '4e5', '随机采样点数'],
    ['<code>nEps</code>', '26', '尺度个数'],
    ['<code>maxEps</code>', '40', '最大球半径（像素）'],
    ['<code>fLo, fHi</code>', '0.02, 0.9', '参与拟合的 f 范围'],
    ['<code>seed</code>', '0', '随机种子（可复现）'],
    ['<code>plot</code>', '<code>false</code>', '画标签图与标度律'],
    ['<code>verbose</code>', '<code>true</code>', '打印 alpha、D、R²'],
]))
A(tbl(['返回字段', '说明'], [
    ['<code>alpha</code>', '不确定指数'],
    ['<code>D</code>', '<code>2 − alpha</code>'],
    ['<code>R2</code>', '幂律拟合优度'],
    ['<code>eps, f</code>', '标度曲线原始数据'],
    ['<code>fitMask</code>', '哪些点进入拟合'],
    ['<code>saturated</code>', '标记 alpha=0 被钳制的情形'],
]))
A('<h4>原理</h4>')
A('<p>随机取点，测半径 ε 的邻域内包含多于一类盆地的概率 <code>f(ε)</code>，'
  '则 <code>f ~ ε^alpha</code>，且</p>')
A('<div class="sig">alpha = d − D        即        D = d − alpha        （d = 2）</div>')
A(box('warn', '符号方向容易写反',
      '<p>正确写法是 <code>alpha = d − D</code>，即 <code>D = d − alpha</code>。'
      '<b>D 在减号右边。</b>因为分形边界有 0 ≤ alpha ≤ 1，'
      '所以 D 落在 d−1 与 d 之间。把 alpha 当成较大的那个量是错的。</p>'))
A(tbl(['alpha', '边界性质', 'D', '说明'], [
    ['1', '平滑', 'd − 1', '最可预测'],
    ['(0,1)', '分形', 'd − alpha', '本项目 F=1.5 属此类'],
    ['0', 'riddled', 'd', '<b>D 不是有效描述量</b>'],
]))
A(box('bad', 'alpha ≈ 0 时不要引用 D',
      '<p>alpha=0 意味着边界填满相空间，<code>D=d</code> 只是说"占满了"。'
      '函数在这种情况下会明确拒绝给出 D 并说明原因，'
      '而不是返回一个看起来正常的数。</p>'))
A(code("M = fp_map('N',200, 'F',1.5, 'gamma',0.2);\n"
       "R = basin_dimension(M.basin, 'plot',true);\n"
       "fprintf('alpha = %.4f  D = %.4f  R2 = %.4f  (N=%d)\\n', ...\n"
       "        R.alpha, R.D, R.R2, R.N);\n"
       "fprintf('boundary pixels: %.1f%%\\n', 100*R.boundaryFrac);\n"
       "%%  ->  alpha = " + ('%.4f' % S['basin_alpha'])
       + "   D = " + ('%.4f' % S['basin_D'])
       + "   R2 = " + ('%.4f' % S['basin_R2'])
       + "   (N=" + str(S['basin_N']) + ")"))
A(fig('fp_basin_dimension.png', 'basin boundary uncertainty exponent scaling',
      '<b>图</b> — 左：盆地标签；右：标度律 <code>f(eps) ~ eps^alpha</code>。'
      '实测 <b>alpha = %.4f → D = %.4f</b>（R² = %.4f）。'
      % (S['basin_alpha'], S['basin_D'], S['basin_R2'])))
A(box('warn', '网格太细的问题',
      '<p>N 过小时标度律无法拟合，函数会<b>报错并打印完整的 f(eps) 曲线</b>，'
      '而不是返回不可信的数。N=200 可以稳定拟合。</p>'))

# ======================================================================
A('<h2 class="sec" id="m-melnikov">分析 · fp_melnikov_threshold</h2>')
A('<div class="sig">Fc = fp_melnikov_threshold(gamma, Omega)\n'
  '[Fc, sechFactor] = fp_melnikov_threshold(gamma, Omega)</div>')
A('<div class="sig">M(t0) = −8*gamma + 2*pi*F*sech(Omega*pi/2)*cos(Omega*t0)\n\n'
  '简零存在（⇒ 横截异宿纠缠 ⇒ Smale 马蹄）当且仅当\n\n'
  'F > F_c = (4*gamma/pi)*cosh(Omega*pi/2)</div>')
A(code("""fp_melnikov_threshold(0.2, 2/3)     % -> 0.40751
fp_melnikov_threshold(0.5, 2/3)     % -> 1.01877
% cosh(pi/3) = 1.600287，故 F_c = 2.037549 * gamma"""))
A('<p>函数内部自查 <code>(4/pi)cosh = 4/(pi*sech)</code> 恒等式。</p>')
A(box('warn', 'Melnikov 的适用边界',
      '<p>它是一阶微扰结果，只在小 gamma、小 F 下<b>定量</b>可靠。'
      '它保证的是马蹄（几何/暂态意义），<b>不保证混沌吸引子存在</b>。</p>'
      '<p>用法：用它定位转变点，再用 <code>fp_lyap</code> 验证。'
      '数值上 F=1.00（F/F_c=0.982）时 lambda_max=−0.0070，几乎精确压在零上。</p>'))

# ======================================================================
A('<h2 class="sec" id="m-gui">界面与图库</h2>')
A('<h3>dp_lab</h3>')
A(code("""dp_lab"""))
A(tbl(['控件', '说明'], [
    ['<code>accuracy</code>', 'preview / standard / accurate，自动填入 N、T、dt'],
    ['<code>N, T, dt</code>', '手动微调；改动后挡位显示为自定义'],
    ['<code>m2/m1, L2/L1, m1, L1</code>', '物理参数（无量纲化后只有两个独立比值）'],
    ['<code>colour by</code>', 'λ 或静态势能；后者叠加解析翻转阈值'],
    ['<code>COMPUTE</code>', '计算，实时进度与预计剩余时间'],
    ['<code>Reset / Cancel</code>', '运行中按下即取消'],
]))
A('<p>点击地图任意位置画出该初值轨迹并报告 λ、能量与去相关时间。'
  '状态栏始终写明指标与积分设置。</p>')

A('<h3>fp_lab</h3>')
A(code("""fp_lab"""))
A('<p>并排显示 λ 与 winding。参数栏实时给出 Melnikov 阈值与区间判语：'
  '<code>SUBCRITICAL</code> / <code>NEAR THRESHOLD</code> / '
  '<code>SUPERCRITICAL</code> / <code>STRONGLY SUPERCRITICAL</code>。'
  '运行中预设按钮变为 CANCEL。</p>')

A('<h2 class="sec" id="m-sp">指标族 · sp_*</h2>')
A('<p>受迫摆是 <b>2 维耗散流</b>，GALI/SALI 在此<b>退化</b>（实测 27% 假阳性）；'
  '双摆是 <b>4 维</b>，GALI 才是主场。因此 <b>指标选择依赖系统维度</b>：'
  '双摆用 GALI/MEGNO，受迫摆用 MEGNO/OFLI2/IACF。</p>')

A('<h3 id="m-sysstep">sp_sys</h3>')
A('<div class="sig">sys = sp_sys(\'pendulum\', \'F\',1.5, \'gamma\',0.2, \'Omega\',2/3)\n'
  'sys = sp_sys(\'coupled\',  \'a\',4,   \'b\',1)</div>')
A('<p>可分哈密顿系统 <code>H = |p|²/2 + V(q)</code>（单位质量），携带'
  '<code>force</code> / <code>dforce</code>（解析 Hessian）/ '
  '<code>d2force</code>（三阶导，供 OFLI2）/ <code>energy</code>。'
  '导数<b>全部解析</b>：差分会在切空间里注入 O(eps) 误差，而切空间正是所有变分指标的来源。'
  '选项名写错会直接报错，不静默取默认值。</p>')

A('<h3>sp_step</h3>')
A('<div class="sig">[y, V, g, t] = sp_step(y, V, t, h, sys, order)</div>')
A('<p>显式辛单步（Yoshida 2/4/6），同时按<b>同一合成映射</b>推进切空间。'
  '<code>order</code> = 2 即 Verlet。<code>g</code> 是每步被除掉的范数，'
  '是 Lyapunov / MEGNO / FLI 的原始材料。'
  '受迫摆 <code>gamma&gt;0</code> 时阻尼作为可精确求解的收缩算子 Strang 夹在两端，'
  '保守部分保持严格辛结构。</p>')

A('<h3 id="m-sprun">sp_run</h3>')
A('<div class="sig">R = sp_run(sys, Y0, opts)   % Y0 是 ndof x N，一整行初值同步推进</div>')
A(tbl(['选项', '默认', '说明'], [
    ['<code>order</code>', '4', 'Yoshida 合成阶：2 | 4 | 6'],
    ['<code>T</code>, <code>dt</code>', '100, 0.01', '积分时间与步长'],
    ['<code>transient</code>', '0.3', '平均前丢弃的比例'],
    ['<code>nGali</code>', '2', '跟踪的偏差向量数 1..ndof'],
    ['<code>sample</code>', '[]', '采样间隔（步）；<code>[]</code> 由 <code>nSamp</code> 推'],
    ['<code>spectral</code>', 'false', '是否逐点计算 IACF / SN（见下）'],
]))
A('<p>返回 <code>lambda</code>、<code>mega</code>（MEGNO）、<code>fli</code>、'
  '<code>gali</code>、<code>sali</code>、<code>galiSeries</code>、'
  '<code>iacf</code>、<code>specnum</code>。</p>')
A(box('note', 'MEGNO 的 T 门槛',
      '<p>实测 T=100 → 1.75、T=3200 → 1.9993。'
      '<b>T &lt; 1000 的 MEGNO 定量结论不可信</b>，地图上尤其容易踩'
      '（<code>periodsInd</code> 默认 200 周期偏短）。</p>'))
A(box('note', '谱指标为何要显式打开',
      '<p><code>iacf</code>/<code>specnum</code> 需要逐点的时间序列。'
      '它们与 MEGNO/GALI 出自<b>同一次积分</b>（无第二次轨迹遍历），'
      '但每点要跑一次自相关/FFT，所以默认关闭。</p>'
      '<p><code>sp_run</code> 曾把这两个字段<b>硬编码为 <code>[]</code></b> —— '
      '字段存在、永远为空、且不报错。现已实现并加回归测试。</p>'))

A('<h3>sp_run_dp</h3>')
A('<div class="sig">R = sp_run_dp(y0, T, dt, p, opts)\n'
  '   % y0 是 4xN，行序 [th1; om1; th2; om2]</div>')
A('<p>双摆版驱动，走<b>隐式</b>辛步进器 —— 双摆哈密顿量不可分'
  '（<code>M(q)</code> 依赖坐标），<b>不存在显式辛格式</b>，必须用隐式中点/2 阶 Gauss。'
  '返回 <code>galiAll(k,:)</code>，同时给出 GALI₂/₃/₄。'
  '<code>nGali = 1</code> 时 <code>R.sali</code> 为 <code>[]</code>：SALI 定义在恰好两个向量上。</p>')

A('<h3 id="m-spind">sp_gali / sp_sali / sp_ofli2</h3>')
A('<div class="sig">g = sp_gali(V)      % V 是 ndof x k x N，返回 GALI_k = ||v₁^…^v_k||\n'
  's = sp_sali(V)      % 恰好两个向量；GALI₂ = SALI·sqrt(4−SALI²)/2\n'
  'O = sp_ofli2(sys, Y0, opts)   % 二阶变分，需 sys.d2force</div>')
A('<p>GALI 用薄 QR 的 <code>|det R|</code> 计算楔积范数，数值稳定。'
  '偏差向量<b>只归一化、不正交化</b>：Gram-Schmidt 会强制正交，'
  '而正交性正是 GALI 要测的东西。</p>')

A('<h3 id="m-spspec">sp_iacf / sp_specnum</h3>')
A('<div class="sig">[W, info] = sp_iacf(q, \'B\',40, \'maxLagFrac\',0.75)\n'
  '[SN, info] = sp_specnum(q, \'cutoff\',0.1)</div>')
A('<p>论文 Eq.11–17 的积分自相关 W 与谱峰计数 SN。二者都是<b>谱指标</b>：'
  '只看一条轨的时间序列，完全不碰变分方程，因此是论文推荐的'
  '「与变分指标对质」的独立交叉检验。</p>')
A(box('note', 'W 默认用精确的全滞后求和',
      '<p>论文的 log-lag cascade（Eq.15–17）是一个<b>近似</b>，'
      '实测在正弦上差 0.13%，但在<b>宽带序列</b>上差 <b>31–38%</b> —— '
      '而宽带正是混沌轨道的样子。</p>'
      '<p>旧版把触发阈值设成 2e8，使该分支<b>实际不可达</b>（死代码）。'
      '现在精确和是默认，cascade 只能显式要求（<code>\'fullLimit\',0</code>）。</p>'))

A('<h3 id="m-spcmp">sp_map_dp / sp_compare_dp / sp_compare_forced</h3>')
A('<div class="sig">M = sp_map_dp(\'N\',40, \'T\',40)          % 双摆 GALI/MEGNO 地图\n'
  'R = sp_compare_dp(\'N\',12, \'T\',40)        % 双摆：各指标 vs 真 λ\n'
  'R = sp_compare_forced(\'cases\',{{1.1 0.5}}) % 受迫摆：同上</div>')
A('<p>对照函数用 Spearman <b>秩</b>相关作头条：地图需要的是点的<b>排序</b>正确，'
  '不是线性关系。真值 <code>lambda</code> 来自<b>既有</b>内核 '
  '<code>fp_lyap_row</code> / <code>sp_run_dp</code>，刻意用不属新代码的部分来评分。</p>')
A(box('warn', '地图必须是网格',
      '<p><code>sp_map_dp</code> 与 <code>sp_compare_dp</code> 曾把初值写成 '
      '<code>[th1v;0;th2v;0]</code>，那只走 (θ₁,θ₂) 平面的<b>对角线</b> —— '
      '矩阵秩为 1，每行逐位相等。它不报错，图看着也正常。</p>'
      '<p>现在有 <code>rank(lambda) &gt;= 2</code> 的断言，'
      '并与既有 RK4 地图在同一 slice 上做相关性检查以钉住取向。</p>'))

A('<h3 id="m-spmath">sp_mathieu_bands</h3>')
A('<div class="sig">R = sp_mathieu_bands(\'mode\',\'both\', \'b\',1, \'fig\',true)</div>')
A('<p>验证论文 Eq.26–28 的解析预测：横向模 <code>δy</code> 满足 Mathieu 方程，'
  '失稳带在 <code>ξ = k/2</code>，即 <code>Ω = 4/k</code>。'
  '实测用本项目自己的辛步进器给出 <code>Ω_eff = 4/k</code> 误差 <b>0.30% / 1.94%</b>（k=2 / k=1）。</p>')
A(box('warn', '状态布局是 [x; y; X; Y] —— 坐标在前',
      '<p>横向位移 <code>δy</code> 是<b>分量 2</b>，分量 3 是 <code>X</code>。'
      '播种分量 3 量到的是规则的 <code>δx</code> 模态、完全没有带。</p>'
      '<p>另外 <code>ξ = k/2</code> 是 <b>b→0</b> 的陈述；'
      'b=1 时带整体上移且位移随 k 增大。'
      '论文用初速度 X 标注共振，但 Ω 是循环频率，只在快循环极限下相等 —— '
      '实测 X/Ω_eff 从 1.86（X=2.05）降到 1.03（X=6）。</p>'))

A('<h3 id="m-sphenon">sp_henon_heiles_ic / sp_henon_heiles_map</h3>')
A('<div class="sig">[Y0, info] = sp_henon_heiles_ic(\'E\',1/12, \'N\',200, \'plane\',\'yY\')\n'
  'M = sp_henon_heiles_map(\'indicator\',\'ofli2\', \'E\',1/8, \'T\',500, \'N\',120)\n'
  'M = sp_henon_heiles_map(\'indicator\',\'fli\', \'dev0\',\'grad\')\n'
  'sp_henon_heiles_figs()      % 一次生成论文 Fig.11 与 Fig.12</div>')
A('<p>论文 Eq.(20) 的经典 Hénon–Heiles '
  '<code>H = (X²+Y²+x²+y²)/2 + x²y − y³/3</code>，由 '
  '<code>sp_sys(\'henonheiles\')</code> 提供（含解析三阶导，供 OFLI2）。</p>')
A('<p><code>sp_henon_heiles_ic</code> 在<b>固定能量面</b>上反解一个动量，'
  '能量精确到 <b>3e−17</b>。网格范围由能量导出而非硬编码 —— '
  '硬编码 ±0.7 会让 73% 的格点落在经典禁区。'
  '禁区点<b>标记在 <code>info.escaped</code> 里</b>，不静默替换成零。</p>')
A(tbl(['选项', '默认', '说明'], [
    ['<code>E</code>', '1/12', '切片能量；论文用 1/12 与 1/8'],
    ['<code>plane</code>', '<code>yY</code>', '<code>\'yY\'</code>（x=0，论文 Fig.12）'
                                       ' | <code>\'xX\'</code>（y=0）'],
    ['<code>indicator</code>', '<code>ofli2</code>', '<code>\'ofli2\'</code> | <code>\'fli\'</code>'],
    ['<code>dev0</code>', '<code>grad</code>', '仅 fli：<code>grad</code> | <code>flow</code>'
                                               ' | <code>fixed</code> | <code>bad</code>'],
    ['<code>N</code>, <code>T</code>, <code>dt</code>', '120, 500, 0.02', '网格与积分'],
]))
A(box('warn', '逃逸能是 1/6，论文的两条切片都在其下',
      '<p>V 沿 <code>y → +∞</code> 下方无界，<code>E > 1/6</code> 时井是开的，'
      '轨道逃逸、指数发散、所有指标都读成"混沌"。'
      '论文用的 <code>E = 1/12</code> 与 <code>E = 1/8</code> 都低于 1/6，故有界。'
      '实测 <code>V(0,1) = 1/6</code> 精确成立。</p>'))
A(box('note', '论文 Fig.12 的实质主张（实测）',
      '<p>以 <code>tf = 2000</code> 为参考按秩相关量化，E=1/8：</p>'
      '<p><code>tf=50 → 0.563</code>、100 → 0.785、200 → 0.872、'
      '500 → 0.937、1000 → <b>0.972</b>，<b>单调收敛</b>。'
      '论文说短 <code>tf</code> 会给出"完全错误"的图，可复现。</p>'
      '<p>注意论文那句话提到"对称性"，但它指的是哪条对称性<b>未能定位</b>：'
      '实测 <code>Y → −Y</code> <b>不是</b>对称性（势含 −y³/3），'
      '真正成立的是 <code>X → −X</code>（机器精度）。'
      '故 Fig.12 改用不依赖对称性的秩相关来验证。</p>'))

A('<h3 id="m-gallery">make_gallery</h3>')
A('<div class="sig">make_gallery                        % 默认 N=160\n'
  'make_gallery(\'N\',200)\n'
  'make_gallery(\'quick\',true)\n'
  'make_gallery(\'N\',200,\'figuresOnly\',true)    % 只重画，复用缓存</div>')
A(tbl(['选项', '默认', '说明'], [
    ['<code>N</code>', '160', '地图分辨率'],
    ['<code>Tdp, dtdp</code>', '120, 0.01', '双摆积分时长与步长'],
    ['<code>fpPeriods, fpdt</code>', '250, 0.01', '受迫摆周期数与步长'],
    ['<code>quick</code>', '<code>false</code>', 'N=60, T=60, 120 周期'],
    ['<code>reuse</code>', '<code>false</code>', '复用 <code>gallery/*.mat</code>'],
    ['<code>figuresOnly</code>', '<code>false</code>', '<code>reuse</code> + 不启动并行池'],
    ['<code>pool</code>', '<code>true</code>', '是否启动 parpool'],
]))
A('<p><b>输出</b>（<code>gallery/</code>）：'
  '<code>dp_lyapunov_map.png</code>、<code>dp_energy_compare.png</code>、'
  '<code>fp_lyapunov_map.png</code>、<code>fp_winding_map.png</code>、'
  '<code>fp_basin_dimension.png</code>、<code>fp_amplitude_vs_lyapunov.png</code>、'
  '<code>sweep_F.png</code>、<code>summary.mat</code> 及缓存 <code>*.mat</code>。</p>')
A(box('ok', '<code>figuresOnly</code> 是重要的工作流工具',
      '<p>正式 <code>make_gallery</code> 要跑一段时间，但全部物理结果缓存在 '
      '<code>gallery/*.mat</code>。调图例、标题、配色时用 '
      '<code>\'figuresOnly\',true</code>，约 30 秒出图，无需重算。</p>'))

A('<h3>实测耗时</h3>')
A(tbl(['任务', '设置', '耗时'], [
    ['交互预览', '<code>tier=preview</code>（48²）', '双摆 9.4 s / 受迫摆 15.7 s（串行）'],
    ['高分辨率图', 'N=200', '双摆 <b>87 s</b> / 受迫摆 <b>157 s</b>（12 workers）'],
    ['出图挡位', '<code>tier=standard</code>（120²）', '双摆 352 s / 受迫摆 617 s（串行）'],
    ['发表数值', '<code>tier=accurate</code>', '双摆约 55 min / 受迫摆约 2 h'],
]))
A('<p>快速路径与并行详见 <code>docs/perf_tiers.md</code>。</p>')

# ======================================================================
A('<h2 class="sec" id="m-tests">工程 · 测试套件</h2>')
A(code("""cd dp_v2/tests
run_all_tests           % 16 个套件，实测约 25 分钟"""))
A(tbl(['套件', '检验对象'], [
    ['<code>test_core</code>', '收敛阶、正则模式频率、Liouville 谱和、双算法互核'],
    ['<code>test_fp</code>', '解析衰减率、Melnikov 转变点、dt 独立性'],
    ['<code>test_speed</code>', '双摆快速路径的正确性与加速比'],
    ['<code>test_speed_fp</code>', '受迫摆快速路径的正确性与加速比'],
    ['<code>test_analysis</code>', 'Cantor 集维数、合成边界、平滑边界'],
    ['<code>test_tex_lint</code>', '图形文本中的非法 TeX 转义'],
    ['<code>verify_docs</code>', '文档声明的选项与代码是否一致（<b>含全部 sp_* 与 Hénon–Heiles</b>）'],
    ['<code>test_gui</code>', '界面构建与错误路径'],
    ['<code>test_cross</code>', '与独立 Python 实现的交叉验证'],
    ['<code>test_symplectic</code>', 'Yoshida 阶条件、收敛阶、辛性、能量有界性'],
    ['<code>test_implicit</code>', '隐式步进器：正则变换、辛性、阶、共轭切映射'],
    ['<code>test_indicators</code>', '指标族解析锚点、SALI↔GALI₂、GALI 二维退化、'
                                    '<b>sp_run 逐点谱指标</b>'],
    ['<code>test_paper_figures</code>', '论文伪结构复现（含解析预测曲线跟踪）'],
    ['<code>test_mathieu</code>', '论文 Eq.26–28：Mathieu 参数共振失稳带 '
                                 '<code>ξ = k/2</code>（解析预测）'],
    ['<code>test_henon_heiles</code>', '论文 Eq.20 / Fig.11–12：解析导数、逃逸能、'
                                       '<b>OFLI2 随 tf 收敛</b>、η₀ 的影响'],
    ['<code>test_comparison</code>', '各指标 vs 真 λ 的相关性断言，'
                                     '<b>地图秩</b>与 <b>nGali 1..4</b>'],
]))
A('<p>每个断言都对照<b>独立已知</b>的值——解析本征频率、Liouville 定理、'
  '已知维数的 Cantor 集、或第二个实现——而不是代码自己以前的输出。</p>')
A('<h4>诊断脚本（不参与回归）</h4>')
A(tbl(['脚本', '用途'], [
    ['<code>diag_bias.m</code>', '重正交间隔引入的偏差'],
    ['<code>diag_converge.m</code>', '残余误差是有限时间效应还是 bug'],
    ['<code>diag_drift.m</code>', '能量漂移随 dt 的收敛阶'],
    ['<code>diag_finite_time_floor.m</code>', '规则轨道的有限时间 λ 地板'],
    ['<code>diag_shadow.m</code>', '双轨迹法的角度缠绕问题'],
    ['<code>why_pointwise_fails.py</code>', '去相关时间与涨落的算术'],
    ['<code>bench_*.m</code>', '基线、优化后、并行、短积分耗时'],
]))

# ======================================================================
A('<h2 class="sec" id="m-layout">工程 · 文件布局</h2>')
TREE = '\n'.join([
    'dp_v2/',
    '├── core/                    数值内核（界面与脚本共用，无重复实现）',
    '│   ├── dp_rk4_step.m        单步 RK4，可同步推进切空间',
    '│   ├── dp_jacobian.m        解析 Jacobian（生成，单点）',
    '│   ├── dp_jacobian_apply.m  向量化 J*v（生成，批量）',
    '│   ├── dp_lyap.m            指数 / 完整谱，单点',
    '│   ├── dp_lyap_row.m        指数，整行 —— 快速路径',
    '│   ├── dp_traj.m            轨迹',
    '│   ├── dp_check_params.m    参数校验',
    '│   ├── dp_apply_tier.m      精度挡位展开',
    '│   ├── fp_lyap.m            受迫摆指数 + winding，单点',
    '│   ├── fp_lyap_row.m        受迫摆，整行 —— 快速路径',
    '│   ├── fp_traj.m            受迫摆轨迹',
    '│   ├── sp_weights.m         Yoshida 合成权重 + 阶条件',
    '│   ├── sp_step.m            显式辛单步 + 切空间传播',
    '│   ├── sp_sys.m             可分哈密顿系统 + 解析导数',
    '│   ├── sp_run.m             指标族驱动（GALI/SALI/MEGNO/FLI/IACF/SN）',
    '│   ├── sp_run_dp.m          双摆版驱动（隐式辛步进器）',
    '│   ├── sp_gali.m            GALI_k（楔积范数）',
    '│   ├── sp_sali.m            SALI',
    '│   ├── sp_ofli2.m           OFLI2（二阶变分，需 d2force）',
    '│   ├── sp_iacf.m            积分自相关 W（论文 Eq.11-17）',
    '│   ├── sp_specnum.m         谱峰计数 SN',
    '│   ├── dp_imp_step.m        双摆隐式辛单步（项目布局包装）',
    '│   ├── dp_imp_canon.m       双摆隐式辛单步（正则变量，真正的积分器）',
    '│   └── dp_canon_*.m         (θ,ω)↔(θ,p) 转换与 Jacobian',
    '├── maps/',
    '│   ├── dp_map_lyapunov.m    双摆 (θ₁,θ₂) Lyapunov 地图',
    '│   ├── fp_map.m             受迫摆 (θ,ω) Lyapunov+winding+盆地',
    '│   ├── sp_paper_repro.m     论文 §4 平面摆伪结构复现',
    '│   ├── sp_map_dp.m          双摆 GALI/MEGNO 地图（辛积分器）',
    '│   └── sp_henon_heiles_map.m Hénon–Heiles OFLI2/FLI 地图（论文 Fig.11/12）',
    '├── analysis/',
    '│   ├── basin_dimension.m    不确定指数法维数',
    '│   ├── fp_melnikov_threshold.m  解析阈值',
    '│   ├── sp_compare_dp.m      双摆：各指标 vs 真 λ',
    '│   ├── sp_compare_forced.m  受迫摆：各指标 vs 真 λ',
    '│   ├── sp_mathieu_bands.m   论文 Eq.26-28 Mathieu 失稳带验证',
    '│   ├── sp_henon_heiles_ic.m Hénon–Heiles 定能量初始条件',
    '│   ├── sp_henon_heiles_figs.m 论文 Fig.11/12 复现出图',
    '│   └── sp_energy_study.m    辛 vs RK4 能量行为对照',
    '├── gui/                     dp_lab.m, fp_lab.m',
    '├── gen/                     符号生成 + 文档生成（Python）',
    '├── tests/                   测试、诊断、基准',
    '├── gallery/                 图与缓存',
    '└── docs/                    性能诊断与标定数据',
])
A('<div class="sig">' + TREE + '</div>')

A('<h2 class="sec" id="m-pitfalls">工程 · 实现注意事项</h2>')
A('<p>这些是开发中实际踩到、并且会影响结果正确性或可读性的点。</p>')
A(tbl(['事项', '说明'], [
    ['角度必须折回',
     '受迫摆旋转轨道的 θ 会累积到 ~1e4 rad，双精度在该量级的间距足以淹没'
     '双轨迹法的 1e-10 扰动。折回 <code>[−pi,pi)</code> 是精确操作。'],
    ['切向量必须在瞬态期就归一化',
     '否则切向量在进入平均窗口前已溢出，得到无意义的指数。'],
    ['有限时间 λ 的符号不可用于判据',
     '规则轨道在 T≥400 时 λ 为正（约 +0.001–0.006）。按量级读图。'],
    ['绘图失败不得毁掉测量',
     '<code>basin_dimension</code> 把绘图包在独立的 try 中：'
     '调用者先要的是测量，其次才是图。'],
    ['chained indexing 在 R2021a 不可用',
     '<code>d(:).max()</code> 会报"不支持的操作数"而非语法错误，'
     '先赋值给变量再索引。'],
    ['<code>clim</code> 在 R2021a 不存在',
     '需回退到 <code>caxis</code>。'],
    ['cell 字面量中不能夹注释',
     '在 <code>...</code> 续行与下一个元素之间插入注释会破坏解析，'
     '报"维度不一致"。'],
    ['parfor 变量分类',
     '<code>parfor</code> 体内构造的结构体要能被正确切片；'
     '行级循环是最自然的粒度。'],
]))
A(box('note', '一条通用原则',
      '<p>每个"快路径"都必须有一个测试断言它与慢路径给出<b>相同</b>的结果。'
      '改变答案的优化不是优化。本项目的做法是：'
      '<code>test_speed</code> / <code>test_speed_fp</code> 逐点比对两条路径，'
      '并要求加速比本身也作为断言。</p>'))

A('<div class="foot">')
A('<p>由 <code>gen/gen_manual.py</code> 生成；数值在构建时从 '
  '<code>gallery/summary.mat</code> 读取；图表内嵌于本文件。<br>'
  'MATLAB R2021a · <code>tests/verify_docs.m</code> 校验本文档的选项声明与代码一致</p>')
A('</div>')

HTML = page('dp_v2 接口参考 — 双摆 / 受迫阻尼摆工具包', TOC, B)

out = os.path.join(ROOT, 'manual.html')
with io.open(out, 'w', encoding='utf-8') as f:
    f.write(HTML)

print('wrote %s' % out)
rc = selfcheck(HTML, out)
if rc:
    raise SystemExit(rc)
