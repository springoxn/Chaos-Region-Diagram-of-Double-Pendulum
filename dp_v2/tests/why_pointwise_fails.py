"""
Why a pointwise cross-check of Lyapunov codes MUST fail for long integrations.

Two implementations integrating the same chaotic initial condition diverge from
each other at the Lyapunov rate once roundoff differences amplify.  After that,
each produces an *independent* finite-time estimate whose scatter is set by
1/sqrt(lambda*T) -- not by any defect.

This script demonstrates the crossover and establishes the horizon below which
a pointwise comparison IS meaningful.
"""
import numpy as np

lam_dp = 1.30      # double pendulum, m=l=1, g=9.81
lam_fp = 0.05      # forced pendulum, F=1.5, gamma=0.2
eps = 2.2e-16

print('Decorrellation horizon T* ~ ln(1/eps)/lambda')
for name, lam, dt in [('double pendulum', lam_dp, 0.01),
                      ('forced pendulum', lam_fp, 0.01)]:
    T = np.log(1 / eps) / lam
    print('  %-18s lambda=%.3f -> T* = %8.1f s' % (name, lam, T))
    if name.startswith('forced'):
        Tdrive = 2 * np.pi / (2 / 3)
        print('  %-18s                    = %8.1f drive periods' % ('', T / Tdrive))

print()
print('Finite-time scatter of a Lyapunov estimate, ~1/sqrt(lambda*T):')
Tdrive = 2 * np.pi / (2 / 3)
for periods in [50, 100, 300, 1000, 3000, 10000]:
    T = periods * Tdrive
    for name, lam in [('dp', lam_dp), ('fp', lam_fp)]:
        if name == 'fp':
            e = lam * T
            print('   periods=%6d (%8.0f s)  fp: lambda*T=%8.1f  scatter~%.1f%%'
                  % (periods, T, e, 100 / np.sqrt(e)))
    if periods > 1000:
        break

print()
print('CONCLUSION for the cross-check design:')
print('  * pointwise trajectory comparison is valid only for T << T*')
print('      dp: T <~ 5 s      fp: T <~ 20 drive periods')
print('  * for long runs, only STATISTICAL agreement is testable:')
print('      mean, spread, and dynamical invariants (winding number)')
print('  * if the true exponent is spatially CONSTANT (single attractor),')
print('    two independent long-run estimates are UNCORRELATED by construction')
print('    even though both are correct -- correlation is the wrong statistic.')
