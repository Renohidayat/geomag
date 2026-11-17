import 'package:drift/drift.dart';
import 'calibration_profiles.dart';
import 'stations.dart';

/// Tabel Sample sesuai ERD.
///
/// PERINGATAN: Tabel ini bersifat APPEND-ONLY.
/// Tidak boleh ada operasi UPDATE atau DELETE pada data sampel.
class Samples extends Table {
  TextColumn get id => text()();
  TextColumn get stationId => text().references(Stations, #id)();
  TextColumn get calibrationId =>
      text().nullable().references(CalibrationProfiles, #id)();

  /// Timestamp event dari Android hardware sensor (nanodetik).
  Int64Column get timestampNs => int64()();

  /// Medan mentah x, y, z dalam mikroTesla.
  RealColumn get rawXMicroT => real()();
  RealColumn get rawYMicroT => real()();
  RealColumn get rawZMicroT => real()();

  /// Estimasi bias hard iron OS x, y, z dalam mikroTesla.
  RealColumn get biasXMicroT => real()();
  RealColumn get biasYMicroT => real()();
  RealColumn get biasZMicroT => real()();

  /// Akurasi sensor Android (0–3).
  IntColumn get accuracy => integer()();

  /// Apakah dibaca dari TYPE_MAGNETIC_FIELD_UNCALIBRATED.
  BoolColumn get isUncalibrated => boolean()();

  /// Suhu baterai (°C) sebagai proksi suhu perangkat.
  RealColumn get batteryTempC => real()();

  /// Status charging saat sampel diambil.
  BoolColumn get isCharging => boolean()();

  /// Status layar menyala saat sampel diambil.
  BoolColumn get isScreenOn => boolean()();

  /// Waktu penyimpanan ke database.
  DateTimeColumn get recordedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
