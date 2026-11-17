"""
Modul referensi Python untuk Tie-Line Crossover Levelling pada survei geomagnetik.

Algoritma:
1. Mendeteksi titik perpotongan (crossover points) antara lintasan survei (survey lines)
   dan lintasan pengikat (tie lines).
2. Menghitung crossover error: epsilon_k = B_survey(x_k, y_k) - B_tie(x_k, y_k).
3. Menyelesaikan sistem persamaan kuadrat terkecil teratur (regularized least squares):
   (G^T G + lambda * I) * c = G^T * epsilon
   untuk menentukan koreksi pergeseran DC (shift/bias) per lintasan.
4. Menerapkan koreksi untuk meratakan data dan meminimalkan residual corrugation antar lintasan.
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Tuple, Any
import numpy as np


@dataclass
class LinePoint:
    x: float
    y: float
    reading_nt: float
    station_id: Optional[str] = None


@dataclass
class SurveyLine:
    line_id: str
    line_type: str  # 'survey' atau 'tie'
    points: List[LinePoint] = field(default_factory=list)


@dataclass
class CrossoverPoint:
    survey_line_id: str
    tie_line_id: str
    x: float
    y: float
    b_survey_nt: float
    b_tie_nt: float
    error_nt: float  # b_survey - b_tie
    residual_nt: Optional[float] = None  # setelah koreksi


@dataclass
class LevellingResult:
    is_successful: bool
    crossover_count: int
    rmse_before_nt: float
    rmse_after_nt: float
    line_corrections: Dict[str, float]  # line_id -> nilai koreksi yang dikurangkan (nT)
    crossovers: List[CrossoverPoint]
    levelled_lines: List[SurveyLine]


def find_segment_intersection(
    p1: LinePoint, p2: LinePoint, q1: LinePoint, q2: LinePoint
) -> Optional[Tuple[float, float, float, float]]:
    """
    Mencari perpotongan antara segmen garis p1-p2 dan q1-q2.
    Mengembalikan (x, y, u, v) jika berpotongan di dalam segmen, atau None.
    """
    dx1 = p2.x - p1.x
    dy1 = p2.y - p1.y
    dx2 = q2.x - q1.x
    dy2 = q2.y - q1.y

    det = dx1 * dy2 - dy1 * dx2
    if abs(det) < 1e-12:
        return None  # Garis sejajar atau kolinier

    x_diff = q1.x - p1.x
    y_diff = q1.y - p1.y

    u = (x_diff * dy2 - y_diff * dx2) / det
    v = (x_diff * dy1 - y_diff * dx1) / det

    # Toleransi numerik kecil untuk titik batas segmen
    eps = 1e-6
    if -eps <= u <= 1.0 + eps and -eps <= v <= 1.0 + eps:
        u_clamped = max(0.0, min(1.0, u))
        v_clamped = max(0.0, min(1.0, v))
        x = p1.x + u_clamped * dx1
        y = p1.y + u_clamped * dy1
        return x, y, u_clamped, v_clamped

    return None


def calculate_crossovers(lines: List[SurveyLine]) -> List[CrossoverPoint]:
    """
    Mencari seluruh titik perpotongan antara lintasan bertipe 'survey' dan 'tie'.
    """
    survey_lines = [l for l in lines if l.line_type == "survey"]
    tie_lines = [l for l in lines if l.line_type == "tie"]

    crossovers: List[CrossoverPoint] = []

    for s_line in survey_lines:
        for t_line in tie_lines:
            s_pts = s_line.points
            t_pts = t_line.points

            for i in range(len(s_pts) - 1):
                p1, p2 = s_pts[i], s_pts[i + 1]
                for j in range(len(t_pts) - 1):
                    q1, q2 = t_pts[j], t_pts[j + 1]
                    res = find_segment_intersection(p1, p2, q1, q2)
                    if res is not None:
                        x, y, u, v = res
                        b_survey = p1.reading_nt + u * (p2.reading_nt - p1.reading_nt)
                        b_tie = q1.reading_nt + v * (q2.reading_nt - q1.reading_nt)
                        crossovers.append(
                            CrossoverPoint(
                                survey_line_id=s_line.line_id,
                                tie_line_id=t_line.line_id,
                                x=x,
                                y=y,
                                b_survey_nt=b_survey,
                                b_tie_nt=b_tie,
                                error_nt=b_survey - b_tie,
                            )
                        )

    return crossovers


def perform_tie_line_levelling(
    lines: List[SurveyLine],
    damping: float = 1e-4,
) -> LevellingResult:
    """
    Melakukan koreksi levelling kuadrat terkecil untuk menghitung bias per lintasan.

    Parameter:
    - lines: daftar SurveyLine ('survey' dan 'tie')
    - damping: parameter regularisasi Tikhonov untuk kestabilan matriks singular
    """
    crossovers = calculate_crossovers(lines)
    if not crossovers:
        # Tidak ada titik perpotongan, kembalikan data apa adanya
        return LevellingResult(
            is_successful=False,
            crossover_count=0,
            rmse_before_nt=0.0,
            rmse_after_nt=0.0,
            line_corrections={l.line_id: 0.0 for l in lines},
            crossovers=[],
            levelled_lines=lines,
        )

    # Identifikasi lintasan unik yang terlibat
    survey_line_ids = sorted(list(set(c.survey_line_id for c in crossovers)))
    tie_line_ids = sorted(list(set(c.tie_line_id for c in crossovers)))

    ns = len(survey_line_ids)
    nt = len(tie_line_ids)
    total_params = ns + nt

    s_idx_map = {lid: i for i, lid in enumerate(survey_line_ids)}
    t_idx_map = {lid: ns + i for i, lid in enumerate(tie_line_ids)}

    k = len(crossovers)
    G = np.zeros((k, total_params), dtype=np.float64)
    epsilon = np.zeros(k, dtype=np.float64)

    for row, c in enumerate(crossovers):
        s_col = s_idx_map[c.survey_line_id]
        t_col = t_idx_map[c.tie_line_id]
        G[row, s_col] = 1.0
        G[row, t_col] = -1.0
        epsilon[row] = c.error_nt

    # Selesaikan sistem normal: (G^T G + damping * I) c = G^T epsilon
    GTG = G.T @ G
    reg_matrix = GTG + damping * np.eye(total_params)
    GTe = G.T @ epsilon

    corrections_vector = np.linalg.solve(reg_matrix, GTe)

    corrections: Dict[str, float] = {}
    for lid, idx in s_idx_map.items():
        corrections[lid] = float(corrections_vector[idx])
    for lid, idx in t_idx_map.items():
        corrections[lid] = float(corrections_vector[idx])

    # Lengkapi lintasan yang tidak memiliki perpotongan (koreksi 0.0)
    for l in lines:
        if l.line_id not in corrections:
            corrections[l.line_id] = 0.0

    # Evaluasi RMSE sebelum dan setelah levelling
    sq_err_before = 0.0
    sq_err_after = 0.0

    updated_crossovers: List[CrossoverPoint] = []
    for c in crossovers:
        c_survey = corrections[c.survey_line_id]
        c_tie = corrections[c.tie_line_id]
        res = (c.b_survey_nt - c_survey) - (c.b_tie_nt - c_tie)

        sq_err_before += c.error_nt ** 2
        sq_err_after += res ** 2

        updated_crossovers.append(
            CrossoverPoint(
                survey_line_id=c.survey_line_id,
                tie_line_id=c.tie_line_id,
                x=c.x,
                y=c.y,
                b_survey_nt=c.b_survey_nt,
                b_tie_nt=c.b_tie_nt,
                error_nt=c.error_nt,
                residual_nt=float(res),
            )
        )

    rmse_before = float(np.sqrt(sq_err_before / k))
    rmse_after = float(np.sqrt(sq_err_after / k))

    # Terapkan koreksi ke semua titik lintasan
    levelled_lines: List[SurveyLine] = []
    for l in lines:
        corr = corrections.get(l.line_id, 0.0)
        new_pts = [
            LinePoint(
                x=p.x,
                y=p.y,
                reading_nt=p.reading_nt - corr,
                station_id=p.station_id,
            )
            for p in l.points
        ]
        levelled_lines.append(
            SurveyLine(
                line_id=l.line_id,
                line_type=l.line_type,
                points=new_pts,
            )
        )

    return LevellingResult(
        is_successful=True,
        crossover_count=k,
        rmse_before_nt=rmse_before,
        rmse_after_nt=rmse_after,
        line_corrections=corrections,
        crossovers=updated_crossovers,
        levelled_lines=levelled_lines,
    )
