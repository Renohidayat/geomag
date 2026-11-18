"""Unit tests untuk modul analisis keterulangan profil survei geomagnetik."""

import pytest
import numpy as np
from reference.repeatability import compute_repeatability_metrics


def test_identical_profiles():
    """Dua profil identik harus memiliki selisih 0, korelasi 1.0, dan konsisten penuh."""
    series_a = [45000.0, 45150.0, 45300.0, 45100.0, 44950.0]
    series_b = [45000.0, 45150.0, 45300.0, 45100.0, 44950.0]

    metrics = compute_repeatability_metrics(
        series_a, series_b, noise_floor_nt=500.0
    )

    assert metrics.sample_count == 5
    assert metrics.mean_absolute_diff_nt == pytest.approx(0.0)
    assert metrics.mean_diff_nt == pytest.approx(0.0)
    assert metrics.rmse_nt == pytest.approx(0.0)
    assert metrics.max_absolute_diff_nt == pytest.approx(0.0)
    assert metrics.pearson_r == pytest.approx(1.0)
    assert metrics.tolerance_limit_nt == 1000.0  # 2.0 * 500.0
    assert metrics.within_tolerance_ratio == 1.0
    assert metrics.is_consistent is True
    assert metrics.paired_differences == [0.0] * 5


def test_systematic_offset():
    """Offset konstan mempertahankan korelasi 1.0 dan menghitung bias persis."""
    base_signal = [45000.0, 45250.0, 45500.0, 45150.0, 44800.0]
    offset_nt = 120.0
    series_b = [v - offset_nt for v in base_signal]

    metrics = compute_repeatability_metrics(
        base_signal, series_b, noise_floor_nt=100.0, tolerance_multiplier=2.0
    )

    assert metrics.sample_count == 5
    assert metrics.mean_absolute_diff_nt == pytest.approx(120.0)
    assert metrics.mean_diff_nt == pytest.approx(120.0)
    assert metrics.rmse_nt == pytest.approx(120.0)
    assert metrics.max_absolute_diff_nt == pytest.approx(120.0)
    assert metrics.pearson_r == pytest.approx(1.0)
    assert metrics.tolerance_limit_nt == 200.0
    assert metrics.within_tolerance_ratio == 1.0
    assert metrics.is_consistent is True


def test_noise_within_tolerance():
    """Perbedaan acak dalam batas 2x noise floor harus dinyatakan konsisten."""
    np.random.seed(42)
    # Sinyal anomali kuat (~2000 nT)
    x = np.linspace(-5, 5, 20)
    anomaly = 2000.0 / (1.0 + x**2)
    noise_floor = 300.0
    tol = 2.0 * noise_floor  # 600 nT

    noise_a = np.random.normal(0, 80.0, size=len(x))
    noise_b = np.random.normal(0, 80.0, size=len(x))

    series_a = (45000.0 + anomaly + noise_a).tolist()
    series_b = (45000.0 + anomaly + noise_b).tolist()

    metrics = compute_repeatability_metrics(
        series_a, series_b, noise_floor_nt=noise_floor
    )

    assert metrics.sample_count == 20
    assert metrics.rmse_nt < tol
    assert metrics.within_tolerance_ratio >= 0.95
    assert metrics.pearson_r > 0.90
    assert metrics.is_consistent is True


def test_inconsistent_profiles():
    """Profil yang tidak cocok atau noise melebihi batas harus dinyatakan tidak konsisten."""
    # Profil A memiliki anomali positif, Profil B memiliki anomali negatif berlawanan
    series_a = [45000.0, 46000.0, 47000.0, 46000.0, 45000.0]
    series_b = [45000.0, 44000.0, 43000.0, 44000.0, 45000.0]

    metrics = compute_repeatability_metrics(
        series_a, series_b, noise_floor_nt=300.0, tolerance_multiplier=2.0
    )

    assert metrics.tolerance_limit_nt == 600.0
    assert metrics.rmse_nt > 1000.0
    assert metrics.within_tolerance_ratio < 0.50
    assert metrics.is_consistent is False


def test_edge_cases_validation():
    """Validasi input kosong, tidak sama panjang, atau satu titik."""
    with pytest.raises(ValueError, match="Panjang kedua profil harus sama"):
        compute_repeatability_metrics([45000.0], [45000.0, 45100.0])

    with pytest.raises(ValueError, match="tidak boleh kosong"):
        compute_repeatability_metrics([], [])

    # Satu titik
    single_metrics = compute_repeatability_metrics([45000.0], [45050.0], noise_floor_nt=100.0)
    assert single_metrics.sample_count == 1
    assert single_metrics.mean_absolute_diff_nt == 50.0
    assert single_metrics.rmse_nt == 50.0
