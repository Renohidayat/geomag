"""
Modul referensi Python untuk perhitungan Analytic Signal 3D geomagnetik.

Sesuai metodologi Roest et al. (1992) dan MacLeod et al. (1993):
Magnitudo sinyal analitik 3D:
    |AS(x, y)| = sqrt((dT/dx)^2 + (dT/dy)^2 + (dT/dz)^2)

Di mana:
- dT/dx dan dT/dy dihitung via finite difference berpusat pada grid 2D.
- dT/dz dihitung di domain wavenumber melalui transformasi Fourier 2D (FFT)
  menggunakan persamaan Laplace: F[dT/dz] = |k| * F[T], di mana |k| = sqrt(kx^2 + ky^2).
"""

from typing import Tuple
import numpy as np
from reference.gridding import Grid2D


def next_pow2(n: int) -> int:
    """Mencari bilangan pangkat 2 terkecil yang >= n."""
    if n <= 1:
        return 1
    return 1 << (n - 1).bit_length()


def compute_analytic_signal(
    grid: Grid2D,
) -> Tuple[Grid2D, Grid2D, Grid2D, Grid2D]:
    """
    Menghitung turunan horizontal (Tx, Ty), turunan vertikal (Tz),
    dan magnitudo Analytic Signal 3D (|AS|).

    Returns:
    - (tx_grid, ty_grid, tz_grid, as_grid)
    """
    vals = grid.values
    ny, nx = vals.shape
    dx, dy = grid.dx, grid.dy

    # 1. Turunan Horizontal Tx (dT/dx)
    tx = np.zeros((ny, nx), dtype=np.float64)
    if nx > 1:
        # Central difference di bagian dalam
        tx[:, 1:-1] = (vals[:, 2:] - vals[:, :-2]) / (2.0 * dx)
        # Forward/backward di batas tepi
        tx[:, 0] = (vals[:, 1] - vals[:, 0]) / dx
        tx[:, -1] = (vals[:, -1] - vals[:, -2]) / dx

    # 2. Turunan Horizontal Ty (dT/dy)
    ty = np.zeros((ny, nx), dtype=np.float64)
    if ny > 1:
        # Central difference di bagian dalam
        ty[1:-1, :] = (vals[2:, :] - vals[:-2, :]) / (2.0 * dy)
        # Forward/backward di batas tepi
        ty[0, :] = (vals[1, :] - vals[0, :]) / dy
        ty[-1, :] = (vals[-1, :] - vals[-2, :]) / dy

    # 3. Turunan Vertikal Tz (dT/dz) via 2D FFT dengan zero/reflection padding
    # Padding ke pangkat 2 minimum 16 untuk mencegah boundary leakage
    py = next_pow2(max(ny, 16))
    px = next_pow2(max(nx, 16))

    # Kurangi mean sebelum FFT untuk mereduksi DC edge discontinuity
    mean_val = np.mean(vals)
    detrended = vals - mean_val

    # Pad dengan edge reflection
    pad_y = py - ny
    pad_x = px - nx
    padded = np.pad(detrended, ((0, pad_y), (0, pad_x)), mode="edge")

    # Wavenumber angular kx dan ky
    kx = 2.0 * np.pi * np.fft.fftfreq(px, d=dx)
    ky = 2.0 * np.pi * np.fft.fftfreq(py, d=dy)
    KX, KY = np.meshgrid(kx, ky)
    K = np.sqrt(KX**2 + KY**2)

    # Transformasi Fourier 2D
    f_padded = np.fft.fft2(padded)
    # Filter turunan vertikal |k|
    tz_fft = K * f_padded
    # Transformasi balik ke domain spasial
    tz_padded = np.real(np.fft.ifft2(tz_fft))

    # Ekstrak kembali region grid asli (unpad)
    tz = tz_padded[:ny, :nx]

    # 4. Magnitudo Analytic Signal 3D
    as_mag = np.sqrt(tx**2 + ty**2 + tz**2)

    def _make_grid(arr: np.ndarray) -> Grid2D:
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
            values=arr,
        )

    return _make_grid(tx), _make_grid(ty), _make_grid(tz), _make_grid(as_mag)
