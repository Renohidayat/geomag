"""
Unit tests untuk reference/room_temp_fit.py.
Memverifikasi kecocokan parameter OLS dan hukum pendinginan Newton.
"""

import os
import csv
import pytest
from reference.room_temp_fit import (
    compute_linear_slope,
    compute_rolling_slopes,
    fit_thermal_parameters,
    fit_steady_offset,
    estimate_room_temperature,
)


def test_compute_linear_slope_perfect_line():
    times = [0.0, 10.0, 20.0, 30.0]
    values = [20.0, 25.0, 30.0, 35.0]  # slope = 0.5 per detik
    slope = compute_linear_slope(times, values)
    assert pytest.approx(slope, abs=1e-9) == 0.5


def test_compute_linear_slope_flat():
    times = [0.0, 5.0, 10.0, 15.0]
    values = [27.0, 27.0, 27.0, 27.0]
    slope = compute_linear_slope(times, values)
    assert pytest.approx(slope, abs=1e-9) == 0.0


def test_fit_thermal_parameters_from_fixture():
    fixture_path = os.path.join(
        os.path.dirname(__file__), "fixtures", "thermal_calibration_fixture.csv"
    )
    assert os.path.exists(fixture_path), f"Fixture tidak ditemukan di {fixture_path}"

    times, bats, refs = [], [], []
    with open(fixture_path, "r") as f:
        reader = csv.DictReader(f)
        for row in reader:
            times.append(float(row["timestamp_s"]))
            bats.append(float(row["battery_temp_c"]))
            refs.append(float(row["reference_temp_c"]))

    assert len(times) == 181
    params = fit_thermal_parameters(times, bats, refs, window_s=180.0)

    # Verifikasi parameter
    assert params["a"] == 1.0
    assert 2.5 <= params["d0"] <= 4.0
    assert params["b"] == pytest.approx(-params["d0"], abs=1e-9)
    assert 100.0 <= params["tau"] <= 400.0
    assert params["rmse"] < 1.0  # Error estimasi di bawah 1°C


def test_fit_steady_offset():
    bats = [30.0, 30.2, 29.8, 30.0]
    ref = 26.0
    d0, std = fit_steady_offset(bats, ref)
    assert pytest.approx(d0, abs=1e-4) == 4.0
    assert std < 0.2


def test_estimate_room_temperature_monotonic():
    # Monoton terhadap T_bat saat keadaan statis
    est1 = estimate_room_temperature(30.0, 0.0, a=1.0, b=-3.0)
    est2 = estimate_room_temperature(35.0, 0.0, a=1.0, b=-3.0)
    assert est2 > est1
    assert pytest.approx(est1, abs=1e-4) == 27.0
    assert pytest.approx(est2, abs=1e-4) == 32.0


def test_estimate_room_temperature_dynamic_cooling():
    # Saat ponsel sedang mendingin (slope < 0), estimasi harus mengoreksi ke bawah
    static_est = estimate_room_temperature(32.0, 0.0, a=1.0, b=-3.0, tau=200.0)
    cooling_est = estimate_room_temperature(32.0, -0.01, a=1.0, b=-3.0, tau=200.0)
    # tau * slope = 200 * -0.01 = -2.0°C koreksi
    assert cooling_est < static_est
    assert pytest.approx(cooling_est, abs=1e-4) == (static_est - 2.0)
