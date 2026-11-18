import 'package:drift/drift.dart';
import 'stations.dart';

/// Tabel StationResult sesuai ERD.
///
/// Merupakan ringkasan stasiun (rata-rata, simpangan baku, keputusan diterima/ditolak).
/// Turunan dari Sample, boleh dihitung ulang.
class StationResults extends Table {
  TextColumn get id => text()();
  TextColumn get stationId => text().unique().references(Stations, #id)();
  RealColumn get totalFieldMeanNt => real()();
  RealColumn get totalFieldStdNt => real()();
  IntColumn get sampleCount => integer()();
  BoolColumn get isAccepted => boolean()();
  TextColumn get rejectionReason => text().nullable()();
  DateTimeColumn get calculatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
