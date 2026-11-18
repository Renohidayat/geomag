import 'package:drift/drift.dart';

/// Tabel Device sesuai ERD.
class Devices extends Table {
  TextColumn get id => text()();
  TextColumn get model => text()();
  TextColumn get androidVersion => text()();
  TextColumn get magnetometerChip => text()();
  RealColumn get noiseFloorNt => real().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
