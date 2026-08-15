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

import 'corrections.dart';
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

  /// Parsed Enhancement and Unit Upgrade records. [enhancementIds] remains the
  /// validator's cheap membership test; this is for anything that has to show
  /// one to a player.
  final List<SourceEnhancement> enhancements;

  /// How each datasheet is made up. Needed only by the builder, to give a new
  /// unit a legal starting loadout.
  final List<UnitComposition> compositions;

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
    this.enhancements = const [],
    this.compositions = const [],
    required this.missingFiles,
  });
}

class DatasetLoader {
  final Directory root;

  /// Applied to abilities as they are read, so every consumer — the bundler,
  /// the snapshot writer, the coverage report — sees the same corrected data
  /// (DESIGN.md §3.6). A loader built without them reads the snapshot as it
  /// came from upstream, which is what the cross-check wants.
  final DataCorrections corrections;

  DatasetLoader(String rootPath, {this.corrections = DataCorrections.empty})
      : root = Directory(rootPath);

  /// Reads corrections from [path], or none if the file is absent.
  static DataCorrections correctionsAt(String path) {
    final file = File(path);
    if (!file.existsSync()) return DataCorrections.empty;
    return DataCorrections.parse(file.readAsStringSync());
  }

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

    final enhancementRecords = read('core/$factionId/enhancements.json');
    final enhancementIds = <String>{};
    for (final raw in enhancementRecords) {
      final id = str(asMap(raw)['id']);
      if (id != null) enhancementIds.add(id);
    }

    return FactionData(
      factionId: factionId,
      units: corrections
          .applyToUnits(factionId, read('core/$factionId/units.json'))
          .records
          .map(SourceUnit.fromJson)
          .toList(growable: false),
      weapons: corrections
          .applyToWeapons(factionId, read('core/$factionId/weapons.json'))
          .records
          .map(SourceWeapon.fromJson)
          .toList(growable: false),
      detachments: read('core/$factionId/detachments.json')
          .map(SourceDetachment.fromJson)
          .toList(growable: false),
      stratagems: read('core/$factionId/stratagems.json')
          .map(SourceStratagem.fromJson)
          .toList(growable: false),
      abilities: corrections
          .applyToAbilities(
            factionId,
            read('enrichment/$factionId/abilities.json'),
          )
          .records
          .map(SourceAbility.fromJson)
          .toList(growable: false),
      phaseMappings: read('enrichment/$factionId/phase-mappings.json')
          .map(PhaseMapping.fromJson)
          .toList(growable: false),
      leaderAttachments: read('core/$factionId/leader-attachments.json')
          .map(LeaderAttachment.fromJson)
          .toList(growable: false),
      enhancementIds: enhancementIds,
      compositions: read('core/$factionId/unit-compositions.json')
          .map(UnitComposition.fromJson)
          .where((c) => c.unitId.isNotEmpty)
          .toList(growable: false),
      enhancements: enhancementRecords
          .map(SourceEnhancement.fromJson)
          .where((e) => e.id.isNotEmpty)
          .toList(growable: false),
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

  Map<String, Object?> rawUnits(String factionId) {
    final index = <String, Object?>{};
    for (final record in correctedUnits(factionId).records) {
      final id = str(asMap(record)['id']);
      if (id != null) index[id] = record;
    }
    return index;
  }

  Map<String, Object?> rawWeapons(String factionId) {
    final index = <String, Object?>{};
    for (final record in correctedWeapons(factionId).records) {
      final id = str(asMap(record)['id']);
      if (id != null) index[id] = record;
    }
    return index;
  }

  Map<String, Object?> rawDetachments(String factionId) =>
      rawIndex('core/$factionId/detachments.json');

  Map<String, Object?> rawAbilities(String factionId) {
    final index = <String, Object?>{};
    for (final record in correctedAbilities(factionId).records) {
      final id = str(asMap(record)['ability_id']);
      if (id != null) index[id] = record;
    }
    return index;
  }

  /// Raw ability records with [corrections] applied, alongside the bookkeeping
  /// of which corrections fired and which matched nothing.
  CorrectionResult correctedAbilities(String factionId) =>
      corrections.applyToAbilities(
        factionId,
        _readArray('enrichment/$factionId/abilities.json') ?? const [],
      );

  /// Raw weapon records with [corrections] applied, including any the
  /// corrections add outright.
  CorrectionResult correctedWeapons(String factionId) =>
      corrections.applyToWeapons(
        factionId,
        _readArray('core/$factionId/weapons.json') ?? const [],
      );

  /// Raw unit records with [corrections] applied.
  CorrectionResult correctedUnits(String factionId) =>
      corrections.applyToUnits(
        factionId,
        _readArray('core/$factionId/units.json') ?? const [],
      );

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
