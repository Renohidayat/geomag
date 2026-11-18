import 'package:drift/drift.dart';
import 'stations.dart';

/// Tabel Anomaly sesuai ERD.
///
/// Anomali magnetik per stasiun (ΔT = B_obs - F_IGRF - koreksi harian).
/// Turunan yang boleh dihitung ulang dari data mentah.
class Anomalies extends Table {
  TextColumn get id => text()();
  TextColumn get stationId => text().unique().references(Stations, #id)();
  RealColumn get fIgrfNt => real().nullable()();
  RealColumn get diurnalCorrectionNt => real().nullable()();
  RealColumn get deltaTNt => real().nullable()();
  DateTimeColumn get calculatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
