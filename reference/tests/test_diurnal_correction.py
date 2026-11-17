"""
Test untuk modul referensi koreksi variasi harian (diurnal_correction.py).
"""

import pytest
import numpy as np
from reference.diurnal_correction import (
    BasePoint,
    DiurnalStatus,
    compute_diurnal_correction,
    correct_rover_survey,
    interpolate_base_reading,
)


def test_linear_interpolation_exact():
    # Base station points at t=0, t=100, t=200
    base_points = [
        BasePoint(timestamp=0.0, total_field_nt=45000.0),
        BasePoint(timestamp=100.0, total_field_nt=45050.0),
        BasePoint(timestamp=200.0, total_field_nt=45020.0),
    ]

    # Exactly at midpoint t=50 -> field should be 45025.0
    val, status, err = interpolate_base_reading(base_points, rover_timestamp=50.0)
    assert status == DiurnalStatus.SUCCESS
    assert val == pytest.approx(45025.0, abs=1e-5)

    # Exactly at t=150 -> field = 45050 + 0.5 * (45020 - 45050) = 45035.0
    val, status, err = interpolate_base_reading(base_points, rover_timestamp=150.0)
    assert status == DiurnalStatus.SUCCESS
    assert val == pytest.approx(45035.0, abs=1e-5)

    # Exactly on existing point t=100 -> 45050.0
    val, status, err = interpolate_base_reading(base_points, rover_timestamp=100.0)
    assert status == DiurnalStatus.SUCCESS
    assert val == pytest.approx(45050.0, abs=1e-5)


def test_diurnal_correction_computation():
    base_points = [
        BasePoint(timestamp=1000.0, total_field_nt=45000.0),
        BasePoint(timestamp=1100.0, total_field_nt=45020.0),
        BasePoint(timestamp=1200.0, total_field_nt=45040.0),
    ]
    # If B0 is explicitly 45000.0
    # At t=1050: B_base = 45010.0
    # Delta B_diurnal = 45010 - 45000 = 10 nT
    # If rover measured 45350 nT:
    # B_corrected = 45350 - 10 = 45340 nT
    res = compute_diurnal_correction(
        base_points=base_points,
        rover_timestamp=1050.0,
        rover_field_nt=45350.0,
        baseline_b0_nt=45000.0,
    )

    assert res.is_valid is True
    assert res.status == DiurnalStatus.SUCCESS
    assert res.b_base_interpolated_nt == pytest.approx(45010.0, abs=1e-5)
    assert res.diurnal_correction_nt == pytest.approx(10.0, abs=1e-5)
    assert res.b_corrected_nt == pytest.approx(45340.0, abs=1e-5)
    assert res.b0_baseline_nt == pytest.approx(45000.0, abs=1e-5)


def test_diurnal_boundary_tolerance_and_out_of_range():
    base_points = [
        BasePoint(timestamp=100.0, total_field_nt=45000.0),
        BasePoint(timestamp=200.0, total_field_nt=45050.0),
    ]

    # Rover at t=90 (10s before start), boundary tolerance is 30s -> should clamp to t=100 (45000)
    res_early_ok = compute_diurnal_correction(
        base_points=base_points,
        rover_timestamp=90.0,
        rover_field_nt=45200.0,
        baseline_b0_nt=45000.0,
        boundary_tolerance=30.0,
    )
    assert res_early_ok.is_valid is True
    assert res_early_ok.b_base_interpolated_nt == pytest.approx(45000.0, abs=1e-5)

    # Rover at t=50 (50s before start), boundary tolerance is 30s -> OUT_OF_RANGE_EARLY
    res_early_bad = compute_diurnal_correction(
        base_points=base_points,
        rover_timestamp=50.0,
        rover_field_nt=45200.0,
        baseline_b0_nt=45000.0,
        boundary_tolerance=30.0,
    )
    assert res_early_bad.is_valid is False
    assert res_early_bad.status == DiurnalStatus.OUT_OF_RANGE_EARLY
    assert res_early_bad.b_corrected_nt is None

    # Rover at t=215 (15s after end), tolerance 30s -> clamp to t=200 (45050)
    res_late_ok = compute_diurnal_correction(
        base_points=base_points,
        rover_timestamp=215.0,
        rover_field_nt=45200.0,
        baseline_b0_nt=45000.0,
        boundary_tolerance=30.0,
    )
    assert res_late_ok.is_valid is True
    assert res_late_ok.b_base_interpolated_nt == pytest.approx(45050.0, abs=1e-5)

    # Rover at t=260 (60s after end) -> OUT_OF_RANGE_LATE
    res_late_bad = compute_diurnal_correction(
        base_points=base_points,
        rover_timestamp=260.0,
        rover_field_nt=45200.0,
        baseline_b0_nt=45000.0,
        boundary_tolerance=30.0,
    )
    assert res_late_bad.is_valid is False
    assert res_late_bad.status == DiurnalStatus.OUT_OF_RANGE_LATE


def test_gap_too_large():
    # Base station points with a huge gap of 1500s (> max_allowed_gap 600s)
    base_points = [
        BasePoint(timestamp=0.0, total_field_nt=45000.0),
        BasePoint(timestamp=1500.0, total_field_nt=45030.0),
    ]

    res = compute_diurnal_correction(
        base_points=base_points,
        rover_timestamp=500.0,
        rover_field_nt=45100.0,
        max_allowed_gap=600.0,
    )
    assert res.is_valid is False
    assert res.status == DiurnalStatus.GAP_TOO_LARGE
    assert "Gap waktu" in res.error_message


def test_no_base_data():
    res = compute_diurnal_correction(
        base_points=[],
        rover_timestamp=100.0,
        rover_field_nt=45100.0,
    )
    assert res.is_valid is False
    assert res.status == DiurnalStatus.NO_BASE_DATA


def test_batch_rover_survey_correction():
    base_points = [
        BasePoint(timestamp=100.0, total_field_nt=45000.0),
        BasePoint(timestamp=200.0, total_field_nt=45020.0),
        BasePoint(timestamp=300.0, total_field_nt=45040.0),
    ]
    # Median of base is 45020.0 -> B0 = 45020.0

    rover_records = [
        {"station_id": "ST-01", "timestamp": 100.0, "total_field_nt": 45100.0},
        {"station_id": "ST-02", "timestamp": 150.0, "total_field_nt": 45150.0},
        {"station_id": "ST-03", "timestamp": 250.0, "total_field_nt": 45200.0},
        {"station_id": "ST-04", "timestamp": 500.0, "total_field_nt": 45300.0},  # out of range
    ]

    results = correct_rover_survey(base_points, rover_records)
    assert len(results) == 4

    # ST-01: t=100 -> b_base=45000, b0=45020 -> diurnal = 45000 - 45020 = -20 nT
    # b_corr = 45100 - (-20) = 45120 nT
    assert results[0]["is_valid"] is True
    assert results[0]["b_base_interpolated_nt"] == pytest.approx(45000.0, abs=1e-5)
    assert results[0]["diurnal_correction_nt"] == pytest.approx(-20.0, abs=1e-5)
    assert results[0]["b_corrected_nt"] == pytest.approx(45120.0, abs=1e-5)

    # ST-02: t=150 -> b_base=45010, b0=45020 -> diurnal = -10 nT
    # b_corr = 45150 - (-10) = 45160 nT
    assert results[1]["is_valid"] is True
    assert results[1]["b_base_interpolated_nt"] == pytest.approx(45010.0, abs=1e-5)
    assert results[1]["b_corrected_nt"] == pytest.approx(45160.0, abs=1e-5)

    # ST-04: t=500 -> out of range
    assert results[3]["is_valid"] is False
    assert results[3]["status"] == "OUT_OF_RANGE_LATE"
