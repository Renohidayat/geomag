"""Modul referensi Python untuk Reduction to Pole (RTP) stabil pada lintang rendah.

Di lintang rendah ekuator (inklinasi |I| < 20° seperti wilayah Indonesia),
filter RTP standar meledak karena pembagian dengan sin(I) mendekati 0.
Modul ini mengimplementasikan filter RTP teratur (regularized / pseudo-inclination RTP)
yang menjaga pergeseran fase (fase reduksi ke kutub) sekaligus membatasi magnitudo filter
agar terbebas dari artefak garis utara-selatan (north-south striations).
"""

from __future__ import annotations
import math
from typing import Tuple
import numpy as np

from reference.analytic_signal import next_pow2
from reference.gridding import Grid2D


def compute_stabilized_rtp(
    grid: Grid2D,
    inclination_deg: float,
    declination_deg: float,
    pseudo_inclination_deg: float = 20.0,
) -> Grid2D:
    """Menghitung peta Reduction to Pole (RTP) teratur untuk grid anomali magnetik.

    Parameter:
    - grid: Grid2D anomali medan total (ΔT)
    - inclination_deg: Inklinasi medan magnet bumi (derajat)
    - declination_deg: Deklinasi medan magnet bumi (derajat dari Utara ke Timur)
    - pseudo_inclination_deg: Batas ambang sudut regularisasi (default 20.0°)
    """
    vals = grid.values
    ny, nx = vals.shape
    dx, dy = grid.dx, grid.dy

    # Konversi sudut ke radian
    inc = math.radians(inclination_deg)
    dec = math.radians(declination_deg)
    inc_p = math.radians(max(5.0, pseudo_inclination_deg))

    # Komponen arah vektor medan magnet bumi (X=East, Y=North, Z=Down)
    l = math.cos(inc) * math.sin(dec)
    m = math.cos(inc) * math.cos(dec)
    n = math.sin(inc)

    # Padding ke kelipatan pangkat 2 (minimal 16)
    py = next_pow2(max(ny, 16))
    px = next_pow2(max(nx, 16))

    mean_val = float(np.mean(vals))
    detrended = vals - mean_val

    pad_y = py - ny
    pad_x = px - nx
    padded = np.pad(detrended, ((0, pad_y), (0, pad_x)), mode="edge")

    # Wavenumber angular kx dan ky
    kx = 2.0 * np.pi * np.fft.fftfreq(px, d=dx)
    ky = 2.0 * np.pi * np.fft.fftfreq(py, d=dy)
    KX, KY = np.meshgrid(kx, ky)
    K = np.sqrt(KX**2 + KY**2)

    # Ambang regularisasi magnitudo minimum
    delta = math.sin(inc_p) ** 2

    # Operator arah kompleks Θ(k) = (n*|k| + i*(l*kx + m*ky)) / |k|
    # Untuk titik DC (|k| == 0), Θ = 1
    with np.errstate(divide="ignore", invalid="ignore"):
        theta = np.where(
            K == 0.0,
            1.0 + 0.0j,
            (n * K + 1j * (l * KX + m * KY)) / K,
        )

    # Respon filter arah untuk induksi murni: H(k) = Θ(k)^2
    H = theta**2
    H_mag = np.abs(H)

    # Regularisasi phase-preserving:
    # Jika |H| < delta, clamp magnitudo ke delta dengan mempertahankan arah fase
    with np.errstate(divide="ignore", invalid="ignore"):
        phase_H = np.where(H_mag == 0.0, 1.0 + 0.0j, H / H_mag)
        H_reg_mag = np.maximum(H_mag, delta)
        H_reg = H_reg_mag * phase_H

        rtp_filter = np.where(K == 0.0, 1.0 + 0.0j, 1.0 / H_reg)

    # Transformasi Fourier 2D data
    f_padded = np.fft.fft2(padded)

    # Terapkan filter RTP
    rtp_fft = f_padded * rtp_filter

    # Transformasi balik ke domain spasial
    rtp_padded = np.real(np.fft.ifft2(rtp_fft))

    # Unpad kembali ke ukuran asli dan tambahkan kembali mean
    rtp_vals = rtp_padded[:ny, :nx] + mean_val

    return Grid2D(
        x_min=grid.x_min,
        x_max=grid.x_max,
        y_min=grid.y_min,
        y_max=grid.y_max,
        dx=grid.dx,
        dy=grid.dy,
        nx=grid.nx,
        ny=grid.ny,
        x_coords=grid.x_coords,
        y_coords=grid.y_coords,
        values=rtp_vals,
    )
