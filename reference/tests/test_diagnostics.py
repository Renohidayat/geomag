import pytest
from reference.diagnostics import analyze_sensor_timing


def test_analyze_sensor_timing_regular_50hz():
    # 50 Hz = interval 20 ms (20,000,000 ns)
    dt_ns = 20_000_000
    timestamps = [1_000_000_000 + i * dt_ns for i in range(101)]  # 101 sampel = 2 detik

    res = analyze_sensor_timing(timestamps)

    assert res["sample_count"] == 101
    assert res["duration_s"] == 2.0
    assert res["actual_rate_hz"] == 50.0
    assert res["avg_interval_ms"] == 20.0
    assert res["jitter_ms"] == 0.0
    assert res["gap_count"] == 0


def test_analyze_sensor_timing_with_jitter_and_gap():
    # Buat deret dengan variasi interval (jitter) dan 1 gap besar
    timestamps = [
        1_000_000_000,
        1_020_000_000,  # +20ms
        1_042_000_000,  # +22ms
        1_061_000_000,  # +19ms
        1_079_000_000,  # +18ms
        1_180_000_000,  # +101ms (GAP > 2x 20ms)
        1_200_000_000,  # +20ms
    ]

    res = analyze_sensor_timing(timestamps)

    assert res["sample_count"] == 7
    assert res["gap_count"] == 1
    assert res["max_interval_ms"] == 101.0
    assert res["min_interval_ms"] == 18.0
    assert res["jitter_ms"] > 0.0


def test_analyze_sensor_timing_screen_states():
    # 5 sampel layar on (20ms = 50Hz), lalu 5 sampel layar off (50ms = 20Hz)
    ts = [1_000_000_000]
    screen = [True]

    for i in range(4):
        ts.append(ts[-1] + 20_000_000)
        screen.append(True)

    for i in range(5):
        ts.append(ts[-1] + 50_000_000)
        screen.append(False)

    res = analyze_sensor_timing(ts, screen)

    assert res["sample_count"] == 10
    assert res["screen_on_rate_hz"] == 50.0
    assert res["screen_off_rate_hz"] == 20.0
