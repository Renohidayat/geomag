import 'package:drift/drift.dart';
import 'devices.dart';

/// Tabel Survey sesuai ERD.
class Surveys extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text().references(Devices, #id)();
  TextColumn get name => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get mode => text()(); // 'rover' atau 'base'
  TextColumn get notes => text().nullable()();
  TextColumn get baseSurveyId => text().nullable().references(Surveys, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
