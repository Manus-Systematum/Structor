/// Loads a 40kdc-data snapshot from disk into source DTOs.
///
/// Reads the layout produced by `tools/fetch-40kdc.sh`:
///
///     <root>/core/<file>.json
///     <root>/core/<faction>/<file>.json
///     <root>/enrichment/<faction>/<file>.json
///
/// Missing files are tolerated and recorded in [FactionData.missingFiles]; an
/// incomplete snapshot should produce a partial load plus an honest report,
/// not an exception.
library;

import 'dart:convert';
import 'dart:io';

import 'json.dart';
import 'source_models.dart';

class CoreData {
  final List<GameVersion> gameVersions;
  final Map<String, String> forceDispositions; // id -> name
  final Map<String, String> missions; // id -> name
  final List<MissionMatchup> missionMatchups;
  final Set<String> weaponKeywordIds;
  final List<SourceStratagem> coreStratagems;
  final List<String> missingFiles;

  const CoreData({
    required this.gameVersions,
    required this.forceDispositions,
    required this.missions,
    required this.missionMatchups,
    required this.weaponKeywordIds,
    required this.coreStratagems,
    required this.missingFiles,
  });
}

class MissionMatchup {
  final String disposition;
  final String opponentDisposition;
  final String missionId;

  const MissionMatchup({
    required this.disposition,
    required this.opponentDisposition,
    required this.missionId,
  });

  factory MissionMatchup.fromJson(Object? v) {
    final j = asMap(v);
    return MissionMatchup(
      disposition: strOr(j['disposition'], ''),
      opponentDisposition: strOr(j['opponent_disposition'], ''),
      missionId: strOr(j['mission_id'], ''),
    );
  }
}

class FactionData {
  final String factionId;
  final List<SourceUnit> units;
  final List<SourceWeapon> weapons;
  final List<SourceDetachment> detachments;
  final List<SourceStratagem> stratagems;
  final List<SourceAbility> abilities;
  final List<PhaseMapping> phaseMappings;
  final List<LeaderAttachment> leaderAttachments;
  final Set<String> enhancementIds;
  final List<String> missingFiles;

  const FactionData({
    required this.factionId,
    required this.units,
    required this.weapons,
    required this.detachments,
    required this.stratagems,
    required this.abilities,
    required this.phaseMappings,
    required this.leaderAttachments,
    required this.enhancementIds,
    required this.missingFiles,
  });
}

class DatasetLoader {
  final Directory root;

  DatasetLoader(String rootPath) : root = Directory(rootPath);

  /// Reads a JSON array file, returning `null` when absent or unparseable.
  List<Object?>? _readArray(String relativePath) {
    final file = File('${root.path}/$relativePath');
    if (!file.existsSync()) return null;
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  CoreData loadCore() {
    final missing = <String>[];

    List<Object?> read(String path) {
      final data = _readArray(path);
      if (data == null) {
        missing.add(path);
        return const [];
      }
      return data;
    }

    final dispositions = <String, String>{};
    for (final raw in read('core/force-dispositions.json')) {
      final j = asMap(raw);
      final id = str(j['id']);
      if (id != null) dispositions[id] = strOr(j['name'], id);
    }

    final missions = <String, String>{};
    for (final raw in read('core/missions.json')) {
      final j = asMap(raw);
      final id = str(j['id']);
      if (id != null) missions[id] = strOr(j['name'], id);
    }

    final keywordIds = <String>{};
    for (final raw in read('core/weapon-keywords.json')) {
      final id = str(asMap(raw)['id']);
      if (id != null) keywordIds.add(id);
    }

    return CoreData(
      gameVersions: read('core/game-versions.json')
          .map(GameVersion.fromJson)
          .toList(growable: false),
      forceDispositions: dispositions,
      missions: missions,
      missionMatchups: read('core/mission-matchups.json')
          .map(MissionMatchup.fromJson)
          .toList(growable: false),
      weaponKeywordIds: keywordIds,
      coreStratagems: read('core/stratagems.json')
          .map(SourceStratagem.fromJson)
          .toList(growable: false),
      missingFiles: missing,
    );
  }

  FactionData loadFaction(String factionId) {
    final missing = <String>[];

    List<Object?> read(String path) {
      final data = _readArray(path);
      if (data == null) {
        missing.add(path);
        return const [];
      }
      return data;
    }

    final enhancementIds = <String>{};
    for (final raw in read('core/$factionId/enhancements.json')) {
      final id = str(asMap(raw)['id']);
      if (id != null) enhancementIds.add(id);
    }

    return FactionData(
      factionId: factionId,
      units: read('core/$factionId/units.json')
          .map(SourceUnit.fromJson)
          .toList(growable: false),
      weapons: read('core/$factionId/weapons.json')
          .map(SourceWeapon.fromJson)
          .toList(growable: false),
      detachments: read('core/$factionId/detachments.json')
          .map(SourceDetachment.fromJson)
          .toList(growable: false),
      stratagems: read('core/$factionId/stratagems.json')
          .map(SourceStratagem.fromJson)
          .toList(growable: false),
      abilities: read('enrichment/$factionId/abilities.json')
          .map(SourceAbility.fromJson)
          .toList(growable: false),
      phaseMappings: read('enrichment/$factionId/phase-mappings.json')
          .map(PhaseMapping.fromJson)
          .toList(growable: false),
      leaderAttachments: read('core/$factionId/leader-attachments.json')
          .map(LeaderAttachment.fromJson)
          .toList(growable: false),
      enhancementIds: enhancementIds,
      missingFiles: missing,
    );
  }

  /// Raw JSON records from [relativePath], keyed by [idKey].
  ///
  /// Snapshots (DESIGN.md §2.2) must preserve the original records rather than
  /// re-serialise parsed DTOs: a snapshot's whole point is that a later build,
  /// whose model has moved on, can still read a list saved today.
  Map<String, Object?> rawIndex(String relativePath, {String idKey = 'id'}) {
    final data = _readArray(relativePath);
    if (data == null) return const {};
    final index = <String, Object?>{};
    for (final record in data) {
      final id = str(asMap(record)[idKey]);
      if (id != null) index[id] = record;
    }
    return index;
  }

  Map<String, Object?> rawUnits(String factionId) =>
      rawIndex('core/$factionId/units.json');

  Map<String, Object?> rawWeapons(String factionId) =>
      rawIndex('core/$factionId/weapons.json');

  Map<String, Object?> rawDetachments(String factionId) =>
      rawIndex('core/$factionId/detachments.json');

  Map<String, Object?> rawAbilities(String factionId) =>
      rawIndex('enrichment/$factionId/abilities.json', idKey: 'ability_id');

  /// Faction ids present under `core/`, i.e. directories rather than files.
  List<String> availableFactions() {
    final dir = Directory('${root.path}/core');
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .where((n) => !n.startsWith('_'))
        .toList()
      ..sort();
  }
}
