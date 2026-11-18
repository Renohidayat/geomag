"""
Modul diagnostik analisis laju sampling, jitter, dan kontinuitas sensor magnetometer.
Digunakan sebagai referensi resmi untuk validasi implementasi Dart di GeoMag.
"""

from typing import List, Dict, Any, Optional
import numpy as np


def analyze_sensor_timing(
    timestamps_ns: List[int],
    screen_states: Optional[List[bool]] = None,
    gap_threshold_factor: float = 2.0,
) -> Dict[str, Any]:
    """
    Menganalisis karakteristik waktu deret sampel magnetometer.

    Parameters:
    - timestamps_ns: list timestamp sensor dalam nanodetik (monotonic).
    - screen_states: list boolean apakah layar menyala pada setiap sampel.
    - gap_threshold_factor: faktor pengali interval rata-rata untuk menandai gap/drop.

    Returns:
    - dict berisi metrik timing, statistik jitter, dan analisis layar mati.
    """
    n = len(timestamps_ns)
    if n < 2:
        return {
            "sample_count": n,
            "duration_s": 0.0,
            "actual_rate_hz": 0.0,
            "avg_interval_ms": 0.0,
            "jitter_ms": 0.0,
            "min_interval_ms": 0.0,
            "max_interval_ms": 0.0,
            "gap_count": 0,
            "screen_on_rate_hz": 0.0,
            "screen_off_rate_hz": 0.0,
        }

    ts_arr = np.array(timestamps_ns, dtype=np.int64)
    # Selisih antar timestamp dalam milidetik
    intervals_ms = np.diff(ts_arr) / 1e6

    # Filter out negatif atau nol jika ada jitter anomali clock
    valid_intervals = intervals_ms[intervals_ms > 0]
    if len(valid_intervals) == 0:
        return {
            "sample_count": n,
            "duration_s": 0.0,
            "actual_rate_hz": 0.0,
            "avg_interval_ms": 0.0,
            "jitter_ms": 0.0,
            "min_interval_ms": 0.0,
            "max_interval_ms": 0.0,
            "gap_count": 0,
            "screen_on_rate_hz": 0.0,
            "screen_off_rate_hz": 0.0,
        }

    total_duration_s = (ts_arr[-1] - ts_arr[0]) / 1e9
    avg_interval_ms = float(np.mean(valid_intervals))
    jitter_ms = float(np.std(valid_intervals, ddof=1)) if len(valid_intervals) > 1 else 0.0
    actual_rate_hz = 1000.0 / avg_interval_ms if avg_interval_ms > 0 else 0.0

    gap_threshold = avg_interval_ms * gap_threshold_factor
    gap_count = int(np.sum(valid_intervals > gap_threshold))

    # Analisis layar hidup vs layar mati
    screen_on_rate = 0.0
    screen_off_rate = 0.0

    if screen_states and len(screen_states) == n:
        states = np.array(screen_states, dtype=bool)
        # Pisahkan interval berdasarkan status layar saat sampel diambil
        on_intervals = intervals_ms[states[1:]]
        off_intervals = intervals_ms[~states[1:]]

        if len(on_intervals) > 0 and np.mean(on_intervals) > 0:
            screen_on_rate = float(1000.0 / np.mean(on_intervals))
        if len(off_intervals) > 0 and np.mean(off_intervals) > 0:
            screen_off_rate = float(1000.0 / np.mean(off_intervals))

    return {
        "sample_count": n,
        "duration_s": round(total_duration_s, 4),
        "actual_rate_hz": round(actual_rate_hz, 2),
        "avg_interval_ms": round(avg_interval_ms, 3),
        "jitter_ms": round(jitter_ms, 3),
        "min_interval_ms": round(float(np.min(valid_intervals)), 3),
        "max_interval_ms": round(float(np.max(valid_intervals)), 3),
        "gap_count": gap_count,
        "screen_on_rate_hz": round(screen_on_rate, 2),
        "screen_off_rate_hz": round(screen_off_rate, 2),
    }
