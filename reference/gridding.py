"""
Modul referensi Python untuk Gridding 2D data survei geomagnetik.

Mengubah kumpulan titik stasiun tak beraturan (scattered points) menjadi matriks
grid 2D beraturan berdimensi (ny, nx) menggunakan algoritma Inverse Distance Weighting (IDW).
"""

from dataclasses import dataclass
from typing import List, Optional, Tuple, Dict, Any
import numpy as np


@dataclass
class DataPoint:
    x: float
    y: float
    value: float
    station_id: Optional[str] = None


@dataclass
class Grid2D:
    x_min: float
    x_max: float
    y_min: float
    y_max: float
    dx: float
    dy: float
    nx: int
    ny: int
    x_coords: List[float]  # 1D array koordinat X (panjang nx)
    y_coords: List[float]  # 1D array koordinat Y (panjang ny)
    values: np.ndarray     # Matriks 2D berdimensi (ny, nx)

    def to_dict(self) -> Dict[str, Any]:
        return {
            "x_min": self.x_min,
            "x_max": self.x_max,
            "y_min": self.y_min,
            "y_max": self.y_max,
            "dx": self.dx,
            "dy": self.dy,
            "nx": self.nx,
            "ny": self.ny,
            "x_coords": self.x_coords,
            "y_coords": self.y_coords,
            "values": self.values.tolist(),
        }


def grid_inverse_distance_weighting(
    points: List[DataPoint],
    nx: int = 25,
    ny: int = 25,
    power: float = 2.0,
    smoothing: float = 0.01,
    bounds: Optional[Tuple[float, float, float, float]] = None,
) -> Grid2D:
    """
    Melakukan interpolasi IDW dari sekumpulan DataPoint tak beraturan ke Grid2D.

    Parameters:
    - points: daftar DataPoint (x, y, value)
    - nx, ny: jumlah kolom dan baris grid
    - power: eksponen pembobotan jarak (default 2.0 untuk inverse square)
    - smoothing: faktor pelunak jarak di penyebut untuk menghindari pembagian dengan nol
    - bounds: tuple (x_min, x_max, y_min, y_max) opsional; jika None dihitung dari points
    """
    if not points:
        raise ValueError("Daftar titik tidak boleh kosong untuk gridding")

    pts_x = np.array([p.x for p in points], dtype=np.float64)
    pts_y = np.array([p.y for p in points], dtype=np.float64)
    pts_v = np.array([p.value for p in points], dtype=np.float64)

    if bounds is None:
        x_min, x_max = float(np.min(pts_x)), float(np.max(pts_x))
        y_min, y_max = float(np.min(pts_y)), float(np.max(pts_y))
        # Jika semua titik pada koordinat yang sama, beri rentang kecil
        if x_min == x_max:
            x_min -= 1.0
            x_max += 1.0
        if y_min == y_max:
            y_min -= 1.0
            y_max += 1.0
    else:
        x_min, x_max, y_min, y_max = bounds

    dx = (x_max - x_min) / max(1, nx - 1)
    dy = (y_max - y_min) / max(1, ny - 1)

    x_coords = [float(x_min + i * dx) for i in range(nx)]
    y_coords = [float(y_min + j * dy) for j in range(ny)]

    grid_values = np.zeros((ny, nx), dtype=np.float64)

    for r in range(ny):
        gy = y_coords[r]
        for c in range(nx):
            gx = x_coords[c]

            dist_sq = (pts_x - gx) ** 2 + (pts_y - gy) ** 2
            # Periksa apakah ada titik yang tepat berada di simpul grid
            exact_match = np.where(dist_sq < 1e-12)[0]
            if len(exact_match) > 0:
                grid_values[r, c] = pts_v[exact_match[0]]
            else:
                dist = np.sqrt(dist_sq)
                weights = 1.0 / ((dist + smoothing) ** power)
                total_w = np.sum(weights)
                grid_values[r, c] = np.sum(weights * pts_v) / total_w

    return Grid2D(
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
        values=grid_values,
    )
