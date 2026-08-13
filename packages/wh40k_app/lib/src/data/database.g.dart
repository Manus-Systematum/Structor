// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RostersTable extends Rosters with TableInfo<$RostersTable, RosterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RostersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _factionIdMeta =
      const VerificationMeta('factionId');
  @override
  late final GeneratedColumn<String> factionId = GeneratedColumn<String>(
      'faction_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _battleSizeIdMeta =
      const VerificationMeta('battleSizeId');
  @override
  late final GeneratedColumn<String> battleSizeId = GeneratedColumn<String>(
      'battle_size_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pointsMeta = const VerificationMeta('points');
  @override
  late final GeneratedColumn<int> points = GeneratedColumn<int>(
      'points', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _unitCountMeta =
      const VerificationMeta('unitCount');
  @override
  late final GeneratedColumn<int> unitCount = GeneratedColumn<int>(
      'unit_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _rosterJsonMeta =
      const VerificationMeta('rosterJson');
  @override
  late final GeneratedColumn<String> rosterJson = GeneratedColumn<String>(
      'roster_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _snapshotJsonMeta =
      const VerificationMeta('snapshotJson');
  @override
  late final GeneratedColumn<String> snapshotJson = GeneratedColumn<String>(
      'snapshot_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        factionId,
        battleSizeId,
        points,
        unitCount,
        updatedAt,
        rosterJson,
        snapshotJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rosters';
  @override
  VerificationContext validateIntegrity(Insertable<RosterRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('faction_id')) {
      context.handle(_factionIdMeta,
          factionId.isAcceptableOrUnknown(data['faction_id']!, _factionIdMeta));
    } else if (isInserting) {
      context.missing(_factionIdMeta);
    }
    if (data.containsKey('battle_size_id')) {
      context.handle(
          _battleSizeIdMeta,
          battleSizeId.isAcceptableOrUnknown(
              data['battle_size_id']!, _battleSizeIdMeta));
    } else if (isInserting) {
      context.missing(_battleSizeIdMeta);
    }
    if (data.containsKey('points')) {
      context.handle(_pointsMeta,
          points.isAcceptableOrUnknown(data['points']!, _pointsMeta));
    } else if (isInserting) {
      context.missing(_pointsMeta);
    }
    if (data.containsKey('unit_count')) {
      context.handle(_unitCountMeta,
          unitCount.isAcceptableOrUnknown(data['unit_count']!, _unitCountMeta));
    } else if (isInserting) {
      context.missing(_unitCountMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('roster_json')) {
      context.handle(
          _rosterJsonMeta,
          rosterJson.isAcceptableOrUnknown(
              data['roster_json']!, _rosterJsonMeta));
    } else if (isInserting) {
      context.missing(_rosterJsonMeta);
    }
    if (data.containsKey('snapshot_json')) {
      context.handle(
          _snapshotJsonMeta,
          snapshotJson.isAcceptableOrUnknown(
              data['snapshot_json']!, _snapshotJsonMeta));
    } else if (isInserting) {
      context.missing(_snapshotJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RosterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RosterRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      factionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}faction_id'])!,
      battleSizeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}battle_size_id'])!,
      points: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}points'])!,
      unitCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}unit_count'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      rosterJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}roster_json'])!,
      snapshotJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}snapshot_json'])!,
    );
  }

  @override
  $RostersTable createAlias(String alias) {
    return $RostersTable(attachedDatabase, alias);
  }
}

class RosterRow extends DataClass implements Insertable<RosterRow> {
  final String id;
  final String name;
  final String factionId;
  final String battleSizeId;
  final int points;
  final int unitCount;
  final DateTime updatedAt;
  final String rosterJson;
  final String snapshotJson;
  const RosterRow(
      {required this.id,
      required this.name,
      required this.factionId,
      required this.battleSizeId,
      required this.points,
      required this.unitCount,
      required this.updatedAt,
      required this.rosterJson,
      required this.snapshotJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['faction_id'] = Variable<String>(factionId);
    map['battle_size_id'] = Variable<String>(battleSizeId);
    map['points'] = Variable<int>(points);
    map['unit_count'] = Variable<int>(unitCount);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['roster_json'] = Variable<String>(rosterJson);
    map['snapshot_json'] = Variable<String>(snapshotJson);
    return map;
  }

  RostersCompanion toCompanion(bool nullToAbsent) {
    return RostersCompanion(
      id: Value(id),
      name: Value(name),
      factionId: Value(factionId),
      battleSizeId: Value(battleSizeId),
      points: Value(points),
      unitCount: Value(unitCount),
      updatedAt: Value(updatedAt),
      rosterJson: Value(rosterJson),
      snapshotJson: Value(snapshotJson),
    );
  }

  factory RosterRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RosterRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      factionId: serializer.fromJson<String>(json['factionId']),
      battleSizeId: serializer.fromJson<String>(json['battleSizeId']),
      points: serializer.fromJson<int>(json['points']),
      unitCount: serializer.fromJson<int>(json['unitCount']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      rosterJson: serializer.fromJson<String>(json['rosterJson']),
      snapshotJson: serializer.fromJson<String>(json['snapshotJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'factionId': serializer.toJson<String>(factionId),
      'battleSizeId': serializer.toJson<String>(battleSizeId),
      'points': serializer.toJson<int>(points),
      'unitCount': serializer.toJson<int>(unitCount),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'rosterJson': serializer.toJson<String>(rosterJson),
      'snapshotJson': serializer.toJson<String>(snapshotJson),
    };
  }

  RosterRow copyWith(
          {String? id,
          String? name,
          String? factionId,
          String? battleSizeId,
          int? points,
          int? unitCount,
          DateTime? updatedAt,
          String? rosterJson,
          String? snapshotJson}) =>
      RosterRow(
        id: id ?? this.id,
        name: name ?? this.name,
        factionId: factionId ?? this.factionId,
        battleSizeId: battleSizeId ?? this.battleSizeId,
        points: points ?? this.points,
        unitCount: unitCount ?? this.unitCount,
        updatedAt: updatedAt ?? this.updatedAt,
        rosterJson: rosterJson ?? this.rosterJson,
        snapshotJson: snapshotJson ?? this.snapshotJson,
      );
  RosterRow copyWithCompanion(RostersCompanion data) {
    return RosterRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      factionId: data.factionId.present ? data.factionId.value : this.factionId,
      battleSizeId: data.battleSizeId.present
          ? data.battleSizeId.value
          : this.battleSizeId,
      points: data.points.present ? data.points.value : this.points,
      unitCount: data.unitCount.present ? data.unitCount.value : this.unitCount,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      rosterJson:
          data.rosterJson.present ? data.rosterJson.value : this.rosterJson,
      snapshotJson: data.snapshotJson.present
          ? data.snapshotJson.value
          : this.snapshotJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RosterRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('factionId: $factionId, ')
          ..write('battleSizeId: $battleSizeId, ')
          ..write('points: $points, ')
          ..write('unitCount: $unitCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rosterJson: $rosterJson, ')
          ..write('snapshotJson: $snapshotJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, factionId, battleSizeId, points,
      unitCount, updatedAt, rosterJson, snapshotJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RosterRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.factionId == this.factionId &&
          other.battleSizeId == this.battleSizeId &&
          other.points == this.points &&
          other.unitCount == this.unitCount &&
          other.updatedAt == this.updatedAt &&
          other.rosterJson == this.rosterJson &&
          other.snapshotJson == this.snapshotJson);
}

class RostersCompanion extends UpdateCompanion<RosterRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> factionId;
  final Value<String> battleSizeId;
  final Value<int> points;
  final Value<int> unitCount;
  final Value<DateTime> updatedAt;
  final Value<String> rosterJson;
  final Value<String> snapshotJson;
  final Value<int> rowid;
  const RostersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.factionId = const Value.absent(),
    this.battleSizeId = const Value.absent(),
    this.points = const Value.absent(),
    this.unitCount = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rosterJson = const Value.absent(),
    this.snapshotJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RostersCompanion.insert({
    required String id,
    required String name,
    required String factionId,
    required String battleSizeId,
    required int points,
    required int unitCount,
    required DateTime updatedAt,
    required String rosterJson,
    required String snapshotJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        factionId = Value(factionId),
        battleSizeId = Value(battleSizeId),
        points = Value(points),
        unitCount = Value(unitCount),
        updatedAt = Value(updatedAt),
        rosterJson = Value(rosterJson),
        snapshotJson = Value(snapshotJson);
  static Insertable<RosterRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? factionId,
    Expression<String>? battleSizeId,
    Expression<int>? points,
    Expression<int>? unitCount,
    Expression<DateTime>? updatedAt,
    Expression<String>? rosterJson,
    Expression<String>? snapshotJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (factionId != null) 'faction_id': factionId,
      if (battleSizeId != null) 'battle_size_id': battleSizeId,
      if (points != null) 'points': points,
      if (unitCount != null) 'unit_count': unitCount,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rosterJson != null) 'roster_json': rosterJson,
      if (snapshotJson != null) 'snapshot_json': snapshotJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RostersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? factionId,
      Value<String>? battleSizeId,
      Value<int>? points,
      Value<int>? unitCount,
      Value<DateTime>? updatedAt,
      Value<String>? rosterJson,
      Value<String>? snapshotJson,
      Value<int>? rowid}) {
    return RostersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      factionId: factionId ?? this.factionId,
      battleSizeId: battleSizeId ?? this.battleSizeId,
      points: points ?? this.points,
      unitCount: unitCount ?? this.unitCount,
      updatedAt: updatedAt ?? this.updatedAt,
      rosterJson: rosterJson ?? this.rosterJson,
      snapshotJson: snapshotJson ?? this.snapshotJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (factionId.present) {
      map['faction_id'] = Variable<String>(factionId.value);
    }
    if (battleSizeId.present) {
      map['battle_size_id'] = Variable<String>(battleSizeId.value);
    }
    if (points.present) {
      map['points'] = Variable<int>(points.value);
    }
    if (unitCount.present) {
      map['unit_count'] = Variable<int>(unitCount.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rosterJson.present) {
      map['roster_json'] = Variable<String>(rosterJson.value);
    }
    if (snapshotJson.present) {
      map['snapshot_json'] = Variable<String>(snapshotJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RostersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('factionId: $factionId, ')
          ..write('battleSizeId: $battleSizeId, ')
          ..write('points: $points, ')
          ..write('unitCount: $unitCount, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rosterJson: $rosterJson, ')
          ..write('snapshotJson: $snapshotJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RostersTable rosters = $RostersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [rosters];
}

typedef $$RostersTableCreateCompanionBuilder = RostersCompanion Function({
  required String id,
  required String name,
  required String factionId,
  required String battleSizeId,
  required int points,
  required int unitCount,
  required DateTime updatedAt,
  required String rosterJson,
  required String snapshotJson,
  Value<int> rowid,
});
typedef $$RostersTableUpdateCompanionBuilder = RostersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> factionId,
  Value<String> battleSizeId,
  Value<int> points,
  Value<int> unitCount,
  Value<DateTime> updatedAt,
  Value<String> rosterJson,
  Value<String> snapshotJson,
  Value<int> rowid,
});

class $$RostersTableFilterComposer
    extends Composer<_$AppDatabase, $RostersTable> {
  $$RostersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get factionId => $composableBuilder(
      column: $table.factionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get battleSizeId => $composableBuilder(
      column: $table.battleSizeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get points => $composableBuilder(
      column: $table.points, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get unitCount => $composableBuilder(
      column: $table.unitCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rosterJson => $composableBuilder(
      column: $table.rosterJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson, builder: (column) => ColumnFilters(column));
}

class $$RostersTableOrderingComposer
    extends Composer<_$AppDatabase, $RostersTable> {
  $$RostersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get factionId => $composableBuilder(
      column: $table.factionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get battleSizeId => $composableBuilder(
      column: $table.battleSizeId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get points => $composableBuilder(
      column: $table.points, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get unitCount => $composableBuilder(
      column: $table.unitCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rosterJson => $composableBuilder(
      column: $table.rosterJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson,
      builder: (column) => ColumnOrderings(column));
}

class $$RostersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RostersTable> {
  $$RostersTableAnnotationComposer({
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

  GeneratedColumn<String> get factionId =>
      $composableBuilder(column: $table.factionId, builder: (column) => column);

  GeneratedColumn<String> get battleSizeId => $composableBuilder(
      column: $table.battleSizeId, builder: (column) => column);

  GeneratedColumn<int> get points =>
      $composableBuilder(column: $table.points, builder: (column) => column);

  GeneratedColumn<int> get unitCount =>
      $composableBuilder(column: $table.unitCount, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get rosterJson => $composableBuilder(
      column: $table.rosterJson, builder: (column) => column);

  GeneratedColumn<String> get snapshotJson => $composableBuilder(
      column: $table.snapshotJson, builder: (column) => column);
}

class $$RostersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RostersTable,
    RosterRow,
    $$RostersTableFilterComposer,
    $$RostersTableOrderingComposer,
    $$RostersTableAnnotationComposer,
    $$RostersTableCreateCompanionBuilder,
    $$RostersTableUpdateCompanionBuilder,
    (RosterRow, BaseReferences<_$AppDatabase, $RostersTable, RosterRow>),
    RosterRow,
    PrefetchHooks Function()> {
  $$RostersTableTableManager(_$AppDatabase db, $RostersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RostersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RostersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RostersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> factionId = const Value.absent(),
            Value<String> battleSizeId = const Value.absent(),
            Value<int> points = const Value.absent(),
            Value<int> unitCount = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<String> rosterJson = const Value.absent(),
            Value<String> snapshotJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RostersCompanion(
            id: id,
            name: name,
            factionId: factionId,
            battleSizeId: battleSizeId,
            points: points,
            unitCount: unitCount,
            updatedAt: updatedAt,
            rosterJson: rosterJson,
            snapshotJson: snapshotJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String factionId,
            required String battleSizeId,
            required int points,
            required int unitCount,
            required DateTime updatedAt,
            required String rosterJson,
            required String snapshotJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              RostersCompanion.insert(
            id: id,
            name: name,
            factionId: factionId,
            battleSizeId: battleSizeId,
            points: points,
            unitCount: unitCount,
            updatedAt: updatedAt,
            rosterJson: rosterJson,
            snapshotJson: snapshotJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RostersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RostersTable,
    RosterRow,
    $$RostersTableFilterComposer,
    $$RostersTableOrderingComposer,
    $$RostersTableAnnotationComposer,
    $$RostersTableCreateCompanionBuilder,
    $$RostersTableUpdateCompanionBuilder,
    (RosterRow, BaseReferences<_$AppDatabase, $RostersTable, RosterRow>),
    RosterRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RostersTableTableManager get rosters =>
      $$RostersTableTableManager(_db, _db.rosters);
}
