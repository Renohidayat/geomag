"""
Modul referensi Python untuk koreksi variasi harian (diurnal correction)
pada survei geomagnetik.

Mengurangkan fluktuasi medan magnet bumi akibat dinamika ionosfer dari data rover
menggunakan interpolasi linear waktu antara titik-titik pengamatan base station:
    Delta B_diurnal(t) = B_base(t) - B0
    B_corrected(t)     = B_rover(t) - Delta B_diurnal(t)
                       = B_rover(t) - (B_base(t) - B0)
"""

from dataclasses import dataclass
from enum import Enum
from typing import List, Optional, Tuple, Dict, Any, Union
import numpy as np


class DiurnalStatus(str, Enum):
    SUCCESS = "SUCCESS"
    OUT_OF_RANGE_EARLY = "OUT_OF_RANGE_EARLY"
    OUT_OF_RANGE_LATE = "OUT_OF_RANGE_LATE"
    GAP_TOO_LARGE = "GAP_TOO_LARGE"
    NO_BASE_DATA = "NO_BASE_DATA"
    INSUFFICIENT_BASE_DATA = "INSUFFICIENT_BASE_DATA"


@dataclass
class BasePoint:
    timestamp: float  # detik, ms, atau ns
    total_field_nt: float


@dataclass
class DiurnalCorrectionResult:
    is_valid: bool
    rover_timestamp: float
    b_rover_nt: float
    b_base_interpolated_nt: Optional[float]
    diurnal_correction_nt: Optional[float]
    b_corrected_nt: Optional[float]
    b0_baseline_nt: Optional[float]
    status: DiurnalStatus
    error_message: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "is_valid": self.is_valid,
            "rover_timestamp": self.rover_timestamp,
            "b_rover_nt": self.b_rover_nt,
            "b_base_interpolated_nt": self.b_base_interpolated_nt,
            "diurnal_correction_nt": self.diurnal_correction_nt,
            "b_corrected_nt": self.b_corrected_nt,
            "b0_baseline_nt": self.b0_baseline_nt,
            "status": self.status.value,
            "error_message": self.error_message,
        }


def interpolate_base_reading(
    base_points: List[BasePoint],
    rover_timestamp: float,
    max_allowed_gap: float = 600.0,
    boundary_tolerance: float = 30.0,
) -> Tuple[Optional[float], DiurnalStatus, Optional[str]]:
    """
    Melakukan interpolasi linier nilai base station pada rover_timestamp.

    Parameters:
    - base_points: list BasePoint yang terurut secara waktu.
    - rover_timestamp: waktu sampel rover (dalam satuan waktu yang sama dengan base_points).
    - max_allowed_gap: selisih waktu maksimum yang diizinkan antar dua titik base bersebelahan.
    - boundary_tolerance: toleransi batas di luar [t_min, t_max] yang masih ditoleransi via clamping.

    Returns:
    - Tuple (b_base_interp, status, error_message)
    """
    n = len(base_points)
    if n == 0:
        return None, DiurnalStatus.NO_BASE_DATA, "Data base station kosong"
    if n == 1:
        # Jika hanya ada 1 titik dan pas toleransi
        diff = abs(rover_timestamp - base_points[0].timestamp)
        if diff <= boundary_tolerance:
            return base_points[0].total_field_nt, DiurnalStatus.SUCCESS, None
        return (
            None,
            DiurnalStatus.INSUFFICIENT_BASE_DATA,
            "Data base station hanya memiliki 1 sampel dan rover berada di luar batas toleransi",
        )

    t_start = base_points[0].timestamp
    t_end = base_points[-1].timestamp

    # Kasus sebelum waktu mulai base station
    if rover_timestamp < t_start:
        if (t_start - rover_timestamp) <= boundary_tolerance:
            # Toleransi batas: gunakan nilai titik awal (clamp)
            return base_points[0].total_field_nt, DiurnalStatus.SUCCESS, None
        return (
            None,
            DiurnalStatus.OUT_OF_RANGE_EARLY,
            f"Waktu rover ({rover_timestamp}) sebelum rekaman base ({t_start}) melebihi toleransi ({boundary_tolerance})",
        )

    # Kasus setelah waktu akhir base station
    if rover_timestamp > t_end:
        if (rover_timestamp - t_end) <= boundary_tolerance:
            # Toleransi batas: gunakan nilai titik akhir (clamp)
            return base_points[-1].total_field_nt, DiurnalStatus.SUCCESS, None
        return (
            None,
            DiurnalStatus.OUT_OF_RANGE_LATE,
            f"Waktu rover ({rover_timestamp}) setelah rekaman base ({t_end}) melebihi toleransi ({boundary_tolerance})",
        )

    # Binary search untuk mencari interval t_i <= rover_timestamp <= t_{i+1}
    timestamps = [p.timestamp for p in base_points]
    idx = int(np.searchsorted(timestamps, rover_timestamp))

    if idx == 0:
        return base_points[0].total_field_nt, DiurnalStatus.SUCCESS, None
    if idx >= n:
        return base_points[-1].total_field_nt, DiurnalStatus.SUCCESS, None

    p1 = base_points[idx - 1]
    p2 = base_points[idx]

    dt = p2.timestamp - p1.timestamp
    if dt < 0:
        raise ValueError("Data base station harus terurut menaik (ascending) secara waktu")

    if dt > max_allowed_gap:
        return (
            None,
            DiurnalStatus.GAP_TOO_LARGE,
            f"Gap waktu base station ({dt:.1f} s) melebihi batas maksimum ({max_allowed_gap:.1f} s)",
        )

    if dt == 0:
        return p1.total_field_nt, DiurnalStatus.SUCCESS, None

    # Interpolasi linear
    alpha = (rover_timestamp - p1.timestamp) / dt
    b_interp = p1.total_field_nt + alpha * (p2.total_field_nt - p1.total_field_nt)

    return float(b_interp), DiurnalStatus.SUCCESS, None


def compute_diurnal_correction(
    base_points: List[BasePoint],
    rover_timestamp: float,
    rover_field_nt: float,
    baseline_b0_nt: Optional[float] = None,
    max_allowed_gap: float = 600.0,
    boundary_tolerance: float = 30.0,
) -> DiurnalCorrectionResult:
    """
    Menghitung koreksi variasi harian untuk satu stasiun rover.

    Parameters:
    - base_points: daftar titik base station (timestamp, total_field_nt)
    - rover_timestamp: waktu pengamatan rover
    - rover_field_nt: nilai total field terukur di rover (nT)
    - baseline_b0_nt: nilai acuan B0 base station (jika None, dihitung dari median base_points)
    - max_allowed_gap: gap maksimum antar titik base station yang diizinkan (detik/unit waktu)
    - boundary_tolerance: toleransi di luar batas waktu rekaman base station (detik/unit waktu)
    """
    if len(base_points) == 0:
        return DiurnalCorrectionResult(
            is_valid=False,
            rover_timestamp=rover_timestamp,
            b_rover_nt=rover_field_nt,
            b_base_interpolated_nt=None,
            diurnal_correction_nt=None,
            b_corrected_nt=None,
            b0_baseline_nt=None,
            status=DiurnalStatus.NO_BASE_DATA,
            error_message="Data base station kosong",
        )

    # Pastikan sorted
    sorted_base = sorted(base_points, key=lambda p: p.timestamp)

    # Tentukan baseline B0 jika belum ditentukan
    if baseline_b0_nt is None:
        all_b = [p.total_field_nt for p in sorted_base]
        baseline_b0 = float(np.median(all_b))
    else:
        baseline_b0 = float(baseline_b0_nt)

    b_interp, status, err_msg = interpolate_base_reading(
        sorted_base,
        rover_timestamp,
        max_allowed_gap=max_allowed_gap,
        boundary_tolerance=boundary_tolerance,
    )

    if status != DiurnalStatus.SUCCESS or b_interp is None:
        return DiurnalCorrectionResult(
            is_valid=False,
            rover_timestamp=rover_timestamp,
            b_rover_nt=rover_field_nt,
            b_base_interpolated_nt=None,
            diurnal_correction_nt=None,
            b_corrected_nt=None,
            b0_baseline_nt=baseline_b0,
            status=status,
            error_message=err_msg,
        )

    diurnal_corr = b_interp - baseline_b0
    b_corrected = rover_field_nt - diurnal_corr

    return DiurnalCorrectionResult(
        is_valid=True,
        rover_timestamp=rover_timestamp,
        b_rover_nt=rover_field_nt,
        b_base_interpolated_nt=b_interp,
        diurnal_correction_nt=diurnal_corr,
        b_corrected_nt=b_corrected,
        b0_baseline_nt=baseline_b0,
        status=DiurnalStatus.SUCCESS,
        error_message=None,
    )


def correct_rover_survey(
    base_points: List[BasePoint],
    rover_records: List[Dict[str, Any]],
    baseline_b0_nt: Optional[float] = None,
    max_allowed_gap: float = 600.0,
    boundary_tolerance: float = 30.0,
) -> List[Dict[str, Any]]:
    """
    Menerapkan koreksi diurnal pada sekumpulan rekaman stasiun rover (batch).

    Tiap record di rover_records harus memiliki:
    - 'station_id': str / int
    - 'timestamp': float
    - 'total_field_nt': float
    """
    if len(base_points) == 0:
        b0 = baseline_b0_nt
    elif baseline_b0_nt is None:
        b0 = float(np.median([p.total_field_nt for p in base_points]))
    else:
        b0 = baseline_b0_nt

    results = []
    for rec in rover_records:
        corr_res = compute_diurnal_correction(
            base_points=base_points,
            rover_timestamp=rec["timestamp"],
            rover_field_nt=rec["total_field_nt"],
            baseline_b0_nt=b0,
            max_allowed_gap=max_allowed_gap,
            boundary_tolerance=boundary_tolerance,
        )
        out = {
            "station_id": rec.get("station_id"),
            **corr_res.to_dict(),
        }
        results.append(out)

    return results
