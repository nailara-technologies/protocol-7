import sys, numpy as np
from datetime import datetime

rows = []
for line in open(sys.argv[1]):
    f = [x.strip() for x in line.split(',')]
    if len(f) < 5:
        continue
    try:
        t = datetime.strptime(f[0], '%Y/%m/%d %H:%M:%S.%f').timestamp()
        rows.append((t, float(f[1]), float(f[2]), float(f[3]), float(f[4])))
    except ValueError:
        pass
a = np.array(rows)
t, T, P, F = a[:, 0], a[:, 1], a[:, 2], a[:, 3]

# idle power and baseline as the gate learns them : low-power quantiles
idle_w = np.percentile(P[P < 60], 50)
base = np.percentile(T[P < 60], 10)
print(f'rows {len(t)}  span {(t[-1]-t[0])/3600:.2f} h  idle {idle_w:.1f} W  baseline {base:.1f} C')

def deriv(x, span):
    out = np.full_like(x, np.nan)
    j = 0
    for i in range(len(x)):
        while j < i and t[i] - t[j] > span:
            j += 1
        if j < i and t[i] - t[j] >= span * 0.8:
            out[i] = (x[i] - x[j]) / (t[i] - t[j])
    return out

def fit(name, X, y):
    m = ~np.isnan(y) & ~np.isnan(X).any(axis=1)
    coef, *_ = np.linalg.lstsq(X[m], y[m], rcond=None)
    pred = X[m] @ coef
    ss_res = ((y[m] - pred) ** 2).sum()
    ss_tot = ((y[m] - y[m].mean()) ** 2).sum()
    print(f'{name:<44} r2 {1-ss_res/ss_tot:.3f}  n {m.sum()}')
    return coef

def smooth(x, n):
    return np.convolve(x, np.ones(n) / n, mode='same')

for span in (20, 60):
    dT = deriv(T, span)
    dP = P - idle_w
    dTb = T - base
    print(f'\n-- derivative span {span} s')
    c = fit('A  gate model  a*dP + b*dTb', np.c_[dP, dTb], dT)
    print(f'     tau {-1/c[1]:.0f} s  k {-c[0]/c[1]:.4f} C/W')
    fit('A+ with intercept', np.c_[dP, dTb, np.ones_like(dP)], dT)
    c = fit('B  fan : + fan*dTb', np.c_[dP, dTb, F * dTb, np.ones_like(dP)], dT)
    # power lag : the die heats, the sensor reads later -> smoothed power
    for lag in (10, 30, 60):
        n = max(1, int(lag / 2))
        c = fit(f'C  power smoothed over {lag} s', np.c_[smooth(dP, n), dTb, F * dTb, np.ones_like(dP)], dT)
    # two time constants : fast die + slow heatsink state
    slow = np.zeros_like(T)
    for i in range(1, len(T)):
        dt = t[i] - t[i-1]
        slow[i] = slow[i-1] + (1 - np.exp(-dt / 600)) * (dP[i] - slow[i-1])
    fit('D  two poles : + slow power state [ 600 s ]', np.c_[smooth(dP, 15), slow, dTb, F * dTb, np.ones_like(dP)], dT)

# steady state view : temp vs power, binned, with fan
print('\n-- settled view [ 120 s means, power bins ]')
n = 60
k = len(T) // n
Tm, Pm, Fm = (x[:k*n].reshape(k, n).mean(1) for x in (T, P, F))
for lo in range(40, 150, 20):
    m = (Pm >= lo) & (Pm < lo + 20)
    if m.sum():
        print(f'  {lo:3d}-{lo+20:3d} W : temp {Tm[m].mean():5.1f} C  fan {Fm[m].mean():4.0f} %  n {m.sum()}')

# level model : T = base + k * lowpass_tau( P - idle )  -- fit the LEVEL, not dT/dt
print('\n-- level model [ T vs low-passed power ]')
dP = P - idle_w
for tau in (30, 60, 90, 120, 180, 300):
    lp = np.zeros_like(T)
    lp[0] = dP[0]
    for i in range(1, len(T)):
        lp[i] = lp[i-1] + (1 - np.exp(-(t[i]-t[i-1]) / tau)) * (dP[i] - lp[i-1])
    X = np.c_[lp, np.ones_like(lp)]
    coef, *_ = np.linalg.lstsq(X, T, rcond=None)
    r = T - X @ coef
    r2 = 1 - (r**2).sum() / ((T - T.mean())**2).sum()
    Xf = np.c_[lp, lp * F, np.ones_like(lp)]
    cf, *_ = np.linalg.lstsq(Xf, T, rcond=None)
    rf = T - Xf @ cf
    r2f = 1 - (rf**2).sum() / ((T - T.mean())**2).sum()
    print(f'  tau {tau:3d} s : k {coef[0]:.3f} C/W  base {coef[1]:.1f} C  r2 {r2:.3f}  rms {np.sqrt((r**2).mean()):.2f} C  | with fan r2 {r2f:.3f}')

#,,,,,,,,,,..,...,,,,,,..,.,,,.,.,.,.,.,,,,,.,..,,...,..,,..,,,..,.,.,,.,,..,,
#3S2RVHXRNVD5LPGZRX2L6RFGKV7XDDE5C4C6LU6SS6XTILCRGQEFFK4I5KKIUBIS64WRCU4B2XIBI
#\\\|LZUATYWTQULCRKV62B4TYW5HKQ43IN6WAO2W3GTCGAKSX4HIUTI \ / AMOS7 \ YOURUM ::
#\[7]ATZ6PV64Q56YGSTDZKZOC74OCOP33ZHDGZHUETB2XQ4Z3NLF4KCI 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
