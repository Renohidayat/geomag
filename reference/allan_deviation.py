"""
Modul perhitungan Allan Deviation (ADEV) untuk magnetometer.
Digunakan untuk menentukan lantai noise (noise floor) perangkat HP Android.
"""

from typing import List, Tuple, Dict, Any
import numpy as np


def compute_allan_deviation(
    values: List[float],
    rate_hz: float,
    num_tau: int = 20,
) -> Dict[str, Any]:
    """
    Menghitung Allan Deviation dari deret bacaan total field magnetometer.

    Parameters:
    - values: list bacaan medan magnetik (dalam nT atau uT).
    - rate_hz: laju sampling rata-rata dalam Hz (misal 50.0).
    - num_tau: jumlah titik tau yang dievaluasi secara logaritmik.

    Returns:
    - dict berisi:
        - tau_s: list durasi cluster waktu tau (detik)
        - adev: list nilai Allan deviation sigma(tau) (satuan sama dengan values)
        - noise_floor: nilai minimum dari kurva adev
        - optimal_tau_s: nilai tau pada titik noise floor minimum
    """
    n = len(values)
    if n < 9:
        raise ValueError("Jumlah sampel terlalu sedikit untuk menghitung Allan deviation (minimal 9 sampel)")

    arr = np.array(values, dtype=np.float64)
    tau0 = 1.0 / rate_hz

    # Maksimum cluster size m adalah n // 3 (agar minimal ada 3 cluster)
    max_m = n // 3
    if max_m < 2:
        max_m = 2

    # Buat rentang m logaritmik integer unik
    m_values = np.unique(
        np.round(np.geomspace(1, max_m, num=min(num_tau, max_m))).astype(int)
    )

    tau_list = []
    adev_list = []

    for m in m_values:
        tau = m * tau0
        # Hitung jumlah cluster berukuran m
        num_clusters = n // m
        if num_clusters < 2:
            continue

        # Truncate agar pas dengan num_clusters * m
        truncated = arr[: num_clusters * m]
        # Reshape dan hitung rata-rata tiap cluster (bin averaging)
        cluster_means = truncated.reshape((num_clusters, m)).mean(axis=1)

        # Selisih kuadrat antar cluster berturutan
        diffs = np.diff(cluster_means)
        allan_var = 0.5 * np.mean(diffs ** 2)
        adev = np.sqrt(allan_var)

        tau_list.append(float(tau))
        adev_list.append(float(adev))

    if not adev_list:
        raise ValueError("Gagal menghitung titik Allan deviation")

    tau_arr = np.array(tau_list)
    adev_arr = np.array(adev_list)

    min_idx = int(np.argmin(adev_arr))
    noise_floor = float(adev_arr[min_idx])
    optimal_tau = float(tau_arr[min_idx])

    return {
        "tau_s": [round(t, 4) for t in tau_list],
        "adev": [round(a, 4) for a in adev_list],
        "noise_floor": round(noise_floor, 4),
        "optimal_tau_s": round(optimal_tau, 4),
    }
