"""
Modul referensi Python untuk model geomagnetik IGRF-14 (International Geomagnetic Reference Field).
Menggunakan ekspansi harmonik bola Schmidt semi-normalized sampai derajat n=13
dan proyeksi secular variation (SV) untuk epoch 2025-2030.

Referensi:
- IAGA Division V-MOD IGRF-14 (2025-2030)
- Wertz, J. R. "Spacecraft Attitude Determination and Control" (Associated Legendre polynomials)
"""

import os
import math
from dataclasses import dataclass
from datetime import datetime, date as py_date
from typing import Dict, List, Optional, Tuple, Union


# Parameter elipsoid WGS-84
WGS84_A_KM = 6378.137
WGS84_F = 1.0 / 298.257223563
WGS84_B_KM = WGS84_A_KM * (1.0 - WGS84_F)
WGS84_E2 = WGS84_F * (2.0 - WGS84_F)

# Radius acuan geomagnetik standar
EARTH_RADIUS_KM = 6371.2


@dataclass
class IgrfResult:
    x_north_nt: float
    y_east_nt: float
    z_down_nt: float
    h_horizontal_nt: float
    f_total_nt: float
    declination_deg: float
    inclination_deg: float

    def to_dict(self) -> Dict[str, float]:
        return {
            "x_north_nt": self.x_north_nt,
            "y_east_nt": self.y_east_nt,
            "z_down_nt": self.z_down_nt,
            "h_horizontal_nt": self.h_horizontal_nt,
            "f_total_nt": self.f_total_nt,
            "declination_deg": self.declination_deg,
            "inclination_deg": self.inclination_deg,
        }


def decimal_year_from_date(dt: Union[datetime, py_date, float, int]) -> float:
    """Mengonversi datetime, date, atau float ke tahun desimal (contoh: 2025.5)."""
    if isinstance(dt, (int, float)):
        return float(dt)
    if isinstance(dt, datetime):
        year = dt.year
        start_of_year = datetime(year, 1, 1)
        start_of_next = datetime(year + 1, 1, 1)
        year_duration = (start_of_next - start_of_year).total_seconds()
        elapsed = (dt - start_of_year).total_seconds()
        return year + (elapsed / year_duration)
    if isinstance(dt, py_date):
        year = dt.year
        start_of_year = py_date(year, 1, 1)
        start_of_next = py_date(year + 1, 1, 1)
        year_duration = (start_of_next - start_of_year).days
        elapsed = (dt - start_of_year).days
        return year + (elapsed / year_duration)
    raise TypeError(f"Tipe tanggal tidak didukung: {type(dt)}")


class Igrf14:
    def __init__(self, coeff_file_path: Optional[str] = None):
        if coeff_file_path is None:
            base_dir = os.path.dirname(os.path.abspath(__file__))
            coeff_file_path = os.path.join(base_dir, "igrf14coeffs.txt")
        self.coeff_file_path = coeff_file_path
        self.epochs: List[float] = []
        # Structure: {(is_h, n, m): [val_at_epoch_0, ..., val_at_epoch_K, sv_val]}
        self.coeffs: Dict[Tuple[int, int, int], List[float]] = {}
        self._load_coefficients()

    def _load_coefficients(self):
        if not os.path.exists(self.coeff_file_path):
            raise FileNotFoundError(f"File koefisien IGRF-14 tidak ditemukan: {self.coeff_file_path}")

        with open(self.coeff_file_path, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f if line.strip() and not line.startswith("#")]

        # Header baris 0: tipe/header
        # Baris 1: daftar tahun epoch
        epoch_line_parts = lines[1].split()[3:]
        # Epochs sampai sebelum kolom SV terakhir
        self.epochs = [float(x) for x in epoch_line_parts[:-1]]

        for line in lines[2:]:
            parts = line.split()
            gh = parts[0].lower()
            is_h = 1 if gh == "h" else 0
            n = int(parts[1])
            m = int(parts[2])
            values = [float(x) for x in parts[3:]]
            self.coeffs[(is_h, n, m)] = values

    def get_interpolated_coeffs(self, year: float) -> Tuple[Dict[Tuple[int, int], float], Dict[Tuple[int, int], float]]:
        """
        Menginterpolasi koefisien Gauss g(n,m) dan h(n,m) untuk tahun desimal yang diminta.
        """
        g_coeffs: Dict[Tuple[int, int], float] = {}
        h_coeffs: Dict[Tuple[int, int], float] = {}

        n_epochs = len(self.epochs)
        first_epoch = self.epochs[0]
        last_epoch = self.epochs[-1]

        for (is_h, n, m), vals in self.coeffs.items():
            if year <= first_epoch:
                val = vals[0]
            elif year >= last_epoch:
                # Gunakan secular variation (kolom terakhir)
                sv = vals[-1]
                dt = year - last_epoch
                val = vals[-2] + dt * sv
            else:
                # Interpolasi linear antara dua epoch terdekat
                idx = 0
                while idx < n_epochs - 1 and self.epochs[idx + 1] <= year:
                    idx += 1
                t1 = self.epochs[idx]
                t2 = self.epochs[idx + 1]
                v1 = vals[idx]
                v2 = vals[idx + 1]
                alpha = (year - t1) / (t2 - t1)
                val = v1 + alpha * (v2 - v1)

            if is_h:
                h_coeffs[(n, m)] = val
            else:
                g_coeffs[(n, m)] = val

        return g_coeffs, h_coeffs

    def calculate(
        self,
        lat_deg: float,
        lon_deg: float,
        alt_km: float = 0.0,
        date_val: Union[datetime, py_date, float, int] = 2025.0,
        max_degree: int = 13,
    ) -> IgrfResult:
        """
        Menghitung medan magnetik total dan komponen-komponennya pada koordinat geodetik.

        Parameters:
        - lat_deg: latitude geodetik (-90 s/d +90 derajat)
        - lon_deg: longitude geodetik (-180 s/d +180 derajat)
        - alt_km: ketinggian di atas elipsoid WGS-84 (km)
        - date_val: tanggal survei atau tahun desimal
        - max_degree: derajat maksimum harmonik bola (1 s/d 13)
        """
        year = decimal_year_from_date(date_val)
        g_map, h_map = self.get_interpolated_coeffs(year)

        # 1. Konversi Geodetik ke Geosentrik
        lat_rad = math.radians(lat_deg)
        lon_rad = math.radians(lon_deg)

        cos_lat = math.cos(lat_rad)
        sin_lat = math.sin(lat_rad)
        cos2_lat = cos_lat * cos_lat
        sin2_lat = sin_lat * sin_lat

        a = WGS84_A_KM
        b = WGS84_B_KM
        tmp = alt_km * math.sqrt(a * a * cos2_lat + b * b * sin2_lat)
        beta = math.atan2((tmp + b * b) * math.sin(lat_rad), (tmp + a * a) * math.cos(lat_rad))
        colat_rad = math.pi / 2.0 - beta

        ba2 = (b / a) ** 2
        ba4 = ba2 * ba2
        r_km = math.sqrt(
            alt_km * alt_km
            + 2.0 * tmp
            + (a * a) * (1.0 - (1.0 - ba4) * sin2_lat) / (1.0 - (1.0 - ba2) * sin2_lat)
        )

        sin_colat = math.sin(colat_rad)
        cos_colat = math.cos(colat_rad)
        # Cegah pembagian dengan nol di kutub
        if abs(sin_colat) < 1e-12:
            sin_colat = 1e-12 if sin_colat >= 0 else -1e-12

        # 2. Polinomial Legendre Terkait (Schmidt semi-normalized)
        # Inisialisasi P[n, m] dan dP[n, m]
        p = [[0.0] * (max_degree + 1) for _ in range(max_degree + 1)]
        dp = [[0.0] * (max_degree + 1) for _ in range(max_degree + 1)]
        s = [[0.0] * (max_degree + 1) for _ in range(max_degree + 1)]

        p[0][0] = 1.0
        dp[0][0] = 0.0
        s[0][0] = 1.0

        for n in range(1, max_degree + 1):
            for m in range(0, n + 1):
                if n == m:
                    p[n][n] = sin_colat * p[n - 1][n - 1]
                    dp[n][n] = sin_colat * dp[n - 1][n - 1] + cos_colat * p[n - 1][n - 1]
                else:
                    if n == 1:
                        p[n][m] = cos_colat * p[n - 1][m]
                        dp[n][m] = -sin_colat * p[n - 1][m]
                    else:
                        knm = ((n - 1) ** 2 - m ** 2) / ((2 * n - 1) * (2 * n - 3))
                        p[n][m] = cos_colat * p[n - 1][m] - knm * p[n - 2][m]
                        dp[n][m] = cos_colat * dp[n - 1][m] - sin_colat * p[n - 1][m] - knm * dp[n - 2][m]

                # Schmidt semi-normalization factor
                if m == 0:
                    s[n][0] = s[n - 1][0] * (2.0 * n - 1.0) / n
                else:
                    factor = 2.0 if m == 1 else 1.0
                    s[n][m] = s[n][m - 1] * math.sqrt((n - m + 1.0) * factor / (n + m))

        # Kalikan dengan faktor Schmidt
        for n in range(1, max_degree + 1):
            for m in range(0, n + 1):
                p[n][m] *= s[n][m]
                dp[n][m] *= s[n][m]

        # 3. Akumulasi Komponen Medan Geosentrik (Br, Btheta, Bphi)
        rho = EARTH_RADIUS_KM / r_km
        rho_n = rho * rho  # (a/r)^2

        b_r = 0.0
        b_theta = 0.0
        b_phi = 0.0

        for n in range(1, max_degree + 1):
            rho_n *= rho  # (a/r)^(n+2)
            sum_r = 0.0
            sum_theta = 0.0
            sum_phi = 0.0

            for m in range(0, n + 1):
                g = g_map.get((n, m), 0.0)
                h = h_map.get((n, m), 0.0)

                cos_m_phi = math.cos(m * lon_rad)
                sin_m_phi = math.sin(m * lon_rad)

                harm = g * cos_m_phi + h * sin_m_phi
                dharm = -g * sin_m_phi + h * cos_m_phi

                sum_r += harm * p[n][m]
                sum_theta += harm * dp[n][m]
                sum_phi += m * dharm * p[n][m]

            b_r += (n + 1) * rho_n * sum_r
            b_theta -= rho_n * sum_theta
            b_phi -= (rho_n / sin_colat) * sum_phi

        # 4. Transformasi dari Geosentrik ke Geodetik (North, East, Down)
        # Sudut rotasi psi antara bidang geodetik dan geosentrik:
        psi = math.sin(lat_rad) * math.sin(colat_rad) - math.cos(lat_rad) * math.cos(colat_rad)

        b_north = -math.cos(psi) * b_theta - math.sin(psi) * b_r
        b_up = -math.sin(psi) * b_theta + math.cos(psi) * b_r
        b_down = -b_up
        b_east = b_phi

        # 5. Parameter Medan Turunan
        h_horiz = math.sqrt(b_north * b_north + b_east * b_east)
        f_total = math.sqrt(h_horiz * h_horiz + b_down * b_down)
        declination = math.degrees(math.atan2(b_east, b_north))
        inclination = math.degrees(math.atan2(b_down, h_horiz))

        return IgrfResult(
            x_north_nt=b_north,
            y_east_nt=b_east,
            z_down_nt=b_down,
            h_horizontal_nt=h_horiz,
            f_total_nt=f_total,
            declination_deg=declination,
            inclination_deg=inclination,
        )


_default_model: Optional[Igrf14] = None


def get_igrf_field(
    lat_deg: float,
    lon_deg: float,
    alt_km: float = 0.0,
    date_val: Union[datetime, py_date, float, int] = 2025.0,
) -> IgrfResult:
    """Fungsi pembantu cepat untuk menghitung medan IGRF-14 default."""
    global _default_model
    if _default_model is None:
        _default_model = Igrf14()
    return _default_model.calculate(lat_deg, lon_deg, alt_km, date_val)
