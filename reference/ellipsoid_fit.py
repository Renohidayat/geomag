"""
Modul referensi Python untuk kalibrasi magnetometer dengan fit ellipsoid robust.
Mengestimasi vektor hard iron b dan matriks koreksi soft iron A sehingga:
    B_cal = A * (B_raw - b)
memenuhi ||B_cal|| ~= B_ref.
"""

from dataclasses import dataclass
from typing import List, Tuple
import numpy as np


@dataclass
class EllipsoidFitResult:
    # Vektor hard iron offset b [bx, by, bz] dalam mikroTesla
    offset_micro_t: np.ndarray
    # Matriks transformasi koreksi 3x3 A
    matrix_a: np.ndarray
    # Residu rata-rata (RMSE) terhadap B_ref dalam nT
    residual_nt: float
    # Simpangan baku magnitudo sebelum kalibrasi dalam nT
    std_before_nt: float
    # Simpangan baku magnitudo sesudah kalibrasi dalam nT
    std_after_nt: float
    # Jumlah titik yang digunakan setelah penolakan outlier
    inlier_count: int


def _solve_quadric_ols(points: np.ndarray, weights: np.ndarray = None) -> np.ndarray:
    """
    Menyelesaikan persamaan kuadrik:
    a*x^2 + b*y^2 + c*z^2 + 2*d*x*y + 2*e*x*z + 2*f*y*z + 2*g*x + 2*h*y + 2*i*z = 1
    menggunakan (Weighted) Least Squares.
    points: array (N, 3) [x, y, z]
    weights: array (N,) atau None
    return: p = [a, b, c, d, e, f, g, h, i]
    """
    x = points[:, 0]
    y = points[:, 1]
    z = points[:, 2]

    # Matriks desain D (N, 9)
    D = np.column_stack([
        x * x,
        y * y,
        z * z,
        2.0 * x * y,
        2.0 * x * z,
        2.0 * y * z,
        2.0 * x,
        2.0 * y,
        2.0 * z,
    ])

    rhs = np.ones(len(points), dtype=np.float64)

    if weights is not None:
        # WLS: (D^T * W * D) p = D^T * W * rhs
        w_diag = weights[:, np.newaxis]
        D_w = D * w_diag
        DtD = D.T @ (D * (weights[:, np.newaxis] ** 2))
        DtY = D.T @ (rhs * (weights ** 2))
        p = np.linalg.solve(DtD, DtY)
    else:
        # OLS
        DtD = D.T @ D
        DtY = D.T @ rhs
        p = np.linalg.solve(DtD, DtY)

    return p


def _params_to_calibration(p: np.ndarray, b_ref_micro_t: float) -> Tuple[np.ndarray, np.ndarray]:
    """
    Mengekstrak offset hard-iron b dan matriks koreksi A dari parameter kuadrik p.
    """
    a, b, c, d, e, f, g, h, i = p

    # Matriks kuadrik 3x3
    A_quad = np.array([
        [a, d, e],
        [d, b, f],
        [e, f, c],
    ], dtype=np.float64)

    b_quad = np.array([g, h, i], dtype=np.float64)

    # Offset hard-iron: v_offset = -A_quad^(-1) * b_quad
    offset = -np.linalg.solve(A_quad, b_quad)

    # Konstanta penskalaan k = 1 + offset^T * A_quad * offset
    k = 1.0 + float(offset.T @ A_quad @ offset)
    if k <= 0:
        raise ValueError("Parameter kuadrik tidak membentuk ellipsoid nyata")

    # Matriks ellipsoid terpusat: M = A_quad / k
    M = A_quad / k

    # Dekomposisi nilai eigen untuk menghitung matriks akar kuadrat simetris:
    # M = V * diag(eigenvals) * V^T
    eigenvals, V = np.linalg.eigh(M)
    if np.any(eigenvals <= 0):
        raise ValueError("Matriks ellipsoid tidak definit positif")

    # M^(1/2) = V * diag(sqrt(eigenvals)) * V^T
    sqrt_diag = np.diag(np.sqrt(eigenvals))
    M_sqrt = V @ sqrt_diag @ V.T

    # A = b_ref * M^(1/2)
    matrix_a = b_ref_micro_t * M_sqrt

    return offset, matrix_a


def fit_ellipsoid_robust(
    points_micro_t: np.ndarray,
    b_ref_micro_t: float,
    max_iter: int = 3,
    outlier_threshold_mad: float = 3.5,
) -> EllipsoidFitResult:
    """
    Kalibrasi ellipsoid robust dengan penolakan outlier Iteratively Reweighted Least Squares (IRLS).
    
    points_micro_t: array (N, 3) bacaan medan magnetik dalam mikroTesla
    b_ref_micro_t: magnitudo medan referensi nominal dalam mikroTesla (misal 45.0 uT)
    max_iter: iterasi reweighting
    outlier_threshold_mad: batas pemotongan outlier dalam kelipatan MAD
    """
    points = np.asarray(points_micro_t, dtype=np.float64)
    n = len(points)
    if n < 10:
        raise ValueError("Dibutuhkan minimal 10 titik orientasi untuk kalibrasi ellipsoid")

    # Pre-filtering awal: buang outlier ekstrim berdasarkan jarak terhadap pusat median
    center_est = np.median(points, axis=0)
    dists = np.linalg.norm(points - center_est, axis=1)
    d_med = np.median(dists)
    mad_dist = np.median(np.abs(dists - d_med))
    cutoff_dist = max(3.0 * (1.4826 * mad_dist), 0.5 * d_med)
    initial_valid = np.abs(dists - d_med) <= cutoff_dist

    # Jika pemotongan menyisakan cukup titik (>= 10), pakai bobot 0 pada outlier ekstrim
    weights = np.ones(n, dtype=np.float64)
    if np.sum(initial_valid) >= 10:
        weights[~initial_valid] = 0.0

    # Hitung simpangan baku awal sebelum kalibrasi (dalam nT)
    norms_before_nt = np.linalg.norm(points, axis=1) * 1000.0
    std_before_nt = float(np.std(norms_before_nt))

    offset = np.zeros(3)
    matrix_a = np.eye(3)

    for iteration in range(max_iter):
        p = _solve_quadric_ols(points, weights)
        offset, matrix_a = _params_to_calibration(p, b_ref_micro_t)

        # Hitung titik terkoreksi: B_cal = A * (B_raw - offset)
        centered = points - offset
        calibrated = (matrix_a @ centered.T).T
        norms_cal = np.linalg.norm(calibrated, axis=1)  # dalam uT

        # Residu terhadap B_ref dalam nT
        residuals_nt = np.abs(norms_cal - b_ref_micro_t) * 1000.0

        # Estimasi skala robust via Median Absolute Deviation (MAD)
        med_res = np.median(residuals_nt)
        mad = np.median(np.abs(residuals_nt - med_res))
        sigma_mad = max(1.4826 * mad, 1e-3)

        # Pembobotan Huber
        huber_k = 1.5 * sigma_mad
        cutoff = outlier_threshold_mad * sigma_mad

        new_weights = np.ones(n, dtype=np.float64)
        for i in range(n):
            r = residuals_nt[i]
            if r > cutoff:
                new_weights[i] = 0.0  # Outlier ditolak total
            elif r > huber_k:
                new_weights[i] = huber_k / r
            else:
                new_weights[i] = 1.0

        weights = new_weights

    # Hasil akhir
    centered = points - offset
    calibrated = (matrix_a @ centered.T).T
    norms_after_nt = np.linalg.norm(calibrated, axis=1) * 1000.0

    inliers_mask = weights > 0
    inlier_count = int(np.sum(inliers_mask))
    if inlier_count == 0:
        inliers_mask = np.ones(n, dtype=bool)
        inlier_count = n

    inlier_residuals_nt = np.abs(norms_after_nt[inliers_mask] - (b_ref_micro_t * 1000.0))
    residual_rmse_nt = float(np.sqrt(np.mean(inlier_residuals_nt ** 2)))
    std_after_nt = float(np.std(norms_after_nt[inliers_mask]))

    return EllipsoidFitResult(
        offset_micro_t=offset,
        matrix_a=matrix_a,
        residual_nt=residual_rmse_nt,
        std_before_nt=std_before_nt,
        std_after_nt=std_after_nt,
        inlier_count=inlier_count,
    )
