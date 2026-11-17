"""
Unit test untuk kalibrasi ellipsoid robust di reference/ellipsoid_fit.py.
"""

import numpy as np
import pytest
from reference.ellipsoid_fit import fit_ellipsoid_robust


def generate_sphere_points(n_points: int = 150, radius: float = 45.0, seed: int = 42) -> np.ndarray:
    """Menghasilkan titik acak seragam pada permukaan bola."""
    rng = np.random.RandomState(seed)
    # Fibonacci sphere atau sampling sudut bola
    indices = np.arange(0, n_points, dtype=float) + 0.5
    phi = np.arccos(1 - 2 * indices / n_points)
    theta = np.pi * (1 + 5**0.5) * indices

    x = radius * np.sin(phi) * np.cos(theta)
    y = radius * np.sin(phi) * np.sin(theta)
    z = radius * np.cos(phi)
    return np.column_stack([x, y, z])


def test_fit_perfect_sphere():
    """Menguji bahwa bola sempurna menghasilkan offset 0 dan matriks identitas."""
    b_ref = 45.0  # uT
    points = generate_sphere_points(100, radius=b_ref, seed=123)

    result = fit_ellipsoid_robust(points, b_ref_micro_t=b_ref)

    # Offset harus sangat mendekati 0
    np.testing.assert_allclose(result.offset_micro_t, [0.0, 0.0, 0.0], atol=1e-3)
    # Matriks A harus mendekati identitas
    np.testing.assert_allclose(result.matrix_a, np.eye(3), atol=1e-3)
    # Residu harus sangat kecil (< 1 nT)
    assert result.residual_nt < 1.0
    assert result.std_after_nt < 1.0


def test_fit_synthetic_ellipsoid_with_offset():
    """Menguji ellipsoid dengan offset hard iron dan distorsi soft iron yang diketahui."""
    b_ref = 45.0  # uT
    true_offset = np.array([12.5, -8.2, 5.0])  # uT
    # Matriks distorsi: deformasi skala sumbu
    distortion = np.diag([1.10, 0.95, 1.05])

    sphere = generate_sphere_points(200, radius=b_ref, seed=99)
    # B_raw = distortion * B_true + true_offset
    distorted_points = (distortion @ sphere.T).T + true_offset

    result = fit_ellipsoid_robust(distorted_points, b_ref_micro_t=b_ref)

    # Offset terestimasi harus mendekati offset sejati
    np.testing.assert_allclose(result.offset_micro_t, true_offset, atol=0.05)
    # Simpangan baku sesudah kalibrasi harus jauh lebih kecil dari sebelum
    assert result.std_after_nt < 5.0
    assert result.std_before_nt > 1000.0  # Sebelum kalibrasi variasinya sangat tinggi


def test_fit_robust_rejects_outliers():
    """Menguji bahwa algoritma robust mengabaikan titik outlier ekstrem."""
    b_ref = 45.0
    true_offset = np.array([5.0, 3.0, -4.0])
    points = generate_sphere_points(150, radius=b_ref, seed=77) + true_offset

    # Tambahkan 5 titik outlier ekstrem (misal gangguan medan lokal 150 uT)
    outliers = np.array([
        [150.0, 150.0, 150.0],
        [-100.0, 80.0, -90.0],
        [80.0, -120.0, 50.0],
        [0.0, 200.0, -50.0],
        [-150.0, -100.0, 100.0],
    ])
    contaminated_points = np.vstack([points, outliers])

    result = fit_ellipsoid_robust(contaminated_points, b_ref_micro_t=b_ref)

    # Outlier harus ditolak
    assert result.inlier_count <= 150
    # Offset terestimasi tetap akurat
    np.testing.assert_allclose(result.offset_micro_t, true_offset, atol=0.1)
    assert result.residual_nt < 10.0


def test_cross_language_consistency():
    """Menguji konsistensi komparasi dengan hasil Dart untuk dataset deterministik."""
    b_ref = 45.0
    golden_ratio = (1.0 + 5.0**0.5) / 2.0
    n = 100
    points = []
    for i in range(n):
        theta = 2.0 * np.pi * i / golden_ratio
        phi = np.arccos(1.0 - 2.0 * (i + 0.5) / n)
        x = b_ref * np.sin(phi) * np.cos(theta)
        y = b_ref * np.sin(phi) * np.sin(theta)
        z = b_ref * np.cos(phi)
        points.append([x, y, z])
    points = np.array(points)

    result = fit_ellipsoid_robust(points, b_ref_micro_t=b_ref)
    np.testing.assert_allclose(result.offset_micro_t, [0.0, 0.0, 0.0], atol=1e-2)
    np.testing.assert_allclose(result.matrix_a, np.eye(3), atol=1e-2)
    assert result.residual_nt < 1.0

