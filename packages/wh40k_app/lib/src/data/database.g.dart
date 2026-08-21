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
  static const VerificationMeta _battleLogJsonMeta =
      const VerificationMeta('battleLogJson');
  @override
  late final GeneratedColumn<String> battleLogJson = GeneratedColumn<String>(
      'battle_log_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
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
        snapshotJson,
        battleLogJson
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
    if (data.containsKey('battle_log_json')) {
      context.handle(
          _battleLogJsonMeta,
          battleLogJson.isAcceptableOrUnknown(
              data['battle_log_json']!, _battleLogJsonMeta));
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
      battleLogJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}battle_log_json']),
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

  /// The battle event log (DESIGN.md §7.4), or null when no game is in
  /// progress. Stored as a document for the same reason as the roster: it is
  /// an append-only history whose value is being replayed verbatim.
  final String? battleLogJson;
  const RosterRow(
      {required this.id,
      required this.name,
      required this.factionId,
      required this.battleSizeId,
      required this.points,
      required this.unitCount,
      required this.updatedAt,
      required this.rosterJson,
      required this.snapshotJson,
      this.battleLogJson});
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
    if (!nullToAbsent || battleLogJson != null) {
      map['battle_log_json'] = Variable<String>(battleLogJson);
    }
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
      battleLogJson: battleLogJson == null && nullToAbsent
          ? const Value.absent()
          : Value(battleLogJson),
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
      battleLogJson: serializer.fromJson<String?>(json['battleLogJson']),
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
      'battleLogJson': serializer.toJson<String?>(battleLogJson),
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
          String? snapshotJson,
          Value<String?> battleLogJson = const Value.absent()}) =>
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
        battleLogJson:
            battleLogJson.present ? battleLogJson.value : this.battleLogJson,
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
      battleLogJson: data.battleLogJson.present
          ? data.battleLogJson.value
          : this.battleLogJson,
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
          ..write('snapshotJson: $snapshotJson, ')
          ..write('battleLogJson: $battleLogJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, factionId, battleSizeId, points,
      unitCount, updatedAt, rosterJson, snapshotJson, battleLogJson);
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
          other.snapshotJson == this.snapshotJson &&
          other.battleLogJson == this.battleLogJson);
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
  final Value<String?> battleLogJson;
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
    this.battleLogJson = const Value.absent(),
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
    this.battleLogJson = const Value.absent(),
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
    Expression<String>? battleLogJson,
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
      if (battleLogJson != null) 'battle_log_json': battleLogJson,
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
      Value<String?>? battleLogJson,
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
      battleLogJson: battleLogJson ?? this.battleLogJson,
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
    if (battleLogJson.present) {
      map['battle_log_json'] = Variable<String>(battleLogJson.value);
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
          ..write('battleLogJson: $battleLogJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BattlesTable extends Battles with TableInfo<$BattlesTable, BattleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BattlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rosterIdMeta =
      const VerificationMeta('rosterId');
  @override
  late final GeneratedColumn<String> rosterId = GeneratedColumn<String>(
      'roster_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rosterNameMeta =
      const VerificationMeta('rosterName');
  @override
  late final GeneratedColumn<String> rosterName = GeneratedColumn<String>(
      'roster_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _factionIdMeta =
      const VerificationMeta('factionId');
  @override
  late final GeneratedColumn<String> factionId = GeneratedColumn<String>(
      'faction_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _finishedAtMeta =
      const VerificationMeta('finishedAt');
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
      'finished_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _roundsMeta = const VerificationMeta('rounds');
  @override
  late final GeneratedColumn<int> rounds = GeneratedColumn<int>(
      'rounds', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _myScoreMeta =
      const VerificationMeta('myScore');
  @override
  late final GeneratedColumn<int> myScore = GeneratedColumn<int>(
      'my_score', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _opponentScoreMeta =
      const VerificationMeta('opponentScore');
  @override
  late final GeneratedColumn<int> opponentScore = GeneratedColumn<int>(
      'opponent_score', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _opponentNameMeta =
      const VerificationMeta('opponentName');
  @override
  late final GeneratedColumn<String> opponentName = GeneratedColumn<String>(
      'opponent_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _logJsonMeta =
      const VerificationMeta('logJson');
  @override
  late final GeneratedColumn<String> logJson = GeneratedColumn<String>(
      'log_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        rosterId,
        rosterName,
        factionId,
        finishedAt,
        rounds,
        myScore,
        opponentScore,
        opponentName,
        logJson
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'battles';
  @override
  VerificationContext validateIntegrity(Insertable<BattleRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('roster_id')) {
      context.handle(_rosterIdMeta,
          rosterId.isAcceptableOrUnknown(data['roster_id']!, _rosterIdMeta));
    } else if (isInserting) {
      context.missing(_rosterIdMeta);
    }
    if (data.containsKey('roster_name')) {
      context.handle(
          _rosterNameMeta,
          rosterName.isAcceptableOrUnknown(
              data['roster_name']!, _rosterNameMeta));
    } else if (isInserting) {
      context.missing(_rosterNameMeta);
    }
    if (data.containsKey('faction_id')) {
      context.handle(_factionIdMeta,
          factionId.isAcceptableOrUnknown(data['faction_id']!, _factionIdMeta));
    } else if (isInserting) {
      context.missing(_factionIdMeta);
    }
    if (data.containsKey('finished_at')) {
      context.handle(
          _finishedAtMeta,
          finishedAt.isAcceptableOrUnknown(
              data['finished_at']!, _finishedAtMeta));
    } else if (isInserting) {
      context.missing(_finishedAtMeta);
    }
    if (data.containsKey('rounds')) {
      context.handle(_roundsMeta,
          rounds.isAcceptableOrUnknown(data['rounds']!, _roundsMeta));
    } else if (isInserting) {
      context.missing(_roundsMeta);
    }
    if (data.containsKey('my_score')) {
      context.handle(_myScoreMeta,
          myScore.isAcceptableOrUnknown(data['my_score']!, _myScoreMeta));
    } else if (isInserting) {
      context.missing(_myScoreMeta);
    }
    if (data.containsKey('opponent_score')) {
      context.handle(
          _opponentScoreMeta,
          opponentScore.isAcceptableOrUnknown(
              data['opponent_score']!, _opponentScoreMeta));
    } else if (isInserting) {
      context.missing(_opponentScoreMeta);
    }
    if (data.containsKey('opponent_name')) {
      context.handle(
          _opponentNameMeta,
          opponentName.isAcceptableOrUnknown(
              data['opponent_name']!, _opponentNameMeta));
    }
    if (data.containsKey('log_json')) {
      context.handle(_logJsonMeta,
          logJson.isAcceptableOrUnknown(data['log_json']!, _logJsonMeta));
    } else if (isInserting) {
      context.missing(_logJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BattleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BattleRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      rosterId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}roster_id'])!,
      rosterName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}roster_name'])!,
      factionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}faction_id'])!,
      finishedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}finished_at'])!,
      rounds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rounds'])!,
      myScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}my_score'])!,
      opponentScore: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}opponent_score'])!,
      opponentName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}opponent_name']),
      logJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}log_json'])!,
    );
  }

  @override
  $BattlesTable createAlias(String alias) {
    return $BattlesTable(attachedDatabase, alias);
  }
}

class BattleRow extends DataClass implements Insertable<BattleRow> {
  final String id;
  final String rosterId;

  /// The army's name **as it was**, because a roster can be renamed or
  /// deleted afterwards and a finished battle must not change with it.
  final String rosterName;
  final String factionId;
  final DateTime finishedAt;
  final int rounds;
  final int myScore;
  final int opponentScore;
  final String? opponentName;
  final String logJson;
  const BattleRow(
      {required this.id,
      required this.rosterId,
      required this.rosterName,
      required this.factionId,
      required this.finishedAt,
      required this.rounds,
      required this.myScore,
      required this.opponentScore,
      this.opponentName,
      required this.logJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['roster_id'] = Variable<String>(rosterId);
    map['roster_name'] = Variable<String>(rosterName);
    map['faction_id'] = Variable<String>(factionId);
    map['finished_at'] = Variable<DateTime>(finishedAt);
    map['rounds'] = Variable<int>(rounds);
    map['my_score'] = Variable<int>(myScore);
    map['opponent_score'] = Variable<int>(opponentScore);
    if (!nullToAbsent || opponentName != null) {
      map['opponent_name'] = Variable<String>(opponentName);
    }
    map['log_json'] = Variable<String>(logJson);
    return map;
  }

  BattlesCompanion toCompanion(bool nullToAbsent) {
    return BattlesCompanion(
      id: Value(id),
      rosterId: Value(rosterId),
      rosterName: Value(rosterName),
      factionId: Value(factionId),
      finishedAt: Value(finishedAt),
      rounds: Value(rounds),
      myScore: Value(myScore),
      opponentScore: Value(opponentScore),
      opponentName: opponentName == null && nullToAbsent
          ? const Value.absent()
          : Value(opponentName),
      logJson: Value(logJson),
    );
  }

  factory BattleRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BattleRow(
      id: serializer.fromJson<String>(json['id']),
      rosterId: serializer.fromJson<String>(json['rosterId']),
      rosterName: serializer.fromJson<String>(json['rosterName']),
      factionId: serializer.fromJson<String>(json['factionId']),
      finishedAt: serializer.fromJson<DateTime>(json['finishedAt']),
      rounds: serializer.fromJson<int>(json['rounds']),
      myScore: serializer.fromJson<int>(json['myScore']),
      opponentScore: serializer.fromJson<int>(json['opponentScore']),
      opponentName: serializer.fromJson<String?>(json['opponentName']),
      logJson: serializer.fromJson<String>(json['logJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'rosterId': serializer.toJson<String>(rosterId),
      'rosterName': serializer.toJson<String>(rosterName),
      'factionId': serializer.toJson<String>(factionId),
      'finishedAt': serializer.toJson<DateTime>(finishedAt),
      'rounds': serializer.toJson<int>(rounds),
      'myScore': serializer.toJson<int>(myScore),
      'opponentScore': serializer.toJson<int>(opponentScore),
      'opponentName': serializer.toJson<String?>(opponentName),
      'logJson': serializer.toJson<String>(logJson),
    };
  }

  BattleRow copyWith(
          {String? id,
          String? rosterId,
          String? rosterName,
          String? factionId,
          DateTime? finishedAt,
          int? rounds,
          int? myScore,
          int? opponentScore,
          Value<String?> opponentName = const Value.absent(),
          String? logJson}) =>
      BattleRow(
        id: id ?? this.id,
        rosterId: rosterId ?? this.rosterId,
        rosterName: rosterName ?? this.rosterName,
        factionId: factionId ?? this.factionId,
        finishedAt: finishedAt ?? this.finishedAt,
        rounds: rounds ?? this.rounds,
        myScore: myScore ?? this.myScore,
        opponentScore: opponentScore ?? this.opponentScore,
        opponentName:
            opponentName.present ? opponentName.value : this.opponentName,
        logJson: logJson ?? this.logJson,
      );
  BattleRow copyWithCompanion(BattlesCompanion data) {
    return BattleRow(
      id: data.id.present ? data.id.value : this.id,
      rosterId: data.rosterId.present ? data.rosterId.value : this.rosterId,
      rosterName:
          data.rosterName.present ? data.rosterName.value : this.rosterName,
      factionId: data.factionId.present ? data.factionId.value : this.factionId,
      finishedAt:
          data.finishedAt.present ? data.finishedAt.value : this.finishedAt,
      rounds: data.rounds.present ? data.rounds.value : this.rounds,
      myScore: data.myScore.present ? data.myScore.value : this.myScore,
      opponentScore: data.opponentScore.present
          ? data.opponentScore.value
          : this.opponentScore,
      opponentName: data.opponentName.present
          ? data.opponentName.value
          : this.opponentName,
      logJson: data.logJson.present ? data.logJson.value : this.logJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BattleRow(')
          ..write('id: $id, ')
          ..write('rosterId: $rosterId, ')
          ..write('rosterName: $rosterName, ')
          ..write('factionId: $factionId, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rounds: $rounds, ')
          ..write('myScore: $myScore, ')
          ..write('opponentScore: $opponentScore, ')
          ..write('opponentName: $opponentName, ')
          ..write('logJson: $logJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, rosterId, rosterName, factionId,
      finishedAt, rounds, myScore, opponentScore, opponentName, logJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BattleRow &&
          other.id == this.id &&
          other.rosterId == this.rosterId &&
          other.rosterName == this.rosterName &&
          other.factionId == this.factionId &&
          other.finishedAt == this.finishedAt &&
          other.rounds == this.rounds &&
          other.myScore == this.myScore &&
          other.opponentScore == this.opponentScore &&
          other.opponentName == this.opponentName &&
          other.logJson == this.logJson);
}

class BattlesCompanion extends UpdateCompanion<BattleRow> {
  final Value<String> id;
  final Value<String> rosterId;
  final Value<String> rosterName;
  final Value<String> factionId;
  final Value<DateTime> finishedAt;
  final Value<int> rounds;
  final Value<int> myScore;
  final Value<int> opponentScore;
  final Value<String?> opponentName;
  final Value<String> logJson;
  final Value<int> rowid;
  const BattlesCompanion({
    this.id = const Value.absent(),
    this.rosterId = const Value.absent(),
    this.rosterName = const Value.absent(),
    this.factionId = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rounds = const Value.absent(),
    this.myScore = const Value.absent(),
    this.opponentScore = const Value.absent(),
    this.opponentName = const Value.absent(),
    this.logJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BattlesCompanion.insert({
    required String id,
    required String rosterId,
    required String rosterName,
    required String factionId,
    required DateTime finishedAt,
    required int rounds,
    required int myScore,
    required int opponentScore,
    this.opponentName = const Value.absent(),
    required String logJson,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        rosterId = Value(rosterId),
        rosterName = Value(rosterName),
        factionId = Value(factionId),
        finishedAt = Value(finishedAt),
        rounds = Value(rounds),
        myScore = Value(myScore),
        opponentScore = Value(opponentScore),
        logJson = Value(logJson);
  static Insertable<BattleRow> custom({
    Expression<String>? id,
    Expression<String>? rosterId,
    Expression<String>? rosterName,
    Expression<String>? factionId,
    Expression<DateTime>? finishedAt,
    Expression<int>? rounds,
    Expression<int>? myScore,
    Expression<int>? opponentScore,
    Expression<String>? opponentName,
    Expression<String>? logJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rosterId != null) 'roster_id': rosterId,
      if (rosterName != null) 'roster_name': rosterName,
      if (factionId != null) 'faction_id': factionId,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rounds != null) 'rounds': rounds,
      if (myScore != null) 'my_score': myScore,
      if (opponentScore != null) 'opponent_score': opponentScore,
      if (opponentName != null) 'opponent_name': opponentName,
      if (logJson != null) 'log_json': logJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BattlesCompanion copyWith(
      {Value<String>? id,
      Value<String>? rosterId,
      Value<String>? rosterName,
      Value<String>? factionId,
      Value<DateTime>? finishedAt,
      Value<int>? rounds,
      Value<int>? myScore,
      Value<int>? opponentScore,
      Value<String?>? opponentName,
      Value<String>? logJson,
      Value<int>? rowid}) {
    return BattlesCompanion(
      id: id ?? this.id,
      rosterId: rosterId ?? this.rosterId,
      rosterName: rosterName ?? this.rosterName,
      factionId: factionId ?? this.factionId,
      finishedAt: finishedAt ?? this.finishedAt,
      rounds: rounds ?? this.rounds,
      myScore: myScore ?? this.myScore,
      opponentScore: opponentScore ?? this.opponentScore,
      opponentName: opponentName ?? this.opponentName,
      logJson: logJson ?? this.logJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (rosterId.present) {
      map['roster_id'] = Variable<String>(rosterId.value);
    }
    if (rosterName.present) {
      map['roster_name'] = Variable<String>(rosterName.value);
    }
    if (factionId.present) {
      map['faction_id'] = Variable<String>(factionId.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rounds.present) {
      map['rounds'] = Variable<int>(rounds.value);
    }
    if (myScore.present) {
      map['my_score'] = Variable<int>(myScore.value);
    }
    if (opponentScore.present) {
      map['opponent_score'] = Variable<int>(opponentScore.value);
    }
    if (opponentName.present) {
      map['opponent_name'] = Variable<String>(opponentName.value);
    }
    if (logJson.present) {
      map['log_json'] = Variable<String>(logJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BattlesCompanion(')
          ..write('id: $id, ')
          ..write('rosterId: $rosterId, ')
          ..write('rosterName: $rosterName, ')
          ..write('factionId: $factionId, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rounds: $rounds, ')
          ..write('myScore: $myScore, ')
          ..write('opponentScore: $opponentScore, ')
          ..write('opponentName: $opponentName, ')
          ..write('logJson: $logJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(Insertable<Setting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final String key;
  final String value;
  const Setting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({String? key, String? value}) => Setting(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting && other.key == this.key && other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<Setting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RostersTable rosters = $RostersTable(this);
  late final $BattlesTable battles = $BattlesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [rosters, battles, settings];
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
  Value<String?> battleLogJson,
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
  Value<String?> battleLogJson,
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

  ColumnFilters<String> get battleLogJson => $composableBuilder(
      column: $table.battleLogJson, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get battleLogJson => $composableBuilder(
      column: $table.battleLogJson,
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

  GeneratedColumn<String> get battleLogJson => $composableBuilder(
      column: $table.battleLogJson, builder: (column) => column);
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
            Value<String?> battleLogJson = const Value.absent(),
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
            battleLogJson: battleLogJson,
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
            Value<String?> battleLogJson = const Value.absent(),
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
            battleLogJson: battleLogJson,
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
typedef $$BattlesTableCreateCompanionBuilder = BattlesCompanion Function({
  required String id,
  required String rosterId,
  required String rosterName,
  required String factionId,
  required DateTime finishedAt,
  required int rounds,
  required int myScore,
  required int opponentScore,
  Value<String?> opponentName,
  required String logJson,
  Value<int> rowid,
});
typedef $$BattlesTableUpdateCompanionBuilder = BattlesCompanion Function({
  Value<String> id,
  Value<String> rosterId,
  Value<String> rosterName,
  Value<String> factionId,
  Value<DateTime> finishedAt,
  Value<int> rounds,
  Value<int> myScore,
  Value<int> opponentScore,
  Value<String?> opponentName,
  Value<String> logJson,
  Value<int> rowid,
});

class $$BattlesTableFilterComposer
    extends Composer<_$AppDatabase, $BattlesTable> {
  $$BattlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rosterId => $composableBuilder(
      column: $table.rosterId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rosterName => $composableBuilder(
      column: $table.rosterName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get factionId => $composableBuilder(
      column: $table.factionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get myScore => $composableBuilder(
      column: $table.myScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get opponentScore => $composableBuilder(
      column: $table.opponentScore, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get opponentName => $composableBuilder(
      column: $table.opponentName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get logJson => $composableBuilder(
      column: $table.logJson, builder: (column) => ColumnFilters(column));
}

class $$BattlesTableOrderingComposer
    extends Composer<_$AppDatabase, $BattlesTable> {
  $$BattlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rosterId => $composableBuilder(
      column: $table.rosterId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rosterName => $composableBuilder(
      column: $table.rosterName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get factionId => $composableBuilder(
      column: $table.factionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rounds => $composableBuilder(
      column: $table.rounds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get myScore => $composableBuilder(
      column: $table.myScore, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get opponentScore => $composableBuilder(
      column: $table.opponentScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get opponentName => $composableBuilder(
      column: $table.opponentName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get logJson => $composableBuilder(
      column: $table.logJson, builder: (column) => ColumnOrderings(column));
}

class $$BattlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BattlesTable> {
  $$BattlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get rosterId =>
      $composableBuilder(column: $table.rosterId, builder: (column) => column);

  GeneratedColumn<String> get rosterName => $composableBuilder(
      column: $table.rosterName, builder: (column) => column);

  GeneratedColumn<String> get factionId =>
      $composableBuilder(column: $table.factionId, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
      column: $table.finishedAt, builder: (column) => column);

  GeneratedColumn<int> get rounds =>
      $composableBuilder(column: $table.rounds, builder: (column) => column);

  GeneratedColumn<int> get myScore =>
      $composableBuilder(column: $table.myScore, builder: (column) => column);

  GeneratedColumn<int> get opponentScore => $composableBuilder(
      column: $table.opponentScore, builder: (column) => column);

  GeneratedColumn<String> get opponentName => $composableBuilder(
      column: $table.opponentName, builder: (column) => column);

  GeneratedColumn<String> get logJson =>
      $composableBuilder(column: $table.logJson, builder: (column) => column);
}

class $$BattlesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BattlesTable,
    BattleRow,
    $$BattlesTableFilterComposer,
    $$BattlesTableOrderingComposer,
    $$BattlesTableAnnotationComposer,
    $$BattlesTableCreateCompanionBuilder,
    $$BattlesTableUpdateCompanionBuilder,
    (BattleRow, BaseReferences<_$AppDatabase, $BattlesTable, BattleRow>),
    BattleRow,
    PrefetchHooks Function()> {
  $$BattlesTableTableManager(_$AppDatabase db, $BattlesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BattlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BattlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BattlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> rosterId = const Value.absent(),
            Value<String> rosterName = const Value.absent(),
            Value<String> factionId = const Value.absent(),
            Value<DateTime> finishedAt = const Value.absent(),
            Value<int> rounds = const Value.absent(),
            Value<int> myScore = const Value.absent(),
            Value<int> opponentScore = const Value.absent(),
            Value<String?> opponentName = const Value.absent(),
            Value<String> logJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BattlesCompanion(
            id: id,
            rosterId: rosterId,
            rosterName: rosterName,
            factionId: factionId,
            finishedAt: finishedAt,
            rounds: rounds,
            myScore: myScore,
            opponentScore: opponentScore,
            opponentName: opponentName,
            logJson: logJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String rosterId,
            required String rosterName,
            required String factionId,
            required DateTime finishedAt,
            required int rounds,
            required int myScore,
            required int opponentScore,
            Value<String?> opponentName = const Value.absent(),
            required String logJson,
            Value<int> rowid = const Value.absent(),
          }) =>
              BattlesCompanion.insert(
            id: id,
            rosterId: rosterId,
            rosterName: rosterName,
            factionId: factionId,
            finishedAt: finishedAt,
            rounds: rounds,
            myScore: myScore,
            opponentScore: opponentScore,
            opponentName: opponentName,
            logJson: logJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BattlesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BattlesTable,
    BattleRow,
    $$BattlesTableFilterComposer,
    $$BattlesTableOrderingComposer,
    $$BattlesTableAnnotationComposer,
    $$BattlesTableCreateCompanionBuilder,
    $$BattlesTableUpdateCompanionBuilder,
    (BattleRow, BaseReferences<_$AppDatabase, $BattlesTable, BattleRow>),
    BattleRow,
    PrefetchHooks Function()>;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()> {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              SettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SettingsTable,
    Setting,
    $$SettingsTableFilterComposer,
    $$SettingsTableOrderingComposer,
    $$SettingsTableAnnotationComposer,
    $$SettingsTableCreateCompanionBuilder,
    $$SettingsTableUpdateCompanionBuilder,
    (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
    Setting,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RostersTableTableManager get rosters =>
      $$RostersTableTableManager(_db, _db.rosters);
  $$BattlesTableTableManager get battles =>
      $$BattlesTableTableManager(_db, _db.battles);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
}
