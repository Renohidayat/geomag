import 'package:drift/drift.dart';
import 'surveys.dart';

/// Tabel Station sesuai ERD.
class Stations extends Table {
  TextColumn get id => text()();
  TextColumn get surveyId => text().references(Surveys, #id)();
  IntColumn get sequenceNumber => integer()();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  RealColumn get gpsAccuracyM => real().nullable()();
  RealColumn get localX => real().nullable()();
  RealColumn get localY => real().nullable()();
  RealColumn get sensorHeightM => real().nullable()();
  RealColumn get holdingDirectionDeg => real().nullable()();
  TextColumn get environmentNotes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
