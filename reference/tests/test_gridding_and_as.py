"""
Unit test untuk modul referensi Gridding 2D dan Analytic Signal 3D.
"""

import pytest
import numpy as np
from reference.gridding import DataPoint, grid_inverse_distance_weighting
from reference.analytic_signal import compute_analytic_signal


def test_idw_gridding_exact_nodes():
    # 4 titik di sudut bujur sangkar (0,0), (10,0), (0,10), (10,10)
    pts = [
        DataPoint(x=0.0, y=0.0, value=100.0),
        DataPoint(x=10.0, y=0.0, value=200.0),
        DataPoint(x=0.0, y=10.0, value=300.0),
        DataPoint(x=10.0, y=10.0, value=400.0),
    ]

    grid = grid_inverse_distance_weighting(pts, nx=3, ny=3, power=2.0)
    assert grid.nx == 3
    assert grid.ny == 3
    assert grid.dx == pytest.approx(5.0)
    assert grid.dy == pytest.approx(5.0)

    # Titik pojok simpul harus mencocokkan nilai asli secara eksak
    assert grid.values[0, 0] == pytest.approx(100.0, abs=1e-4)
    assert grid.values[0, 2] == pytest.approx(200.0, abs=1e-4)
    assert grid.values[2, 0] == pytest.approx(300.0, abs=1e-4)
    assert grid.values[2, 2] == pytest.approx(400.0, abs=1e-4)

    # Titik tengah (5, 5) harus merupakan rata-rata simetris (250.0)
    assert grid.values[1, 1] == pytest.approx(250.0, abs=1.0)


def test_analytic_signal_dipole_anomaly():
    # Buat grid sintetis anomali magnetik dipol di tengah (x0=50, y0=50, z0=15)
    nx, ny = 21, 21
    dx, dy = 5.0, 5.0
    x_min, x_max = 0.0, 100.0
    y_min, y_max = 0.0, 100.0

    x_coords = [x_min + i * dx for i in range(nx)]
    y_coords = [y_min + j * dy for j in range(ny)]

    vals = np.zeros((ny, nx), dtype=np.float64)
    z0 = 15.0
    for r in range(ny):
        y = y_coords[r]
        for c in range(nx):
            x = x_coords[c]
            dist_sq = (x - 50.0) ** 2 + (y - 50.0) ** 2 + z0**2
            # Anomali medan dipol vertikal
            vals[r, c] = 100000.0 * (2.0 * z0**2 - ((x - 50.0)**2 + (y - 50.0)**2)) / (dist_sq ** 2.5)

    from reference.gridding import Grid2D
    in_grid = Grid2D(
        x_min=x_min,
        x_max=x_max,
        y_min=y_min,
        y_max=y_max,
        dx=dx,
        dy=dy,
        nx=nx,
        ny=ny,
        x_coords=x_coords,
        y_coords=y_coords,
        values=vals,
    )

    tx_grid, ty_grid, tz_grid, as_grid = compute_analytic_signal(in_grid)

    # 1. Analytic Signal selalu non-negatif
    assert np.all(as_grid.values >= 0.0)

    # 2. Nilai maksimum |AS| harus berada tepat di simpul tengah (row=10, col=10)
    max_idx = np.unravel_index(np.argmax(as_grid.values), as_grid.values.shape)
    assert max_idx == (10, 10), f"Puncak AS di {max_idx}, diharapkan tepat di tengah (10, 10)"

    # 3. Simetri turunan horizontal Tx dan Ty di sekitar pusat:
    # Tx di sebelah kiri dan kanan pusat harus berlawanan tanda
    assert tx_grid.values[10, 8] == pytest.approx(-tx_grid.values[10, 12], rel=0.1)
    # Ty di sebelah atas dan bawah pusat harus berlawanan tanda
    assert ty_grid.values[8, 10] == pytest.approx(-ty_grid.values[12, 10], rel=0.1)
