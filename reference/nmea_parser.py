"""Modul referensi Python untuk parsing stream kalimat NMEA-0183 GNSS (DGPS/RTK).

Mendukung kalimat GGA ($xxGGA) dan RMC ($xxRMC) dengan ekstraksi koordinat WGS-84,
elevasi, HDOP, jumlah satelit, kualitas fix, serta verifikasi checksum XOR.
"""

from __future__ import annotations
from dataclasses import dataclass
from enum import Enum
from typing import Optional, Tuple


class GnssFixQuality(Enum):
    INVALID = "INVALID"           # 0
    GPS_FIX = "GPS_FIX"           # 1 (SPS / Standalone)
    DGPS_FIX = "DGPS_FIX"         # 2 (Differential GPS)
    PPS_FIX = "PPS_FIX"           # 3
    RTK_FIX = "RTK_FIX"           # 4 (RTK Fixed)
    RTK_FLOAT = "RTK_FLOAT"       # 5 (RTK Float)
    ESTIMATED = "ESTIMATED"       # 6 (Dead Reckoning)


@dataclass
class NmeaPosition:
    latitude: float
    longitude: float
    altitude_m: Optional[float] = None
    hdop: Optional[float] = None
    satellites: Optional[int] = None
    fix_quality: GnssFixQuality = GnssFixQuality.GPS_FIX
    sentence_type: str = "GGA"
    raw_sentence: str = ""


def compute_nmea_checksum(payload: str) -> str:
    """Menghitung nilai checksum XOR 2 digit hexadesimal dari string payload NMEA (tanpa $ dan *)."""
    csum = 0
    for char in payload:
        csum ^= ord(char)
    return f"{csum:02X}"


def verify_nmea_sentence(sentence: str) -> Tuple[bool, str]:
    """Memvalidasi integritas kalimat NMEA terhadap checksum XOR.

    Mengembalikan (is_valid, payload_without_prefix_and_checksum).
    """
    sentence = sentence.strip()
    if not sentence.startswith("$"):
        return False, ""

    if "*" not in sentence:
        return False, ""

    parts = sentence[1:].split("*", 1)
    payload = parts[0]
    expected_csum = parts[1].strip().upper()

    actual_csum = compute_nmea_checksum(payload)
    if actual_csum != expected_csum:
        return False, ""

    return True, payload


def parse_nmea_coordinate(coord_str: str, direction: str) -> Optional[float]:
    """Mengonversi koordinat format NMEA (ddmm.mmmm atau dddmm.mmmm) ke derajat desimal WGS-84."""
    if not coord_str or not direction:
        return None

    try:
        val = float(coord_str)
        # 2 digit terakhir sebelum titik desimal adalah menit
        # Contoh: 4807.038 -> deg=48, min=07.038
        # Contoh: 10736.789 -> deg=107, min=36.789
        degrees = int(val / 100.0)
        minutes = val - (degrees * 100.0)
        decimal = degrees + (minutes / 60.0)

        direction = direction.upper()
        if direction in ("S", "W"):
            decimal = -decimal

        return round(decimal, 7)
    except (ValueError, TypeError):
        return None


def parse_gga(payload: str, raw_sentence: str) -> Optional[NmeaPosition]:
    """Mem-parsing isi payload kalimat GGA ($GPGGA, $GNGGA, dsb)."""
    fields = payload.split(",")
    # Minimal 10 field untuk GGA
    if len(fields) < 10:
        return None

    lat = parse_nmea_coordinate(fields[2], fields[3])
    lon = parse_nmea_coordinate(fields[4], fields[5])
    if lat is None or lon is None:
        return None

    # Kualitas fix
    fix_code = fields[6].strip()
    fix_map = {
        "0": GnssFixQuality.INVALID,
        "1": GnssFixQuality.GPS_FIX,
        "2": GnssFixQuality.DGPS_FIX,
        "3": GnssFixQuality.PPS_FIX,
        "4": GnssFixQuality.RTK_FIX,
        "5": GnssFixQuality.RTK_FLOAT,
        "6": GnssFixQuality.ESTIMATED,
    }
    fix_quality = fix_map.get(fix_code, GnssFixQuality.INVALID)

    # Satelit
    satellites = int(fields[7]) if fields[7].isdigit() else None

    # HDOP
    try:
        hdop = float(fields[8]) if fields[8] else None
    except ValueError:
        hdop = None

    # Altitude
    try:
        alt = float(fields[9]) if fields[9] else None
    except ValueError:
        alt = None

    return NmeaPosition(
        latitude=lat,
        longitude=lon,
        altitude_m=alt,
        hdop=hdop,
        satellites=satellites,
        fix_quality=fix_quality,
        sentence_type="GGA",
        raw_sentence=raw_sentence,
    )


def parse_rmc(payload: str, raw_sentence: str) -> Optional[NmeaPosition]:
    """Mem-parsing isi payload kalimat RMC ($GPRMC, $GNRMC, dsb)."""
    fields = payload.split(",")
    if len(fields) < 7:
        return None

    # Status: 'A' = Valid, 'V' = Warning
    status = fields[2].strip().upper()
    if status != "A":
        return None

    lat = parse_nmea_coordinate(fields[3], fields[4])
    lon = parse_nmea_coordinate(fields[5], fields[6])
    if lat is None or lon is None:
        return None

    return NmeaPosition(
        latitude=lat,
        longitude=lon,
        altitude_m=None,
        hdop=None,
        satellites=None,
        fix_quality=GnssFixQuality.GPS_FIX,
        sentence_type="RMC",
        raw_sentence=raw_sentence,
    )


def parse_nmea_sentence(sentence: str) -> Optional[NmeaPosition]:
    """Fungsi utama untuk mem-parsing kalimat NMEA sembarang ($GPGGA, $GNGGA, $GPRMC, $GNRMC)."""
    is_valid, payload = verify_nmea_sentence(sentence)
    if not is_valid:
        return None

    type_code = payload.split(",", 1)[0].upper()
    if type_code.endswith("GGA"):
        return parse_gga(payload, sentence.strip())
    elif type_code.endswith("RMC"):
        return parse_rmc(payload, sentence.strip())

    return None
