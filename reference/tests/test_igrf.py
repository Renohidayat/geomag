"""
Unit test untuk modul referensi IGRF-14 (reference/igrf.py).
Membandingkan hasil perhitungan dengan library resmi IAGA ppigrf.
"""

import datetime
import pytest
import ppigrf
from reference.igrf import get_igrf_field, Igrf14


def test_igrf14_benchmark_locations():
    test_cases = [
        ("Jakarta", -6.2088, 106.8456, 0.0, datetime.datetime(2025, 1, 1)),
        ("Bandung", -6.9175, 107.6191, 0.768, datetime.datetime(2025, 7, 1)),
        ("Yogyakarta", -7.7956, 110.3695, 0.113, datetime.datetime(2026, 1, 1)),
        ("Medan", 3.5952, 98.6722, 0.026, datetime.datetime(2025, 1, 1)),
        ("London", 51.5074, -0.1278, 0.035, datetime.datetime(2025, 1, 1)),
        ("NorthPole", 89.0, 0.0, 0.0, datetime.datetime(2025, 1, 1)),
        ("SouthPole", -89.0, 0.0, 0.0, datetime.datetime(2025, 1, 1)),
    ]

    for name, lat, lon, h, dt in test_cases:
        res = get_igrf_field(lat, lon, h, dt)
        be, bn, bu = ppigrf.igrf(lon, lat, h, dt)
        be_val, bn_val, bu_val = be[0], bn[0], bu[0]
        f_expected = (bn_val**2 + be_val**2 + bu_val**2)**0.5

        # Target PRD: selisih < 1 nT (kita capai < 0.1 nT)
        assert abs(res.y_east_nt - be_val) < 0.1, f"Gagal pada {name} (East)"
        assert abs(res.x_north_nt - bn_val) < 0.1, f"Gagal pada {name} (North)"
        assert abs((-res.z_down_nt) - bu_val) < 0.1, f"Gagal pada {name} (Up/Down)"
        assert abs(res.f_total_nt - f_expected) < 0.1, f"Gagal pada {name} (Total Field F)"


def test_indonesia_low_inclination_characteristics():
    # Menguji karakteristik geomagnetik Indonesia:
    # Inklinasi mendekati 0 di utara (Medan ~ -8°) dan ~ -31° di selatan (Yogyakarta)
    medan = get_igrf_field(3.5952, 98.6722, 0.0, 2025.0)
    yogya = get_igrf_field(-7.7956, 110.3695, 0.0, 2025.0)

    assert -12.0 < medan.inclination_deg < -5.0
    assert -35.0 < yogya.inclination_deg < -28.0
    assert medan.f_total_nt > 40000.0
    assert yogya.f_total_nt > 44000.0


def test_custom_max_degree():
    # Derajat 1 (dipol murni) vs Derajat 13 (harmonik penuh)
    model = Igrf14()
    dipole = model.calculate(0.0, 100.0, 0.0, 2025.0, max_degree=1)
    full = model.calculate(0.0, 100.0, 0.0, 2025.0, max_degree=13)

    assert dipole.f_total_nt > 30000.0
    assert abs(dipole.f_total_nt - full.f_total_nt) < 15000.0
