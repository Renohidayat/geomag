"""
Modul pencocokan parameter termal ponsel untuk estimasi suhu ruangan (Ordinary Least Squares).
Berdasarkan model neraca panas konduksi/konveksi Newton (He et al. 2020 BaT):
    dT_bat / dt = -(1 / tau) * (T_bat - T_ruang - D0)
Maka:
    T_ruang = T_bat + tau * (dT_bat / dt) - D0
Atau dalam bentuk linear:
    T_ruang = a * T_bat + b + tau * (dT_bat / dt)
"""

from typing import List, Dict, Any, Tuple
import math
import numpy as np


def compute_linear_slope(times_s: List[float], values: List[float]) -> float:
    """
    Menghitung kemiringan regresi linear (slope) dari pasangan waktu dan nilai.
    slope = cov(t, y) / var(t) = sum((t - t_bar)(y - y_bar)) / sum((t - t_bar)^2)
    Jika titik < 2 atau varians waktu 0, return 0.0.
    """
    n = len(times_s)
    if n < 2 or len(values) != n:
        return 0.0

    t_mean = sum(times_s) / n
    y_mean = sum(values) / n

    numerator = 0.0
    denominator = 0.0
    for i in range(n):
        dt = times_s[i] - t_mean
        dy = values[i] - y_mean
        numerator += dt * dy
        denominator += dt * dt

    if abs(denominator) < 1e-12:
        return 0.0

    return numerator / denominator


def compute_rolling_slopes(
    times_s: List[float],
    values: List[float],
    window_s: float = 180.0,
) -> List[float]:
    """
    Menghitung slope dT/dt pada rolling window waktu (default 180 detik / 3 menit).
    Untuk setiap titik i, mengambil semua titik dalam rentang [times_s[i] - window_s, times_s[i]].
    """
    n = len(times_s)
    slopes = [0.0] * n
    start_idx = 0

    for i in range(n):
        t_current = times_s[i]
        while start_idx < i and (t_current - times_s[start_idx]) > window_s:
            start_idx += 1

        w_times = times_s[start_idx : i + 1]
        w_values = values[start_idx : i + 1]
        slopes[i] = compute_linear_slope(w_times, w_values)

    return slopes


def fit_thermal_parameters(
    times_s: List[float],
    bat_temps: List[float],
    ref_temps: List[float],
    window_s: float = 180.0,
) -> Dict[str, Any]:
    """
    Mencocokkan parameter model termal ponsel berbasis hukum pendinginan Newton:
        (T_bat - T_ref) = D0 - tau * (dT_bat / dt)
    Memberikan estimasi:
        T_ruang = a * T_bat + b + tau * (dT_bat / dt)
        dengan a = 1.0, b = -D0, dan tau = konstanta waktu (detik).
    """
    n = len(times_s)
    if n < 5 or len(bat_temps) != n or len(ref_temps) != n:
        raise ValueError("Minimal 5 sampel valid diperlukan untuk kalibrasi termal.")

    # 1. Hitung dT/dt untuk setiap titik
    slopes = compute_rolling_slopes(times_s, bat_temps, window_s)

    # 2. Untuk kalibrasi Newton dengan suhu referensi acuan:
    # x = -(dT_bat / dt), y = T_bat - T_ref
    # y = tau * x + D0
    x_vals = [-s for s in slopes]
    y_vals = [bat_temps[i] - ref_temps[i] for i in range(n)]

    # Regresi linear 1D tertutup
    tau = compute_linear_slope(x_vals, y_vals)
    # Batasi tau pada rentang fisik wajar smartphone (30 s.d. 600 detik)
    if tau < 30.0 or tau > 600.0 or math.isnan(tau):
        tau = 240.0  # Default nominal ~4 menit

    x_mean = sum(x_vals) / n
    y_mean = sum(y_vals) / n
    d0 = y_mean - tau * x_mean

    # Batasi D0 pada rentang wajar (1.0 s.d. 8.0 °C)
    if d0 < 0.5 or d0 > 10.0 or math.isnan(d0):
        d0 = max(0.5, min(10.0, sum(y_vals) / n))

    a = 1.0
    b = -d0

    # 3. Hitung residual dan RMSE
    residuals = []
    for i in range(n):
        # T_est = a * T_bat + b + tau * slope
        # Batasi koreksi dinamik tau * slope ke [-3.0, 3.0]
        dyn_corr = max(-3.0, min(3.0, tau * slopes[i]))
        t_est = a * bat_temps[i] + b + dyn_corr
        residuals.append(t_est - ref_temps[i])

    rmse = math.sqrt(sum(r * r for r in residuals) / n)

    ref_mean = sum(ref_temps) / n
    ss_tot = sum((r - ref_mean) ** 2 for r in ref_temps)
    ss_res = sum(r * r for r in residuals)
    r2 = 1.0 - (ss_res / ss_tot) if ss_tot > 1e-6 else 1.0

    return {
        "a": float(a),
        "b": float(b),
        "tau": float(tau),
        "d0": float(d0),
        "rmse": float(rmse),
        "r2": float(r2),
        "sample_count": n,
    }


def fit_steady_offset(bat_temps: List[float], ref_temp: float) -> Tuple[float, float]:
    """
    Menghitung estimasi delta tunak D0 = mean(T_bat) - T_ref
    dan simpangan baku (std dev).
    """
    n = len(bat_temps)
    if n == 0:
        return 3.0, 0.0

    mean_bat = sum(bat_temps) / n
    d0 = mean_bat - ref_temp

    variance = sum((t - mean_bat) ** 2 for t in bat_temps) / n if n > 1 else 0.0
    std_dev = math.sqrt(variance)

    return float(d0), float(std_dev)


def estimate_room_temperature(
    bat_temp_c: float,
    slope_c_per_s: float,
    a: float = 1.0,
    b: float = -3.0,
    tau: float = 240.0,
    max_dyn_c: float = 3.0,
    user_offset_c: float = 0.0,
) -> float:
    """
    Menghitung estimasi suhu ruangan T_est dari suhu baterai dan laju perubahan dT/dt.
    T_est = a * T_bat + b + clamp(tau * slope, -max_dyn_c, +max_dyn_c) + user_offset_c
    """
    dyn_corr = max(-max_dyn_c, min(max_dyn_c, tau * slope_c_per_s))
    est = a * bat_temp_c + b + dyn_corr + user_offset_c
    return est
