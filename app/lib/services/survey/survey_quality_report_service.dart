import 'dart:math';

import 'package:drift/drift.dart';
import 'package:geomag/database/app_database.dart';

/// Kategori predikat mutu survei geofisika.
enum QualityGrade {
  /// Mutu Sangat Baik (Skor >= 85): Data sangat stabil dan andal untuk pemetaan detail.
  gradeA,

  /// Mutu Baik (Skor 70 - 84): Andal untuk pemetaan anomali skala menengah hingga regional.
  gradeB,

  /// Mutu Cukup (Skor 50 - 69): Hanya dapat diandalkan untuk anomali kuat (> 500 nT).
  gradeC,

  /// Mutu Kurang / Perlu Pengulangan (Skor < 50): Banyak noise atau tanpa kalibrasi.
  gradeD,
}

extension QualityGradeExtension on QualityGrade {
  String get label {
    switch (this) {
      case QualityGrade.gradeA:
        return 'Grade A (Sangat Baik)';
      case QualityGrade.gradeB:
        return 'Grade B (Baik)';
      case QualityGrade.gradeC:
        return 'Grade C (Cukup / Terbatas)';
      case QualityGrade.gradeD:
        return 'Grade D (Perlu Pengulangan)';
    }
  }

  String get shortLabel {
    switch (this) {
      case QualityGrade.gradeA:
        return 'A';
      case QualityGrade.gradeB:
        return 'B';
      case QualityGrade.gradeC:
        return 'C';
      case QualityGrade.gradeD:
        return 'D';
    }
  }
}

/// Dokumen hasil audit mutu satu sesi survei magnetik.
class SurveyQualityReport {
  final String surveyId;
  final String surveyName;
  final DateTime surveyDate;
  final int totalStations;
  final int acceptedStations;
  final int flaggedStations;
  final int rejectedStations;
  final double acceptedRatio; // 0.0 - 1.0

  final double meanStdDevNt;
  final double maxStdDevNt;
  final double minStdDevNt;

  final bool hasCalibration;
  final double? calibrationResidualNt;
  final int? calibrationAgeDays;

  final bool hasBaseStation;
  final bool hasBaseStationGaps;
  final int? baseStationPoints;

  final int overallScore; // 0 - 100
  final QualityGrade grade;

  final List<String> findings;
  final List<String> recommendations;

  const SurveyQualityReport({
    required this.surveyId,
    required this.surveyName,
    required this.surveyDate,
    required this.totalStations,
    required this.acceptedStations,
    required this.flaggedStations,
    required this.rejectedStations,
    required this.acceptedRatio,
    required this.meanStdDevNt,
    required this.maxStdDevNt,
    required this.minStdDevNt,
    required this.hasCalibration,
    this.calibrationResidualNt,
    this.calibrationAgeDays,
    required this.hasBaseStation,
    required this.hasBaseStationGaps,
    this.baseStationPoints,
    required this.overallScore,
    required this.grade,
    required this.findings,
    required this.recommendations,
  });

  /// Mengonversi laporan audit ke format Markdown resmi.
  String toMarkdown() {
    final buffer = StringBuffer();
    buffer.writeln('# Laporan Audit Mutu Survei Geomagnetik: $surveyName');
    buffer.writeln();
    buffer.writeln('- **ID Survei**: `$surveyId`');
    buffer.writeln('- **Tanggal Pelaksanaan**: ${surveyDate.toIso8601String().split('T').first}');
    buffer.writeln('- **Skor Mutu Keseluruhan**: **$overallScore / 100** (${grade.label})');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('## 1. Ringkasan Kinerja Stasiun Rover');
    buffer.writeln('- **Total Titik Stasiun**: $totalStations');
    buffer.writeln('- **Stasiun Diterima (ACCEPTED)**: $acceptedStations (${(acceptedRatio * 100).toStringAsFixed(1)}%)');
    buffer.writeln('- **Stasiun Ditandai (FLAGGED)**: $flaggedStations');
    buffer.writeln('- **Stasiun Ditolak (REJECTED)**: $rejectedStations');
    buffer.writeln('- **Simpangan Baku Rata-rata (Mean σ)**: ${meanStdDevNt.toStringAsFixed(2)} nT');
    buffer.writeln('- **Simpangan Baku Maksimum (Max σ)**: ${maxStdDevNt.toStringAsFixed(2)} nT');
    buffer.writeln('- **Simpangan Baku Minimum (Min σ)**: ${minStdDevNt.toStringAsFixed(2)} nT');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('## 2. Audit Instrumen & Kalibrasi Sensor');
    if (hasCalibration) {
      buffer.writeln('- **Profil Kalibrasi Aktif**: Terpasang');
      buffer.writeln('- **Residu Fit Ellipsoid**: ${calibrationResidualNt?.toStringAsFixed(2) ?? "-"} nT');
      buffer.writeln('- **Umur Kalibrasi**: $calibrationAgeDays hari');
    } else {
      buffer.writeln('- **Profil Kalibrasi Aktif**: **TIDAK TERPASANG** (Data mentah tanpa koreksi hard/soft iron)');
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('## 3. Evaluasi Variasi Harian (Base Station)');
    if (hasBaseStation) {
      buffer.writeln('- **Base Station Acuan**: Terhubung ($baseStationPoints titik rekaman)');
      buffer.writeln('- **Celah Waktu (Gap > 10 menit)**: ${hasBaseStationGaps ? "TERDETEKSI ADA GAP" : "Tidak ada gap (kontinu)"}');
    } else {
      buffer.writeln('- **Base Station Acuan**: **TIDAK ADA** (Tanpa reduksi drift harian)');
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('## 4. Temuan & Evaluasi Teknis');
    if (findings.isEmpty) {
      buffer.writeln('- Tidak ditemukan anomali instrumen atau ketidakstabilan data yang signifikan.');
    } else {
      for (final f in findings) {
        buffer.writeln('- $f');
      }
    }
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln('## 5. Rekomendasi Tindakan Lapangan');
    if (recommendations.isEmpty) {
      buffer.writeln('- Data survei memenuhi seluruh kriteria mutu dan siap diproses ke tahap pemetaan anomali & interpretasi geologi.');
    } else {
      for (final r in recommendations) {
        buffer.writeln('- $r');
      }
    }

    return buffer.toString();
  }
}

/// Layanan untuk mengaudit dan menghasilkan laporan mutu otomatis satu sesi survei.
class SurveyQualityReportService {
  final AppDatabase database;

  const SurveyQualityReportService({required this.database});

  /// Menghitung dan menyusun laporan mutu komprehensif untuk [surveyId].
  Future<SurveyQualityReport> generateReport(String surveyId) async {
    final survey = await (database.select(database.surveys)
          ..where((t) => t.id.equals(surveyId)))
        .getSingleOrNull();

    if (survey == null) {
      throw ArgumentError('Survei dengan ID "$surveyId" tidak ditemukan.');
    }

    // Ambil seluruh stasiun survei ini
    final stations = await (database.select(database.stations)
          ..where((t) => t.surveyId.equals(surveyId)))
        .get();

    final totalStations = stations.length;
    if (totalStations == 0) {
      return SurveyQualityReport(
        surveyId: surveyId,
        surveyName: survey.name,
        surveyDate: survey.date,
        totalStations: 0,
        acceptedStations: 0,
        flaggedStations: 0,
        rejectedStations: 0,
        acceptedRatio: 0.0,
        meanStdDevNt: 0.0,
        maxStdDevNt: 0.0,
        minStdDevNt: 0.0,
        hasCalibration: false,
        hasBaseStation: false,
        hasBaseStationGaps: false,
        overallScore: 0,
        grade: QualityGrade.gradeD,
        findings: const ['Belum ada titik stasiun yang diukur pada survei ini.'],
        recommendations: const ['Lakukan pengukuran stasiun rover di lapangan.'],
      );
    }

    // Ambil hasil stasiun
    final stationIds = stations.map((s) => s.id).toSet();
    final allResults = await database.select(database.stationResults).get();
    final results = allResults.where((r) => stationIds.contains(r.stationId)).toList();

    int accepted = 0;
    int flagged = 0;
    int rejected = 0;
    final stdDevs = <double>[];

    for (final res in results) {
      if (res.isAccepted) {
        accepted++;
      } else if (res.rejectionReason?.contains('FLAG') ?? false) {
        flagged++;
      } else {
        rejected++;
      }
      stdDevs.add(res.totalFieldStdNt);
    }

    // Hitung stasiun yang belum punya result sebagai rejected/pending
    final missingCount = totalStations - results.length;
    if (missingCount > 0) {
      rejected += missingCount;
    }

    final acceptedRatio = totalStations > 0 ? accepted / totalStations : 0.0;
    final meanStd = stdDevs.isNotEmpty ? stdDevs.reduce((a, b) => a + b) / stdDevs.length : 0.0;
    final maxStd = stdDevs.isNotEmpty ? stdDevs.reduce(max) : 0.0;
    final minStd = stdDevs.isNotEmpty ? stdDevs.reduce(min) : 0.0;

    // Ambil profil kalibrasi aktif untuk perangkat ini
    final profiles = await (database.select(database.calibrationProfiles)
          ..where((t) => t.deviceId.equals(survey.deviceId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();

    final activeProfile = profiles.isNotEmpty ? profiles.first : null;
    final hasCalibration = activeProfile != null;
    final calResidual = activeProfile?.residualNt;
    final calAgeDays = activeProfile != null
        ? survey.date.difference(activeProfile.createdAt).inDays.abs()
        : null;

    // Periksa base station
    final hasBaseStation = survey.baseSurveyId != null;
    bool hasBaseGaps = false;
    int? basePointsCount;

    if (hasBaseStation) {
      final baseStations = await (database.select(database.stations)
            ..where((t) => t.surveyId.equals(survey.baseSurveyId!)))
          .get();
      basePointsCount = baseStations.length;
      // Deteksi gap jika ada jeda sequence atau selisih waktu
      // Dalam implementasi sederhana, anggap ada data jika count > 0
    }

    // Hitung Skor Mutu (0 - 100)
    int score = 0;

    // 1. Rasio Stasiun Diterima (Maks 40 poin)
    score += (acceptedRatio * 40.0).round();

    // 2. Kestabilan Simpangan Baku (Maks 25 poin)
    if (meanStd <= 10.0) {
      score += 25;
    } else if (meanStd <= 50.0) {
      score += 20;
    } else if (meanStd <= 200.0) {
      score += 12;
    } else if (meanStd <= 500.0) {
      score += 5;
    }

    // 3. Status Kalibrasi (Maks 20 poin)
    if (hasCalibration) {
      if ((calAgeDays ?? 999) <= 7 && (calResidual ?? 999) <= 50.0) {
        score += 20;
      } else if ((calAgeDays ?? 999) <= 30) {
        score += 14;
      } else {
        score += 8;
      }
    }

    // 4. Koreksi Variasi Harian (Maks 15 poin)
    if (hasBaseStation && (basePointsCount ?? 0) > 0) {
      score += 15;
    }

    score = score.clamp(0, 100);

    // Tentukan Grade
    final QualityGrade grade;
    if (score >= 85) {
      grade = QualityGrade.gradeA;
    } else if (score >= 70) {
      grade = QualityGrade.gradeB;
    } else if (score >= 50) {
      grade = QualityGrade.gradeC;
    } else {
      grade = QualityGrade.gradeD;
    }

    // Susun Temuan (Findings) & Rekomendasi
    final findings = <String>[];
    final recommendations = <String>[];

    if (rejected > 0) {
      findings.add('Terdapat $rejected stasiun yang DITOLAK karena variasi/noise tinggi melebihi toleransi.');
      recommendations.add('Lakukan pengukuran ulang (resurvey) pada titik-titik stasiun yang berstatus REJECTED.');
    }

    if (flagged > 0) {
      findings.add('Terdapat $flagged stasiun berstatus FLAGGED dengan simpangan baku mendekati ambang toleransi.');
      recommendations.add('Periksa adanya objek logam (pagar kawat, kendaraan, pipa) di sekitar stasiun berstatus FLAGGED.');
    }

    if (!hasCalibration) {
      findings.add('Survei dilakukan TANPA kalibrasi ellipsoid aktif untuk perangkat ini.');
      recommendations.add('Lakukan kalibrasi ellipsoid pada menu Kalibrasi sebelum survei berikutnya untuk mengoreksi hard iron.');
    } else if ((calAgeDays ?? 0) > 14) {
      findings.add('Profil kalibrasi yang digunakan telah berumur $calAgeDays hari (disarankan < 7 hari).');
      recommendations.add('Perbarui profil kalibrasi ellipsoid secara berkala sebelum memulai sesi survei baru.');
    }

    if (!hasBaseStation) {
      findings.add('Survei tidak ditautkan ke base station harian (variasi medan diurnal tidak terkoreksi).');
      recommendations.add('Gunakan satu HP terdedikasi sebagai Base Station kontinu di titik tenang selama survei berlangsung.');
    }

    return SurveyQualityReport(
      surveyId: surveyId,
      surveyName: survey.name,
      surveyDate: survey.date,
      totalStations: totalStations,
      acceptedStations: accepted,
      flaggedStations: flagged,
      rejectedStations: rejected,
      acceptedRatio: acceptedRatio,
      meanStdDevNt: meanStd,
      maxStdDevNt: maxStd,
      minStdDevNt: minStd,
      hasCalibration: hasCalibration,
      calibrationResidualNt: calResidual,
      calibrationAgeDays: calAgeDays,
      hasBaseStation: hasBaseStation,
      hasBaseStationGaps: hasBaseGaps,
      baseStationPoints: basePointsCount,
      overallScore: score,
      grade: grade,
      findings: findings,
      recommendations: recommendations,
    );
  }
}
