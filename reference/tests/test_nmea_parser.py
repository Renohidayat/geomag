import pytest
from reference.nmea_parser import (
    GnssFixQuality,
    compute_nmea_checksum,
    verify_nmea_sentence,
    parse_nmea_coordinate,
    parse_nmea_sentence,
)


def test_compute_nmea_checksum():
    # Contoh standar NMEA: GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,
    payload = "GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,"
    csum = compute_nmea_checksum(payload)
    assert csum == "47"


def test_verify_nmea_sentence():
    valid = "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47"
    is_ok, payload = verify_nmea_sentence(valid)
    assert is_ok is True
    assert payload.startswith("GPGGA")

    corrupt = "$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*99"
    is_ok, _ = verify_nmea_sentence(corrupt)
    assert is_ok is False

    malformed = "GPGGA,12345"
    is_ok, _ = verify_nmea_sentence(malformed)
    assert is_ok is False


def test_parse_nmea_coordinate_indonesia():
    # Bandung: 06° 53.4800' S (-6.891333°), 107° 36.7200' E (107.612000°)
    lat = parse_nmea_coordinate("0653.4800", "S")
    assert lat is not None
    assert round(lat, 4) == -6.8913

    lon = parse_nmea_coordinate("10736.7200", "E")
    assert lon is not None
    assert round(lon, 4) == 107.6120


def test_parse_gpgga_rtk_fix():
    # Kalimat GNSS RTK Fixed dari u-blox ZED-F9P
    payload = "GNGGA,072412.00,0653.4800,S,10736.7200,E,4,18,0.65,765.20,M,25.4,M,1.2,0001"
    csum = compute_nmea_checksum(payload)
    sentence = f"${payload}*{csum}"

    pos = parse_nmea_sentence(sentence)
    assert pos is not None
    assert pos.sentence_type == "GGA"
    assert round(pos.latitude, 4) == -6.8913
    assert round(pos.longitude, 4) == 107.6120
    assert pos.altitude_m == 765.20
    assert pos.hdop == 0.65
    assert pos.satellites == 18
    assert pos.fix_quality == GnssFixQuality.RTK_FIX


def test_parse_gprmc_valid():
    payload = "GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W"
    csum = compute_nmea_checksum(payload)
    sentence = f"${payload}*{csum}"

    pos = parse_nmea_sentence(sentence)
    assert pos is not None
    assert pos.sentence_type == "RMC"
    assert round(pos.latitude, 4) == 48.1173
    assert round(pos.longitude, 4) == 11.5167
    assert pos.fix_quality == GnssFixQuality.GPS_FIX
