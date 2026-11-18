// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DevicesTable extends Devices with TableInfo<$DevicesTable, Device> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _androidVersionMeta = const VerificationMeta(
    'androidVersion',
  );
  @override
  late final GeneratedColumn<String> androidVersion = GeneratedColumn<String>(
    'android_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _magnetometerChipMeta = const VerificationMeta(
    'magnetometerChip',
  );
  @override
  late final GeneratedColumn<String> magnetometerChip = GeneratedColumn<String>(
    'magnetometer_chip',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noiseFloorNtMeta = const VerificationMeta(
    'noiseFloorNt',
  );
  @override
  late final GeneratedColumn<double> noiseFloorNt = GeneratedColumn<double>(
    'noise_floor_nt',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    model,
    androidVersion,
    magnetometerChip,
    noiseFloorNt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<Device> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('android_version')) {
      context.handle(
        _androidVersionMeta,
        androidVersion.isAcceptableOrUnknown(
          data['android_version']!,
          _androidVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_androidVersionMeta);
    }
    if (data.containsKey('magnetometer_chip')) {
      context.handle(
        _magnetometerChipMeta,
        magnetometerChip.isAcceptableOrUnknown(
          data['magnetometer_chip']!,
          _magnetometerChipMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_magnetometerChipMeta);
    }
    if (data.containsKey('noise_floor_nt')) {
      context.handle(
        _noiseFloorNtMeta,
        noiseFloorNt.isAcceptableOrUnknown(
          data['noise_floor_nt']!,
          _noiseFloorNtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Device map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Device(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      androidVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}android_version'],
      )!,
      magnetometerChip: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}magnetometer_chip'],
      )!,
      noiseFloorNt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}noise_floor_nt'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DevicesTable createAlias(String alias) {
    return $DevicesTable(attachedDatabase, alias);
  }
}

class Device extends DataClass implements Insertable<Device> {
  final String id;
  final String model;
  final String androidVersion;
  final String magnetometerChip;
  final double? noiseFloorNt;
  final DateTime createdAt;
  const Device({
    required this.id,
    required this.model,
    required this.androidVersion,
    required this.magnetometerChip,
    this.noiseFloorNt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['model'] = Variable<String>(model);
    map['android_version'] = Variable<String>(androidVersion);
    map['magnetometer_chip'] = Variable<String>(magnetometerChip);
    if (!nullToAbsent || noiseFloorNt != null) {
      map['noise_floor_nt'] = Variable<double>(noiseFloorNt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DevicesCompanion toCompanion(bool nullToAbsent) {
    return DevicesCompanion(
      id: Value(id),
      model: Value(model),
      androidVersion: Value(androidVersion),
      magnetometerChip: Value(magnetometerChip),
      noiseFloorNt: noiseFloorNt == null && nullToAbsent
          ? const Value.absent()
          : Value(noiseFloorNt),
      createdAt: Value(createdAt),
    );
  }

  factory Device.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Device(
      id: serializer.fromJson<String>(json['id']),
      model: serializer.fromJson<String>(json['model']),
      androidVersion: serializer.fromJson<String>(json['androidVersion']),
      magnetometerChip: serializer.fromJson<String>(json['magnetometerChip']),
      noiseFloorNt: serializer.fromJson<double?>(json['noiseFloorNt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'model': serializer.toJson<String>(model),
      'androidVersion': serializer.toJson<String>(androidVersion),
      'magnetometerChip': serializer.toJson<String>(magnetometerChip),
      'noiseFloorNt': serializer.toJson<double?>(noiseFloorNt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Device copyWith({
    String? id,
    String? model,
    String? androidVersion,
    String? magnetometerChip,
    Value<double?> noiseFloorNt = const Value.absent(),
    DateTime? createdAt,
  }) => Device(
    id: id ?? this.id,
    model: model ?? this.model,
    androidVersion: androidVersion ?? this.androidVersion,
    magnetometerChip: magnetometerChip ?? this.magnetometerChip,
    noiseFloorNt: noiseFloorNt.present ? noiseFloorNt.value : this.noiseFloorNt,
    createdAt: createdAt ?? this.createdAt,
  );
  Device copyWithCompanion(DevicesCompanion data) {
    return Device(
      id: data.id.present ? data.id.value : this.id,
      model: data.model.present ? data.model.value : this.model,
      androidVersion: data.androidVersion.present
          ? data.androidVersion.value
          : this.androidVersion,
      magnetometerChip: data.magnetometerChip.present
          ? data.magnetometerChip.value
          : this.magnetometerChip,
      noiseFloorNt: data.noiseFloorNt.present
          ? data.noiseFloorNt.value
          : this.noiseFloorNt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Device(')
          ..write('id: $id, ')
          ..write('model: $model, ')
          ..write('androidVersion: $androidVersion, ')
          ..write('magnetometerChip: $magnetometerChip, ')
          ..write('noiseFloorNt: $noiseFloorNt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    model,
    androidVersion,
    magnetometerChip,
    noiseFloorNt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Device &&
          other.id == this.id &&
          other.model == this.model &&
          other.androidVersion == this.androidVersion &&
          other.magnetometerChip == this.magnetometerChip &&
          other.noiseFloorNt == this.noiseFloorNt &&
          other.createdAt == this.createdAt);
}

class DevicesCompanion extends UpdateCompanion<Device> {
  final Value<String> id;
  final Value<String> model;
  final Value<String> androidVersion;
  final Value<String> magnetometerChip;
  final Value<double?> noiseFloorNt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DevicesCompanion({
    this.id = const Value.absent(),
    this.model = const Value.absent(),
    this.androidVersion = const Value.absent(),
    this.magnetometerChip = const Value.absent(),
    this.noiseFloorNt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DevicesCompanion.insert({
    required String id,
    required String model,
    required String androidVersion,
    required String magnetometerChip,
    this.noiseFloorNt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       model = Value(model),
       androidVersion = Value(androidVersion),
       magnetometerChip = Value(magnetometerChip);
  static Insertable<Device> custom({
    Expression<String>? id,
    Expression<String>? model,
    Expression<String>? androidVersion,
    Expression<String>? magnetometerChip,
    Expression<double>? noiseFloorNt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (model != null) 'model': model,
      if (androidVersion != null) 'android_version': androidVersion,
      if (magnetometerChip != null) 'magnetometer_chip': magnetometerChip,
      if (noiseFloorNt != null) 'noise_floor_nt': noiseFloorNt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? model,
    Value<String>? androidVersion,
    Value<String>? magnetometerChip,
    Value<double?>? noiseFloorNt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DevicesCompanion(
      id: id ?? this.id,
      model: model ?? this.model,
      androidVersion: androidVersion ?? this.androidVersion,
      magnetometerChip: magnetometerChip ?? this.magnetometerChip,
      noiseFloorNt: noiseFloorNt ?? this.noiseFloorNt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (androidVersion.present) {
      map['android_version'] = Variable<String>(androidVersion.value);
    }
    if (magnetometerChip.present) {
      map['magnetometer_chip'] = Variable<String>(magnetometerChip.value);
    }
    if (noiseFloorNt.present) {
      map['noise_floor_nt'] = Variable<double>(noiseFloorNt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DevicesCompanion(')
          ..write('id: $id, ')
          ..write('model: $model, ')
          ..write('androidVersion: $androidVersion, ')
          ..write('magnetometerChip: $magnetometerChip, ')
          ..write('noiseFloorNt: $noiseFloorNt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CalibrationProfilesTable extends CalibrationProfiles
    with TableInfo<$CalibrationProfilesTable, CalibrationProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CalibrationProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hardIronBxMicroTMeta = const VerificationMeta(
    'hardIronBxMicroT',
  );
  @override
  late final GeneratedColumn<double> hardIronBxMicroT = GeneratedColumn<double>(
    'hard_iron_bx_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hardIronByMicroTMeta = const VerificationMeta(
    'hardIronByMicroT',
  );
  @override
  late final GeneratedColumn<double> hardIronByMicroT = GeneratedColumn<double>(
    'hard_iron_by_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hardIronBzMicroTMeta = const VerificationMeta(
    'hardIronBzMicroT',
  );
  @override
  late final GeneratedColumn<double> hardIronBzMicroT = GeneratedColumn<double>(
    'hard_iron_bz_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _matrixAMeta = const VerificationMeta(
    'matrixA',
  );
  @override
  late final GeneratedColumn<String> matrixA = GeneratedColumn<String>(
    'matrix_a',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temperatureCMeta = const VerificationMeta(
    'temperatureC',
  );
  @override
  late final GeneratedColumn<double> temperatureC = GeneratedColumn<double>(
    'temperature_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _casingAttachedMeta = const VerificationMeta(
    'casingAttached',
  );
  @override
  late final GeneratedColumn<bool> casingAttached = GeneratedColumn<bool>(
    'casing_attached',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("casing_attached" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _residualNtMeta = const VerificationMeta(
    'residualNt',
  );
  @override
  late final GeneratedColumn<double> residualNt = GeneratedColumn<double>(
    'residual_nt',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    timestamp,
    hardIronBxMicroT,
    hardIronByMicroT,
    hardIronBzMicroT,
    matrixA,
    temperatureC,
    casingAttached,
    residualNt,
    expiresAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'calibration_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CalibrationProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('hard_iron_bx_micro_t')) {
      context.handle(
        _hardIronBxMicroTMeta,
        hardIronBxMicroT.isAcceptableOrUnknown(
          data['hard_iron_bx_micro_t']!,
          _hardIronBxMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hardIronBxMicroTMeta);
    }
    if (data.containsKey('hard_iron_by_micro_t')) {
      context.handle(
        _hardIronByMicroTMeta,
        hardIronByMicroT.isAcceptableOrUnknown(
          data['hard_iron_by_micro_t']!,
          _hardIronByMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hardIronByMicroTMeta);
    }
    if (data.containsKey('hard_iron_bz_micro_t')) {
      context.handle(
        _hardIronBzMicroTMeta,
        hardIronBzMicroT.isAcceptableOrUnknown(
          data['hard_iron_bz_micro_t']!,
          _hardIronBzMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_hardIronBzMicroTMeta);
    }
    if (data.containsKey('matrix_a')) {
      context.handle(
        _matrixAMeta,
        matrixA.isAcceptableOrUnknown(data['matrix_a']!, _matrixAMeta),
      );
    } else if (isInserting) {
      context.missing(_matrixAMeta);
    }
    if (data.containsKey('temperature_c')) {
      context.handle(
        _temperatureCMeta,
        temperatureC.isAcceptableOrUnknown(
          data['temperature_c']!,
          _temperatureCMeta,
        ),
      );
    }
    if (data.containsKey('casing_attached')) {
      context.handle(
        _casingAttachedMeta,
        casingAttached.isAcceptableOrUnknown(
          data['casing_attached']!,
          _casingAttachedMeta,
        ),
      );
    }
    if (data.containsKey('residual_nt')) {
      context.handle(
        _residualNtMeta,
        residualNt.isAcceptableOrUnknown(data['residual_nt']!, _residualNtMeta),
      );
    } else if (isInserting) {
      context.missing(_residualNtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CalibrationProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CalibrationProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      hardIronBxMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hard_iron_bx_micro_t'],
      )!,
      hardIronByMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hard_iron_by_micro_t'],
      )!,
      hardIronBzMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hard_iron_bz_micro_t'],
      )!,
      matrixA: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}matrix_a'],
      )!,
      temperatureC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature_c'],
      ),
      casingAttached: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}casing_attached'],
      )!,
      residualNt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}residual_nt'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CalibrationProfilesTable createAlias(String alias) {
    return $CalibrationProfilesTable(attachedDatabase, alias);
  }
}

class CalibrationProfile extends DataClass
    implements Insertable<CalibrationProfile> {
  final String id;
  final String deviceId;
  final DateTime timestamp;
  final double hardIronBxMicroT;
  final double hardIronByMicroT;
  final double hardIronBzMicroT;
  final String matrixA;
  final double? temperatureC;
  final bool casingAttached;
  final double residualNt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  const CalibrationProfile({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.hardIronBxMicroT,
    required this.hardIronByMicroT,
    required this.hardIronBzMicroT,
    required this.matrixA,
    this.temperatureC,
    required this.casingAttached,
    required this.residualNt,
    this.expiresAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['hard_iron_bx_micro_t'] = Variable<double>(hardIronBxMicroT);
    map['hard_iron_by_micro_t'] = Variable<double>(hardIronByMicroT);
    map['hard_iron_bz_micro_t'] = Variable<double>(hardIronBzMicroT);
    map['matrix_a'] = Variable<String>(matrixA);
    if (!nullToAbsent || temperatureC != null) {
      map['temperature_c'] = Variable<double>(temperatureC);
    }
    map['casing_attached'] = Variable<bool>(casingAttached);
    map['residual_nt'] = Variable<double>(residualNt);
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CalibrationProfilesCompanion toCompanion(bool nullToAbsent) {
    return CalibrationProfilesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      timestamp: Value(timestamp),
      hardIronBxMicroT: Value(hardIronBxMicroT),
      hardIronByMicroT: Value(hardIronByMicroT),
      hardIronBzMicroT: Value(hardIronBzMicroT),
      matrixA: Value(matrixA),
      temperatureC: temperatureC == null && nullToAbsent
          ? const Value.absent()
          : Value(temperatureC),
      casingAttached: Value(casingAttached),
      residualNt: Value(residualNt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      createdAt: Value(createdAt),
    );
  }

  factory CalibrationProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CalibrationProfile(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      hardIronBxMicroT: serializer.fromJson<double>(json['hardIronBxMicroT']),
      hardIronByMicroT: serializer.fromJson<double>(json['hardIronByMicroT']),
      hardIronBzMicroT: serializer.fromJson<double>(json['hardIronBzMicroT']),
      matrixA: serializer.fromJson<String>(json['matrixA']),
      temperatureC: serializer.fromJson<double?>(json['temperatureC']),
      casingAttached: serializer.fromJson<bool>(json['casingAttached']),
      residualNt: serializer.fromJson<double>(json['residualNt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'hardIronBxMicroT': serializer.toJson<double>(hardIronBxMicroT),
      'hardIronByMicroT': serializer.toJson<double>(hardIronByMicroT),
      'hardIronBzMicroT': serializer.toJson<double>(hardIronBzMicroT),
      'matrixA': serializer.toJson<String>(matrixA),
      'temperatureC': serializer.toJson<double?>(temperatureC),
      'casingAttached': serializer.toJson<bool>(casingAttached),
      'residualNt': serializer.toJson<double>(residualNt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CalibrationProfile copyWith({
    String? id,
    String? deviceId,
    DateTime? timestamp,
    double? hardIronBxMicroT,
    double? hardIronByMicroT,
    double? hardIronBzMicroT,
    String? matrixA,
    Value<double?> temperatureC = const Value.absent(),
    bool? casingAttached,
    double? residualNt,
    Value<DateTime?> expiresAt = const Value.absent(),
    DateTime? createdAt,
  }) => CalibrationProfile(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    timestamp: timestamp ?? this.timestamp,
    hardIronBxMicroT: hardIronBxMicroT ?? this.hardIronBxMicroT,
    hardIronByMicroT: hardIronByMicroT ?? this.hardIronByMicroT,
    hardIronBzMicroT: hardIronBzMicroT ?? this.hardIronBzMicroT,
    matrixA: matrixA ?? this.matrixA,
    temperatureC: temperatureC.present ? temperatureC.value : this.temperatureC,
    casingAttached: casingAttached ?? this.casingAttached,
    residualNt: residualNt ?? this.residualNt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    createdAt: createdAt ?? this.createdAt,
  );
  CalibrationProfile copyWithCompanion(CalibrationProfilesCompanion data) {
    return CalibrationProfile(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      hardIronBxMicroT: data.hardIronBxMicroT.present
          ? data.hardIronBxMicroT.value
          : this.hardIronBxMicroT,
      hardIronByMicroT: data.hardIronByMicroT.present
          ? data.hardIronByMicroT.value
          : this.hardIronByMicroT,
      hardIronBzMicroT: data.hardIronBzMicroT.present
          ? data.hardIronBzMicroT.value
          : this.hardIronBzMicroT,
      matrixA: data.matrixA.present ? data.matrixA.value : this.matrixA,
      temperatureC: data.temperatureC.present
          ? data.temperatureC.value
          : this.temperatureC,
      casingAttached: data.casingAttached.present
          ? data.casingAttached.value
          : this.casingAttached,
      residualNt: data.residualNt.present
          ? data.residualNt.value
          : this.residualNt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationProfile(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('timestamp: $timestamp, ')
          ..write('hardIronBxMicroT: $hardIronBxMicroT, ')
          ..write('hardIronByMicroT: $hardIronByMicroT, ')
          ..write('hardIronBzMicroT: $hardIronBzMicroT, ')
          ..write('matrixA: $matrixA, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('casingAttached: $casingAttached, ')
          ..write('residualNt: $residualNt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    timestamp,
    hardIronBxMicroT,
    hardIronByMicroT,
    hardIronBzMicroT,
    matrixA,
    temperatureC,
    casingAttached,
    residualNt,
    expiresAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CalibrationProfile &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.timestamp == this.timestamp &&
          other.hardIronBxMicroT == this.hardIronBxMicroT &&
          other.hardIronByMicroT == this.hardIronByMicroT &&
          other.hardIronBzMicroT == this.hardIronBzMicroT &&
          other.matrixA == this.matrixA &&
          other.temperatureC == this.temperatureC &&
          other.casingAttached == this.casingAttached &&
          other.residualNt == this.residualNt &&
          other.expiresAt == this.expiresAt &&
          other.createdAt == this.createdAt);
}

class CalibrationProfilesCompanion extends UpdateCompanion<CalibrationProfile> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<DateTime> timestamp;
  final Value<double> hardIronBxMicroT;
  final Value<double> hardIronByMicroT;
  final Value<double> hardIronBzMicroT;
  final Value<String> matrixA;
  final Value<double?> temperatureC;
  final Value<bool> casingAttached;
  final Value<double> residualNt;
  final Value<DateTime?> expiresAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CalibrationProfilesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.hardIronBxMicroT = const Value.absent(),
    this.hardIronByMicroT = const Value.absent(),
    this.hardIronBzMicroT = const Value.absent(),
    this.matrixA = const Value.absent(),
    this.temperatureC = const Value.absent(),
    this.casingAttached = const Value.absent(),
    this.residualNt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CalibrationProfilesCompanion.insert({
    required String id,
    required String deviceId,
    required DateTime timestamp,
    required double hardIronBxMicroT,
    required double hardIronByMicroT,
    required double hardIronBzMicroT,
    required String matrixA,
    this.temperatureC = const Value.absent(),
    this.casingAttached = const Value.absent(),
    required double residualNt,
    this.expiresAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       timestamp = Value(timestamp),
       hardIronBxMicroT = Value(hardIronBxMicroT),
       hardIronByMicroT = Value(hardIronByMicroT),
       hardIronBzMicroT = Value(hardIronBzMicroT),
       matrixA = Value(matrixA),
       residualNt = Value(residualNt);
  static Insertable<CalibrationProfile> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<DateTime>? timestamp,
    Expression<double>? hardIronBxMicroT,
    Expression<double>? hardIronByMicroT,
    Expression<double>? hardIronBzMicroT,
    Expression<String>? matrixA,
    Expression<double>? temperatureC,
    Expression<bool>? casingAttached,
    Expression<double>? residualNt,
    Expression<DateTime>? expiresAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (timestamp != null) 'timestamp': timestamp,
      if (hardIronBxMicroT != null) 'hard_iron_bx_micro_t': hardIronBxMicroT,
      if (hardIronByMicroT != null) 'hard_iron_by_micro_t': hardIronByMicroT,
      if (hardIronBzMicroT != null) 'hard_iron_bz_micro_t': hardIronBzMicroT,
      if (matrixA != null) 'matrix_a': matrixA,
      if (temperatureC != null) 'temperature_c': temperatureC,
      if (casingAttached != null) 'casing_attached': casingAttached,
      if (residualNt != null) 'residual_nt': residualNt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CalibrationProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<DateTime>? timestamp,
    Value<double>? hardIronBxMicroT,
    Value<double>? hardIronByMicroT,
    Value<double>? hardIronBzMicroT,
    Value<String>? matrixA,
    Value<double?>? temperatureC,
    Value<bool>? casingAttached,
    Value<double>? residualNt,
    Value<DateTime?>? expiresAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CalibrationProfilesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      timestamp: timestamp ?? this.timestamp,
      hardIronBxMicroT: hardIronBxMicroT ?? this.hardIronBxMicroT,
      hardIronByMicroT: hardIronByMicroT ?? this.hardIronByMicroT,
      hardIronBzMicroT: hardIronBzMicroT ?? this.hardIronBzMicroT,
      matrixA: matrixA ?? this.matrixA,
      temperatureC: temperatureC ?? this.temperatureC,
      casingAttached: casingAttached ?? this.casingAttached,
      residualNt: residualNt ?? this.residualNt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (hardIronBxMicroT.present) {
      map['hard_iron_bx_micro_t'] = Variable<double>(hardIronBxMicroT.value);
    }
    if (hardIronByMicroT.present) {
      map['hard_iron_by_micro_t'] = Variable<double>(hardIronByMicroT.value);
    }
    if (hardIronBzMicroT.present) {
      map['hard_iron_bz_micro_t'] = Variable<double>(hardIronBzMicroT.value);
    }
    if (matrixA.present) {
      map['matrix_a'] = Variable<String>(matrixA.value);
    }
    if (temperatureC.present) {
      map['temperature_c'] = Variable<double>(temperatureC.value);
    }
    if (casingAttached.present) {
      map['casing_attached'] = Variable<bool>(casingAttached.value);
    }
    if (residualNt.present) {
      map['residual_nt'] = Variable<double>(residualNt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CalibrationProfilesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('timestamp: $timestamp, ')
          ..write('hardIronBxMicroT: $hardIronBxMicroT, ')
          ..write('hardIronByMicroT: $hardIronByMicroT, ')
          ..write('hardIronBzMicroT: $hardIronBzMicroT, ')
          ..write('matrixA: $matrixA, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('casingAttached: $casingAttached, ')
          ..write('residualNt: $residualNt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SurveysTable extends Surveys with TableInfo<$SurveysTable, Survey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurveysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES devices (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseSurveyIdMeta = const VerificationMeta(
    'baseSurveyId',
  );
  @override
  late final GeneratedColumn<String> baseSurveyId = GeneratedColumn<String>(
    'base_survey_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES surveys (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    name,
    date,
    mode,
    notes,
    baseSurveyId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'surveys';
  @override
  VerificationContext validateIntegrity(
    Insertable<Survey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('base_survey_id')) {
      context.handle(
        _baseSurveyIdMeta,
        baseSurveyId.isAcceptableOrUnknown(
          data['base_survey_id']!,
          _baseSurveyIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Survey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Survey(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      baseSurveyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_survey_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SurveysTable createAlias(String alias) {
    return $SurveysTable(attachedDatabase, alias);
  }
}

class Survey extends DataClass implements Insertable<Survey> {
  final String id;
  final String deviceId;
  final String name;
  final DateTime date;
  final String mode;
  final String? notes;
  final String? baseSurveyId;
  final DateTime createdAt;
  const Survey({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.date,
    required this.mode,
    this.notes,
    this.baseSurveyId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['name'] = Variable<String>(name);
    map['date'] = Variable<DateTime>(date);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || baseSurveyId != null) {
      map['base_survey_id'] = Variable<String>(baseSurveyId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SurveysCompanion toCompanion(bool nullToAbsent) {
    return SurveysCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      name: Value(name),
      date: Value(date),
      mode: Value(mode),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      baseSurveyId: baseSurveyId == null && nullToAbsent
          ? const Value.absent()
          : Value(baseSurveyId),
      createdAt: Value(createdAt),
    );
  }

  factory Survey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Survey(
      id: serializer.fromJson<String>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      name: serializer.fromJson<String>(json['name']),
      date: serializer.fromJson<DateTime>(json['date']),
      mode: serializer.fromJson<String>(json['mode']),
      notes: serializer.fromJson<String?>(json['notes']),
      baseSurveyId: serializer.fromJson<String?>(json['baseSurveyId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'name': serializer.toJson<String>(name),
      'date': serializer.toJson<DateTime>(date),
      'mode': serializer.toJson<String>(mode),
      'notes': serializer.toJson<String?>(notes),
      'baseSurveyId': serializer.toJson<String?>(baseSurveyId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Survey copyWith({
    String? id,
    String? deviceId,
    String? name,
    DateTime? date,
    String? mode,
    Value<String?> notes = const Value.absent(),
    Value<String?> baseSurveyId = const Value.absent(),
    DateTime? createdAt,
  }) => Survey(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    name: name ?? this.name,
    date: date ?? this.date,
    mode: mode ?? this.mode,
    notes: notes.present ? notes.value : this.notes,
    baseSurveyId: baseSurveyId.present ? baseSurveyId.value : this.baseSurveyId,
    createdAt: createdAt ?? this.createdAt,
  );
  Survey copyWithCompanion(SurveysCompanion data) {
    return Survey(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      name: data.name.present ? data.name.value : this.name,
      date: data.date.present ? data.date.value : this.date,
      mode: data.mode.present ? data.mode.value : this.mode,
      notes: data.notes.present ? data.notes.value : this.notes,
      baseSurveyId: data.baseSurveyId.present
          ? data.baseSurveyId.value
          : this.baseSurveyId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Survey(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('date: $date, ')
          ..write('mode: $mode, ')
          ..write('notes: $notes, ')
          ..write('baseSurveyId: $baseSurveyId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deviceId,
    name,
    date,
    mode,
    notes,
    baseSurveyId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Survey &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.name == this.name &&
          other.date == this.date &&
          other.mode == this.mode &&
          other.notes == this.notes &&
          other.baseSurveyId == this.baseSurveyId &&
          other.createdAt == this.createdAt);
}

class SurveysCompanion extends UpdateCompanion<Survey> {
  final Value<String> id;
  final Value<String> deviceId;
  final Value<String> name;
  final Value<DateTime> date;
  final Value<String> mode;
  final Value<String?> notes;
  final Value<String?> baseSurveyId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SurveysCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.name = const Value.absent(),
    this.date = const Value.absent(),
    this.mode = const Value.absent(),
    this.notes = const Value.absent(),
    this.baseSurveyId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SurveysCompanion.insert({
    required String id,
    required String deviceId,
    required String name,
    required DateTime date,
    required String mode,
    this.notes = const Value.absent(),
    this.baseSurveyId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deviceId = Value(deviceId),
       name = Value(name),
       date = Value(date),
       mode = Value(mode);
  static Insertable<Survey> custom({
    Expression<String>? id,
    Expression<String>? deviceId,
    Expression<String>? name,
    Expression<DateTime>? date,
    Expression<String>? mode,
    Expression<String>? notes,
    Expression<String>? baseSurveyId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (name != null) 'name': name,
      if (date != null) 'date': date,
      if (mode != null) 'mode': mode,
      if (notes != null) 'notes': notes,
      if (baseSurveyId != null) 'base_survey_id': baseSurveyId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SurveysCompanion copyWith({
    Value<String>? id,
    Value<String>? deviceId,
    Value<String>? name,
    Value<DateTime>? date,
    Value<String>? mode,
    Value<String?>? notes,
    Value<String?>? baseSurveyId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SurveysCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      date: date ?? this.date,
      mode: mode ?? this.mode,
      notes: notes ?? this.notes,
      baseSurveyId: baseSurveyId ?? this.baseSurveyId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (baseSurveyId.present) {
      map['base_survey_id'] = Variable<String>(baseSurveyId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurveysCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('name: $name, ')
          ..write('date: $date, ')
          ..write('mode: $mode, ')
          ..write('notes: $notes, ')
          ..write('baseSurveyId: $baseSurveyId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StationsTable extends Stations with TableInfo<$StationsTable, Station> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _surveyIdMeta = const VerificationMeta(
    'surveyId',
  );
  @override
  late final GeneratedColumn<String> surveyId = GeneratedColumn<String>(
    'survey_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES surveys (id)',
    ),
  );
  static const VerificationMeta _sequenceNumberMeta = const VerificationMeta(
    'sequenceNumber',
  );
  @override
  late final GeneratedColumn<int> sequenceNumber = GeneratedColumn<int>(
    'sequence_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gpsAccuracyMMeta = const VerificationMeta(
    'gpsAccuracyM',
  );
  @override
  late final GeneratedColumn<double> gpsAccuracyM = GeneratedColumn<double>(
    'gps_accuracy_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localXMeta = const VerificationMeta('localX');
  @override
  late final GeneratedColumn<double> localX = GeneratedColumn<double>(
    'local_x',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localYMeta = const VerificationMeta('localY');
  @override
  late final GeneratedColumn<double> localY = GeneratedColumn<double>(
    'local_y',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sensorHeightMMeta = const VerificationMeta(
    'sensorHeightM',
  );
  @override
  late final GeneratedColumn<double> sensorHeightM = GeneratedColumn<double>(
    'sensor_height_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _holdingDirectionDegMeta =
      const VerificationMeta('holdingDirectionDeg');
  @override
  late final GeneratedColumn<double> holdingDirectionDeg =
      GeneratedColumn<double>(
        'holding_direction_deg',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _environmentNotesMeta = const VerificationMeta(
    'environmentNotes',
  );
  @override
  late final GeneratedColumn<String> environmentNotes = GeneratedColumn<String>(
    'environment_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    surveyId,
    sequenceNumber,
    latitude,
    longitude,
    gpsAccuracyM,
    localX,
    localY,
    sensorHeightM,
    holdingDirectionDeg,
    environmentNotes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Station> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('survey_id')) {
      context.handle(
        _surveyIdMeta,
        surveyId.isAcceptableOrUnknown(data['survey_id']!, _surveyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_surveyIdMeta);
    }
    if (data.containsKey('sequence_number')) {
      context.handle(
        _sequenceNumberMeta,
        sequenceNumber.isAcceptableOrUnknown(
          data['sequence_number']!,
          _sequenceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceNumberMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('gps_accuracy_m')) {
      context.handle(
        _gpsAccuracyMMeta,
        gpsAccuracyM.isAcceptableOrUnknown(
          data['gps_accuracy_m']!,
          _gpsAccuracyMMeta,
        ),
      );
    }
    if (data.containsKey('local_x')) {
      context.handle(
        _localXMeta,
        localX.isAcceptableOrUnknown(data['local_x']!, _localXMeta),
      );
    }
    if (data.containsKey('local_y')) {
      context.handle(
        _localYMeta,
        localY.isAcceptableOrUnknown(data['local_y']!, _localYMeta),
      );
    }
    if (data.containsKey('sensor_height_m')) {
      context.handle(
        _sensorHeightMMeta,
        sensorHeightM.isAcceptableOrUnknown(
          data['sensor_height_m']!,
          _sensorHeightMMeta,
        ),
      );
    }
    if (data.containsKey('holding_direction_deg')) {
      context.handle(
        _holdingDirectionDegMeta,
        holdingDirectionDeg.isAcceptableOrUnknown(
          data['holding_direction_deg']!,
          _holdingDirectionDegMeta,
        ),
      );
    }
    if (data.containsKey('environment_notes')) {
      context.handle(
        _environmentNotesMeta,
        environmentNotes.isAcceptableOrUnknown(
          data['environment_notes']!,
          _environmentNotesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Station map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Station(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      surveyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}survey_id'],
      )!,
      sequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_number'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      ),
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      ),
      gpsAccuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gps_accuracy_m'],
      ),
      localX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}local_x'],
      ),
      localY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}local_y'],
      ),
      sensorHeightM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sensor_height_m'],
      ),
      holdingDirectionDeg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}holding_direction_deg'],
      ),
      environmentNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}environment_notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StationsTable createAlias(String alias) {
    return $StationsTable(attachedDatabase, alias);
  }
}

class Station extends DataClass implements Insertable<Station> {
  final String id;
  final String surveyId;
  final int sequenceNumber;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracyM;
  final double? localX;
  final double? localY;
  final double? sensorHeightM;
  final double? holdingDirectionDeg;
  final String? environmentNotes;
  final DateTime createdAt;
  const Station({
    required this.id,
    required this.surveyId,
    required this.sequenceNumber,
    this.latitude,
    this.longitude,
    this.gpsAccuracyM,
    this.localX,
    this.localY,
    this.sensorHeightM,
    this.holdingDirectionDeg,
    this.environmentNotes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['survey_id'] = Variable<String>(surveyId);
    map['sequence_number'] = Variable<int>(sequenceNumber);
    if (!nullToAbsent || latitude != null) {
      map['latitude'] = Variable<double>(latitude);
    }
    if (!nullToAbsent || longitude != null) {
      map['longitude'] = Variable<double>(longitude);
    }
    if (!nullToAbsent || gpsAccuracyM != null) {
      map['gps_accuracy_m'] = Variable<double>(gpsAccuracyM);
    }
    if (!nullToAbsent || localX != null) {
      map['local_x'] = Variable<double>(localX);
    }
    if (!nullToAbsent || localY != null) {
      map['local_y'] = Variable<double>(localY);
    }
    if (!nullToAbsent || sensorHeightM != null) {
      map['sensor_height_m'] = Variable<double>(sensorHeightM);
    }
    if (!nullToAbsent || holdingDirectionDeg != null) {
      map['holding_direction_deg'] = Variable<double>(holdingDirectionDeg);
    }
    if (!nullToAbsent || environmentNotes != null) {
      map['environment_notes'] = Variable<String>(environmentNotes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StationsCompanion toCompanion(bool nullToAbsent) {
    return StationsCompanion(
      id: Value(id),
      surveyId: Value(surveyId),
      sequenceNumber: Value(sequenceNumber),
      latitude: latitude == null && nullToAbsent
          ? const Value.absent()
          : Value(latitude),
      longitude: longitude == null && nullToAbsent
          ? const Value.absent()
          : Value(longitude),
      gpsAccuracyM: gpsAccuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(gpsAccuracyM),
      localX: localX == null && nullToAbsent
          ? const Value.absent()
          : Value(localX),
      localY: localY == null && nullToAbsent
          ? const Value.absent()
          : Value(localY),
      sensorHeightM: sensorHeightM == null && nullToAbsent
          ? const Value.absent()
          : Value(sensorHeightM),
      holdingDirectionDeg: holdingDirectionDeg == null && nullToAbsent
          ? const Value.absent()
          : Value(holdingDirectionDeg),
      environmentNotes: environmentNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(environmentNotes),
      createdAt: Value(createdAt),
    );
  }

  factory Station.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Station(
      id: serializer.fromJson<String>(json['id']),
      surveyId: serializer.fromJson<String>(json['surveyId']),
      sequenceNumber: serializer.fromJson<int>(json['sequenceNumber']),
      latitude: serializer.fromJson<double?>(json['latitude']),
      longitude: serializer.fromJson<double?>(json['longitude']),
      gpsAccuracyM: serializer.fromJson<double?>(json['gpsAccuracyM']),
      localX: serializer.fromJson<double?>(json['localX']),
      localY: serializer.fromJson<double?>(json['localY']),
      sensorHeightM: serializer.fromJson<double?>(json['sensorHeightM']),
      holdingDirectionDeg: serializer.fromJson<double?>(
        json['holdingDirectionDeg'],
      ),
      environmentNotes: serializer.fromJson<String?>(json['environmentNotes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'surveyId': serializer.toJson<String>(surveyId),
      'sequenceNumber': serializer.toJson<int>(sequenceNumber),
      'latitude': serializer.toJson<double?>(latitude),
      'longitude': serializer.toJson<double?>(longitude),
      'gpsAccuracyM': serializer.toJson<double?>(gpsAccuracyM),
      'localX': serializer.toJson<double?>(localX),
      'localY': serializer.toJson<double?>(localY),
      'sensorHeightM': serializer.toJson<double?>(sensorHeightM),
      'holdingDirectionDeg': serializer.toJson<double?>(holdingDirectionDeg),
      'environmentNotes': serializer.toJson<String?>(environmentNotes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Station copyWith({
    String? id,
    String? surveyId,
    int? sequenceNumber,
    Value<double?> latitude = const Value.absent(),
    Value<double?> longitude = const Value.absent(),
    Value<double?> gpsAccuracyM = const Value.absent(),
    Value<double?> localX = const Value.absent(),
    Value<double?> localY = const Value.absent(),
    Value<double?> sensorHeightM = const Value.absent(),
    Value<double?> holdingDirectionDeg = const Value.absent(),
    Value<String?> environmentNotes = const Value.absent(),
    DateTime? createdAt,
  }) => Station(
    id: id ?? this.id,
    surveyId: surveyId ?? this.surveyId,
    sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    latitude: latitude.present ? latitude.value : this.latitude,
    longitude: longitude.present ? longitude.value : this.longitude,
    gpsAccuracyM: gpsAccuracyM.present ? gpsAccuracyM.value : this.gpsAccuracyM,
    localX: localX.present ? localX.value : this.localX,
    localY: localY.present ? localY.value : this.localY,
    sensorHeightM: sensorHeightM.present
        ? sensorHeightM.value
        : this.sensorHeightM,
    holdingDirectionDeg: holdingDirectionDeg.present
        ? holdingDirectionDeg.value
        : this.holdingDirectionDeg,
    environmentNotes: environmentNotes.present
        ? environmentNotes.value
        : this.environmentNotes,
    createdAt: createdAt ?? this.createdAt,
  );
  Station copyWithCompanion(StationsCompanion data) {
    return Station(
      id: data.id.present ? data.id.value : this.id,
      surveyId: data.surveyId.present ? data.surveyId.value : this.surveyId,
      sequenceNumber: data.sequenceNumber.present
          ? data.sequenceNumber.value
          : this.sequenceNumber,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      gpsAccuracyM: data.gpsAccuracyM.present
          ? data.gpsAccuracyM.value
          : this.gpsAccuracyM,
      localX: data.localX.present ? data.localX.value : this.localX,
      localY: data.localY.present ? data.localY.value : this.localY,
      sensorHeightM: data.sensorHeightM.present
          ? data.sensorHeightM.value
          : this.sensorHeightM,
      holdingDirectionDeg: data.holdingDirectionDeg.present
          ? data.holdingDirectionDeg.value
          : this.holdingDirectionDeg,
      environmentNotes: data.environmentNotes.present
          ? data.environmentNotes.value
          : this.environmentNotes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Station(')
          ..write('id: $id, ')
          ..write('surveyId: $surveyId, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('gpsAccuracyM: $gpsAccuracyM, ')
          ..write('localX: $localX, ')
          ..write('localY: $localY, ')
          ..write('sensorHeightM: $sensorHeightM, ')
          ..write('holdingDirectionDeg: $holdingDirectionDeg, ')
          ..write('environmentNotes: $environmentNotes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    surveyId,
    sequenceNumber,
    latitude,
    longitude,
    gpsAccuracyM,
    localX,
    localY,
    sensorHeightM,
    holdingDirectionDeg,
    environmentNotes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Station &&
          other.id == this.id &&
          other.surveyId == this.surveyId &&
          other.sequenceNumber == this.sequenceNumber &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.gpsAccuracyM == this.gpsAccuracyM &&
          other.localX == this.localX &&
          other.localY == this.localY &&
          other.sensorHeightM == this.sensorHeightM &&
          other.holdingDirectionDeg == this.holdingDirectionDeg &&
          other.environmentNotes == this.environmentNotes &&
          other.createdAt == this.createdAt);
}

class StationsCompanion extends UpdateCompanion<Station> {
  final Value<String> id;
  final Value<String> surveyId;
  final Value<int> sequenceNumber;
  final Value<double?> latitude;
  final Value<double?> longitude;
  final Value<double?> gpsAccuracyM;
  final Value<double?> localX;
  final Value<double?> localY;
  final Value<double?> sensorHeightM;
  final Value<double?> holdingDirectionDeg;
  final Value<String?> environmentNotes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const StationsCompanion({
    this.id = const Value.absent(),
    this.surveyId = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.gpsAccuracyM = const Value.absent(),
    this.localX = const Value.absent(),
    this.localY = const Value.absent(),
    this.sensorHeightM = const Value.absent(),
    this.holdingDirectionDeg = const Value.absent(),
    this.environmentNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StationsCompanion.insert({
    required String id,
    required String surveyId,
    required int sequenceNumber,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.gpsAccuracyM = const Value.absent(),
    this.localX = const Value.absent(),
    this.localY = const Value.absent(),
    this.sensorHeightM = const Value.absent(),
    this.holdingDirectionDeg = const Value.absent(),
    this.environmentNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       surveyId = Value(surveyId),
       sequenceNumber = Value(sequenceNumber);
  static Insertable<Station> custom({
    Expression<String>? id,
    Expression<String>? surveyId,
    Expression<int>? sequenceNumber,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? gpsAccuracyM,
    Expression<double>? localX,
    Expression<double>? localY,
    Expression<double>? sensorHeightM,
    Expression<double>? holdingDirectionDeg,
    Expression<String>? environmentNotes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (surveyId != null) 'survey_id': surveyId,
      if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (gpsAccuracyM != null) 'gps_accuracy_m': gpsAccuracyM,
      if (localX != null) 'local_x': localX,
      if (localY != null) 'local_y': localY,
      if (sensorHeightM != null) 'sensor_height_m': sensorHeightM,
      if (holdingDirectionDeg != null)
        'holding_direction_deg': holdingDirectionDeg,
      if (environmentNotes != null) 'environment_notes': environmentNotes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StationsCompanion copyWith({
    Value<String>? id,
    Value<String>? surveyId,
    Value<int>? sequenceNumber,
    Value<double?>? latitude,
    Value<double?>? longitude,
    Value<double?>? gpsAccuracyM,
    Value<double?>? localX,
    Value<double?>? localY,
    Value<double?>? sensorHeightM,
    Value<double?>? holdingDirectionDeg,
    Value<String?>? environmentNotes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return StationsCompanion(
      id: id ?? this.id,
      surveyId: surveyId ?? this.surveyId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      localX: localX ?? this.localX,
      localY: localY ?? this.localY,
      sensorHeightM: sensorHeightM ?? this.sensorHeightM,
      holdingDirectionDeg: holdingDirectionDeg ?? this.holdingDirectionDeg,
      environmentNotes: environmentNotes ?? this.environmentNotes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (surveyId.present) {
      map['survey_id'] = Variable<String>(surveyId.value);
    }
    if (sequenceNumber.present) {
      map['sequence_number'] = Variable<int>(sequenceNumber.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (gpsAccuracyM.present) {
      map['gps_accuracy_m'] = Variable<double>(gpsAccuracyM.value);
    }
    if (localX.present) {
      map['local_x'] = Variable<double>(localX.value);
    }
    if (localY.present) {
      map['local_y'] = Variable<double>(localY.value);
    }
    if (sensorHeightM.present) {
      map['sensor_height_m'] = Variable<double>(sensorHeightM.value);
    }
    if (holdingDirectionDeg.present) {
      map['holding_direction_deg'] = Variable<double>(
        holdingDirectionDeg.value,
      );
    }
    if (environmentNotes.present) {
      map['environment_notes'] = Variable<String>(environmentNotes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StationsCompanion(')
          ..write('id: $id, ')
          ..write('surveyId: $surveyId, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('gpsAccuracyM: $gpsAccuracyM, ')
          ..write('localX: $localX, ')
          ..write('localY: $localY, ')
          ..write('sensorHeightM: $sensorHeightM, ')
          ..write('holdingDirectionDeg: $holdingDirectionDeg, ')
          ..write('environmentNotes: $environmentNotes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SamplesTable extends Samples with TableInfo<$SamplesTable, Sample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stationIdMeta = const VerificationMeta(
    'stationId',
  );
  @override
  late final GeneratedColumn<String> stationId = GeneratedColumn<String>(
    'station_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES stations (id)',
    ),
  );
  static const VerificationMeta _calibrationIdMeta = const VerificationMeta(
    'calibrationId',
  );
  @override
  late final GeneratedColumn<String> calibrationId = GeneratedColumn<String>(
    'calibration_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES calibration_profiles (id)',
    ),
  );
  static const VerificationMeta _timestampNsMeta = const VerificationMeta(
    'timestampNs',
  );
  @override
  late final GeneratedColumn<BigInt> timestampNs = GeneratedColumn<BigInt>(
    'timestamp_ns',
    aliasedName,
    false,
    type: DriftSqlType.bigInt,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawXMicroTMeta = const VerificationMeta(
    'rawXMicroT',
  );
  @override
  late final GeneratedColumn<double> rawXMicroT = GeneratedColumn<double>(
    'raw_x_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawYMicroTMeta = const VerificationMeta(
    'rawYMicroT',
  );
  @override
  late final GeneratedColumn<double> rawYMicroT = GeneratedColumn<double>(
    'raw_y_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rawZMicroTMeta = const VerificationMeta(
    'rawZMicroT',
  );
  @override
  late final GeneratedColumn<double> rawZMicroT = GeneratedColumn<double>(
    'raw_z_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _biasXMicroTMeta = const VerificationMeta(
    'biasXMicroT',
  );
  @override
  late final GeneratedColumn<double> biasXMicroT = GeneratedColumn<double>(
    'bias_x_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _biasYMicroTMeta = const VerificationMeta(
    'biasYMicroT',
  );
  @override
  late final GeneratedColumn<double> biasYMicroT = GeneratedColumn<double>(
    'bias_y_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _biasZMicroTMeta = const VerificationMeta(
    'biasZMicroT',
  );
  @override
  late final GeneratedColumn<double> biasZMicroT = GeneratedColumn<double>(
    'bias_z_micro_t',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMeta = const VerificationMeta(
    'accuracy',
  );
  @override
  late final GeneratedColumn<int> accuracy = GeneratedColumn<int>(
    'accuracy',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isUncalibratedMeta = const VerificationMeta(
    'isUncalibrated',
  );
  @override
  late final GeneratedColumn<bool> isUncalibrated = GeneratedColumn<bool>(
    'is_uncalibrated',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_uncalibrated" IN (0, 1))',
    ),
  );
  static const VerificationMeta _batteryTempCMeta = const VerificationMeta(
    'batteryTempC',
  );
  @override
  late final GeneratedColumn<double> batteryTempC = GeneratedColumn<double>(
    'battery_temp_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isChargingMeta = const VerificationMeta(
    'isCharging',
  );
  @override
  late final GeneratedColumn<bool> isCharging = GeneratedColumn<bool>(
    'is_charging',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_charging" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isScreenOnMeta = const VerificationMeta(
    'isScreenOn',
  );
  @override
  late final GeneratedColumn<bool> isScreenOn = GeneratedColumn<bool>(
    'is_screen_on',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_screen_on" IN (0, 1))',
    ),
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<DateTime> recordedAt = GeneratedColumn<DateTime>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    stationId,
    calibrationId,
    timestampNs,
    rawXMicroT,
    rawYMicroT,
    rawZMicroT,
    biasXMicroT,
    biasYMicroT,
    biasZMicroT,
    accuracy,
    isUncalibrated,
    batteryTempC,
    isCharging,
    isScreenOn,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<Sample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('station_id')) {
      context.handle(
        _stationIdMeta,
        stationId.isAcceptableOrUnknown(data['station_id']!, _stationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stationIdMeta);
    }
    if (data.containsKey('calibration_id')) {
      context.handle(
        _calibrationIdMeta,
        calibrationId.isAcceptableOrUnknown(
          data['calibration_id']!,
          _calibrationIdMeta,
        ),
      );
    }
    if (data.containsKey('timestamp_ns')) {
      context.handle(
        _timestampNsMeta,
        timestampNs.isAcceptableOrUnknown(
          data['timestamp_ns']!,
          _timestampNsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_timestampNsMeta);
    }
    if (data.containsKey('raw_x_micro_t')) {
      context.handle(
        _rawXMicroTMeta,
        rawXMicroT.isAcceptableOrUnknown(
          data['raw_x_micro_t']!,
          _rawXMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawXMicroTMeta);
    }
    if (data.containsKey('raw_y_micro_t')) {
      context.handle(
        _rawYMicroTMeta,
        rawYMicroT.isAcceptableOrUnknown(
          data['raw_y_micro_t']!,
          _rawYMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawYMicroTMeta);
    }
    if (data.containsKey('raw_z_micro_t')) {
      context.handle(
        _rawZMicroTMeta,
        rawZMicroT.isAcceptableOrUnknown(
          data['raw_z_micro_t']!,
          _rawZMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rawZMicroTMeta);
    }
    if (data.containsKey('bias_x_micro_t')) {
      context.handle(
        _biasXMicroTMeta,
        biasXMicroT.isAcceptableOrUnknown(
          data['bias_x_micro_t']!,
          _biasXMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_biasXMicroTMeta);
    }
    if (data.containsKey('bias_y_micro_t')) {
      context.handle(
        _biasYMicroTMeta,
        biasYMicroT.isAcceptableOrUnknown(
          data['bias_y_micro_t']!,
          _biasYMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_biasYMicroTMeta);
    }
    if (data.containsKey('bias_z_micro_t')) {
      context.handle(
        _biasZMicroTMeta,
        biasZMicroT.isAcceptableOrUnknown(
          data['bias_z_micro_t']!,
          _biasZMicroTMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_biasZMicroTMeta);
    }
    if (data.containsKey('accuracy')) {
      context.handle(
        _accuracyMeta,
        accuracy.isAcceptableOrUnknown(data['accuracy']!, _accuracyMeta),
      );
    } else if (isInserting) {
      context.missing(_accuracyMeta);
    }
    if (data.containsKey('is_uncalibrated')) {
      context.handle(
        _isUncalibratedMeta,
        isUncalibrated.isAcceptableOrUnknown(
          data['is_uncalibrated']!,
          _isUncalibratedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isUncalibratedMeta);
    }
    if (data.containsKey('battery_temp_c')) {
      context.handle(
        _batteryTempCMeta,
        batteryTempC.isAcceptableOrUnknown(
          data['battery_temp_c']!,
          _batteryTempCMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_batteryTempCMeta);
    }
    if (data.containsKey('is_charging')) {
      context.handle(
        _isChargingMeta,
        isCharging.isAcceptableOrUnknown(data['is_charging']!, _isChargingMeta),
      );
    } else if (isInserting) {
      context.missing(_isChargingMeta);
    }
    if (data.containsKey('is_screen_on')) {
      context.handle(
        _isScreenOnMeta,
        isScreenOn.isAcceptableOrUnknown(
          data['is_screen_on']!,
          _isScreenOnMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isScreenOnMeta);
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Sample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Sample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      stationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_id'],
      )!,
      calibrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}calibration_id'],
      ),
      timestampNs: attachedDatabase.typeMapping.read(
        DriftSqlType.bigInt,
        data['${effectivePrefix}timestamp_ns'],
      )!,
      rawXMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}raw_x_micro_t'],
      )!,
      rawYMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}raw_y_micro_t'],
      )!,
      rawZMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}raw_z_micro_t'],
      )!,
      biasXMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bias_x_micro_t'],
      )!,
      biasYMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bias_y_micro_t'],
      )!,
      biasZMicroT: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}bias_z_micro_t'],
      )!,
      accuracy: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}accuracy'],
      )!,
      isUncalibrated: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_uncalibrated'],
      )!,
      batteryTempC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}battery_temp_c'],
      )!,
      isCharging: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_charging'],
      )!,
      isScreenOn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_screen_on'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $SamplesTable createAlias(String alias) {
    return $SamplesTable(attachedDatabase, alias);
  }
}

class Sample extends DataClass implements Insertable<Sample> {
  final String id;
  final String stationId;
  final String? calibrationId;

  /// Timestamp event dari Android hardware sensor (nanodetik).
  final BigInt timestampNs;

  /// Medan mentah x, y, z dalam mikroTesla.
  final double rawXMicroT;
  final double rawYMicroT;
  final double rawZMicroT;

  /// Estimasi bias hard iron OS x, y, z dalam mikroTesla.
  final double biasXMicroT;
  final double biasYMicroT;
  final double biasZMicroT;

  /// Akurasi sensor Android (0–3).
  final int accuracy;

  /// Apakah dibaca dari TYPE_MAGNETIC_FIELD_UNCALIBRATED.
  final bool isUncalibrated;

  /// Suhu baterai (°C) sebagai proksi suhu perangkat.
  final double batteryTempC;

  /// Status charging saat sampel diambil.
  final bool isCharging;

  /// Status layar menyala saat sampel diambil.
  final bool isScreenOn;

  /// Waktu penyimpanan ke database.
  final DateTime recordedAt;
  const Sample({
    required this.id,
    required this.stationId,
    this.calibrationId,
    required this.timestampNs,
    required this.rawXMicroT,
    required this.rawYMicroT,
    required this.rawZMicroT,
    required this.biasXMicroT,
    required this.biasYMicroT,
    required this.biasZMicroT,
    required this.accuracy,
    required this.isUncalibrated,
    required this.batteryTempC,
    required this.isCharging,
    required this.isScreenOn,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['station_id'] = Variable<String>(stationId);
    if (!nullToAbsent || calibrationId != null) {
      map['calibration_id'] = Variable<String>(calibrationId);
    }
    map['timestamp_ns'] = Variable<BigInt>(timestampNs);
    map['raw_x_micro_t'] = Variable<double>(rawXMicroT);
    map['raw_y_micro_t'] = Variable<double>(rawYMicroT);
    map['raw_z_micro_t'] = Variable<double>(rawZMicroT);
    map['bias_x_micro_t'] = Variable<double>(biasXMicroT);
    map['bias_y_micro_t'] = Variable<double>(biasYMicroT);
    map['bias_z_micro_t'] = Variable<double>(biasZMicroT);
    map['accuracy'] = Variable<int>(accuracy);
    map['is_uncalibrated'] = Variable<bool>(isUncalibrated);
    map['battery_temp_c'] = Variable<double>(batteryTempC);
    map['is_charging'] = Variable<bool>(isCharging);
    map['is_screen_on'] = Variable<bool>(isScreenOn);
    map['recorded_at'] = Variable<DateTime>(recordedAt);
    return map;
  }

  SamplesCompanion toCompanion(bool nullToAbsent) {
    return SamplesCompanion(
      id: Value(id),
      stationId: Value(stationId),
      calibrationId: calibrationId == null && nullToAbsent
          ? const Value.absent()
          : Value(calibrationId),
      timestampNs: Value(timestampNs),
      rawXMicroT: Value(rawXMicroT),
      rawYMicroT: Value(rawYMicroT),
      rawZMicroT: Value(rawZMicroT),
      biasXMicroT: Value(biasXMicroT),
      biasYMicroT: Value(biasYMicroT),
      biasZMicroT: Value(biasZMicroT),
      accuracy: Value(accuracy),
      isUncalibrated: Value(isUncalibrated),
      batteryTempC: Value(batteryTempC),
      isCharging: Value(isCharging),
      isScreenOn: Value(isScreenOn),
      recordedAt: Value(recordedAt),
    );
  }

  factory Sample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Sample(
      id: serializer.fromJson<String>(json['id']),
      stationId: serializer.fromJson<String>(json['stationId']),
      calibrationId: serializer.fromJson<String?>(json['calibrationId']),
      timestampNs: serializer.fromJson<BigInt>(json['timestampNs']),
      rawXMicroT: serializer.fromJson<double>(json['rawXMicroT']),
      rawYMicroT: serializer.fromJson<double>(json['rawYMicroT']),
      rawZMicroT: serializer.fromJson<double>(json['rawZMicroT']),
      biasXMicroT: serializer.fromJson<double>(json['biasXMicroT']),
      biasYMicroT: serializer.fromJson<double>(json['biasYMicroT']),
      biasZMicroT: serializer.fromJson<double>(json['biasZMicroT']),
      accuracy: serializer.fromJson<int>(json['accuracy']),
      isUncalibrated: serializer.fromJson<bool>(json['isUncalibrated']),
      batteryTempC: serializer.fromJson<double>(json['batteryTempC']),
      isCharging: serializer.fromJson<bool>(json['isCharging']),
      isScreenOn: serializer.fromJson<bool>(json['isScreenOn']),
      recordedAt: serializer.fromJson<DateTime>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'stationId': serializer.toJson<String>(stationId),
      'calibrationId': serializer.toJson<String?>(calibrationId),
      'timestampNs': serializer.toJson<BigInt>(timestampNs),
      'rawXMicroT': serializer.toJson<double>(rawXMicroT),
      'rawYMicroT': serializer.toJson<double>(rawYMicroT),
      'rawZMicroT': serializer.toJson<double>(rawZMicroT),
      'biasXMicroT': serializer.toJson<double>(biasXMicroT),
      'biasYMicroT': serializer.toJson<double>(biasYMicroT),
      'biasZMicroT': serializer.toJson<double>(biasZMicroT),
      'accuracy': serializer.toJson<int>(accuracy),
      'isUncalibrated': serializer.toJson<bool>(isUncalibrated),
      'batteryTempC': serializer.toJson<double>(batteryTempC),
      'isCharging': serializer.toJson<bool>(isCharging),
      'isScreenOn': serializer.toJson<bool>(isScreenOn),
      'recordedAt': serializer.toJson<DateTime>(recordedAt),
    };
  }

  Sample copyWith({
    String? id,
    String? stationId,
    Value<String?> calibrationId = const Value.absent(),
    BigInt? timestampNs,
    double? rawXMicroT,
    double? rawYMicroT,
    double? rawZMicroT,
    double? biasXMicroT,
    double? biasYMicroT,
    double? biasZMicroT,
    int? accuracy,
    bool? isUncalibrated,
    double? batteryTempC,
    bool? isCharging,
    bool? isScreenOn,
    DateTime? recordedAt,
  }) => Sample(
    id: id ?? this.id,
    stationId: stationId ?? this.stationId,
    calibrationId: calibrationId.present
        ? calibrationId.value
        : this.calibrationId,
    timestampNs: timestampNs ?? this.timestampNs,
    rawXMicroT: rawXMicroT ?? this.rawXMicroT,
    rawYMicroT: rawYMicroT ?? this.rawYMicroT,
    rawZMicroT: rawZMicroT ?? this.rawZMicroT,
    biasXMicroT: biasXMicroT ?? this.biasXMicroT,
    biasYMicroT: biasYMicroT ?? this.biasYMicroT,
    biasZMicroT: biasZMicroT ?? this.biasZMicroT,
    accuracy: accuracy ?? this.accuracy,
    isUncalibrated: isUncalibrated ?? this.isUncalibrated,
    batteryTempC: batteryTempC ?? this.batteryTempC,
    isCharging: isCharging ?? this.isCharging,
    isScreenOn: isScreenOn ?? this.isScreenOn,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  Sample copyWithCompanion(SamplesCompanion data) {
    return Sample(
      id: data.id.present ? data.id.value : this.id,
      stationId: data.stationId.present ? data.stationId.value : this.stationId,
      calibrationId: data.calibrationId.present
          ? data.calibrationId.value
          : this.calibrationId,
      timestampNs: data.timestampNs.present
          ? data.timestampNs.value
          : this.timestampNs,
      rawXMicroT: data.rawXMicroT.present
          ? data.rawXMicroT.value
          : this.rawXMicroT,
      rawYMicroT: data.rawYMicroT.present
          ? data.rawYMicroT.value
          : this.rawYMicroT,
      rawZMicroT: data.rawZMicroT.present
          ? data.rawZMicroT.value
          : this.rawZMicroT,
      biasXMicroT: data.biasXMicroT.present
          ? data.biasXMicroT.value
          : this.biasXMicroT,
      biasYMicroT: data.biasYMicroT.present
          ? data.biasYMicroT.value
          : this.biasYMicroT,
      biasZMicroT: data.biasZMicroT.present
          ? data.biasZMicroT.value
          : this.biasZMicroT,
      accuracy: data.accuracy.present ? data.accuracy.value : this.accuracy,
      isUncalibrated: data.isUncalibrated.present
          ? data.isUncalibrated.value
          : this.isUncalibrated,
      batteryTempC: data.batteryTempC.present
          ? data.batteryTempC.value
          : this.batteryTempC,
      isCharging: data.isCharging.present
          ? data.isCharging.value
          : this.isCharging,
      isScreenOn: data.isScreenOn.present
          ? data.isScreenOn.value
          : this.isScreenOn,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Sample(')
          ..write('id: $id, ')
          ..write('stationId: $stationId, ')
          ..write('calibrationId: $calibrationId, ')
          ..write('timestampNs: $timestampNs, ')
          ..write('rawXMicroT: $rawXMicroT, ')
          ..write('rawYMicroT: $rawYMicroT, ')
          ..write('rawZMicroT: $rawZMicroT, ')
          ..write('biasXMicroT: $biasXMicroT, ')
          ..write('biasYMicroT: $biasYMicroT, ')
          ..write('biasZMicroT: $biasZMicroT, ')
          ..write('accuracy: $accuracy, ')
          ..write('isUncalibrated: $isUncalibrated, ')
          ..write('batteryTempC: $batteryTempC, ')
          ..write('isCharging: $isCharging, ')
          ..write('isScreenOn: $isScreenOn, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    stationId,
    calibrationId,
    timestampNs,
    rawXMicroT,
    rawYMicroT,
    rawZMicroT,
    biasXMicroT,
    biasYMicroT,
    biasZMicroT,
    accuracy,
    isUncalibrated,
    batteryTempC,
    isCharging,
    isScreenOn,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Sample &&
          other.id == this.id &&
          other.stationId == this.stationId &&
          other.calibrationId == this.calibrationId &&
          other.timestampNs == this.timestampNs &&
          other.rawXMicroT == this.rawXMicroT &&
          other.rawYMicroT == this.rawYMicroT &&
          other.rawZMicroT == this.rawZMicroT &&
          other.biasXMicroT == this.biasXMicroT &&
          other.biasYMicroT == this.biasYMicroT &&
          other.biasZMicroT == this.biasZMicroT &&
          other.accuracy == this.accuracy &&
          other.isUncalibrated == this.isUncalibrated &&
          other.batteryTempC == this.batteryTempC &&
          other.isCharging == this.isCharging &&
          other.isScreenOn == this.isScreenOn &&
          other.recordedAt == this.recordedAt);
}

class SamplesCompanion extends UpdateCompanion<Sample> {
  final Value<String> id;
  final Value<String> stationId;
  final Value<String?> calibrationId;
  final Value<BigInt> timestampNs;
  final Value<double> rawXMicroT;
  final Value<double> rawYMicroT;
  final Value<double> rawZMicroT;
  final Value<double> biasXMicroT;
  final Value<double> biasYMicroT;
  final Value<double> biasZMicroT;
  final Value<int> accuracy;
  final Value<bool> isUncalibrated;
  final Value<double> batteryTempC;
  final Value<bool> isCharging;
  final Value<bool> isScreenOn;
  final Value<DateTime> recordedAt;
  final Value<int> rowid;
  const SamplesCompanion({
    this.id = const Value.absent(),
    this.stationId = const Value.absent(),
    this.calibrationId = const Value.absent(),
    this.timestampNs = const Value.absent(),
    this.rawXMicroT = const Value.absent(),
    this.rawYMicroT = const Value.absent(),
    this.rawZMicroT = const Value.absent(),
    this.biasXMicroT = const Value.absent(),
    this.biasYMicroT = const Value.absent(),
    this.biasZMicroT = const Value.absent(),
    this.accuracy = const Value.absent(),
    this.isUncalibrated = const Value.absent(),
    this.batteryTempC = const Value.absent(),
    this.isCharging = const Value.absent(),
    this.isScreenOn = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SamplesCompanion.insert({
    required String id,
    required String stationId,
    this.calibrationId = const Value.absent(),
    required BigInt timestampNs,
    required double rawXMicroT,
    required double rawYMicroT,
    required double rawZMicroT,
    required double biasXMicroT,
    required double biasYMicroT,
    required double biasZMicroT,
    required int accuracy,
    required bool isUncalibrated,
    required double batteryTempC,
    required bool isCharging,
    required bool isScreenOn,
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       stationId = Value(stationId),
       timestampNs = Value(timestampNs),
       rawXMicroT = Value(rawXMicroT),
       rawYMicroT = Value(rawYMicroT),
       rawZMicroT = Value(rawZMicroT),
       biasXMicroT = Value(biasXMicroT),
       biasYMicroT = Value(biasYMicroT),
       biasZMicroT = Value(biasZMicroT),
       accuracy = Value(accuracy),
       isUncalibrated = Value(isUncalibrated),
       batteryTempC = Value(batteryTempC),
       isCharging = Value(isCharging),
       isScreenOn = Value(isScreenOn);
  static Insertable<Sample> custom({
    Expression<String>? id,
    Expression<String>? stationId,
    Expression<String>? calibrationId,
    Expression<BigInt>? timestampNs,
    Expression<double>? rawXMicroT,
    Expression<double>? rawYMicroT,
    Expression<double>? rawZMicroT,
    Expression<double>? biasXMicroT,
    Expression<double>? biasYMicroT,
    Expression<double>? biasZMicroT,
    Expression<int>? accuracy,
    Expression<bool>? isUncalibrated,
    Expression<double>? batteryTempC,
    Expression<bool>? isCharging,
    Expression<bool>? isScreenOn,
    Expression<DateTime>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stationId != null) 'station_id': stationId,
      if (calibrationId != null) 'calibration_id': calibrationId,
      if (timestampNs != null) 'timestamp_ns': timestampNs,
      if (rawXMicroT != null) 'raw_x_micro_t': rawXMicroT,
      if (rawYMicroT != null) 'raw_y_micro_t': rawYMicroT,
      if (rawZMicroT != null) 'raw_z_micro_t': rawZMicroT,
      if (biasXMicroT != null) 'bias_x_micro_t': biasXMicroT,
      if (biasYMicroT != null) 'bias_y_micro_t': biasYMicroT,
      if (biasZMicroT != null) 'bias_z_micro_t': biasZMicroT,
      if (accuracy != null) 'accuracy': accuracy,
      if (isUncalibrated != null) 'is_uncalibrated': isUncalibrated,
      if (batteryTempC != null) 'battery_temp_c': batteryTempC,
      if (isCharging != null) 'is_charging': isCharging,
      if (isScreenOn != null) 'is_screen_on': isScreenOn,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SamplesCompanion copyWith({
    Value<String>? id,
    Value<String>? stationId,
    Value<String?>? calibrationId,
    Value<BigInt>? timestampNs,
    Value<double>? rawXMicroT,
    Value<double>? rawYMicroT,
    Value<double>? rawZMicroT,
    Value<double>? biasXMicroT,
    Value<double>? biasYMicroT,
    Value<double>? biasZMicroT,
    Value<int>? accuracy,
    Value<bool>? isUncalibrated,
    Value<double>? batteryTempC,
    Value<bool>? isCharging,
    Value<bool>? isScreenOn,
    Value<DateTime>? recordedAt,
    Value<int>? rowid,
  }) {
    return SamplesCompanion(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      calibrationId: calibrationId ?? this.calibrationId,
      timestampNs: timestampNs ?? this.timestampNs,
      rawXMicroT: rawXMicroT ?? this.rawXMicroT,
      rawYMicroT: rawYMicroT ?? this.rawYMicroT,
      rawZMicroT: rawZMicroT ?? this.rawZMicroT,
      biasXMicroT: biasXMicroT ?? this.biasXMicroT,
      biasYMicroT: biasYMicroT ?? this.biasYMicroT,
      biasZMicroT: biasZMicroT ?? this.biasZMicroT,
      accuracy: accuracy ?? this.accuracy,
      isUncalibrated: isUncalibrated ?? this.isUncalibrated,
      batteryTempC: batteryTempC ?? this.batteryTempC,
      isCharging: isCharging ?? this.isCharging,
      isScreenOn: isScreenOn ?? this.isScreenOn,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stationId.present) {
      map['station_id'] = Variable<String>(stationId.value);
    }
    if (calibrationId.present) {
      map['calibration_id'] = Variable<String>(calibrationId.value);
    }
    if (timestampNs.present) {
      map['timestamp_ns'] = Variable<BigInt>(timestampNs.value);
    }
    if (rawXMicroT.present) {
      map['raw_x_micro_t'] = Variable<double>(rawXMicroT.value);
    }
    if (rawYMicroT.present) {
      map['raw_y_micro_t'] = Variable<double>(rawYMicroT.value);
    }
    if (rawZMicroT.present) {
      map['raw_z_micro_t'] = Variable<double>(rawZMicroT.value);
    }
    if (biasXMicroT.present) {
      map['bias_x_micro_t'] = Variable<double>(biasXMicroT.value);
    }
    if (biasYMicroT.present) {
      map['bias_y_micro_t'] = Variable<double>(biasYMicroT.value);
    }
    if (biasZMicroT.present) {
      map['bias_z_micro_t'] = Variable<double>(biasZMicroT.value);
    }
    if (accuracy.present) {
      map['accuracy'] = Variable<int>(accuracy.value);
    }
    if (isUncalibrated.present) {
      map['is_uncalibrated'] = Variable<bool>(isUncalibrated.value);
    }
    if (batteryTempC.present) {
      map['battery_temp_c'] = Variable<double>(batteryTempC.value);
    }
    if (isCharging.present) {
      map['is_charging'] = Variable<bool>(isCharging.value);
    }
    if (isScreenOn.present) {
      map['is_screen_on'] = Variable<bool>(isScreenOn.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<DateTime>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SamplesCompanion(')
          ..write('id: $id, ')
          ..write('stationId: $stationId, ')
          ..write('calibrationId: $calibrationId, ')
          ..write('timestampNs: $timestampNs, ')
          ..write('rawXMicroT: $rawXMicroT, ')
          ..write('rawYMicroT: $rawYMicroT, ')
          ..write('rawZMicroT: $rawZMicroT, ')
          ..write('biasXMicroT: $biasXMicroT, ')
          ..write('biasYMicroT: $biasYMicroT, ')
          ..write('biasZMicroT: $biasZMicroT, ')
          ..write('accuracy: $accuracy, ')
          ..write('isUncalibrated: $isUncalibrated, ')
          ..write('batteryTempC: $batteryTempC, ')
          ..write('isCharging: $isCharging, ')
          ..write('isScreenOn: $isScreenOn, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StationResultsTable extends StationResults
    with TableInfo<$StationResultsTable, StationResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StationResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stationIdMeta = const VerificationMeta(
    'stationId',
  );
  @override
  late final GeneratedColumn<String> stationId = GeneratedColumn<String>(
    'station_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES stations (id)',
    ),
  );
  static const VerificationMeta _totalFieldMeanNtMeta = const VerificationMeta(
    'totalFieldMeanNt',
  );
  @override
  late final GeneratedColumn<double> totalFieldMeanNt = GeneratedColumn<double>(
    'total_field_mean_nt',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalFieldStdNtMeta = const VerificationMeta(
    'totalFieldStdNt',
  );
  @override
  late final GeneratedColumn<double> totalFieldStdNt = GeneratedColumn<double>(
    'total_field_std_nt',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleCountMeta = const VerificationMeta(
    'sampleCount',
  );
  @override
  late final GeneratedColumn<int> sampleCount = GeneratedColumn<int>(
    'sample_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isAcceptedMeta = const VerificationMeta(
    'isAccepted',
  );
  @override
  late final GeneratedColumn<bool> isAccepted = GeneratedColumn<bool>(
    'is_accepted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_accepted" IN (0, 1))',
    ),
  );
  static const VerificationMeta _rejectionReasonMeta = const VerificationMeta(
    'rejectionReason',
  );
  @override
  late final GeneratedColumn<String> rejectionReason = GeneratedColumn<String>(
    'rejection_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calculatedAtMeta = const VerificationMeta(
    'calculatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> calculatedAt = GeneratedColumn<DateTime>(
    'calculated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    stationId,
    totalFieldMeanNt,
    totalFieldStdNt,
    sampleCount,
    isAccepted,
    rejectionReason,
    calculatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'station_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<StationResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('station_id')) {
      context.handle(
        _stationIdMeta,
        stationId.isAcceptableOrUnknown(data['station_id']!, _stationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stationIdMeta);
    }
    if (data.containsKey('total_field_mean_nt')) {
      context.handle(
        _totalFieldMeanNtMeta,
        totalFieldMeanNt.isAcceptableOrUnknown(
          data['total_field_mean_nt']!,
          _totalFieldMeanNtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalFieldMeanNtMeta);
    }
    if (data.containsKey('total_field_std_nt')) {
      context.handle(
        _totalFieldStdNtMeta,
        totalFieldStdNt.isAcceptableOrUnknown(
          data['total_field_std_nt']!,
          _totalFieldStdNtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalFieldStdNtMeta);
    }
    if (data.containsKey('sample_count')) {
      context.handle(
        _sampleCountMeta,
        sampleCount.isAcceptableOrUnknown(
          data['sample_count']!,
          _sampleCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sampleCountMeta);
    }
    if (data.containsKey('is_accepted')) {
      context.handle(
        _isAcceptedMeta,
        isAccepted.isAcceptableOrUnknown(data['is_accepted']!, _isAcceptedMeta),
      );
    } else if (isInserting) {
      context.missing(_isAcceptedMeta);
    }
    if (data.containsKey('rejection_reason')) {
      context.handle(
        _rejectionReasonMeta,
        rejectionReason.isAcceptableOrUnknown(
          data['rejection_reason']!,
          _rejectionReasonMeta,
        ),
      );
    }
    if (data.containsKey('calculated_at')) {
      context.handle(
        _calculatedAtMeta,
        calculatedAt.isAcceptableOrUnknown(
          data['calculated_at']!,
          _calculatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StationResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StationResult(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      stationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_id'],
      )!,
      totalFieldMeanNt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_field_mean_nt'],
      )!,
      totalFieldStdNt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_field_std_nt'],
      )!,
      sampleCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_count'],
      )!,
      isAccepted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_accepted'],
      )!,
      rejectionReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rejection_reason'],
      ),
      calculatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}calculated_at'],
      )!,
    );
  }

  @override
  $StationResultsTable createAlias(String alias) {
    return $StationResultsTable(attachedDatabase, alias);
  }
}

class StationResult extends DataClass implements Insertable<StationResult> {
  final String id;
  final String stationId;
  final double totalFieldMeanNt;
  final double totalFieldStdNt;
  final int sampleCount;
  final bool isAccepted;
  final String? rejectionReason;
  final DateTime calculatedAt;
  const StationResult({
    required this.id,
    required this.stationId,
    required this.totalFieldMeanNt,
    required this.totalFieldStdNt,
    required this.sampleCount,
    required this.isAccepted,
    this.rejectionReason,
    required this.calculatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['station_id'] = Variable<String>(stationId);
    map['total_field_mean_nt'] = Variable<double>(totalFieldMeanNt);
    map['total_field_std_nt'] = Variable<double>(totalFieldStdNt);
    map['sample_count'] = Variable<int>(sampleCount);
    map['is_accepted'] = Variable<bool>(isAccepted);
    if (!nullToAbsent || rejectionReason != null) {
      map['rejection_reason'] = Variable<String>(rejectionReason);
    }
    map['calculated_at'] = Variable<DateTime>(calculatedAt);
    return map;
  }

  StationResultsCompanion toCompanion(bool nullToAbsent) {
    return StationResultsCompanion(
      id: Value(id),
      stationId: Value(stationId),
      totalFieldMeanNt: Value(totalFieldMeanNt),
      totalFieldStdNt: Value(totalFieldStdNt),
      sampleCount: Value(sampleCount),
      isAccepted: Value(isAccepted),
      rejectionReason: rejectionReason == null && nullToAbsent
          ? const Value.absent()
          : Value(rejectionReason),
      calculatedAt: Value(calculatedAt),
    );
  }

  factory StationResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StationResult(
      id: serializer.fromJson<String>(json['id']),
      stationId: serializer.fromJson<String>(json['stationId']),
      totalFieldMeanNt: serializer.fromJson<double>(json['totalFieldMeanNt']),
      totalFieldStdNt: serializer.fromJson<double>(json['totalFieldStdNt']),
      sampleCount: serializer.fromJson<int>(json['sampleCount']),
      isAccepted: serializer.fromJson<bool>(json['isAccepted']),
      rejectionReason: serializer.fromJson<String?>(json['rejectionReason']),
      calculatedAt: serializer.fromJson<DateTime>(json['calculatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'stationId': serializer.toJson<String>(stationId),
      'totalFieldMeanNt': serializer.toJson<double>(totalFieldMeanNt),
      'totalFieldStdNt': serializer.toJson<double>(totalFieldStdNt),
      'sampleCount': serializer.toJson<int>(sampleCount),
      'isAccepted': serializer.toJson<bool>(isAccepted),
      'rejectionReason': serializer.toJson<String?>(rejectionReason),
      'calculatedAt': serializer.toJson<DateTime>(calculatedAt),
    };
  }

  StationResult copyWith({
    String? id,
    String? stationId,
    double? totalFieldMeanNt,
    double? totalFieldStdNt,
    int? sampleCount,
    bool? isAccepted,
    Value<String?> rejectionReason = const Value.absent(),
    DateTime? calculatedAt,
  }) => StationResult(
    id: id ?? this.id,
    stationId: stationId ?? this.stationId,
    totalFieldMeanNt: totalFieldMeanNt ?? this.totalFieldMeanNt,
    totalFieldStdNt: totalFieldStdNt ?? this.totalFieldStdNt,
    sampleCount: sampleCount ?? this.sampleCount,
    isAccepted: isAccepted ?? this.isAccepted,
    rejectionReason: rejectionReason.present
        ? rejectionReason.value
        : this.rejectionReason,
    calculatedAt: calculatedAt ?? this.calculatedAt,
  );
  StationResult copyWithCompanion(StationResultsCompanion data) {
    return StationResult(
      id: data.id.present ? data.id.value : this.id,
      stationId: data.stationId.present ? data.stationId.value : this.stationId,
      totalFieldMeanNt: data.totalFieldMeanNt.present
          ? data.totalFieldMeanNt.value
          : this.totalFieldMeanNt,
      totalFieldStdNt: data.totalFieldStdNt.present
          ? data.totalFieldStdNt.value
          : this.totalFieldStdNt,
      sampleCount: data.sampleCount.present
          ? data.sampleCount.value
          : this.sampleCount,
      isAccepted: data.isAccepted.present
          ? data.isAccepted.value
          : this.isAccepted,
      rejectionReason: data.rejectionReason.present
          ? data.rejectionReason.value
          : this.rejectionReason,
      calculatedAt: data.calculatedAt.present
          ? data.calculatedAt.value
          : this.calculatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StationResult(')
          ..write('id: $id, ')
          ..write('stationId: $stationId, ')
          ..write('totalFieldMeanNt: $totalFieldMeanNt, ')
          ..write('totalFieldStdNt: $totalFieldStdNt, ')
          ..write('sampleCount: $sampleCount, ')
          ..write('isAccepted: $isAccepted, ')
          ..write('rejectionReason: $rejectionReason, ')
          ..write('calculatedAt: $calculatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    stationId,
    totalFieldMeanNt,
    totalFieldStdNt,
    sampleCount,
    isAccepted,
    rejectionReason,
    calculatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StationResult &&
          other.id == this.id &&
          other.stationId == this.stationId &&
          other.totalFieldMeanNt == this.totalFieldMeanNt &&
          other.totalFieldStdNt == this.totalFieldStdNt &&
          other.sampleCount == this.sampleCount &&
          other.isAccepted == this.isAccepted &&
          other.rejectionReason == this.rejectionReason &&
          other.calculatedAt == this.calculatedAt);
}

class StationResultsCompanion extends UpdateCompanion<StationResult> {
  final Value<String> id;
  final Value<String> stationId;
  final Value<double> totalFieldMeanNt;
  final Value<double> totalFieldStdNt;
  final Value<int> sampleCount;
  final Value<bool> isAccepted;
  final Value<String?> rejectionReason;
  final Value<DateTime> calculatedAt;
  final Value<int> rowid;
  const StationResultsCompanion({
    this.id = const Value.absent(),
    this.stationId = const Value.absent(),
    this.totalFieldMeanNt = const Value.absent(),
    this.totalFieldStdNt = const Value.absent(),
    this.sampleCount = const Value.absent(),
    this.isAccepted = const Value.absent(),
    this.rejectionReason = const Value.absent(),
    this.calculatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StationResultsCompanion.insert({
    required String id,
    required String stationId,
    required double totalFieldMeanNt,
    required double totalFieldStdNt,
    required int sampleCount,
    required bool isAccepted,
    this.rejectionReason = const Value.absent(),
    this.calculatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       stationId = Value(stationId),
       totalFieldMeanNt = Value(totalFieldMeanNt),
       totalFieldStdNt = Value(totalFieldStdNt),
       sampleCount = Value(sampleCount),
       isAccepted = Value(isAccepted);
  static Insertable<StationResult> custom({
    Expression<String>? id,
    Expression<String>? stationId,
    Expression<double>? totalFieldMeanNt,
    Expression<double>? totalFieldStdNt,
    Expression<int>? sampleCount,
    Expression<bool>? isAccepted,
    Expression<String>? rejectionReason,
    Expression<DateTime>? calculatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stationId != null) 'station_id': stationId,
      if (totalFieldMeanNt != null) 'total_field_mean_nt': totalFieldMeanNt,
      if (totalFieldStdNt != null) 'total_field_std_nt': totalFieldStdNt,
      if (sampleCount != null) 'sample_count': sampleCount,
      if (isAccepted != null) 'is_accepted': isAccepted,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (calculatedAt != null) 'calculated_at': calculatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StationResultsCompanion copyWith({
    Value<String>? id,
    Value<String>? stationId,
    Value<double>? totalFieldMeanNt,
    Value<double>? totalFieldStdNt,
    Value<int>? sampleCount,
    Value<bool>? isAccepted,
    Value<String?>? rejectionReason,
    Value<DateTime>? calculatedAt,
    Value<int>? rowid,
  }) {
    return StationResultsCompanion(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      totalFieldMeanNt: totalFieldMeanNt ?? this.totalFieldMeanNt,
      totalFieldStdNt: totalFieldStdNt ?? this.totalFieldStdNt,
      sampleCount: sampleCount ?? this.sampleCount,
      isAccepted: isAccepted ?? this.isAccepted,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stationId.present) {
      map['station_id'] = Variable<String>(stationId.value);
    }
    if (totalFieldMeanNt.present) {
      map['total_field_mean_nt'] = Variable<double>(totalFieldMeanNt.value);
    }
    if (totalFieldStdNt.present) {
      map['total_field_std_nt'] = Variable<double>(totalFieldStdNt.value);
    }
    if (sampleCount.present) {
      map['sample_count'] = Variable<int>(sampleCount.value);
    }
    if (isAccepted.present) {
      map['is_accepted'] = Variable<bool>(isAccepted.value);
    }
    if (rejectionReason.present) {
      map['rejection_reason'] = Variable<String>(rejectionReason.value);
    }
    if (calculatedAt.present) {
      map['calculated_at'] = Variable<DateTime>(calculatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StationResultsCompanion(')
          ..write('id: $id, ')
          ..write('stationId: $stationId, ')
          ..write('totalFieldMeanNt: $totalFieldMeanNt, ')
          ..write('totalFieldStdNt: $totalFieldStdNt, ')
          ..write('sampleCount: $sampleCount, ')
          ..write('isAccepted: $isAccepted, ')
          ..write('rejectionReason: $rejectionReason, ')
          ..write('calculatedAt: $calculatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnomaliesTable extends Anomalies
    with TableInfo<$AnomaliesTable, Anomaly> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnomaliesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stationIdMeta = const VerificationMeta(
    'stationId',
  );
  @override
  late final GeneratedColumn<String> stationId = GeneratedColumn<String>(
    'station_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES stations (id)',
    ),
  );
  static const VerificationMeta _fIgrfNtMeta = const VerificationMeta(
    'fIgrfNt',
  );
  @override
  late final GeneratedColumn<double> fIgrfNt = GeneratedColumn<double>(
    'f_igrf_nt',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diurnalCorrectionNtMeta =
      const VerificationMeta('diurnalCorrectionNt');
  @override
  late final GeneratedColumn<double> diurnalCorrectionNt =
      GeneratedColumn<double>(
        'diurnal_correction_nt',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deltaTNtMeta = const VerificationMeta(
    'deltaTNt',
  );
  @override
  late final GeneratedColumn<double> deltaTNt = GeneratedColumn<double>(
    'delta_t_nt',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calculatedAtMeta = const VerificationMeta(
    'calculatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> calculatedAt = GeneratedColumn<DateTime>(
    'calculated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    stationId,
    fIgrfNt,
    diurnalCorrectionNt,
    deltaTNt,
    calculatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'anomalies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Anomaly> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('station_id')) {
      context.handle(
        _stationIdMeta,
        stationId.isAcceptableOrUnknown(data['station_id']!, _stationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stationIdMeta);
    }
    if (data.containsKey('f_igrf_nt')) {
      context.handle(
        _fIgrfNtMeta,
        fIgrfNt.isAcceptableOrUnknown(data['f_igrf_nt']!, _fIgrfNtMeta),
      );
    }
    if (data.containsKey('diurnal_correction_nt')) {
      context.handle(
        _diurnalCorrectionNtMeta,
        diurnalCorrectionNt.isAcceptableOrUnknown(
          data['diurnal_correction_nt']!,
          _diurnalCorrectionNtMeta,
        ),
      );
    }
    if (data.containsKey('delta_t_nt')) {
      context.handle(
        _deltaTNtMeta,
        deltaTNt.isAcceptableOrUnknown(data['delta_t_nt']!, _deltaTNtMeta),
      );
    }
    if (data.containsKey('calculated_at')) {
      context.handle(
        _calculatedAtMeta,
        calculatedAt.isAcceptableOrUnknown(
          data['calculated_at']!,
          _calculatedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Anomaly map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Anomaly(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      stationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_id'],
      )!,
      fIgrfNt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}f_igrf_nt'],
      ),
      diurnalCorrectionNt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}diurnal_correction_nt'],
      ),
      deltaTNt: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}delta_t_nt'],
      ),
      calculatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}calculated_at'],
      )!,
    );
  }

  @override
  $AnomaliesTable createAlias(String alias) {
    return $AnomaliesTable(attachedDatabase, alias);
  }
}

class Anomaly extends DataClass implements Insertable<Anomaly> {
  final String id;
  final String stationId;
  final double? fIgrfNt;
  final double? diurnalCorrectionNt;
  final double? deltaTNt;
  final DateTime calculatedAt;
  const Anomaly({
    required this.id,
    required this.stationId,
    this.fIgrfNt,
    this.diurnalCorrectionNt,
    this.deltaTNt,
    required this.calculatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['station_id'] = Variable<String>(stationId);
    if (!nullToAbsent || fIgrfNt != null) {
      map['f_igrf_nt'] = Variable<double>(fIgrfNt);
    }
    if (!nullToAbsent || diurnalCorrectionNt != null) {
      map['diurnal_correction_nt'] = Variable<double>(diurnalCorrectionNt);
    }
    if (!nullToAbsent || deltaTNt != null) {
      map['delta_t_nt'] = Variable<double>(deltaTNt);
    }
    map['calculated_at'] = Variable<DateTime>(calculatedAt);
    return map;
  }

  AnomaliesCompanion toCompanion(bool nullToAbsent) {
    return AnomaliesCompanion(
      id: Value(id),
      stationId: Value(stationId),
      fIgrfNt: fIgrfNt == null && nullToAbsent
          ? const Value.absent()
          : Value(fIgrfNt),
      diurnalCorrectionNt: diurnalCorrectionNt == null && nullToAbsent
          ? const Value.absent()
          : Value(diurnalCorrectionNt),
      deltaTNt: deltaTNt == null && nullToAbsent
          ? const Value.absent()
          : Value(deltaTNt),
      calculatedAt: Value(calculatedAt),
    );
  }

  factory Anomaly.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Anomaly(
      id: serializer.fromJson<String>(json['id']),
      stationId: serializer.fromJson<String>(json['stationId']),
      fIgrfNt: serializer.fromJson<double?>(json['fIgrfNt']),
      diurnalCorrectionNt: serializer.fromJson<double?>(
        json['diurnalCorrectionNt'],
      ),
      deltaTNt: serializer.fromJson<double?>(json['deltaTNt']),
      calculatedAt: serializer.fromJson<DateTime>(json['calculatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'stationId': serializer.toJson<String>(stationId),
      'fIgrfNt': serializer.toJson<double?>(fIgrfNt),
      'diurnalCorrectionNt': serializer.toJson<double?>(diurnalCorrectionNt),
      'deltaTNt': serializer.toJson<double?>(deltaTNt),
      'calculatedAt': serializer.toJson<DateTime>(calculatedAt),
    };
  }

  Anomaly copyWith({
    String? id,
    String? stationId,
    Value<double?> fIgrfNt = const Value.absent(),
    Value<double?> diurnalCorrectionNt = const Value.absent(),
    Value<double?> deltaTNt = const Value.absent(),
    DateTime? calculatedAt,
  }) => Anomaly(
    id: id ?? this.id,
    stationId: stationId ?? this.stationId,
    fIgrfNt: fIgrfNt.present ? fIgrfNt.value : this.fIgrfNt,
    diurnalCorrectionNt: diurnalCorrectionNt.present
        ? diurnalCorrectionNt.value
        : this.diurnalCorrectionNt,
    deltaTNt: deltaTNt.present ? deltaTNt.value : this.deltaTNt,
    calculatedAt: calculatedAt ?? this.calculatedAt,
  );
  Anomaly copyWithCompanion(AnomaliesCompanion data) {
    return Anomaly(
      id: data.id.present ? data.id.value : this.id,
      stationId: data.stationId.present ? data.stationId.value : this.stationId,
      fIgrfNt: data.fIgrfNt.present ? data.fIgrfNt.value : this.fIgrfNt,
      diurnalCorrectionNt: data.diurnalCorrectionNt.present
          ? data.diurnalCorrectionNt.value
          : this.diurnalCorrectionNt,
      deltaTNt: data.deltaTNt.present ? data.deltaTNt.value : this.deltaTNt,
      calculatedAt: data.calculatedAt.present
          ? data.calculatedAt.value
          : this.calculatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Anomaly(')
          ..write('id: $id, ')
          ..write('stationId: $stationId, ')
          ..write('fIgrfNt: $fIgrfNt, ')
          ..write('diurnalCorrectionNt: $diurnalCorrectionNt, ')
          ..write('deltaTNt: $deltaTNt, ')
          ..write('calculatedAt: $calculatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    stationId,
    fIgrfNt,
    diurnalCorrectionNt,
    deltaTNt,
    calculatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Anomaly &&
          other.id == this.id &&
          other.stationId == this.stationId &&
          other.fIgrfNt == this.fIgrfNt &&
          other.diurnalCorrectionNt == this.diurnalCorrectionNt &&
          other.deltaTNt == this.deltaTNt &&
          other.calculatedAt == this.calculatedAt);
}

class AnomaliesCompanion extends UpdateCompanion<Anomaly> {
  final Value<String> id;
  final Value<String> stationId;
  final Value<double?> fIgrfNt;
  final Value<double?> diurnalCorrectionNt;
  final Value<double?> deltaTNt;
  final Value<DateTime> calculatedAt;
  final Value<int> rowid;
  const AnomaliesCompanion({
    this.id = const Value.absent(),
    this.stationId = const Value.absent(),
    this.fIgrfNt = const Value.absent(),
    this.diurnalCorrectionNt = const Value.absent(),
    this.deltaTNt = const Value.absent(),
    this.calculatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnomaliesCompanion.insert({
    required String id,
    required String stationId,
    this.fIgrfNt = const Value.absent(),
    this.diurnalCorrectionNt = const Value.absent(),
    this.deltaTNt = const Value.absent(),
    this.calculatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       stationId = Value(stationId);
  static Insertable<Anomaly> custom({
    Expression<String>? id,
    Expression<String>? stationId,
    Expression<double>? fIgrfNt,
    Expression<double>? diurnalCorrectionNt,
    Expression<double>? deltaTNt,
    Expression<DateTime>? calculatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (stationId != null) 'station_id': stationId,
      if (fIgrfNt != null) 'f_igrf_nt': fIgrfNt,
      if (diurnalCorrectionNt != null)
        'diurnal_correction_nt': diurnalCorrectionNt,
      if (deltaTNt != null) 'delta_t_nt': deltaTNt,
      if (calculatedAt != null) 'calculated_at': calculatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnomaliesCompanion copyWith({
    Value<String>? id,
    Value<String>? stationId,
    Value<double?>? fIgrfNt,
    Value<double?>? diurnalCorrectionNt,
    Value<double?>? deltaTNt,
    Value<DateTime>? calculatedAt,
    Value<int>? rowid,
  }) {
    return AnomaliesCompanion(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      fIgrfNt: fIgrfNt ?? this.fIgrfNt,
      diurnalCorrectionNt: diurnalCorrectionNt ?? this.diurnalCorrectionNt,
      deltaTNt: deltaTNt ?? this.deltaTNt,
      calculatedAt: calculatedAt ?? this.calculatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (stationId.present) {
      map['station_id'] = Variable<String>(stationId.value);
    }
    if (fIgrfNt.present) {
      map['f_igrf_nt'] = Variable<double>(fIgrfNt.value);
    }
    if (diurnalCorrectionNt.present) {
      map['diurnal_correction_nt'] = Variable<double>(
        diurnalCorrectionNt.value,
      );
    }
    if (deltaTNt.present) {
      map['delta_t_nt'] = Variable<double>(deltaTNt.value);
    }
    if (calculatedAt.present) {
      map['calculated_at'] = Variable<DateTime>(calculatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnomaliesCompanion(')
          ..write('id: $id, ')
          ..write('stationId: $stationId, ')
          ..write('fIgrfNt: $fIgrfNt, ')
          ..write('diurnalCorrectionNt: $diurnalCorrectionNt, ')
          ..write('deltaTNt: $deltaTNt, ')
          ..write('calculatedAt: $calculatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DevicesTable devices = $DevicesTable(this);
  late final $CalibrationProfilesTable calibrationProfiles =
      $CalibrationProfilesTable(this);
  late final $SurveysTable surveys = $SurveysTable(this);
  late final $StationsTable stations = $StationsTable(this);
  late final $SamplesTable samples = $SamplesTable(this);
  late final $StationResultsTable stationResults = $StationResultsTable(this);
  late final $AnomaliesTable anomalies = $AnomaliesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    devices,
    calibrationProfiles,
    surveys,
    stations,
    samples,
    stationResults,
    anomalies,
  ];
}

typedef $$DevicesTableCreateCompanionBuilder =
    DevicesCompanion Function({
      required String id,
      required String model,
      required String androidVersion,
      required String magnetometerChip,
      Value<double?> noiseFloorNt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DevicesTableUpdateCompanionBuilder =
    DevicesCompanion Function({
      Value<String> id,
      Value<String> model,
      Value<String> androidVersion,
      Value<String> magnetometerChip,
      Value<double?> noiseFloorNt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$DevicesTableReferences
    extends BaseReferences<_$AppDatabase, $DevicesTable, Device> {
  $$DevicesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $CalibrationProfilesTable,
    List<CalibrationProfile>
  >
  _calibrationProfilesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.calibrationProfiles,
        aliasName: 'devices__id__calibration_profiles__device_id',
      );

  $$CalibrationProfilesTableProcessedTableManager get calibrationProfilesRefs {
    final manager = $$CalibrationProfilesTableTableManager(
      $_db,
      $_db.calibrationProfiles,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _calibrationProfilesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SurveysTable, List<Survey>> _surveysRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.surveys,
    aliasName: 'devices__id__surveys__device_id',
  );

  $$SurveysTableProcessedTableManager get surveysRefs {
    final manager = $$SurveysTableTableManager(
      $_db,
      $_db.surveys,
    ).filter((f) => f.deviceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_surveysRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DevicesTableFilterComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get androidVersion => $composableBuilder(
    column: $table.androidVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get magnetometerChip => $composableBuilder(
    column: $table.magnetometerChip,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get noiseFloorNt => $composableBuilder(
    column: $table.noiseFloorNt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> calibrationProfilesRefs(
    Expression<bool> Function($$CalibrationProfilesTableFilterComposer f) f,
  ) {
    final $$CalibrationProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.calibrationProfiles,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalibrationProfilesTableFilterComposer(
            $db: $db,
            $table: $db.calibrationProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> surveysRefs(
    Expression<bool> Function($$SurveysTableFilterComposer f) f,
  ) {
    final $$SurveysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableFilterComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get androidVersion => $composableBuilder(
    column: $table.androidVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get magnetometerChip => $composableBuilder(
    column: $table.magnetometerChip,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get noiseFloorNt => $composableBuilder(
    column: $table.noiseFloorNt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DevicesTable> {
  $$DevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get androidVersion => $composableBuilder(
    column: $table.androidVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get magnetometerChip => $composableBuilder(
    column: $table.magnetometerChip,
    builder: (column) => column,
  );

  GeneratedColumn<double> get noiseFloorNt => $composableBuilder(
    column: $table.noiseFloorNt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> calibrationProfilesRefs<T extends Object>(
    Expression<T> Function($$CalibrationProfilesTableAnnotationComposer a) f,
  ) {
    final $$CalibrationProfilesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.calibrationProfiles,
          getReferencedColumn: (t) => t.deviceId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalibrationProfilesTableAnnotationComposer(
                $db: $db,
                $table: $db.calibrationProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> surveysRefs<T extends Object>(
    Expression<T> Function($$SurveysTableAnnotationComposer a) f,
  ) {
    final $$SurveysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.deviceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableAnnotationComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DevicesTable,
          Device,
          $$DevicesTableFilterComposer,
          $$DevicesTableOrderingComposer,
          $$DevicesTableAnnotationComposer,
          $$DevicesTableCreateCompanionBuilder,
          $$DevicesTableUpdateCompanionBuilder,
          (Device, $$DevicesTableReferences),
          Device,
          PrefetchHooks Function({
            bool calibrationProfilesRefs,
            bool surveysRefs,
          })
        > {
  $$DevicesTableTableManager(_$AppDatabase db, $DevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> androidVersion = const Value.absent(),
                Value<String> magnetometerChip = const Value.absent(),
                Value<double?> noiseFloorNt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion(
                id: id,
                model: model,
                androidVersion: androidVersion,
                magnetometerChip: magnetometerChip,
                noiseFloorNt: noiseFloorNt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String model,
                required String androidVersion,
                required String magnetometerChip,
                Value<double?> noiseFloorNt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DevicesCompanion.insert(
                id: id,
                model: model,
                androidVersion: androidVersion,
                magnetometerChip: magnetometerChip,
                noiseFloorNt: noiseFloorNt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DevicesTable, Device>(table),
                  $$DevicesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({calibrationProfilesRefs = false, surveysRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (calibrationProfilesRefs) db.calibrationProfiles,
                    if (surveysRefs) db.surveys,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (calibrationProfilesRefs)
                        await $_getPrefetchedDataByColumns<
                          Device,
                          $DevicesTable,
                          CalibrationProfile,
                          $CalibrationProfilesTable
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._calibrationProfilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).calibrationProfilesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'device_id',
                          typedResults: items,
                        ),
                      if (surveysRefs)
                        await $_getPrefetchedDataByColumns<
                          Device,
                          $DevicesTable,
                          Survey,
                          $SurveysTable
                        >(
                          currentTable: table,
                          referencedTable: $$DevicesTableReferences
                              ._surveysRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DevicesTableReferences(
                                db,
                                table,
                                p0,
                              ).surveysRefs,
                          currentColumn: 'id',
                          referencedColumn: 'device_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DevicesTable,
      Device,
      $$DevicesTableFilterComposer,
      $$DevicesTableOrderingComposer,
      $$DevicesTableAnnotationComposer,
      $$DevicesTableCreateCompanionBuilder,
      $$DevicesTableUpdateCompanionBuilder,
      (Device, $$DevicesTableReferences),
      Device,
      PrefetchHooks Function({bool calibrationProfilesRefs, bool surveysRefs})
    >;
typedef $$CalibrationProfilesTableCreateCompanionBuilder =
    CalibrationProfilesCompanion Function({
      required String id,
      required String deviceId,
      required DateTime timestamp,
      required double hardIronBxMicroT,
      required double hardIronByMicroT,
      required double hardIronBzMicroT,
      required String matrixA,
      Value<double?> temperatureC,
      Value<bool> casingAttached,
      required double residualNt,
      Value<DateTime?> expiresAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$CalibrationProfilesTableUpdateCompanionBuilder =
    CalibrationProfilesCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<DateTime> timestamp,
      Value<double> hardIronBxMicroT,
      Value<double> hardIronByMicroT,
      Value<double> hardIronBzMicroT,
      Value<String> matrixA,
      Value<double?> temperatureC,
      Value<bool> casingAttached,
      Value<double> residualNt,
      Value<DateTime?> expiresAt,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$CalibrationProfilesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $CalibrationProfilesTable,
          CalibrationProfile
        > {
  $$CalibrationProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias('calibration_profiles__device_id__devices__id');

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SamplesTable, List<Sample>> _samplesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.samples,
    aliasName: 'calibration_profiles__id__samples__calibration_id',
  );

  $$SamplesTableProcessedTableManager get samplesRefs {
    final manager = $$SamplesTableTableManager(
      $_db,
      $_db.samples,
    ).filter((f) => f.calibrationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_samplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CalibrationProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $CalibrationProfilesTable> {
  $$CalibrationProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hardIronBxMicroT => $composableBuilder(
    column: $table.hardIronBxMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hardIronByMicroT => $composableBuilder(
    column: $table.hardIronByMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hardIronBzMicroT => $composableBuilder(
    column: $table.hardIronBzMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get matrixA => $composableBuilder(
    column: $table.matrixA,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get casingAttached => $composableBuilder(
    column: $table.casingAttached,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get residualNt => $composableBuilder(
    column: $table.residualNt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> samplesRefs(
    Expression<bool> Function($$SamplesTableFilterComposer f) f,
  ) {
    final $$SamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.calibrationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableFilterComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CalibrationProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $CalibrationProfilesTable> {
  $$CalibrationProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hardIronBxMicroT => $composableBuilder(
    column: $table.hardIronBxMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hardIronByMicroT => $composableBuilder(
    column: $table.hardIronByMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hardIronBzMicroT => $composableBuilder(
    column: $table.hardIronBzMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get matrixA => $composableBuilder(
    column: $table.matrixA,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get casingAttached => $composableBuilder(
    column: $table.casingAttached,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get residualNt => $composableBuilder(
    column: $table.residualNt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CalibrationProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CalibrationProfilesTable> {
  $$CalibrationProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<double> get hardIronBxMicroT => $composableBuilder(
    column: $table.hardIronBxMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<double> get hardIronByMicroT => $composableBuilder(
    column: $table.hardIronByMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<double> get hardIronBzMicroT => $composableBuilder(
    column: $table.hardIronBzMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<String> get matrixA =>
      $composableBuilder(column: $table.matrixA, builder: (column) => column);

  GeneratedColumn<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get casingAttached => $composableBuilder(
    column: $table.casingAttached,
    builder: (column) => column,
  );

  GeneratedColumn<double> get residualNt => $composableBuilder(
    column: $table.residualNt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> samplesRefs<T extends Object>(
    Expression<T> Function($$SamplesTableAnnotationComposer a) f,
  ) {
    final $$SamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.calibrationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CalibrationProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CalibrationProfilesTable,
          CalibrationProfile,
          $$CalibrationProfilesTableFilterComposer,
          $$CalibrationProfilesTableOrderingComposer,
          $$CalibrationProfilesTableAnnotationComposer,
          $$CalibrationProfilesTableCreateCompanionBuilder,
          $$CalibrationProfilesTableUpdateCompanionBuilder,
          (CalibrationProfile, $$CalibrationProfilesTableReferences),
          CalibrationProfile,
          PrefetchHooks Function({bool deviceId, bool samplesRefs})
        > {
  $$CalibrationProfilesTableTableManager(
    _$AppDatabase db,
    $CalibrationProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CalibrationProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CalibrationProfilesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$CalibrationProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<double> hardIronBxMicroT = const Value.absent(),
                Value<double> hardIronByMicroT = const Value.absent(),
                Value<double> hardIronBzMicroT = const Value.absent(),
                Value<String> matrixA = const Value.absent(),
                Value<double?> temperatureC = const Value.absent(),
                Value<bool> casingAttached = const Value.absent(),
                Value<double> residualNt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalibrationProfilesCompanion(
                id: id,
                deviceId: deviceId,
                timestamp: timestamp,
                hardIronBxMicroT: hardIronBxMicroT,
                hardIronByMicroT: hardIronByMicroT,
                hardIronBzMicroT: hardIronBzMicroT,
                matrixA: matrixA,
                temperatureC: temperatureC,
                casingAttached: casingAttached,
                residualNt: residualNt,
                expiresAt: expiresAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required DateTime timestamp,
                required double hardIronBxMicroT,
                required double hardIronByMicroT,
                required double hardIronBzMicroT,
                required String matrixA,
                Value<double?> temperatureC = const Value.absent(),
                Value<bool> casingAttached = const Value.absent(),
                required double residualNt,
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CalibrationProfilesCompanion.insert(
                id: id,
                deviceId: deviceId,
                timestamp: timestamp,
                hardIronBxMicroT: hardIronBxMicroT,
                hardIronByMicroT: hardIronByMicroT,
                hardIronBzMicroT: hardIronBzMicroT,
                matrixA: matrixA,
                temperatureC: temperatureC,
                casingAttached: casingAttached,
                residualNt: residualNt,
                expiresAt: expiresAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CalibrationProfilesTable, CalibrationProfile>(
                    table,
                  ),
                  $$CalibrationProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({deviceId = false, samplesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (samplesRefs) db.samples],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (deviceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.deviceId,
                                referencedTable:
                                    $$CalibrationProfilesTableReferences
                                        ._deviceIdTable(db),
                                referencedColumn:
                                    $$CalibrationProfilesTableReferences
                                        ._deviceIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (samplesRefs)
                    await $_getPrefetchedDataByColumns<
                      CalibrationProfile,
                      $CalibrationProfilesTable,
                      Sample,
                      $SamplesTable
                    >(
                      currentTable: table,
                      referencedTable: $$CalibrationProfilesTableReferences
                          ._samplesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CalibrationProfilesTableReferences(
                            db,
                            table,
                            p0,
                          ).samplesRefs,
                      currentColumn: 'id',
                      referencedColumn: 'calibration_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CalibrationProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CalibrationProfilesTable,
      CalibrationProfile,
      $$CalibrationProfilesTableFilterComposer,
      $$CalibrationProfilesTableOrderingComposer,
      $$CalibrationProfilesTableAnnotationComposer,
      $$CalibrationProfilesTableCreateCompanionBuilder,
      $$CalibrationProfilesTableUpdateCompanionBuilder,
      (CalibrationProfile, $$CalibrationProfilesTableReferences),
      CalibrationProfile,
      PrefetchHooks Function({bool deviceId, bool samplesRefs})
    >;
typedef $$SurveysTableCreateCompanionBuilder =
    SurveysCompanion Function({
      required String id,
      required String deviceId,
      required String name,
      required DateTime date,
      required String mode,
      Value<String?> notes,
      Value<String?> baseSurveyId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$SurveysTableUpdateCompanionBuilder =
    SurveysCompanion Function({
      Value<String> id,
      Value<String> deviceId,
      Value<String> name,
      Value<DateTime> date,
      Value<String> mode,
      Value<String?> notes,
      Value<String?> baseSurveyId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$SurveysTableReferences
    extends BaseReferences<_$AppDatabase, $SurveysTable, Survey> {
  $$SurveysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DevicesTable _deviceIdTable(_$AppDatabase db) =>
      db.devices.createAlias('surveys__device_id__devices__id');

  $$DevicesTableProcessedTableManager get deviceId {
    final $_column = $_itemColumn<String>('device_id')!;

    final manager = $$DevicesTableTableManager(
      $_db,
      $_db.devices,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_deviceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SurveysTable _baseSurveyIdTable(_$AppDatabase db) =>
      db.surveys.createAlias('surveys__base_survey_id__surveys__id');

  $$SurveysTableProcessedTableManager? get baseSurveyId {
    final $_column = $_itemColumn<String>('base_survey_id');
    if ($_column == null) return null;
    final manager = $$SurveysTableTableManager(
      $_db,
      $_db.surveys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_baseSurveyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StationsTable, List<Station>> _stationsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.stations,
    aliasName: 'surveys__id__stations__survey_id',
  );

  $$StationsTableProcessedTableManager get stationsRefs {
    final manager = $$StationsTableTableManager(
      $_db,
      $_db.stations,
    ).filter((f) => f.surveyId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SurveysTableFilterComposer
    extends Composer<_$AppDatabase, $SurveysTable> {
  $$SurveysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$DevicesTableFilterComposer get deviceId {
    final $$DevicesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableFilterComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SurveysTableFilterComposer get baseSurveyId {
    final $$SurveysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.baseSurveyId,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableFilterComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stationsRefs(
    Expression<bool> Function($$StationsTableFilterComposer f) f,
  ) {
    final $$StationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.surveyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableFilterComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SurveysTableOrderingComposer
    extends Composer<_$AppDatabase, $SurveysTable> {
  $$SurveysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$DevicesTableOrderingComposer get deviceId {
    final $$DevicesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableOrderingComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SurveysTableOrderingComposer get baseSurveyId {
    final $$SurveysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.baseSurveyId,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableOrderingComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SurveysTableAnnotationComposer
    extends Composer<_$AppDatabase, $SurveysTable> {
  $$SurveysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$DevicesTableAnnotationComposer get deviceId {
    final $$DevicesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.deviceId,
      referencedTable: $db.devices,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DevicesTableAnnotationComposer(
            $db: $db,
            $table: $db.devices,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SurveysTableAnnotationComposer get baseSurveyId {
    final $$SurveysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.baseSurveyId,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableAnnotationComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stationsRefs<T extends Object>(
    Expression<T> Function($$StationsTableAnnotationComposer a) f,
  ) {
    final $$StationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.surveyId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableAnnotationComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SurveysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SurveysTable,
          Survey,
          $$SurveysTableFilterComposer,
          $$SurveysTableOrderingComposer,
          $$SurveysTableAnnotationComposer,
          $$SurveysTableCreateCompanionBuilder,
          $$SurveysTableUpdateCompanionBuilder,
          (Survey, $$SurveysTableReferences),
          Survey,
          PrefetchHooks Function({
            bool deviceId,
            bool baseSurveyId,
            bool stationsRefs,
          })
        > {
  $$SurveysTableTableManager(_$AppDatabase db, $SurveysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurveysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurveysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurveysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> baseSurveyId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurveysCompanion(
                id: id,
                deviceId: deviceId,
                name: name,
                date: date,
                mode: mode,
                notes: notes,
                baseSurveyId: baseSurveyId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deviceId,
                required String name,
                required DateTime date,
                required String mode,
                Value<String?> notes = const Value.absent(),
                Value<String?> baseSurveyId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SurveysCompanion.insert(
                id: id,
                deviceId: deviceId,
                name: name,
                date: date,
                mode: mode,
                notes: notes,
                baseSurveyId: baseSurveyId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SurveysTable, Survey>(table),
                  $$SurveysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({deviceId = false, baseSurveyId = false, stationsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (stationsRefs) db.stations],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (deviceId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.deviceId,
                                    referencedTable: $$SurveysTableReferences
                                        ._deviceIdTable(db),
                                    referencedColumn: $$SurveysTableReferences
                                        ._deviceIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (baseSurveyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.baseSurveyId,
                                    referencedTable: $$SurveysTableReferences
                                        ._baseSurveyIdTable(db),
                                    referencedColumn: $$SurveysTableReferences
                                        ._baseSurveyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stationsRefs)
                        await $_getPrefetchedDataByColumns<
                          Survey,
                          $SurveysTable,
                          Station,
                          $StationsTable
                        >(
                          currentTable: table,
                          referencedTable: $$SurveysTableReferences
                              ._stationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SurveysTableReferences(
                                db,
                                table,
                                p0,
                              ).stationsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'survey_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SurveysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SurveysTable,
      Survey,
      $$SurveysTableFilterComposer,
      $$SurveysTableOrderingComposer,
      $$SurveysTableAnnotationComposer,
      $$SurveysTableCreateCompanionBuilder,
      $$SurveysTableUpdateCompanionBuilder,
      (Survey, $$SurveysTableReferences),
      Survey,
      PrefetchHooks Function({
        bool deviceId,
        bool baseSurveyId,
        bool stationsRefs,
      })
    >;
typedef $$StationsTableCreateCompanionBuilder =
    StationsCompanion Function({
      required String id,
      required String surveyId,
      required int sequenceNumber,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> gpsAccuracyM,
      Value<double?> localX,
      Value<double?> localY,
      Value<double?> sensorHeightM,
      Value<double?> holdingDirectionDeg,
      Value<String?> environmentNotes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$StationsTableUpdateCompanionBuilder =
    StationsCompanion Function({
      Value<String> id,
      Value<String> surveyId,
      Value<int> sequenceNumber,
      Value<double?> latitude,
      Value<double?> longitude,
      Value<double?> gpsAccuracyM,
      Value<double?> localX,
      Value<double?> localY,
      Value<double?> sensorHeightM,
      Value<double?> holdingDirectionDeg,
      Value<String?> environmentNotes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$StationsTableReferences
    extends BaseReferences<_$AppDatabase, $StationsTable, Station> {
  $$StationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SurveysTable _surveyIdTable(_$AppDatabase db) =>
      db.surveys.createAlias('stations__survey_id__surveys__id');

  $$SurveysTableProcessedTableManager get surveyId {
    final $_column = $_itemColumn<String>('survey_id')!;

    final manager = $$SurveysTableTableManager(
      $_db,
      $_db.surveys,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_surveyIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$SamplesTable, List<Sample>> _samplesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.samples,
    aliasName: 'stations__id__samples__station_id',
  );

  $$SamplesTableProcessedTableManager get samplesRefs {
    final manager = $$SamplesTableTableManager(
      $_db,
      $_db.samples,
    ).filter((f) => f.stationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_samplesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$StationResultsTable, List<StationResult>>
  _stationResultsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stationResults,
    aliasName: 'stations__id__station_results__station_id',
  );

  $$StationResultsTableProcessedTableManager get stationResultsRefs {
    final manager = $$StationResultsTableTableManager(
      $_db,
      $_db.stationResults,
    ).filter((f) => f.stationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_stationResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AnomaliesTable, List<Anomaly>>
  _anomaliesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.anomalies,
    aliasName: 'stations__id__anomalies__station_id',
  );

  $$AnomaliesTableProcessedTableManager get anomaliesRefs {
    final manager = $$AnomaliesTableTableManager(
      $_db,
      $_db.anomalies,
    ).filter((f) => f.stationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_anomaliesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StationsTableFilterComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gpsAccuracyM => $composableBuilder(
    column: $table.gpsAccuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get localX => $composableBuilder(
    column: $table.localX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get localY => $composableBuilder(
    column: $table.localY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sensorHeightM => $composableBuilder(
    column: $table.sensorHeightM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get holdingDirectionDeg => $composableBuilder(
    column: $table.holdingDirectionDeg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get environmentNotes => $composableBuilder(
    column: $table.environmentNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SurveysTableFilterComposer get surveyId {
    final $$SurveysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surveyId,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableFilterComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> samplesRefs(
    Expression<bool> Function($$SamplesTableFilterComposer f) f,
  ) {
    final $$SamplesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableFilterComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> stationResultsRefs(
    Expression<bool> Function($$StationResultsTableFilterComposer f) f,
  ) {
    final $$StationResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stationResults,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationResultsTableFilterComposer(
            $db: $db,
            $table: $db.stationResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> anomaliesRefs(
    Expression<bool> Function($$AnomaliesTableFilterComposer f) f,
  ) {
    final $$AnomaliesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anomalies,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnomaliesTableFilterComposer(
            $db: $db,
            $table: $db.anomalies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StationsTableOrderingComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gpsAccuracyM => $composableBuilder(
    column: $table.gpsAccuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get localX => $composableBuilder(
    column: $table.localX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get localY => $composableBuilder(
    column: $table.localY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sensorHeightM => $composableBuilder(
    column: $table.sensorHeightM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get holdingDirectionDeg => $composableBuilder(
    column: $table.holdingDirectionDeg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get environmentNotes => $composableBuilder(
    column: $table.environmentNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SurveysTableOrderingComposer get surveyId {
    final $$SurveysTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surveyId,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableOrderingComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StationsTable> {
  $$StationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get gpsAccuracyM => $composableBuilder(
    column: $table.gpsAccuracyM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get localX =>
      $composableBuilder(column: $table.localX, builder: (column) => column);

  GeneratedColumn<double> get localY =>
      $composableBuilder(column: $table.localY, builder: (column) => column);

  GeneratedColumn<double> get sensorHeightM => $composableBuilder(
    column: $table.sensorHeightM,
    builder: (column) => column,
  );

  GeneratedColumn<double> get holdingDirectionDeg => $composableBuilder(
    column: $table.holdingDirectionDeg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get environmentNotes => $composableBuilder(
    column: $table.environmentNotes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SurveysTableAnnotationComposer get surveyId {
    final $$SurveysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.surveyId,
      referencedTable: $db.surveys,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SurveysTableAnnotationComposer(
            $db: $db,
            $table: $db.surveys,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> samplesRefs<T extends Object>(
    Expression<T> Function($$SamplesTableAnnotationComposer a) f,
  ) {
    final $$SamplesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.samples,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SamplesTableAnnotationComposer(
            $db: $db,
            $table: $db.samples,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> stationResultsRefs<T extends Object>(
    Expression<T> Function($$StationResultsTableAnnotationComposer a) f,
  ) {
    final $$StationResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stationResults,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.stationResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> anomaliesRefs<T extends Object>(
    Expression<T> Function($$AnomaliesTableAnnotationComposer a) f,
  ) {
    final $$AnomaliesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.anomalies,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AnomaliesTableAnnotationComposer(
            $db: $db,
            $table: $db.anomalies,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StationsTable,
          Station,
          $$StationsTableFilterComposer,
          $$StationsTableOrderingComposer,
          $$StationsTableAnnotationComposer,
          $$StationsTableCreateCompanionBuilder,
          $$StationsTableUpdateCompanionBuilder,
          (Station, $$StationsTableReferences),
          Station,
          PrefetchHooks Function({
            bool surveyId,
            bool samplesRefs,
            bool stationResultsRefs,
            bool anomaliesRefs,
          })
        > {
  $$StationsTableTableManager(_$AppDatabase db, $StationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> surveyId = const Value.absent(),
                Value<int> sequenceNumber = const Value.absent(),
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> gpsAccuracyM = const Value.absent(),
                Value<double?> localX = const Value.absent(),
                Value<double?> localY = const Value.absent(),
                Value<double?> sensorHeightM = const Value.absent(),
                Value<double?> holdingDirectionDeg = const Value.absent(),
                Value<String?> environmentNotes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StationsCompanion(
                id: id,
                surveyId: surveyId,
                sequenceNumber: sequenceNumber,
                latitude: latitude,
                longitude: longitude,
                gpsAccuracyM: gpsAccuracyM,
                localX: localX,
                localY: localY,
                sensorHeightM: sensorHeightM,
                holdingDirectionDeg: holdingDirectionDeg,
                environmentNotes: environmentNotes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String surveyId,
                required int sequenceNumber,
                Value<double?> latitude = const Value.absent(),
                Value<double?> longitude = const Value.absent(),
                Value<double?> gpsAccuracyM = const Value.absent(),
                Value<double?> localX = const Value.absent(),
                Value<double?> localY = const Value.absent(),
                Value<double?> sensorHeightM = const Value.absent(),
                Value<double?> holdingDirectionDeg = const Value.absent(),
                Value<String?> environmentNotes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StationsCompanion.insert(
                id: id,
                surveyId: surveyId,
                sequenceNumber: sequenceNumber,
                latitude: latitude,
                longitude: longitude,
                gpsAccuracyM: gpsAccuracyM,
                localX: localX,
                localY: localY,
                sensorHeightM: sensorHeightM,
                holdingDirectionDeg: holdingDirectionDeg,
                environmentNotes: environmentNotes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StationsTable, Station>(table),
                  $$StationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                surveyId = false,
                samplesRefs = false,
                stationResultsRefs = false,
                anomaliesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (samplesRefs) db.samples,
                    if (stationResultsRefs) db.stationResults,
                    if (anomaliesRefs) db.anomalies,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (surveyId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.surveyId,
                                    referencedTable: $$StationsTableReferences
                                        ._surveyIdTable(db),
                                    referencedColumn: $$StationsTableReferences
                                        ._surveyIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (samplesRefs)
                        await $_getPrefetchedDataByColumns<
                          Station,
                          $StationsTable,
                          Sample,
                          $SamplesTable
                        >(
                          currentTable: table,
                          referencedTable: $$StationsTableReferences
                              ._samplesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StationsTableReferences(
                                db,
                                table,
                                p0,
                              ).samplesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'station_id',
                          typedResults: items,
                        ),
                      if (stationResultsRefs)
                        await $_getPrefetchedDataByColumns<
                          Station,
                          $StationsTable,
                          StationResult,
                          $StationResultsTable
                        >(
                          currentTable: table,
                          referencedTable: $$StationsTableReferences
                              ._stationResultsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StationsTableReferences(
                                db,
                                table,
                                p0,
                              ).stationResultsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'station_id',
                          typedResults: items,
                        ),
                      if (anomaliesRefs)
                        await $_getPrefetchedDataByColumns<
                          Station,
                          $StationsTable,
                          Anomaly,
                          $AnomaliesTable
                        >(
                          currentTable: table,
                          referencedTable: $$StationsTableReferences
                              ._anomaliesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StationsTableReferences(
                                db,
                                table,
                                p0,
                              ).anomaliesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'station_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StationsTable,
      Station,
      $$StationsTableFilterComposer,
      $$StationsTableOrderingComposer,
      $$StationsTableAnnotationComposer,
      $$StationsTableCreateCompanionBuilder,
      $$StationsTableUpdateCompanionBuilder,
      (Station, $$StationsTableReferences),
      Station,
      PrefetchHooks Function({
        bool surveyId,
        bool samplesRefs,
        bool stationResultsRefs,
        bool anomaliesRefs,
      })
    >;
typedef $$SamplesTableCreateCompanionBuilder =
    SamplesCompanion Function({
      required String id,
      required String stationId,
      Value<String?> calibrationId,
      required BigInt timestampNs,
      required double rawXMicroT,
      required double rawYMicroT,
      required double rawZMicroT,
      required double biasXMicroT,
      required double biasYMicroT,
      required double biasZMicroT,
      required int accuracy,
      required bool isUncalibrated,
      required double batteryTempC,
      required bool isCharging,
      required bool isScreenOn,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });
typedef $$SamplesTableUpdateCompanionBuilder =
    SamplesCompanion Function({
      Value<String> id,
      Value<String> stationId,
      Value<String?> calibrationId,
      Value<BigInt> timestampNs,
      Value<double> rawXMicroT,
      Value<double> rawYMicroT,
      Value<double> rawZMicroT,
      Value<double> biasXMicroT,
      Value<double> biasYMicroT,
      Value<double> biasZMicroT,
      Value<int> accuracy,
      Value<bool> isUncalibrated,
      Value<double> batteryTempC,
      Value<bool> isCharging,
      Value<bool> isScreenOn,
      Value<DateTime> recordedAt,
      Value<int> rowid,
    });

final class $$SamplesTableReferences
    extends BaseReferences<_$AppDatabase, $SamplesTable, Sample> {
  $$SamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StationsTable _stationIdTable(_$AppDatabase db) =>
      db.stations.createAlias('samples__station_id__stations__id');

  $$StationsTableProcessedTableManager get stationId {
    final $_column = $_itemColumn<String>('station_id')!;

    final manager = $$StationsTableTableManager(
      $_db,
      $_db.stations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CalibrationProfilesTable _calibrationIdTable(_$AppDatabase db) => db
      .calibrationProfiles
      .createAlias('samples__calibration_id__calibration_profiles__id');

  $$CalibrationProfilesTableProcessedTableManager? get calibrationId {
    final $_column = $_itemColumn<String>('calibration_id');
    if ($_column == null) return null;
    final manager = $$CalibrationProfilesTableTableManager(
      $_db,
      $_db.calibrationProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_calibrationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SamplesTableFilterComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<BigInt> get timestampNs => $composableBuilder(
    column: $table.timestampNs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rawXMicroT => $composableBuilder(
    column: $table.rawXMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rawYMicroT => $composableBuilder(
    column: $table.rawYMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get rawZMicroT => $composableBuilder(
    column: $table.rawZMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get biasXMicroT => $composableBuilder(
    column: $table.biasXMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get biasYMicroT => $composableBuilder(
    column: $table.biasYMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get biasZMicroT => $composableBuilder(
    column: $table.biasZMicroT,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isUncalibrated => $composableBuilder(
    column: $table.isUncalibrated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get batteryTempC => $composableBuilder(
    column: $table.batteryTempC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCharging => $composableBuilder(
    column: $table.isCharging,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isScreenOn => $composableBuilder(
    column: $table.isScreenOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StationsTableFilterComposer get stationId {
    final $$StationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableFilterComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalibrationProfilesTableFilterComposer get calibrationId {
    final $$CalibrationProfilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.calibrationId,
      referencedTable: $db.calibrationProfiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CalibrationProfilesTableFilterComposer(
            $db: $db,
            $table: $db.calibrationProfiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<BigInt> get timestampNs => $composableBuilder(
    column: $table.timestampNs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rawXMicroT => $composableBuilder(
    column: $table.rawXMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rawYMicroT => $composableBuilder(
    column: $table.rawYMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get rawZMicroT => $composableBuilder(
    column: $table.rawZMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get biasXMicroT => $composableBuilder(
    column: $table.biasXMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get biasYMicroT => $composableBuilder(
    column: $table.biasYMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get biasZMicroT => $composableBuilder(
    column: $table.biasZMicroT,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accuracy => $composableBuilder(
    column: $table.accuracy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isUncalibrated => $composableBuilder(
    column: $table.isUncalibrated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get batteryTempC => $composableBuilder(
    column: $table.batteryTempC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCharging => $composableBuilder(
    column: $table.isCharging,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isScreenOn => $composableBuilder(
    column: $table.isScreenOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StationsTableOrderingComposer get stationId {
    final $$StationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableOrderingComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalibrationProfilesTableOrderingComposer get calibrationId {
    final $$CalibrationProfilesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.calibrationId,
          referencedTable: $db.calibrationProfiles,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalibrationProfilesTableOrderingComposer(
                $db: $db,
                $table: $db.calibrationProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SamplesTable> {
  $$SamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<BigInt> get timestampNs => $composableBuilder(
    column: $table.timestampNs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rawXMicroT => $composableBuilder(
    column: $table.rawXMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rawYMicroT => $composableBuilder(
    column: $table.rawYMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<double> get rawZMicroT => $composableBuilder(
    column: $table.rawZMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<double> get biasXMicroT => $composableBuilder(
    column: $table.biasXMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<double> get biasYMicroT => $composableBuilder(
    column: $table.biasYMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<double> get biasZMicroT => $composableBuilder(
    column: $table.biasZMicroT,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accuracy =>
      $composableBuilder(column: $table.accuracy, builder: (column) => column);

  GeneratedColumn<bool> get isUncalibrated => $composableBuilder(
    column: $table.isUncalibrated,
    builder: (column) => column,
  );

  GeneratedColumn<double> get batteryTempC => $composableBuilder(
    column: $table.batteryTempC,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCharging => $composableBuilder(
    column: $table.isCharging,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isScreenOn => $composableBuilder(
    column: $table.isScreenOn,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  $$StationsTableAnnotationComposer get stationId {
    final $$StationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableAnnotationComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CalibrationProfilesTableAnnotationComposer get calibrationId {
    final $$CalibrationProfilesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.calibrationId,
          referencedTable: $db.calibrationProfiles,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$CalibrationProfilesTableAnnotationComposer(
                $db: $db,
                $table: $db.calibrationProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$SamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SamplesTable,
          Sample,
          $$SamplesTableFilterComposer,
          $$SamplesTableOrderingComposer,
          $$SamplesTableAnnotationComposer,
          $$SamplesTableCreateCompanionBuilder,
          $$SamplesTableUpdateCompanionBuilder,
          (Sample, $$SamplesTableReferences),
          Sample,
          PrefetchHooks Function({bool stationId, bool calibrationId})
        > {
  $$SamplesTableTableManager(_$AppDatabase db, $SamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> stationId = const Value.absent(),
                Value<String?> calibrationId = const Value.absent(),
                Value<BigInt> timestampNs = const Value.absent(),
                Value<double> rawXMicroT = const Value.absent(),
                Value<double> rawYMicroT = const Value.absent(),
                Value<double> rawZMicroT = const Value.absent(),
                Value<double> biasXMicroT = const Value.absent(),
                Value<double> biasYMicroT = const Value.absent(),
                Value<double> biasZMicroT = const Value.absent(),
                Value<int> accuracy = const Value.absent(),
                Value<bool> isUncalibrated = const Value.absent(),
                Value<double> batteryTempC = const Value.absent(),
                Value<bool> isCharging = const Value.absent(),
                Value<bool> isScreenOn = const Value.absent(),
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SamplesCompanion(
                id: id,
                stationId: stationId,
                calibrationId: calibrationId,
                timestampNs: timestampNs,
                rawXMicroT: rawXMicroT,
                rawYMicroT: rawYMicroT,
                rawZMicroT: rawZMicroT,
                biasXMicroT: biasXMicroT,
                biasYMicroT: biasYMicroT,
                biasZMicroT: biasZMicroT,
                accuracy: accuracy,
                isUncalibrated: isUncalibrated,
                batteryTempC: batteryTempC,
                isCharging: isCharging,
                isScreenOn: isScreenOn,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String stationId,
                Value<String?> calibrationId = const Value.absent(),
                required BigInt timestampNs,
                required double rawXMicroT,
                required double rawYMicroT,
                required double rawZMicroT,
                required double biasXMicroT,
                required double biasYMicroT,
                required double biasZMicroT,
                required int accuracy,
                required bool isUncalibrated,
                required double batteryTempC,
                required bool isCharging,
                required bool isScreenOn,
                Value<DateTime> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SamplesCompanion.insert(
                id: id,
                stationId: stationId,
                calibrationId: calibrationId,
                timestampNs: timestampNs,
                rawXMicroT: rawXMicroT,
                rawYMicroT: rawYMicroT,
                rawZMicroT: rawZMicroT,
                biasXMicroT: biasXMicroT,
                biasYMicroT: biasYMicroT,
                biasZMicroT: biasZMicroT,
                accuracy: accuracy,
                isUncalibrated: isUncalibrated,
                batteryTempC: batteryTempC,
                isCharging: isCharging,
                isScreenOn: isScreenOn,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SamplesTable, Sample>(table),
                  $$SamplesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({stationId = false, calibrationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (stationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.stationId,
                                referencedTable: $$SamplesTableReferences
                                    ._stationIdTable(db),
                                referencedColumn: $$SamplesTableReferences
                                    ._stationIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (calibrationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.calibrationId,
                                referencedTable: $$SamplesTableReferences
                                    ._calibrationIdTable(db),
                                referencedColumn: $$SamplesTableReferences
                                    ._calibrationIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SamplesTable,
      Sample,
      $$SamplesTableFilterComposer,
      $$SamplesTableOrderingComposer,
      $$SamplesTableAnnotationComposer,
      $$SamplesTableCreateCompanionBuilder,
      $$SamplesTableUpdateCompanionBuilder,
      (Sample, $$SamplesTableReferences),
      Sample,
      PrefetchHooks Function({bool stationId, bool calibrationId})
    >;
typedef $$StationResultsTableCreateCompanionBuilder =
    StationResultsCompanion Function({
      required String id,
      required String stationId,
      required double totalFieldMeanNt,
      required double totalFieldStdNt,
      required int sampleCount,
      required bool isAccepted,
      Value<String?> rejectionReason,
      Value<DateTime> calculatedAt,
      Value<int> rowid,
    });
typedef $$StationResultsTableUpdateCompanionBuilder =
    StationResultsCompanion Function({
      Value<String> id,
      Value<String> stationId,
      Value<double> totalFieldMeanNt,
      Value<double> totalFieldStdNt,
      Value<int> sampleCount,
      Value<bool> isAccepted,
      Value<String?> rejectionReason,
      Value<DateTime> calculatedAt,
      Value<int> rowid,
    });

final class $$StationResultsTableReferences
    extends BaseReferences<_$AppDatabase, $StationResultsTable, StationResult> {
  $$StationResultsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $StationsTable _stationIdTable(_$AppDatabase db) =>
      db.stations.createAlias('station_results__station_id__stations__id');

  $$StationsTableProcessedTableManager get stationId {
    final $_column = $_itemColumn<String>('station_id')!;

    final manager = $$StationsTableTableManager(
      $_db,
      $_db.stations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StationResultsTableFilterComposer
    extends Composer<_$AppDatabase, $StationResultsTable> {
  $$StationResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalFieldMeanNt => $composableBuilder(
    column: $table.totalFieldMeanNt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalFieldStdNt => $composableBuilder(
    column: $table.totalFieldStdNt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAccepted => $composableBuilder(
    column: $table.isAccepted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StationsTableFilterComposer get stationId {
    final $$StationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableFilterComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StationResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $StationResultsTable> {
  $$StationResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalFieldMeanNt => $composableBuilder(
    column: $table.totalFieldMeanNt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalFieldStdNt => $composableBuilder(
    column: $table.totalFieldStdNt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAccepted => $composableBuilder(
    column: $table.isAccepted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StationsTableOrderingComposer get stationId {
    final $$StationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableOrderingComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StationResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StationResultsTable> {
  $$StationResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get totalFieldMeanNt => $composableBuilder(
    column: $table.totalFieldMeanNt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalFieldStdNt => $composableBuilder(
    column: $table.totalFieldStdNt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sampleCount => $composableBuilder(
    column: $table.sampleCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isAccepted => $composableBuilder(
    column: $table.isAccepted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rejectionReason => $composableBuilder(
    column: $table.rejectionReason,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => column,
  );

  $$StationsTableAnnotationComposer get stationId {
    final $$StationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableAnnotationComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StationResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StationResultsTable,
          StationResult,
          $$StationResultsTableFilterComposer,
          $$StationResultsTableOrderingComposer,
          $$StationResultsTableAnnotationComposer,
          $$StationResultsTableCreateCompanionBuilder,
          $$StationResultsTableUpdateCompanionBuilder,
          (StationResult, $$StationResultsTableReferences),
          StationResult,
          PrefetchHooks Function({bool stationId})
        > {
  $$StationResultsTableTableManager(
    _$AppDatabase db,
    $StationResultsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StationResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StationResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StationResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> stationId = const Value.absent(),
                Value<double> totalFieldMeanNt = const Value.absent(),
                Value<double> totalFieldStdNt = const Value.absent(),
                Value<int> sampleCount = const Value.absent(),
                Value<bool> isAccepted = const Value.absent(),
                Value<String?> rejectionReason = const Value.absent(),
                Value<DateTime> calculatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StationResultsCompanion(
                id: id,
                stationId: stationId,
                totalFieldMeanNt: totalFieldMeanNt,
                totalFieldStdNt: totalFieldStdNt,
                sampleCount: sampleCount,
                isAccepted: isAccepted,
                rejectionReason: rejectionReason,
                calculatedAt: calculatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String stationId,
                required double totalFieldMeanNt,
                required double totalFieldStdNt,
                required int sampleCount,
                required bool isAccepted,
                Value<String?> rejectionReason = const Value.absent(),
                Value<DateTime> calculatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StationResultsCompanion.insert(
                id: id,
                stationId: stationId,
                totalFieldMeanNt: totalFieldMeanNt,
                totalFieldStdNt: totalFieldStdNt,
                sampleCount: sampleCount,
                isAccepted: isAccepted,
                rejectionReason: rejectionReason,
                calculatedAt: calculatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StationResultsTable, StationResult>(table),
                  $$StationResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({stationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (stationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.stationId,
                                referencedTable: $$StationResultsTableReferences
                                    ._stationIdTable(db),
                                referencedColumn:
                                    $$StationResultsTableReferences
                                        ._stationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StationResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StationResultsTable,
      StationResult,
      $$StationResultsTableFilterComposer,
      $$StationResultsTableOrderingComposer,
      $$StationResultsTableAnnotationComposer,
      $$StationResultsTableCreateCompanionBuilder,
      $$StationResultsTableUpdateCompanionBuilder,
      (StationResult, $$StationResultsTableReferences),
      StationResult,
      PrefetchHooks Function({bool stationId})
    >;
typedef $$AnomaliesTableCreateCompanionBuilder =
    AnomaliesCompanion Function({
      required String id,
      required String stationId,
      Value<double?> fIgrfNt,
      Value<double?> diurnalCorrectionNt,
      Value<double?> deltaTNt,
      Value<DateTime> calculatedAt,
      Value<int> rowid,
    });
typedef $$AnomaliesTableUpdateCompanionBuilder =
    AnomaliesCompanion Function({
      Value<String> id,
      Value<String> stationId,
      Value<double?> fIgrfNt,
      Value<double?> diurnalCorrectionNt,
      Value<double?> deltaTNt,
      Value<DateTime> calculatedAt,
      Value<int> rowid,
    });

final class $$AnomaliesTableReferences
    extends BaseReferences<_$AppDatabase, $AnomaliesTable, Anomaly> {
  $$AnomaliesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StationsTable _stationIdTable(_$AppDatabase db) =>
      db.stations.createAlias('anomalies__station_id__stations__id');

  $$StationsTableProcessedTableManager get stationId {
    final $_column = $_itemColumn<String>('station_id')!;

    final manager = $$StationsTableTableManager(
      $_db,
      $_db.stations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AnomaliesTableFilterComposer
    extends Composer<_$AppDatabase, $AnomaliesTable> {
  $$AnomaliesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fIgrfNt => $composableBuilder(
    column: $table.fIgrfNt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get diurnalCorrectionNt => $composableBuilder(
    column: $table.diurnalCorrectionNt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get deltaTNt => $composableBuilder(
    column: $table.deltaTNt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StationsTableFilterComposer get stationId {
    final $$StationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableFilterComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnomaliesTableOrderingComposer
    extends Composer<_$AppDatabase, $AnomaliesTable> {
  $$AnomaliesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fIgrfNt => $composableBuilder(
    column: $table.fIgrfNt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get diurnalCorrectionNt => $composableBuilder(
    column: $table.diurnalCorrectionNt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get deltaTNt => $composableBuilder(
    column: $table.deltaTNt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StationsTableOrderingComposer get stationId {
    final $$StationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableOrderingComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnomaliesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnomaliesTable> {
  $$AnomaliesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get fIgrfNt =>
      $composableBuilder(column: $table.fIgrfNt, builder: (column) => column);

  GeneratedColumn<double> get diurnalCorrectionNt => $composableBuilder(
    column: $table.diurnalCorrectionNt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get deltaTNt =>
      $composableBuilder(column: $table.deltaTNt, builder: (column) => column);

  GeneratedColumn<DateTime> get calculatedAt => $composableBuilder(
    column: $table.calculatedAt,
    builder: (column) => column,
  );

  $$StationsTableAnnotationComposer get stationId {
    final $$StationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.stations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StationsTableAnnotationComposer(
            $db: $db,
            $table: $db.stations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AnomaliesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnomaliesTable,
          Anomaly,
          $$AnomaliesTableFilterComposer,
          $$AnomaliesTableOrderingComposer,
          $$AnomaliesTableAnnotationComposer,
          $$AnomaliesTableCreateCompanionBuilder,
          $$AnomaliesTableUpdateCompanionBuilder,
          (Anomaly, $$AnomaliesTableReferences),
          Anomaly,
          PrefetchHooks Function({bool stationId})
        > {
  $$AnomaliesTableTableManager(_$AppDatabase db, $AnomaliesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnomaliesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnomaliesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnomaliesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> stationId = const Value.absent(),
                Value<double?> fIgrfNt = const Value.absent(),
                Value<double?> diurnalCorrectionNt = const Value.absent(),
                Value<double?> deltaTNt = const Value.absent(),
                Value<DateTime> calculatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnomaliesCompanion(
                id: id,
                stationId: stationId,
                fIgrfNt: fIgrfNt,
                diurnalCorrectionNt: diurnalCorrectionNt,
                deltaTNt: deltaTNt,
                calculatedAt: calculatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String stationId,
                Value<double?> fIgrfNt = const Value.absent(),
                Value<double?> diurnalCorrectionNt = const Value.absent(),
                Value<double?> deltaTNt = const Value.absent(),
                Value<DateTime> calculatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnomaliesCompanion.insert(
                id: id,
                stationId: stationId,
                fIgrfNt: fIgrfNt,
                diurnalCorrectionNt: diurnalCorrectionNt,
                deltaTNt: deltaTNt,
                calculatedAt: calculatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnomaliesTable, Anomaly>(table),
                  $$AnomaliesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({stationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (stationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.stationId,
                                referencedTable: $$AnomaliesTableReferences
                                    ._stationIdTable(db),
                                referencedColumn: $$AnomaliesTableReferences
                                    ._stationIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$AnomaliesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnomaliesTable,
      Anomaly,
      $$AnomaliesTableFilterComposer,
      $$AnomaliesTableOrderingComposer,
      $$AnomaliesTableAnnotationComposer,
      $$AnomaliesTableCreateCompanionBuilder,
      $$AnomaliesTableUpdateCompanionBuilder,
      (Anomaly, $$AnomaliesTableReferences),
      Anomaly,
      PrefetchHooks Function({bool stationId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DevicesTableTableManager get devices =>
      $$DevicesTableTableManager(_db, _db.devices);
  $$CalibrationProfilesTableTableManager get calibrationProfiles =>
      $$CalibrationProfilesTableTableManager(_db, _db.calibrationProfiles);
  $$SurveysTableTableManager get surveys =>
      $$SurveysTableTableManager(_db, _db.surveys);
  $$StationsTableTableManager get stations =>
      $$StationsTableTableManager(_db, _db.stations);
  $$SamplesTableTableManager get samples =>
      $$SamplesTableTableManager(_db, _db.samples);
  $$StationResultsTableTableManager get stationResults =>
      $$StationResultsTableTableManager(_db, _db.stationResults);
  $$AnomaliesTableTableManager get anomalies =>
      $$AnomaliesTableTableManager(_db, _db.anomalies);
}
