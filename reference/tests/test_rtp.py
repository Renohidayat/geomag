import math
import numpy as np
import pytest
from reference.gridding import Grid2D
from reference.rtp_low_latitude import compute_stabilized_rtp


def create_synthetic_equatorial_dipole(
    nx: int = 17,
    ny: int = 17,
    dx: float = 5.0,
    dy: float = 5.0,
    inc_deg: float = -15.0,
    dec_deg: float = 1.0,
) -> Grid2D:
    """Membuat grid sintetis anomali dipol pada lintang rendah (I = -15°)."""
    x_coords = np.linspace(0, (nx - 1) * dx, nx)
    y_coords = np.linspace(0, (ny - 1) * dy, ny)
    X, Y = np.meshgrid(x_coords, y_coords)

    # Pusat dipol di (40 m, 40 m) pada kedalaman z = 10 m
    x0, y0, z0 = 40.0, 40.0, 10.0
    rx = X - x0
    ry = Y - y0
    rz = z0  # z ke bawah positif

    inc = math.radians(inc_deg)
    dec = math.radians(dec_deg)
    l = math.cos(inc) * math.sin(dec)
    m = math.cos(inc) * math.cos(dec)
    n = math.sin(inc)

    r_sq = rx**2 + ry**2 + rz**2
    r_5 = r_sq**2.5

    # Momen dipol M sejajar medan utama
    M = 100000.0
    r_dot_m = l * rx + m * ry + n * rz

    # Anomali medan total ΔT
    Bx = M * (3.0 * rx * r_dot_m - l * r_sq) / r_5
    By = M * (3.0 * ry * r_dot_m - m * r_sq) / r_5
    Bz = M * (3.0 * rz * r_dot_m - n * r_sq) / r_5
    delta_t = l * Bx + m * By + n * Bz

    return Grid2D(
        x_min=0.0,
        x_max=float((nx - 1) * dx),
        y_min=0.0,
        y_max=float((ny - 1) * dy),
        dx=dx,
        dy=dy,
        nx=nx,
        ny=ny,
        x_coords=x_coords,
        y_coords=y_coords,
        values=delta_t,
    )


def test_stabilized_rtp_centers_anomaly_peak():
    # Buat anomali dipol ekuator (I = -15°)
    grid = create_synthetic_equatorial_dipole(nx=17, ny=17, inc_deg=-15.0)

    # Pada anomali mentah, puncak tidak tepat di pusat (40m, 40m) karena inklinasi miring
    raw_peak_idx = np.unravel_index(np.argmax(grid.values), grid.values.shape)
    raw_peak_x = grid.x_coords[raw_peak_idx[1]]
    raw_peak_y = grid.y_coords[raw_peak_idx[0]]

    # Jalankan RTP teratur
    rtp_grid = compute_stabilized_rtp(
        grid=grid,
        inclination_deg=-15.0,
        declination_deg=1.0,
        pseudo_inclination_deg=20.0,
    )

    assert rtp_grid.values.shape == grid.values.shape
    assert not np.isnan(rtp_grid.values).any()
    assert not np.isinf(rtp_grid.values).any()

    # Puncak anomali setelah RTP harus berada tepat di sekitar pusat benda (40m, 40m)
    rtp_peak_idx = np.unravel_index(np.argmax(rtp_grid.values), rtp_grid.values.shape)
    rtp_peak_x = rtp_grid.x_coords[rtp_peak_idx[1]]
    rtp_peak_y = rtp_grid.y_coords[rtp_peak_idx[0]]

    # Selisih puncak terhadap sumber geologi harus mendekati nol
    dist_to_center = math.sqrt((rtp_peak_x - 40.0) ** 2 + (rtp_peak_y - 40.0) ** 2)
    assert dist_to_center <= 5.0  # Dalam radius 1 sel


def test_stabilized_rtp_stability_at_equator():
    # Uji pada inklinasi mendekati nol (I = -2.0°)
    grid = create_synthetic_equatorial_dipole(nx=17, ny=17, inc_deg=-2.0)

    rtp_grid = compute_stabilized_rtp(
        grid=grid,
        inclination_deg=-2.0,
        declination_deg=0.5,
        pseudo_inclination_deg=20.0,
    )

    # Nilai harus stabil, tidak boleh meledak ke magnitudo 10^10 akibat pembagian nol
    max_val = np.max(np.abs(rtp_grid.values))
    raw_max = np.max(np.abs(grid.values))
    # Rasio amplifikasi harus terkendali (tidak meledak)
    assert max_val < raw_max * 10.0
