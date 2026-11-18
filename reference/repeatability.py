"""Modul analisis komparasi keterulangan dan konsistensi multi-smartphone / multi-sesi.

Implementasi referensi Python untuk validasi keterulangan survei geomagnetik
sesuai PRD GeoMag.
"""

from dataclasses import dataclass
from typing import List, Sequence
import numpy as np


@dataclass
class RepeatabilityMetrics:
    sample_count: int
    mean_absolute_diff_nt: float
    mean_diff_nt: float
    rmse_nt: float
    max_absolute_diff_nt: float
    pearson_r: float
    tolerance_limit_nt: float
    within_tolerance_ratio: float
    is_consistent: bool
    paired_differences: List[float]


def compute_repeatability_metrics(
    series_a: Sequence[float],
    series_b: Sequence[float],
    noise_floor_nt: float = 500.0,
    tolerance_multiplier: float = 2.0,
    min_correlation: float = 0.85,
) -> RepeatabilityMetrics:
    """Menghitung metrik keterulangan dan konsistensi antara dua profil survei geomagnetik.

    Parameter:
    - series_a: Nilai medan magnetik / anomali profil A (nT)
    - series_b: Nilai medan magnetik / anomali profil B (nT)
    - noise_floor_nt: Lantai noise instrumen HP (nT, default 500.0 nT)
    - tolerance_multiplier: Pengali batas toleransi terhadap lantai noise (PRD: 2x)
    - min_correlation: Ambang korelasi Pearson minimum yang dapat diterima (default 0.85)

    Mengembalikan objek RepeatabilityMetrics.
    """
    n_a = len(series_a)
    n_b = len(series_b)
    if n_a != n_b:
        raise ValueError(
            f"Panjang kedua profil harus sama! Profil A={n_a}, Profil B={n_b}"
        )
    if n_a == 0:
        raise ValueError("Profil survei tidak boleh kosong!")

    a = np.asarray(series_a, dtype=np.float64)
    b = np.asarray(series_b, dtype=np.float64)

    # Selisih pasangan A - B
    diffs = a - b
    abs_diffs = np.abs(diffs)

    mean_abs_diff = float(np.mean(abs_diffs))
    mean_diff = float(np.mean(diffs))
    rmse = float(np.sqrt(np.mean(diffs**2)))
    max_abs_diff = float(np.max(abs_diffs))

    tolerance_limit = float(tolerance_multiplier * noise_floor_nt)
    within_tol_count = int(np.sum(abs_diffs <= tolerance_limit))
    within_tol_ratio = float(within_tol_count / n_a)

    # Korelasi Pearson (r)
    if n_a < 2:
        pearson_r = 1.0 if np.isclose(a[0], b[0]) else 0.0
    else:
        var_a = float(np.var(a))
        var_b = float(np.var(b))
        if var_a < 1e-12 or var_b < 1e-12:
            if np.allclose(a, b):
                pearson_r = 1.0
            else:
                pearson_r = 0.0
        else:
            std_a = np.std(a)
            std_b = np.std(b)
            cov = np.mean((a - np.mean(a)) * (b - np.mean(b)))
            r = cov / (std_a * std_b)
            pearson_r = float(np.clip(r, -1.0, 1.0))

    # Kriteria konsistensi sesuai PRD:
    # 1. Rasio titik dalam batas toleransi (<= 2x noise floor) >= 90%
    # 2. RMSE <= tolerance_limit
    # 3. Bentuk profil konsisten (korelasi r >= min_correlation jika variansi sinyal lebih besar dari noise)
    is_profile_correlated = (
        pearson_r >= min_correlation or np.std(a) < noise_floor_nt
    )
    is_consistent = bool(
        (within_tol_ratio >= 0.90)
        and (rmse <= tolerance_limit)
        and is_profile_correlated
    )

    return RepeatabilityMetrics(
        sample_count=n_a,
        mean_absolute_diff_nt=mean_abs_diff,
        mean_diff_nt=mean_diff,
        rmse_nt=rmse,
        max_absolute_diff_nt=max_abs_diff,
        pearson_r=pearson_r,
        tolerance_limit_nt=tolerance_limit,
        within_tolerance_ratio=within_tol_ratio,
        is_consistent=is_consistent,
        paired_differences=diffs.tolist(),
    )
