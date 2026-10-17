"""
Independent cross-check of dp_v2 against the original project's numerics.

WHAT IS AND IS NOT TESTABLE
---------------------------
Two implementations integrating the same chaotic orbit decorrelate after
T* ~ ln(1/eps)/lambda  (about 28 s for the double pendulum, ~77 drive periods
for the forced pendulum).  Beyond that, each produces an independent finite-time
estimate whose scatter goes like 1/sqrt(lambda*T); a pointwise comparison then
tests nothing but statistical luck.  See why_pointwise_fails.py.

So this script verifies the two implementations against each other using
quantities that are actually invariant:

  A. SHORT-HORIZON POINTWISE: integrate both for T << T* and require the
     trajectories to agree to near machine precision.  This validates the
     vector field, the integrator, and the units.
  B. SHARP INVARIANTS: rotation number (winding) over a long run, which is a
     property of the attractor and must match tightly.
  C. STATISTICAL AGREEMENT: mean and spread of the Lyapunov grid over the
     whole domain.  For a single-attractor regime the pointwise values are
     independent samples of the same distribution -- compare distributions,
     not points.

Reads:  matlab_short.mat, matlab_fp_lyap.mat  (written by test_cross.m)
Writes: crosscheck_result.mat
"""
import sys
import os
import numpy as np
import scipy.io as sio
from numba import njit, prange

# --------------------------------------------------------------------------
#  Double pendulum
# --------------------------------------------------------------------------
@njit(cache=True)
def dp_accel(th1, om1, th2, om2, m1, m2, L1, L2, g):
    d = th2 - th1
    sd = np.sin(d); cd = np.cos(d)
    den1 = (m1 + m2) * L1 - m2 * L1 * cd * cd
    den2 = (L2 / L1) * den1
    a1 = (m2 * L1 * om1 * om1 * sd * cd + m2 * g * np.sin(th2) * cd
          + m2 * L2 * om2 * om2 * sd - (m1 + m2) * g * np.sin(th1)) / den1
    a2 = (-m2 * L2 * om2 * om2 * sd * cd + (m1 + m2) * g * np.sin(th1) * cd
          - (m1 + m2) * L1 * om1 * om1 * sd - (m1 + m2) * g * np.sin(th2)) / den2
    return a1, a2


@njit(cache=True)
def dp_step(y, dt, m1, m2, L1, L2, g):
    a1, b1 = dp_accel(y[0], y[1], y[2], y[3], m1, m2, L1, L2, g)
    k1 = np.array([y[1], a1, y[3], b1])
    p = y + 0.5 * dt * k1
    a2, b2 = dp_accel(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g)
    k2 = np.array([p[1], a2, p[3], b2])
    p = y + 0.5 * dt * k2
    a3, b3 = dp_accel(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g)
    k3 = np.array([p[1], a3, p[3], b3])
    p = y + dt * k3
    a4, b4 = dp_accel(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g)
    k4 = np.array([p[1], a4, p[3], b4])
    return y + (dt / 6.0) * (k1 + 2 * k2 + 2 * k3 + k4)


@njit(cache=True)
def dp_traj(y0, T, dt, m1, m2, L1, L2, g):
    y = y0.copy()
    n = int(round(T / dt))
    for _ in range(n):
        y = dp_step(y, dt, m1, m2, L1, L2, g)
    return y


@njit(cache=True)
def dp_jac(th1, om1, th2, om2, m1, m2, L1, L2, g):
    h = 1e-7
    J = np.zeros((4, 4))
    y = np.array([th1, om1, th2, om2])
    for k in range(4):
        yp = y.copy(); yp[k] += h
        ym = y.copy(); ym[k] -= h
        ap = dp_accel(yp[0], yp[1], yp[2], yp[3], m1, m2, L1, L2, g)
        am = dp_accel(ym[0], ym[1], ym[2], ym[3], m1, m2, L1, L2, g)
        J[0, k] = 1.0 if k == 1 else 0.0
        J[2, k] = 1.0 if k == 3 else 0.0
        J[1, k] = (ap[0] - am[0]) / (2 * h)
        J[3, k] = (ap[1] - am[1]) / (2 * h)
    return J


@njit(cache=True)
def dp_lyap_variational(y0, dt, n_total, n_trans, reortho, m1, m2, L1, L2, g):
    y = y0.copy()
    Q = np.eye(4)
    acc = 0.0
    n_samp = 0
    for step in range(n_total):
        a1, b1 = dp_accel(y[0], y[1], y[2], y[3], m1, m2, L1, L2, g)
        k1 = np.array([y[1], a1, y[3], b1])
        K1 = dp_jac(y[0], y[1], y[2], y[3], m1, m2, L1, L2, g) @ Q
        p = y + 0.5 * dt * k1
        a2_, b2_ = dp_accel(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g)
        k2 = np.array([p[1], a2_, p[3], b2_])
        K2 = dp_jac(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g) @ (Q + 0.5 * dt * K1)
        p = y + 0.5 * dt * k2
        a3_, b3_ = dp_accel(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g)
        k3 = np.array([p[1], a3_, p[3], b3_])
        K3 = dp_jac(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g) @ (Q + 0.5 * dt * K2)
        p = y + dt * k3
        a4_, b4_ = dp_accel(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g)
        k4 = np.array([p[1], a4_, p[3], b4_])
        K4 = dp_jac(p[0], p[1], p[2], p[3], m1, m2, L1, L2, g) @ (Q + dt * K3)

        y = y + (dt / 6.0) * (k1 + 2 * k2 + 2 * k3 + k4)
        Q = Q + (dt / 6.0) * (K1 + 2 * K2 + 2 * K3 + K4)

        if (step + 1) % reortho == 0:
            Qn, R = np.linalg.qr(Q)
            dg = np.abs(np.diag(R)); dg[dg == 0] = 1.0
            s = np.sign(np.diag(R)); s[s == 0] = 1.0
            Q = Qn * s
            if step + 1 > n_trans:
                acc += np.log(dg[0])
                n_samp += 1
    if n_samp == 0:
        return 0.0
    return acc / (n_samp * reortho * dt)


@njit(parallel=True, cache=True)
def dp_lyap_grid(th, dt, n_total, n_trans, reortho, m1, m2, L1, L2, g):
    N = th.shape[0]
    out = np.zeros((N, N))
    for i in prange(N):
        for j in range(N):
            y0 = np.array([th[j], 0.0, th[i], 0.0])
            out[i, j] = dp_lyap_variational(y0, dt, n_total, n_trans, reortho,
                                            m1, m2, L1, L2, g)
    return out


# --------------------------------------------------------------------------
#  Forced pendulum
# --------------------------------------------------------------------------
@njit(cache=True)
def fp_traj(th0, om0, T, dt, F, gam, Om):
    th = th0; om = om0; t = 0.0
    n = int(round(T / dt))
    for _ in range(n):
        f1 = -gam * om - np.sin(th) + F * np.cos(Om * t)
        a1 = om; b1 = f1
        th2 = th + 0.5 * dt * a1; om2 = om + 0.5 * dt * b1
        f2 = -gam * om2 - np.sin(th2) + F * np.cos(Om * (t + 0.5 * dt))
        a2 = om2; b2 = f2
        th3 = th + 0.5 * dt * a2; om3 = om + 0.5 * dt * b2
        f3 = -gam * om3 - np.sin(th3) + F * np.cos(Om * (t + 0.5 * dt))
        a3 = om3; b3 = f3
        th4 = th + dt * a3; om4 = om + dt * b3
        f4 = -gam * om4 - np.sin(th4) + F * np.cos(Om * (t + dt))
        a4 = om4; b4 = f4
        th = th + (dt / 6.0) * (a1 + 2 * a2 + 2 * a3 + a4)
        om = om + (dt / 6.0) * (b1 + 2 * b2 + 2 * b3 + b4)
        th = (th + np.pi) % (2 * np.pi) - np.pi
        t += dt
    return th, om


@njit(cache=True)
def fp_lyap_variational(th0, om0, F, gam, Om, dt, n_total, n_trans, reortho):
    th = th0; om = om0; t = 0.0
    q1 = 1.0; q2 = 0.0
    acc = 0.0; n_samp = 0
    w_sum = 0.0; n_avg = 0
    for step in range(n_total):
        f1 = -gam * om - np.sin(th) + F * np.cos(Om * t)
        a1 = om; b1 = f1
        th2 = th + 0.5 * dt * a1; om2 = om + 0.5 * dt * b1
        f2 = -gam * om2 - np.sin(th2) + F * np.cos(Om * (t + 0.5 * dt))
        a2 = om2; b2 = f2
        th3 = th + 0.5 * dt * a2; om3 = om + 0.5 * dt * b2
        f3 = -gam * om3 - np.sin(th3) + F * np.cos(Om * (t + 0.5 * dt))
        a3 = om3; b3 = f3
        th4 = th + dt * a3; om4 = om + dt * b3
        f4 = -gam * om4 - np.sin(th4) + F * np.cos(Om * (t + dt))
        a4 = om4; b4 = f4

        e1_1 = q2;             e1_2 = -np.cos(th) * q1 - gam * q2
        r1_1 = q1 + 0.5 * dt * e1_1; r1_2 = q2 + 0.5 * dt * e1_2
        e2_1 = r1_2;           e2_2 = -np.cos(th2) * r1_1 - gam * r1_2
        r2_1 = q1 + 0.5 * dt * e2_1; r2_2 = q2 + 0.5 * dt * e2_2
        e3_1 = r2_2;           e3_2 = -np.cos(th3) * r2_1 - gam * r2_2
        r3_1 = q1 + dt * e3_1; r3_2 = q2 + dt * e3_2
        e4_1 = r3_2;           e4_2 = -np.cos(th4) * r3_1 - gam * r3_2

        th = th + (dt / 6.0) * (a1 + 2 * a2 + 2 * a3 + a4)
        om = om + (dt / 6.0) * (b1 + 2 * b2 + 2 * b3 + b4)
        q1 = q1 + (dt / 6.0) * (e1_1 + 2 * e2_1 + 2 * e3_1 + e4_1)
        q2 = q2 + (dt / 6.0) * (e1_2 + 2 * e2_2 + 2 * e3_2 + e4_2)
        th = (th + np.pi) % (2 * np.pi) - np.pi
        t += dt

        if (step + 1) % reortho == 0:
            nr = np.sqrt(q1 * q1 + q2 * q2)
            if nr > 0:
                if step + 1 > n_trans:
                    acc += np.log(nr)
                    n_samp += 1
                q1 /= nr; q2 /= nr
        if step + 1 > n_trans:
            w_sum += om; n_avg += 1
    if n_samp == 0:
        return 0.0, 0.0
    return acc / (n_samp * reortho * dt), w_sum / max(1, n_avg) / Om


@njit(parallel=True, cache=True)
def fp_lyap_grid(th, om, F, gam, Om, dt, n_total, n_trans, reortho):
    N = th.shape[0]
    out = np.zeros((N, N)); wid = np.zeros((N, N))
    for i in prange(N):
        for j in range(N):
            v, w = fp_lyap_variational(th[j], om[i], F, gam, Om, dt,
                                       n_total, n_trans, reortho)
            out[i, j] = v; wid[i, j] = w
    return out, wid


# ==========================================================================
def main(outdir):
    ok = True
    print('  ---- A. short-horizon pointwise trajectory agreement ----')

    f = os.path.join(outdir, 'matlab_short.mat')
    if os.path.exists(f):
        d = sio.loadmat(f)
        yM = d['Yshort']; Tshort = float(d['Tshort'].ravel()[0])
        dt = float(d['dtShort'].ravel()[0])
        th_s = d['thShort'].ravel()
        n = len(th_s)
        maxerr = 0.0
        for i in range(n):
            for j in range(n):
                y0 = np.array([th_s[j], 0.0, th_s[i], 0.0])
                yP = dp_traj(y0, Tshort, dt, 1.0, 1.0, 1.0, 1.0, 9.81)
                e = np.abs(yM[i, j, :] - yP)
                e[0] = abs((yM[i, j, 0] - yP[0] + np.pi) % (2 * np.pi) - np.pi)
                e[2] = abs((yM[i, j, 2] - yP[2] + np.pi) % (2 * np.pi) - np.pi)
                maxerr = max(maxerr, e.max())
        print('  [dp] short horizon T=%.2f s, dt=%.4f, %dx%d ICs'
              % (Tshort, dt, n, n))
        print('  [dp] max pointwise trajectory error = %.3e' % maxerr)
        if maxerr > 1e-9:
            print('  [dp] FAIL: integrators disagree at short horizon'); ok = False
        else:
            print('  [dp] ok  (vector field, integrator and units are identical)')
    else:
        print('  [dp] missing', f)

    # forced pendulum short horizon
    f = os.path.join(outdir, 'matlab_fpshort.mat')
    if os.path.exists(f):
        d = sio.loadmat(f)
        YM = d['YPshort']; Tshort = float(d['TpShort'].ravel()[0])
        dt = float(d['dtpShort'].ravel()[0])
        th_s = d['thpShort'].ravel(); om_s = d['ompShort'].ravel()
        n = len(th_s)
        maxerr = 0.0
        for i in range(n):
            for j in range(n):
                thP, omP = fp_traj(th_s[j], om_s[i], Tshort, dt, 1.5, 0.2, 2 / 3)
                e = max(abs((YM[i, j, 0] - thP + np.pi) % (2 * np.pi) - np.pi),
                        abs(YM[i, j, 1] - omP))
                maxerr = max(maxerr, e)
        print('  [fp] short horizon T=%.2f s, dt=%.4f, %dx%d ICs'
              % (Tshort, dt, n, n))
        print('  [fp] max pointwise trajectory error = %.3e' % maxerr)
        if maxerr > 1e-9:
            print('  [fp] FAIL: integrators disagree at short horizon'); ok = False
        else:
            print('  [fp] ok')
    else:
        print('  [fp] missing', f)

    print()
    print('  ---- B. long-run invariant: rotation number (winding) ----')
    f = os.path.join(outdir, 'matlab_fp_lyap.mat')
    if os.path.exists(f):
        d = sio.loadmat(f)
        LAMf_m = d['LAMf']; Wf_m = d['Wf']
        thf = d['thf'].ravel(); omf = d['omf'].ravel()
        Om = 2 / 3; dt = 0.01
        Tdrive = 2 * np.pi / Om
        n_total = int(round(300 * Tdrive / dt))
        n_trans = int(round(0.3 * n_total))
        LAMf_p, Wf_p = fp_lyap_grid(thf, omf, 1.5, 0.2, Om, dt,
                                    n_total, n_trans, 10)
        dw = np.abs(Wf_m - Wf_p)
        print('  [fp] winding: max|diff| = %.3e  mean|diff| = %.3e'
              % (dw.max(), dw.mean()))
        if dw.max() > 0.05:
            print('  [fp] FAIL: winding numbers disagree'); ok = False
        else:
            print('  [fp] ok  (rotation number is a sharp attractor invariant)')

        print()
        print('  ---- C. statistical agreement of the Lyapunov grids ----')
        print('  [fp] MATLAB : mean=%.5f  std=%.5f  min=%.5f  max=%.5f'
              % (LAMf_m.mean(), LAMf_m.std(), LAMf_m.min(), LAMf_m.max()))
        print('  [fp] Python : mean=%.5f  std=%.5f  min=%.5f  max=%.5f'
              % (LAMf_p.mean(), LAMf_p.std(), LAMf_p.min(), LAMf_p.max()))
        dmean = abs(LAMf_m.mean() - LAMf_p.mean()) / LAMf_p.mean()
        dstd = abs(LAMf_m.std() - LAMf_p.std()) / LAMf_p.std()
        print('  [fp] rel diff of mean = %.3e   of std = %.3e' % (dmean, dstd))
        # two-sample Kolmogorov-Smirnov style comparison via quantiles
        qs = [0.05, 0.25, 0.5, 0.75, 0.95]
        qm = np.quantile(LAMf_m, qs); qp = np.quantile(LAMf_p, qs)
        print('  [fp] quantile rel diff: %s'
              % np.array2string(np.abs(qm - qp) / np.maximum(1e-9, np.abs(qp)),
                                precision=3))
        if dmean > 0.05 or dstd > 0.15:
            print('  [fp] FAIL: distributions disagree'); ok = False
        else:
            print('  [fp] ok  (independent samples of the same distribution)')
        sio.savemat(os.path.join(outdir, 'py_fp_lyap.mat'),
                    {'LAMf_p': LAMf_p, 'Wf_p': Wf_p})
    else:
        print('  [fp] missing', f)

    sio.savemat(os.path.join(outdir, 'crosscheck_result.mat'), {'pass': bool(ok)})
    print('\nCROSSCHECK %s' % ('PASS' if ok else 'FAIL'))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else '.'))
