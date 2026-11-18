import 'package:drift/drift.dart';
import 'devices.dart';

/// Tabel CalibrationProfile sesuai ERD.
class CalibrationProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text().references(Devices, #id)();
  DateTimeColumn get timestamp => dateTime()();

  // Vektor hard iron b (mikroTesla)
  RealColumn get hardIronBxMicroT => real()();
  RealColumn get hardIronByMicroT => real()();
  RealColumn get hardIronBzMicroT => real()();

  // Matriks A 3x3 (disimpan sebagai CSV 9 angka: a11,a12,a13,a21,a22,a23,a31,a32,a33)
  TextColumn get matrixA => text()();

  RealColumn get temperatureC => real().nullable()();
  BoolColumn get casingAttached => boolean().withDefault(const Constant(false))();
  RealColumn get residualNt => real()();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
