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

  ModelProfile withInvulnerableSave(String? save) => ModelProfile(
        name: name,
        m: m,
        t: t,
        w: w,
        sv: sv,
        invulnSv: save,
        ld: ld,
        oc: oc,
      );
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

  bool hasKeyword(String keyword) =>
      keywords.any((k) => k.toLowerCase() == keyword.toLowerCase());

  bool get isCharacter => hasKeyword('Character');
  bool get isEpicHero => hasKeyword('Epic Hero');

  /// Battleline and Dedicated Transport share a doubled duplicate cap
  /// (DESIGN.md §4.4), so they are tested together.
  bool get hasDoubledCap =>
      hasKeyword('Battleline') || hasKeyword('Dedicated Transport');

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

/// A weapon keyword together with the parameters that give it its meaning.
///
/// The parameters are not decoration. `melta` is Melta 2, `anti` is
/// Anti-Infantry 4+, `rapid-fire` is Rapid Fire 1 — **201 of 920 keyword
/// instances in the snapshot carry one**, and dropping them turns a specific
/// rule into a vague one at exactly the moment a player is reading it to
/// decide whether to shoot.
class WeaponKeyword {
  final String id;

  /// `{value: 2}` for Melta 2, `{target_keyword: INFANTRY, threshold: 4}` for
  /// Anti-Infantry 4+. Kept raw so a keyword the app has never heard of still
  /// shows its numbers.
  final Map<String, String> parameters;

  const WeaponKeyword(this.id, {this.parameters = const {}});

  factory WeaponKeyword.fromJson(Object? v) {
    final j = asMap(v);
    final params = <String, String>{};
    for (final entry in asMap(j['parameters']).entries) {
      final value = str(entry.value);
      if (value != null && value.isNotEmpty) params[entry.key] = value;
    }
    return WeaponKeyword(strOr(j['keyword_id'], ''), parameters: params);
  }

  Map<String, Object?> toJson() => {
        'keyword_id': id,
        if (parameters.isNotEmpty) 'parameters': parameters,
      };

  /// As it is printed on a datasheet: `MELTA 2`, `ANTI-INFANTRY 4+`,
  /// `SUSTAINED HITS 1`, `TORRENT`.
  String get label {
    final name = id.replaceAll('-', ' ').toUpperCase();
    final target = parameters['target_keyword'];
    final threshold = parameters['threshold'];
    if (target != null || threshold != null) {
      final subject = target == null ? name : '$name-${target.toUpperCase()}';
      return threshold == null ? subject : '$subject $threshold+';
    }
    final value = parameters['value'];
    if (value != null) return '$name $value';
    // An unrecognised parameter set is shown rather than dropped: a keyword
    // rendered without its numbers reads as though it had none.
    if (parameters.isEmpty) return name;
    return '$name ${parameters.values.join('/')}';
  }

  /// Stable identity for aggregation — Melta 2 and Melta 4 are not the same
  /// profile, and keying on the bare id would merge them.
  String get key {
    if (parameters.isEmpty) return id;
    final keys = parameters.keys.toList()..sort();
    return '$id(${keys.map((k) => '$k=${parameters[k]}').join(',')})';
  }

  @override
  String toString() => label;
}

class WeaponProfile {
  final String name;
  final String? range;
  final Map<String, String> stats;
  final List<WeaponKeyword> keywords;

  const WeaponProfile({
    required this.name,
    required this.range,
    required this.stats,
    required this.keywords,
  });

  /// Bare keyword ids, for callers that only ask whether a keyword is present.
  List<String> get keywordIds =>
      [for (final k in keywords) k.id];

  bool hasKeyword(String id) => keywords.any((k) => k.id == id);

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
      keywords: asList(j['keywords'])
          .map(WeaponKeyword.fromJson)
          .where((k) => k.id.isNotEmpty)
          .toList(growable: false),
    );
  }

  /// Skill characteristic, or null for Torrent-style auto-hitting weapons.
  String? get skill => stats['BS'] ?? stats['WS'];

  /// Whether this *profile* is a melee profile.
  ///
  /// A weapon's declared `type` is not sufficient: several weapons are typed
  /// `ranged` yet carry both a `Ranged` and a `Melee` profile — the T'au
  /// Fusion eliminator has BS2+ at 18" and WS4+ in combat. The reliable
  /// discriminator is the skill characteristic, `WS` for melee and `BS` for
  /// ranged, with the range string and then the weapon's own type as
  /// fallbacks for auto-hitting profiles that carry neither.
  bool isMelee({required bool weaponIsMelee}) {
    if (stats.containsKey('WS')) return true;
    if (stats.containsKey('BS')) return false;
    if ((range ?? '').toLowerCase() == 'melee') return true;
    return weaponIsMelee;
  }

  /// Identity used for aggregation on the shooting/fight screens.
  ///
  /// DESIGN.md §7.3.5: aggregation keys on the *resolved profile*, never on the
  /// weapon name. A Commander's Missile pod (BS3+) and a Crisis suit's Missile
  /// pod (BS4+) are the same name and must remain separate rows.
  String get profileKey {
    final keys = stats.keys.toList()..sort();
    final body = keys.map((k) => '$k=${stats[k]}').join(',');
    final kw = (keywords.map((k) => k.key).toList()..sort()).join('+');
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

  /// `{frequency: once-per-turn}` and similar. Kept raw — the renderer reads
  /// it, nothing else needs a typed view yet.
  final Map<String, dynamic> usage;

  /// `{event, subject, optional}` for reactive abilities. Raw for the same
  /// reason as [usage].
  final Map<String, dynamic> trigger;

  final List<String> unitIds;
  final GameVersion gameVersion;

  const SourceAbility({
    required this.abilityId,
    required this.name,
    required this.abilityType,
    required this.behavior,
    required this.effect,
    required this.usage,
    required this.trigger,
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
      usage: asMap(j['usage']),
      trigger: asMap(j['trigger']),
      unitIds: strList(j['unit_ids']),
      gameVersion: GameVersion.fromJson(j['game_version']),
    );
  }

  /// Outermost effect discriminator, e.g. `conditional`, `stat-modifier`.
  /// The rules renderer (DESIGN.md §7.3.6) dispatches on this.
  String get effectType => strOr(effect['type'], 'none');

  /// An invulnerable save this ability grants unconditionally, if any.
  ///
  /// The two encodings coexist upstream: most models carry `invuln_sv` on the
  /// profile, but the Commander in Coldstar Battlesuit's 4+ lives only in its
  /// `shield-generator` ability. A screen that reads the statline alone shows
  /// no invulnerable save on a model that has one.
  ///
  /// Deliberately does not descend into `conditional`. A save that applies
  /// only sometimes is a rule to read, not a number to print in a column that
  /// says the model always has it.
  int? get unconditionalInvulnerableSave => _invulnIn(effect);

  static int? _invulnIn(Map<String, dynamic> node) {
    switch (strOr(node['type'], '')) {
      case 'invulnerable-save':
        return asInt(asMap(node['modifier'])['invuln_sv']);
      case 'sequence':
        for (final step in asList(node['steps'])) {
          final found = _invulnIn(asMap(step));
          if (found != null) return found;
        }
    }
    return null;
  }

  /// The weapon this ability grants its bearer, if it names one.
  ///
  /// Drones are wargear that give the model a rule, and a Gun Drone's rule is
  /// a twin pulse carbine (§7.3.7). Only an explicit `weapon_id` counts:
  /// `{grant_type: ranged-weapon}` with no id names nothing, and guessing
  /// which weapon was meant is the invention §7.6 forbids.
  String? get grantedWeaponId => _grantedWeaponIn(effect);

  static String? _grantedWeaponIn(Map<String, dynamic> node) {
    if (strOr(node['type'], '') == 'ability-grant') {
      final id = str(asMap(node['modifier'])['weapon_id']);
      if (id != null) return id;
    }
    for (final step in asList(node['steps'])) {
      final found = _grantedWeaponIn(asMap(step));
      if (found != null) return found;
    }
    return null;
  }

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

/// Which units a given leader may join. This is the data behind the `LEADS`
/// edge of DESIGN.md §2.2, and the reason leader legality is checkable rather
/// than left to the player.
class LeaderAttachment {
  final String leaderId;
  final List<String> eligibleBodyguardIds;

  const LeaderAttachment({
    required this.leaderId,
    required this.eligibleBodyguardIds,
  });

  factory LeaderAttachment.fromJson(Object? v) {
    final j = asMap(v);
    return LeaderAttachment(
      leaderId: strOr(j['leader_id'], ''),
      eligibleBodyguardIds: strList(j['eligible_bodyguard_ids']),
    );
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
