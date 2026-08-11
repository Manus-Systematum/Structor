/// Data-transfer objects mirroring the 40kdc-data source format.
///
/// These are deliberately *source-shaped*, not domain-shaped. The normalised
/// domain model (DESIGN.md §2.1) is derived from these in a later stage; keeping
/// the two apart means upstream schema drift lands in one place.
library;

import 'json.dart';

class GameVersion {
  final String edition;
  final String dataslate;

  const GameVersion({required this.edition, required this.dataslate});

  factory GameVersion.fromJson(Object? v) {
    final j = asMap(v);
    return GameVersion(
      edition: strOr(j['edition'], 'unknown'),
      dataslate: strOr(j['dataslate'], 'unknown'),
    );
  }

  /// True for content still carried over from the 10e archive. DESIGN.md §3.0
  /// requires this be surfaced, never silently presented as current.
  bool get isProvisional => dataslate.contains('provisional');

  @override
  String toString() => '$edition/$dataslate';
}

class ModelProfile {
  final String name;
  final String? m, t, w, sv, invulnSv, ld, oc;

  const ModelProfile({
    required this.name,
    this.m,
    this.t,
    this.w,
    this.sv,
    this.invulnSv,
    this.ld,
    this.oc,
  });

  factory ModelProfile.fromJson(Object? v) {
    final j = asMap(v);
    return ModelProfile(
      name: strOr(j['name'], '(unnamed)'),
      m: str(j['M']),
      t: str(j['T']),
      w: str(j['W']),
      sv: str(j['Sv']),
      invulnSv: str(j['invuln_sv']),
      ld: str(j['Ld']),
      oc: str(j['OC']),
    );
  }

  /// Statline identity, used to detect genuinely divergent per-model profiles
  /// within one attached unit (DESIGN.md §7.3.6).
  String get statKey => '$m|$t|$w|$sv|$invulnSv|$ld|$oc';
}

/// Points bracket. Carries `unitCountMin`/`unitCountMax` because 11e prices
/// some units by *copy index* as well as model count — see DESIGN.md §2.1.
class PointsBracket {
  final int models;
  final int? modelsMax;
  final int cost;
  final int? unitCountMin;
  final int? unitCountMax;

  const PointsBracket({
    required this.models,
    required this.cost,
    this.modelsMax,
    this.unitCountMin,
    this.unitCountMax,
  });

  factory PointsBracket.fromJson(Object? v) {
    final j = asMap(v);
    return PointsBracket(
      models: intOr(j['models'], 0),
      modelsMax: asInt(j['models_max']),
      cost: intOr(j['cost'], 0),
      unitCountMin: asInt(j['unit_count_min']),
      unitCountMax: asInt(j['unit_count_max']),
    );
  }

  /// True when this bracket's price depends on how many copies of the datasheet
  /// the roster already holds.
  bool get isCopyScaled => (unitCountMin ?? 1) > 1 || unitCountMax != null;
}

/// Wargear that costs points per instance, e.g. a missile pod at 5 pts.
class WargearCost {
  final String itemId;
  final int cost;

  const WargearCost({required this.itemId, required this.cost});

  factory WargearCost.fromJson(Object? v) {
    final j = asMap(v);
    return WargearCost(
      itemId: strOr(j['item_id'], ''),
      cost: intOr(j['cost'], 0),
    );
  }
}

/// A free-but-capped wargear allowance, e.g. up to 3 shield drones per 3
/// models. Contributes no points, only a legality bound.
class WargearBudget {
  final List<String> items;
  final int count;
  final int? perModels;

  const WargearBudget({
    required this.items,
    required this.count,
    required this.perModels,
  });

  factory WargearBudget.fromJson(Object? v) {
    final j = asMap(v);
    return WargearBudget(
      items: strList(j['items']),
      count: intOr(j['count'], 0),
      perModels: asInt(j['per_models']),
    );
  }
}

class SourceUnit {
  final String id;
  final String name;
  final String factionId;
  final List<ModelProfile> profiles;
  final List<PointsBracket> points;
  final List<WargearCost> wargearCosts;
  final List<WargearBudget> wargearBudgets;
  final List<String> keywords;
  final List<String> factionKeywords;
  final List<String> abilityIds;
  final List<String> weaponIds;
  final String? attachmentRole;
  final GameVersion gameVersion;

  const SourceUnit({
    required this.id,
    required this.name,
    required this.factionId,
    required this.profiles,
    required this.points,
    required this.wargearCosts,
    required this.wargearBudgets,
    required this.keywords,
    required this.factionKeywords,
    required this.abilityIds,
    required this.weaponIds,
    required this.attachmentRole,
    required this.gameVersion,
  });

  factory SourceUnit.fromJson(Object? v) {
    final j = asMap(v);
    return SourceUnit(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], '(unnamed)'),
      factionId: strOr(j['faction_id'], ''),
      profiles: asList(j['profiles']).map(ModelProfile.fromJson).toList(growable: false),
      points: asList(j['points']).map(PointsBracket.fromJson).toList(growable: false),
      wargearCosts:
          asList(j['wargear_costs']).map(WargearCost.fromJson).toList(growable: false),
      wargearBudgets: asList(j['wargear_budgets'])
          .map(WargearBudget.fromJson)
          .toList(growable: false),
      keywords: strList(j['keywords']),
      factionKeywords: strList(j['faction_keywords']),
      abilityIds: strList(j['ability_ids']),
      weaponIds: strList(j['weapon_ids']),
      attachmentRole: str(j['attachment_role']),
      gameVersion: GameVersion.fromJson(j['game_version']),
    );
  }

  bool get isLeader => attachmentRole == 'leader';

  /// Selects the bracket for [models] models when this is the [copyIndex]-th
  /// unit of this datasheet in the roster (1-based).
  ///
  /// 11e prices some datasheets by copy index as well as model count, so the
  /// full cost of a unit is `bracketFor(...).cost` plus the per-instance
  /// wargear costs — see DESIGN.md §2.1. Verified against a real 2,000 pt list:
  /// Crisis Fireknife is 100 base + 6 missile pods at 5 = 130.
  PointsBracket? bracketFor({required int models, int copyIndex = 1}) {
    for (final b in points) {
      final withinModels =
          models >= b.models && models <= (b.modelsMax ?? b.models);
      final withinCopies = copyIndex >= (b.unitCountMin ?? 1) &&
          copyIndex <= (b.unitCountMax ?? 1 << 30);
      if (withinModels && withinCopies) return b;
    }
    return null;
  }

  int costOfWargear(String itemId) => wargearCosts
      .where((c) => c.itemId == itemId)
      .fold(0, (sum, c) => sum + c.cost);
}

class WeaponProfile {
  final String name;
  final String? range;
  final Map<String, String> stats;
  final List<String> keywordIds;

  const WeaponProfile({
    required this.name,
    required this.range,
    required this.stats,
    required this.keywordIds,
  });

  factory WeaponProfile.fromJson(Object? v) {
    final j = asMap(v);
    final rawStats = asMap(j['stats']);
    final stats = <String, String>{};
    for (final entry in rawStats.entries) {
      final s = str(entry.value);
      if (s != null) stats[entry.key] = s;
    }
    return WeaponProfile(
      name: strOr(j['name'], '(unnamed)'),
      range: str(j['range']),
      stats: stats,
      keywordIds: asList(j['keywords'])
          .map((k) => str(asMap(k)['keyword_id']))
          .whereType<String>()
          .toList(growable: false),
    );
  }

  /// Skill characteristic, or null for Torrent-style auto-hitting weapons.
  String? get skill => stats['BS'] ?? stats['WS'];

  /// Identity used for aggregation on the shooting/fight screens.
  ///
  /// DESIGN.md §7.3.5: aggregation keys on the *resolved profile*, never on the
  /// weapon name. A Commander's Missile pod (BS3+) and a Crisis suit's Missile
  /// pod (BS4+) are the same name and must remain separate rows.
  String get profileKey {
    final keys = stats.keys.toList()..sort();
    final body = keys.map((k) => '$k=${stats[k]}').join(',');
    final kw = (List<String>.from(keywordIds)..sort()).join('+');
    return '$range|$body|$kw';
  }
}

class SourceWeapon {
  final String id;
  final String name;
  final String type;
  final List<WeaponProfile> profiles;
  final GameVersion gameVersion;

  const SourceWeapon({
    required this.id,
    required this.name,
    required this.type,
    required this.profiles,
    required this.gameVersion,
  });

  factory SourceWeapon.fromJson(Object? v) {
    final j = asMap(v);
    return SourceWeapon(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], '(unnamed)'),
      type: strOr(j['type'], 'unknown'),
      profiles: asList(j['profiles']).map(WeaponProfile.fromJson).toList(growable: false),
      gameVersion: GameVersion.fromJson(j['game_version']),
    );
  }

  bool get isRanged => type == 'ranged';
}

class SourceStratagem {
  final String id;
  final String name;
  final String? category;
  final String? type;
  final String? detachmentId;
  final String? playerTurn;
  final String? timing;
  final String? abilityId;
  final int cpCost;
  final List<String> phases;
  final GameVersion gameVersion;

  const SourceStratagem({
    required this.id,
    required this.name,
    required this.category,
    required this.type,
    required this.detachmentId,
    required this.playerTurn,
    required this.timing,
    required this.abilityId,
    required this.cpCost,
    required this.phases,
    required this.gameVersion,
  });

  factory SourceStratagem.fromJson(Object? v) {
    final j = asMap(v);
    return SourceStratagem(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], '(unnamed)'),
      category: str(j['category']),
      type: str(j['type']),
      detachmentId: str(j['detachment_id']),
      playerTurn: str(j['player_turn']),
      timing: str(j['timing']),
      abilityId: str(j['ability_id']),
      cpCost: intOr(j['cp_cost'], 0),
      phases: strList(j['phases']),
      gameVersion: GameVersion.fromJson(j['game_version']),
    );
  }
}

class SourceDetachment {
  final String id;
  final String name;
  final String factionId;
  final String? detachmentRuleId;
  final int detachmentPoints;
  final List<String> forceDispositions;
  final List<String> uniqueTags;
  final List<String> stratagemIds;
  final List<String> enhancementIds;
  final GameVersion gameVersion;

  const SourceDetachment({
    required this.id,
    required this.name,
    required this.factionId,
    required this.detachmentRuleId,
    required this.detachmentPoints,
    required this.forceDispositions,
    required this.uniqueTags,
    required this.stratagemIds,
    required this.enhancementIds,
    required this.gameVersion,
  });

  factory SourceDetachment.fromJson(Object? v) {
    final j = asMap(v);
    return SourceDetachment(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], '(unnamed)'),
      factionId: strOr(j['faction_id'], ''),
      detachmentRuleId: str(j['detachment_rule_id']),
      detachmentPoints: intOr(j['detachment_points'], 0),
      forceDispositions: strList(j['force_dispositions']),
      uniqueTags: strList(pick(j, ['unique_tags', 'tags'])),
      stratagemIds: strList(j['stratagem_ids']),
      enhancementIds: strList(j['enhancement_ids']),
      gameVersion: GameVersion.fromJson(j['game_version']),
    );
  }
}

class SourceAbility {
  final String abilityId;
  final String name;
  final String? abilityType;
  final String? behavior;
  final Map<String, dynamic> effect;
  final List<String> unitIds;
  final GameVersion gameVersion;

  const SourceAbility({
    required this.abilityId,
    required this.name,
    required this.abilityType,
    required this.behavior,
    required this.effect,
    required this.unitIds,
    required this.gameVersion,
  });

  factory SourceAbility.fromJson(Object? v) {
    final j = asMap(v);
    return SourceAbility(
      abilityId: strOr(j['ability_id'], ''),
      name: strOr(j['name'], '(unnamed)'),
      abilityType: str(j['ability_type']),
      behavior: str(j['behavior']),
      effect: asMap(j['effect']),
      unitIds: strList(j['unit_ids']),
      gameVersion: GameVersion.fromJson(j['game_version']),
    );
  }

  /// Outermost effect discriminator, e.g. `conditional`, `stat-modifier`.
  /// The rules renderer (DESIGN.md §7.3.6) dispatches on this.
  String get effectType => strOr(effect['type'], 'none');

  /// Structural fingerprint used to detect near-duplicate ability records —
  /// upstream carries both `weapon-support-system` and
  /// `weapon-support-systems` with identical effects (DESIGN.md §7.3.6).
  String get effectFingerprint => _fingerprint(effect);

  static String _fingerprint(Object? node) {
    if (node is Map) {
      final keys = node.keys.map((k) => k.toString()).toList()..sort();
      return '{${keys.map((k) => '$k:${_fingerprint(node[k])}').join(',')}}';
    }
    if (node is List) return '[${node.map(_fingerprint).join(',')}]';
    return str(node) ?? 'null';
  }
}

class PhaseMapping {
  final String sourceId;
  final String? sourceType;
  final List<String> phases;

  const PhaseMapping({
    required this.sourceId,
    required this.sourceType,
    required this.phases,
  });

  factory PhaseMapping.fromJson(Object? v) {
    final j = asMap(v);
    return PhaseMapping(
      sourceId: strOr(j['source_id'], ''),
      sourceType: str(j['source_type']),
      phases: strList(j['phases']),
    );
  }
}
