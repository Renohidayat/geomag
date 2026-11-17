"""
Unit test untuk modul referensi Tie-Line Crossover Levelling (reference/levelling.py).
"""

import pytest
import numpy as np
from reference.levelling import (
    LinePoint,
    SurveyLine,
    calculate_crossovers,
    perform_tie_line_levelling,
)


def test_crossover_detection():
    # Survey line dari (10, 0) ke (10, 50)
    # Tie line dari (0, 25) ke (30, 25)
    # Perpotongan harus berada tepat di (10, 25)
    s_line = SurveyLine(
        line_id="L1",
        line_type="survey",
        points=[
            LinePoint(x=10.0, y=0.0, reading_nt=45000.0),
            LinePoint(x=10.0, y=50.0, reading_nt=45050.0),
        ],
    )
    t_line = SurveyLine(
        line_id="T1",
        line_type="tie",
        points=[
            LinePoint(x=0.0, y=25.0, reading_nt=45020.0),
            LinePoint(x=30.0, y=25.0, reading_nt=45030.0),
        ],
    )

    crossovers = calculate_crossovers([s_line, t_line])
    assert len(crossovers) == 1
    c = crossovers[0]
    assert c.x == pytest.approx(10.0, abs=1e-5)
    assert c.y == pytest.approx(25.0, abs=1e-5)
    # Pada y=25 (midpoint L1): B_survey = 45025.0
    # Pada x=10 (1/3 dari T1): B_tie = 45020 + (10/30)*10 = 45023.3333
    assert c.b_survey_nt == pytest.approx(45025.0, abs=1e-4)
    assert c.b_tie_nt == pytest.approx(45023.3333, abs=1e-4)
    assert c.error_nt == pytest.approx(45025.0 - 45023.3333, abs=1e-4)


def test_synthetic_grid_levelling_reduction():
    # Grid sintetis 3 survey lines (Utara-Selatan) x 2 tie lines (Timur-Barat)
    # Total 6 titik perpotongan
    # Medan dasar murni: B_true(x, y) = 45000 + 2.0 * x - 1.5 * y
    def b_true(x, y):
        return 45000.0 + 2.0 * x - 1.5 * y

    # Berikan shift/bias artifisial per lintasan:
    shift_s1 = 20.0
    shift_s2 = -15.0
    shift_s3 = 30.0
    shift_t1 = 5.0
    shift_t2 = -10.0

    lines = [
        SurveyLine(
            line_id="L1",
            line_type="survey",
            points=[
                LinePoint(x=10.0, y=0.0, reading_nt=b_true(10.0, 0.0) + shift_s1),
                LinePoint(x=10.0, y=50.0, reading_nt=b_true(10.0, 50.0) + shift_s1),
            ],
        ),
        SurveyLine(
            line_id="L2",
            line_type="survey",
            points=[
                LinePoint(x=20.0, y=0.0, reading_nt=b_true(20.0, 0.0) + shift_s2),
                LinePoint(x=20.0, y=50.0, reading_nt=b_true(20.0, 50.0) + shift_s2),
            ],
        ),
        SurveyLine(
            line_id="L3",
            line_type="survey",
            points=[
                LinePoint(x=30.0, y=0.0, reading_nt=b_true(30.0, 0.0) + shift_s3),
                LinePoint(x=30.0, y=50.0, reading_nt=b_true(30.0, 50.0) + shift_s3),
            ],
        ),
        SurveyLine(
            line_id="T1",
            line_type="tie",
            points=[
                LinePoint(x=0.0, y=15.0, reading_nt=b_true(0.0, 15.0) + shift_t1),
                LinePoint(x=40.0, y=15.0, reading_nt=b_true(40.0, 15.0) + shift_t1),
            ],
        ),
        SurveyLine(
            line_id="T2",
            line_type="tie",
            points=[
                LinePoint(x=0.0, y=35.0, reading_nt=b_true(0.0, 35.0) + shift_t2),
                LinePoint(x=40.0, y=35.0, reading_nt=b_true(40.0, 35.0) + shift_t2),
            ],
        ),
    ]

    result = perform_tie_line_levelling(lines)
    assert result.is_successful is True
    assert result.crossover_count == 6

    # RMSE sebelum levelling harus signifikan (> 20 nT)
    assert result.rmse_before_nt > 20.0

    # RMSE setelah levelling harus mendekati nol (< 0.01 nT)
    assert result.rmse_after_nt < 0.01

    # Verifikasi konsistensi titik perpotongan setelah koreksi
    for c in result.crossovers:
        assert abs(c.residual_nt) < 0.01


def test_parallel_lines_no_crossovers():
    # Dua garis sejajar tanpa perpotongan
    lines = [
        SurveyLine(
            line_id="L1",
            line_type="survey",
            points=[LinePoint(x=0.0, y=0.0, reading_nt=45000.0), LinePoint(x=0.0, y=10.0, reading_nt=45010.0)],
        ),
        SurveyLine(
            line_id="L2",
            line_type="survey",
            points=[LinePoint(x=10.0, y=0.0, reading_nt=45000.0), LinePoint(x=10.0, y=10.0, reading_nt=45010.0)],
        ),
    ]
    res = perform_tie_line_levelling(lines)
    assert res.is_successful is False
    assert res.crossover_count == 0
