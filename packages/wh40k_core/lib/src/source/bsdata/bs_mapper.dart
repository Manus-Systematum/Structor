/// BattleScribe entries -> records in 40kdc's shape (DESIGN.md §3.10).
///
/// **Raw records, not typed models.** The obvious output was `SourceUnit` and
/// friends, and it is the wrong one: the bundler, the snapshot writer and the
/// corrections layer all work on the JSON the loader read, never on the DTOs.
/// Emitting JSON means the merge is a field-by-field diff of two records that
/// already speak the same language, the conflict log is readable by a person,
/// and every downstream consumer carries on unchanged.
///
/// The mapper is **partial, and honest about it**. BSData is a list-building
/// catalogue: it knows what a datasheet costs, what models it contains, what it
/// may carry and what its rules say. It knows nothing about missions, terrain,
/// stratagems, or the structured ability effects the play surfaces render from.
/// Everything in that second group stays on 40kdc, and this file does not
/// pretend to produce it.
library;

import '../json.dart';
import 'bs_document.dart';
import 'bs_slug.dart';

/// Stamped on every record this mapper writes, so a merged dataset says which
/// lineage each field came from without anyone having to diff two trees.
const bsGameVersion = {'edition': '11th', 'dataslate': 'bsdata'};

class BsFaction {
  final String factionId;
  final List<Map<String, Object?>> units;
  final List<Map<String, Object?>> weapons;
  final List<Map<String, Object?>> abilities;
  final List<Map<String, Object?>> compositions;

  /// Names that slugged to the same id.
  ///
  /// Reported rather than resolved. A collision means two datasheets would
  /// share one record, and picking a winner quietly is how a unit disappears
  /// from a faction without anybody noticing.
  final List<String> collisions;

  const BsFaction({
    required this.factionId,
    required this.units,
    required this.weapons,
    required this.abilities,
    required this.compositions,
    required this.collisions,
  });
}

class BsMapper {
  final BsIndex index;

  /// The `pts` cost type id. Every entry lists all eight cost types — Crusade
  /// Points, Blackstone Fragments and the rest, all zero on a normal
  /// datasheet — so the type has to be matched, not the first cost taken.
  late final String _pts = index.costTypes.entries
      .firstWhere((e) => e.value == 'pts', orElse: () => const MapEntry('', ''))
      .key;

  BsMapper(this.index);

  /// One faction's records.
  ///
  /// [anchors] are the 40kdc weapon records, when there are any. They decide
  /// only one thing — which of several variants of a weapon keeps the plain
  /// id — and that one thing protects every saved roster and every correction
  /// already keyed to it.
  BsFaction faction(String factionId, {List<Object?> anchors = const []}) {
    final units = <String, Map<String, Object?>>{};

    /// Keyed by `slug|profile-fingerprint` until every datasheet has been
    /// read, because which variant deserves the plain id is not knowable
    /// until they have all been counted.
    final weapons = <String, Map<String, Object?>>{};
    final variantUsers = <String, Set<String>>{};
    final abilities = <String, Map<String, Object?>>{};
    final compositions = <String, Map<String, Object?>>{};
    final collisions = <String>[];

    for (final root in index.roots) {
      if (!_isDatasheet(root)) continue;
      final id = bsSlug(root.name);
      if (id.isEmpty) continue;
      if (units.containsKey(id)) {
        collisions.add('$id <- ${root.name}');
        continue;
      }

      final walk = _Walk(index, _pts)..visit(root);

      units[id] = {
        'id': id,
        'name': bsDisplayName(root.name),
        'faction_id': factionId,
        'profiles': walk.profiles,
        'points': _points(root, walk),
        if (walk.wargearCosts.isNotEmpty) 'wargear_costs': walk.wargearCosts,
        'keywords': _keywords(root),
        'faction_keywords': _factionKeywords(root),
        'weapon_ids': walk.weaponIds.toList(),
        'ability_ids': [
          for (final id in walk.abilityIds)
            if (!walk.weaponKeywordIds.contains(id)) id,
        ],
        'model_count': {'min': walk.modelCount, 'max': walk.modelCountMax},
        'is_legend': isLegends(root.name),
        'battlefield_role': root.primaryCategory,
        'game_version': bsGameVersion,
      };

      for (final w in walk.weapons.entries) {
        weapons.putIfAbsent(w.key, () => w.value);
        (variantUsers[w.key] ??= <String>{}).add(id);
      }
      for (final a in walk.abilities.entries) {
        abilities.putIfAbsent(a.key, () => a.value);
      }
      if (walk.models.isNotEmpty) {
        compositions[id] = {
          'unit_id': id,
          'faction_id': factionId,
          'models': walk.models,
          'game_version': bsGameVersion,
        };
      }
    }

    final ids = _resolveWeaponIds(weapons, variantUsers, _anchorProfiles(anchors));
    for (final unit in units.values) {
      final linked = unit['weapon_ids']! as List;
      unit['weapon_ids'] = [
        for (final key in linked)
          if (ids[key] case final resolved?) resolved else key,
      ];
    }
    for (final entry in weapons.entries) {
      entry.value['id'] = ids[entry.key] ?? entry.key;
    }

    return BsFaction(
      factionId: factionId,
      units: units.values.toList(growable: false),
      weapons: weapons.values.toList(growable: false),
      abilities: abilities.values.toList(growable: false),
      compositions: compositions.values.toList(growable: false),
      collisions: collisions,
    );
  }

  /// Final ids for weapons that differ only by which datasheet carries them.
  ///
  /// BSData holds **four separate `Missile pod` entries** — BS 3+, 4+ and two
  /// at 5+ — one per datasheet that fields one, which is exactly the
  /// distinction §7.3.5 says must survive: a Commander's missile pod and a
  /// Crisis suit's are the same name and not the same gun. 40kdc collapses
  /// them into a single BS4+ record, so the app has been showing one number
  /// for three weapons.
  ///
  /// Keeping them apart needs ids to tell them apart. The variant the most
  /// datasheets carry takes the plain slug — so the common case keeps the id
  /// 40kdc used, and saved rosters and corrections keep resolving — and the
  /// rest are suffixed with the skill that distinguishes them. Ties break on
  /// the id itself, never on walk order, or a rebuild would silently
  /// renumber every weapon in the faction.
  /// Whether a modifier condition is counting models.
  ///
  /// Both encodings appear and only one is obvious. T'au writes the literal
  /// `childId: "model"`; Space Marines names the id of the model entry itself,
  /// so `set 150 when at least 6 Intercessors` looked like a condition about
  /// wargear and every squad in the codex lost its ten-model price.
  bool _countsModels(String? childId) {
    if (childId == null) return false;
    if (childId == 'model') return true;
    final target = index.byId(childId);
    if (target == null) return false;
    if (target.type == 'model') return true;
    // A composition group has no `type` at all, so testing for `model` alone
    // still missed it: `set 150 when at least 6 Intercessors` names the
    // *group*, and every Space Marine squad stayed at its five-model price.
    for (final raw in target.selectionEntries) {
      if (str(asMap(raw)['type']) == 'model') return true;
    }
    return false;
  }

  /// 40kdc's weapon records, indexed by id, for anchoring.
  Map<String, Map<String, dynamic>> _anchorProfiles(List<Object?> anchors) {
    final out = <String, Map<String, dynamic>>{};
    for (final raw in anchors) {
      final record = asMap(raw);
      if (str(record['id']) case final id?) out[id] = record;
    }
    return out;
  }

  Map<String, String> _resolveWeaponIds(
    Map<String, Map<String, Object?>> weapons,
    Map<String, Set<String>> users,
    Map<String, Map<String, dynamic>> anchors,
  ) {
    final bySlug = <String, List<String>>{};
    for (final key in weapons.keys) {
      (bySlug[key.split('|').first] ??= []).add(key);
    }

    final out = <String, String>{};
    for (final entry in bySlug.entries) {
      final slug = entry.key;
      final anchor = anchors[slug];
      final variants = entry.value
        ..sort((a, b) {
          // The variant that matches what 40kdc called by this name keeps the
          // name. Without this the plain id goes to whichever variant the most
          // datasheets carry, and `missile-pod` silently stopped meaning the
          // BS4+ gun every saved roster was built with.
          final byAnchor = _anchorScore(weapons[b], anchor)
              .compareTo(_anchorScore(weapons[a], anchor));
          if (byAnchor != 0) return byAnchor;
          final byUse = (users[b]?.length ?? 0).compareTo(users[a]?.length ?? 0);
          return byUse != 0 ? byUse : a.compareTo(b);
        });
      out[variants.first] = slug;
      final taken = <String>{slug};
      for (final key in variants.skip(1)) {
        var id = '$slug-${_skillOf(weapons[key])}';
        if (!taken.add(id)) {
          var n = 2;
          while (!taken.add('$id-$n')) {
            n++;
          }
          id = '$id-$n';
        }
        out[key] = id;
      }
    }
    return out;
  }

  /// How well a variant matches the record 40kdc published under that id.
  ///
  /// The skill is the characteristic these variants differ by, so matching it
  /// is the whole test; anything else scores zero and falls through to the
  /// usage count.
  int _anchorScore(Map<String, Object?>? weapon, Map<String, dynamic>? anchor) {
    if (weapon == null || anchor == null) return 0;
    final theirs = asList(anchor['profiles']).map(asMap).firstOrNull;
    if (theirs == null) return 0;
    final theirStats = asMap(theirs['stats']);
    for (final raw in asList(weapon['profiles'])) {
      final stats = asMap(asMap(raw)['stats']);
      for (final key in const ['BS', 'WS']) {
        final mine = asInt(stats[key]);
        final other = asInt(theirStats[key]);
        if (mine != null && other != null && mine == other) return 1;
      }
    }
    return 0;
  }

  /// `bs3`, `ws4`, or `alt` when the profiles differ in some other way.
  String _skillOf(Map<String, Object?>? weapon) {
    for (final raw in asList(weapon?['profiles'])) {
      final stats = asMap(asMap(raw)['stats']);
      for (final key in const ['BS', 'WS']) {
        if (asInt(stats[key]) case final value?) {
          return '${key.toLowerCase()}$value';
        }
      }
    }
    return 'alt';
  }

  /// A datasheet is a selectable unit or single model with a battlefield role.
  ///
  /// The role is what separates a datasheet from the hundreds of `upgrade`
  /// entries, and from configuration entries like `Detachment` — selectable,
  /// but not something you put on the table.
  bool _isDatasheet(BsEntry e) {
    if (e.type != 'unit' && e.type != 'model') return false;
    if (e.hidden) return false;
    final role = e.primaryCategory;
    return role != null && role != 'Configuration';
  }

  /// Keywords, from the categories BattleScribe hangs on the entry — which is
  /// where 11e keywords actually live.
  ///
  /// `Faction: X` is separated out: it is the faction keyword line, printed
  /// apart from the rest on a real datasheet.
  List<String> _keywords(BsEntry e) => [
        for (final name in e.categoryNames)
          if (!name.startsWith('Faction:')) name,
      ];

  List<String> _factionKeywords(BsEntry e) => [
        for (final name in e.categoryNames)
          if (name.startsWith('Faction:')) name.substring(8).trim(),
      ];

  /// Points: the model-count brackets, and the 11e escalating cost for a
  /// third and later copy.
  ///
  /// 40kdc states both outright. BattleScribe expresses them as modifiers on
  /// the points field, and although evaluating BattleScribe modifiers in
  /// general is a project of its own, these two are entirely regular:
  ///
  ///   `set 150 when selections of model == 2`      -> a two-model bracket
  ///   `set 255 when selections of model >= 3`      -> a three-model bracket
  ///   `increment 20 when 2 selected before this`   -> the third copy onward
  ///
  /// Broadsides come out 75/150/255 and 95/170/275, which is what 40kdc says
  /// to the point. Nothing beyond these two shapes is interpreted — a
  /// half-understood modifier yields a number that looks authoritative and is
  /// wrong, which is worse than a flat cost that is visibly simple.
  List<Map<String, Object?>> _points(BsEntry unit, _Walk walk) {
    final base = unit.costFor(_pts);
    if (base == null) return const [];

    final brackets = <({int models, int cost})>[
      (models: walk.modelCount, cost: base),
      ..._modelBrackets(unit),
    ]..sort((a, b) => a.models.compareTo(b.models));

    // Two modifiers can name the same count — the base already covers it.
    final unique = <int, int>{};
    for (final b in brackets) {
      unique[b.models] = b.cost;
    }
    final counts = unique.keys.toList()..sort();

    final escalation = _escalation(unit);
    final out = <Map<String, Object?>>[];

    for (var i = 0; i < counts.length; i++) {
      final models = counts[i];
      final cost = unique[models]!;
      // A bracket runs up to the model count where the next one starts.
      final modelsMax = i + 1 < counts.length
          ? counts[i + 1] - 1
          : (walk.modelCountMax > models ? walk.modelCountMax : null);

      Map<String, Object?> row(int value, int? min, int? max) => {
            'models': models,
            if (modelsMax != null && modelsMax != models) 'models_max': modelsMax,
            'cost': value,
            if (min != null) 'unit_count_min': min,
            if (max != null) 'unit_count_max': max,
          };

      if (escalation == null) {
        out.add(row(cost, null, null));
      } else {
        out.add(row(cost, 1, escalation.copy - 1));
        out.add(row(cost + escalation.delta, escalation.copy, null));
      }
    }
    return out;
  }

  /// `set <cost> when the unit has N models` modifiers, as brackets.
  List<({int models, int cost})> _modelBrackets(BsEntry unit) {
    final out = <({int models, int cost})>[];
    for (final raw in [
      ...unit.modifiers,
      for (final group in unit.modifierGroups)
        ...asList(asMap(group)['modifiers']),
    ]) {
      final m = asMap(raw);
      if (str(m['field']) != _pts) continue;
      if (str(m['type']) != 'set') continue;
      final cost = asInt(m['value']);
      if (cost == null) continue;

      for (final rawCondition in asList(m['conditions'])) {
        final condition = asMap(rawCondition);
        if (str(condition['field']) != 'selections') continue;
        if (!_countsModels(str(condition['childId']))) continue;
        final value = asInt(condition['value']);
        if (value == null) continue;
        final models = switch (str(condition['type'])) {
          'equalTo' || 'atLeast' => value,
          // `greaterThan 10` is the eleventh model.
          'greaterThan' => value + 1,
          _ => null,
        };
        if (models != null) out.add((models: models, cost: cost));
      }
    }
    return out;
  }

  /// The `increment N points once M copies are already taken` modifier, if
  /// there is one.
  ///
  /// Anything more elaborate is left alone rather than guessed at. A
  /// half-understood modifier produces a points value that looks authoritative
  /// and is wrong, which is worse than a flat cost that is visibly simple.
  ({int copy, int delta})? _escalation(BsEntry unit) {
    for (final raw in unit.modifiers) {
      final m = asMap(raw);
      if (str(m['field']) != _pts) continue;
      if (str(m['type']) != 'increment') continue;
      final delta = asInt(m['value']);
      if (delta == null) continue;
      for (final rawGroup in asList(m['conditionGroups'])) {
        for (final rawLocal in asList(asMap(rawGroup)['localConditionGroups'])) {
          final local = asMap(rawLocal);
          if (str(local['type']) != 'atLeast') continue;
          final before = asInt(local['value']);
          // "at least 2 selected before this one" is the third copy onward.
          if (before != null) return (copy: before + 1, delta: delta);
        }
      }
    }
    return null;
  }
}

/// One pass over a datasheet, gathering everything hanging off it.
///
/// A datasheet is a tree — groups of model entries, each linking weapons, each
/// carrying profiles — and the same weapon is reachable by several routes, so
/// collection is into maps by id rather than by appending.
class _Walk {
  final BsIndex index;
  final String pts;

  final profiles = <Map<String, Object?>>[];

  /// Model entries, grouped the way the datasheet groups them.
  ///
  /// The grouping is not presentational. BattleScribe puts `4 Stealth Shas'ui`
  /// on the group and `min 2 / max 4` on each loadout inside it: the group is
  /// how many models there are, the entries are which weapons those models may
  /// carry. Summing the entries counts every model once per loadout it could
  /// have taken — Stealth Battlesuits came out as nine models instead of five.
  final modelGroups = <_ModelGroup>[];
  final weaponIds = <String>{};
  final abilityIds = <String>{};
  final weapons = <String, Map<String, Object?>>{};
  final abilities = <String, Map<String, Object?>>{};
  final wargearCosts = <Map<String, Object?>>[];

  /// Guards the graph's cycles and its diamonds: a shared entry reachable by
  /// two routes would otherwise be walked twice.
  final _seen = <String>{};

  /// Keyword ids seen on this faction's weapon profiles.
  ///
  /// BattleScribe links the rule for `[ASSAULT]` from every weapon that has
  /// it, so a datasheet's rules came out listing ten weapon keywords among its
  /// abilities. They are keywords printed on a gun, not rules the unit has —
  /// and now that BSData supplies their text, leaving them in would render
  /// each one on the rules screen as though it were the datasheet's own.
  ///
  /// The records are still kept: the text is worth having where a player looks
  /// a keyword up. Only the unit's ability list is filtered.
  final weaponKeywordIds = <String>{};

  _Walk(this.index, this.pts);

  /// Models when every minimum is taken — the datasheet's starting size, which
  /// is what the builder needs to put a legal unit on the table.
  /// The datasheet's own name, used when it turns out to have no composition.
  String _rootName = '';

  /// A single-model datasheet — a Commander, a tank — carries its statline on
  /// the root and has no composition group at all, so it is one model.
  ///
  /// This has to be decided *after* the walk, not during it. A multi-model
  /// datasheet also carries the statline on its root, so counting the root as
  /// a model up front added one phantom model to every squad: Vespid
  /// Stingwings came out as six, and its five-model price bracket vanished
  /// under the six-model one.
  List<_ModelGroup> get _groups => modelGroups.isEmpty
      ? [_ModelGroup(_rootName, 1, 1)]
      : modelGroups;

  int get modelCount {
    final total = _groups.fold(0, (sum, g) => sum + g.min);
    return total == 0 ? 1 : total;
  }

  int get modelCountMax {
    final total = _groups.fold(0, (sum, g) => sum + g.max);
    return total < modelCount ? modelCount : total;
  }

  /// The composition, one record per distinct model in the datasheet.
  List<Map<String, Object?>> get models => [
        for (final group in _groups)
          {
            'name': group.name,
            'min': group.min,
            'max': group.max,
            'is_leader_model': false,
            'default_weapon_ids': const <String>[],
          },
      ];

  /// Subtrees that hang off a datasheet without belonging to it.
  ///
  /// A BattleScribe datasheet links the whole Crusade apparatus — battle
  /// traits, relics, specialisms, battle scars — and those links reach shared
  /// trees covering the entire game. Walking them gave an Enforcer Commander
  /// 180 abilities, most of them from other factions, and a Dominion Squad the
  /// Sisters' entire hymn list. None of it is on the datasheet.
  static final _notThisDatasheet = RegExp(
    r'crusade|battle\s*trait|battle\s*scar|relic|specialism|'
    r'expanding the empire|white dwarf|warlord|requisition|enhancement',
    caseSensitive: false,
  );

  bool _belongs(String name) => !_notThisDatasheet.hasMatch(name);

  void visit(BsEntry entry, {int depth = 0}) {
    if (depth > 8) return;
    if (!_seen.add(entry.id.isEmpty ? '${entry.name}@$depth' : entry.id)) {
      return;
    }

    _readProfiles(entry);

    final cost = entry.costFor(pts);
    if (depth > 0 && cost != null && cost != 0) {
      wargearCosts.add({'item_id': bsSlug(entry.name), 'cost': cost});
    }

    for (final raw in entry.infoLinks) {
      final link = asMap(raw);
      final type = str(link['type']);
      if (type != 'rule' && type != 'profile') continue;
      final target = index.resolve(link);
      if (target != null) _readRule(target);
    }

    if (depth == 0) _rootName = entry.name;

    // A model can be a direct child rather than sit in a group — a Breacher
    // Team is one `Breacher Fire Warriors` entry with its count on itself.
    // Reading only groups lost every such datasheet down to a single model.
    for (final raw in entry.selectionEntries) {
      final child = BsEntry(asMap(raw), entry.sourceId);
      if (depth == 0 && _hasUnitProfile(child)) {
        modelGroups.add(_ModelGroup(
          child.name,
          _constraint(child, 'min') ?? 1,
          _constraint(child, 'max') ?? _constraint(child, 'min') ?? 1,
        ));
      }
      _child(child, depth);
    }
    for (final rawGroup in entry.selectionEntryGroups) {
      final group = BsEntry(asMap(rawGroup), entry.sourceId);
      if (!_belongs(group.name)) continue;
      _group(group, entry, depth);
    }
    for (final raw in entry.entryLinks) {
      if (!_belongs(strOr(asMap(raw)['name'], ''))) continue;
      final target = index.resolve(raw);
      if (target != null && _belongs(target.name)) _child(target, depth);
    }
  }

  /// One composition group: how many models, and which loadouts they may take.
  void _group(BsEntry group, BsEntry owner, int depth) {
    final children = <BsEntry>[
      for (final raw in group.selectionEntries) BsEntry(asMap(raw), owner.sourceId),
      for (final raw in group.entryLinks)
        if (_belongs(strOr(asMap(raw)['name'], '')))
          if (index.resolve(raw) case final target?) target,
    ];

    final modelChildren = children.where(_hasUnitProfile).toList();
    if (modelChildren.isNotEmpty) {
      // The group's own bound is the model count when it states one; without
      // it the loadouts are the only evidence and their minimums are summed.
      final statedMin = _constraint(group, 'min') ??
          _sum(modelChildren, 'min', missing: null);
      final statedMax = _constraint(group, 'max') ??
          _sum(modelChildren, 'max', missing: null);

      // Silence and `max 2` mean different things, and conflating them costs
      // a price bracket. A group stating nothing at all is exactly one model —
      // the Long-quill in a Kroot pack, the Shas'vre in a Stealth team. A
      // group stating only a maximum genuinely starts at zero: Broadsides are
      // 0-2 Shas'ui plus one Shas'vre, so the datasheet's smallest legal size
      // is one model, and reading that minimum as one lost the 75-point row.
      final bare = statedMin == null && statedMax == null;
      modelGroups.add(_ModelGroup(
        _groupName(group, modelChildren),
        bare ? 1 : (statedMin ?? 0),
        bare ? 1 : (statedMax ?? statedMin ?? 1),
      ));
    }

    for (final child in children) {
      visit(child, depth: depth + 1);
    }
  }

  /// Sums a constraint across a group's entries, or null when none states it.
  int? _sum(List<BsEntry> children, String type, {required int? missing}) {
    var total = 0;
    var any = false;
    for (final child in children) {
      final value = _constraint(child, type);
      if (value != null) {
        any = true;
        total += value;
      }
    }
    return any ? total : missing;
  }

  /// `4 Stealth Shas'ui` names the group after its models, which reads better
  /// than the loadout of whichever entry happened to come first. A group with
  /// no name of its own falls back to what is in it.
  String _groupName(BsEntry group, List<BsEntry> children) {
    final name = group.name.replaceFirst(RegExp(r'^\d+\s+'), '').trim();
    return name.isEmpty ? children.first.name : name;
  }

  void _child(BsEntry child, int depth) {
    visit(child, depth: depth + 1);
  }

  /// Whether this entry is one of the datasheet's models.
  ///
  /// BattleScribe says so outright with `type: model`. Testing for a `Unit`
  /// profile instead — the first thing I tried — misses most of them: a
  /// Vespid Strain Leader carries no profile at all, because the statline sits
  /// on the datasheet root and the model entry only says how many there are.
  bool _hasUnitProfile(BsEntry e) {
    if (e.type == 'model') return true;
    for (final raw in e.profiles) {
      if (str(asMap(raw)['typeName']) == 'Unit') return true;
    }
    return false;
  }

  /// A count constraint, preferring the group's over the entry's.
  ///
  /// BattleScribe puts `4 Stealth Shas'ui` on the group and `min 2 / max 4` on
  /// the entry inside it: the group says how many models the datasheet fields,
  /// the entry only bounds which loadouts those models may take. Reading the
  /// entry alone makes a five-model unit look like a three-model one.
  int? _constraint(BsEntry e, String type) {
    for (final raw in e.constraints) {
      final c = asMap(raw);
      if (str(c['type']) != type) continue;
      if (str(c['field']) != 'selections') continue;
      final scope = str(c['scope']);
      if (scope != 'parent' && scope != 'self') continue;
      return asInt(c['value']);
    }
    return null;
  }

  void _readProfiles(BsEntry entry) {
    for (final raw in entry.profiles) {
      _readProfile(asMap(raw), entry);
    }
  }

  void _readRule(BsEntry rule) {
    // A shared rule carries its text on the record itself; a profile carries
    // it in a characteristic. Both shapes appear, and both are rules.
    final description = str(rule.json['description']);
    if (description == null || description.isEmpty) {
      _readProfiles(rule);
      return;
    }
    final id = bsSlug(rule.name);
    if (id.isEmpty) return;
    abilityIds.add(id);
    abilities.putIfAbsent(
      id,
      () => {
        'ability_id': id,
        'name': rule.name,
        'description': description,
        'ability_type': 'core',
        'game_version': bsGameVersion,
      },
    );
  }

  /// `➤ Ion cannon - overcharge` -> `overcharge`.
  ///
  /// BattleScribe names a sub-profile by repeating its weapon; 40kdc names it
  /// by what distinguishes it. Same information, and left alone it reported
  /// every multi-profile weapon in the game as a conflict about nothing.
  static String _profileName(String raw, String ownerName) {
    var name = raw.replaceFirst(RegExp(r'^[➤>\s]+'), '').trim();
    final prefix = RegExp('^${RegExp.escape(ownerName)}\\s*[-–]\\s*');
    name = name.replaceFirst(prefix, '').trim();
    if (name.isEmpty) return raw.trim();
    // `overcharge` -> `Overcharge`. What is left after the weapon's own name
    // is stripped is a bare word, and a datasheet prints it capitalised.
    return name[0].toUpperCase() + name.substring(1);
  }

  void _readProfile(Map<String, dynamic> profile, BsEntry owner) {
    final typeName = strOr(profile['typeName'], '');
    final name = strOr(profile['name'], '');
    if (name.isEmpty) return;

    final chars = <String, String>{};
    for (final raw in asList(profile['characteristics'])) {
      final c = asMap(raw);
      final key = str(c['name']);
      final value = str(c[r'$text']);
      if (key != null && value != null && value.isNotEmpty) chars[key] = value;
    }
    if (chars.isEmpty) return;

    switch (typeName) {
      case 'Unit':
        // The same statline arrives once per loadout that shares it. Three
        // identical Shas'ui rows say nothing the first one did not.
        if (profiles.any((p) => p['name'] == name)) return;
        profiles.add({
          'name': name,
          'M': chars['M'],
          'T': chars['T'],
          'W': chars['W'],
          'Sv': chars['Sv'],
          'invuln_sv': chars['InSv'],
          'Ld': chars['LD'],
          'OC': chars['OC'],
        });
      case 'Ranged Weapons':
      case 'Melee Weapons':
        _readWeapon(_profileName(name, owner.name), chars, owner,
            melee: typeName == 'Melee Weapons');
      default:
        final text = chars['Description'];
        if (text == null) return;
        final id = bsSlug(name);
        if (id.isEmpty) return;
        abilityIds.add(id);
        abilities.putIfAbsent(
          id,
          () => {
            'ability_id': id,
            'name': name,
            'description': text,
            if (typeName != 'Abilities') 'ability_type': typeName,
            'game_version': bsGameVersion,
          },
        );
    }
  }

  /// A weapon record, keyed by the entry that owns the profile.
  ///
  /// The owning entry is what a datasheet links to and what the roster records,
  /// so its name is the id — while a *profile* may be one of several under that
  /// entry, which is how a two-profile weapon stays one weapon.
  void _readWeapon(
    String name,
    Map<String, String> chars,
    BsEntry owner, {
    required bool melee,
  }) {
    final slug = bsSlug(owner.name);
    if (slug.isEmpty) return;

    final stats = <String, Object?>{};
    for (final key in const ['A', 'BS', 'WS', 'S', 'AP', 'D']) {
      if (chars[key] case final v?) stats[key] = _statValue(v);
    }
    final profile = <String, Object?>{
      'name': name,
      'range': _rangeValue(chars['Range']),
      'stats': stats,
      'keywords': _weaponKeywords(chars['Keywords']),
    };
    for (final keyword in profile['keywords']! as List) {
      if (str(asMap(keyword)['keyword_id']) case final id?) {
        weaponKeywordIds.add(id);
      }
    }

    // Two profiles of one weapon — an ion rifle's standard and overcharge —
    // belong to the same record, and two datasheets' versions of the same
    // weapon do not. The owning entry's id separates them, since BattleScribe
    // declares one entry per datasheet that carries the gun.
    final key = '$slug|${owner.id}';
    weaponIds.add(key);

    final existing = weapons[key];
    if (existing == null) {
      weapons[key] = {
        'id': slug,
        'name': owner.name,
        'type': melee ? 'melee' : 'ranged',
        'profiles': [profile],
        'game_version': bsGameVersion,
      };
      return;
    }
    // A weapon with both a ranged and a melee profile keeps the type of the
    // first seen; §7.3.5 discriminates per profile on the skill characteristic
    // anyway, so the weapon-level type is only a fallback.
    (existing['profiles']! as List).add(profile);
  }

  /// A characteristic in 40kdc's convention: bare numbers where the value is
  /// one, the string otherwise.
  ///
  /// BattleScribe prints characteristics as they appear on the datasheet —
  /// `2+` for a skill, `-4` for AP, `D6` for variable damage. 40kdc stores the
  /// number. Left unconverted, every weapon in the game reported a conflict
  /// over its own punctuation, and the handful of genuine disagreements
  /// underneath — Battlesuit fists are WS4+ in one source and WS5+ in the
  /// other — were invisible in the noise.
  Object? _statValue(String raw) {
    final text = raw.trim();
    // A Torrent weapon auto-hits and has no skill. BattleScribe prints `N/A`
    // where 40kdc stores null, and shipping the literal would put "N/A" in the
    // BS column as though it were a value.
    if (text == 'N/A' || text == '-') return null;
    final skill = RegExp(r'^(\d+)\+$').firstMatch(text);
    if (skill != null) return int.parse(skill.group(1)!);
    return int.tryParse(text) ?? text;
  }

  /// `24"` -> 24, `Melee` -> `Melee`.
  Object? _rangeValue(String? raw) {
    if (raw == null) return null;
    final text = raw.trim();
    final inches = RegExp(r'^(\d+)\s*"?$').firstMatch(text);
    if (inches != null) return int.parse(inches.group(1)!);
    return text;
  }

  /// `[ASSAULT], [MELTA 2], [ANTI-INFANTRY 4+]` -> structured keywords.
  ///
  /// The parameters are the whole point. §3.7 found 201 of 920 keyword
  /// instances carry one, and a Melta 2 rendered as a bare `MELTA` is a lie
  /// about how much damage the weapon does.
  List<Map<String, Object?>> _weaponKeywords(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    final out = <Map<String, Object?>>[];
    for (final match in RegExp(r'\[([^\]]+)\]').allMatches(text)) {
      final body = match.group(1)!.trim();
      if (body.isNotEmpty) out.add(_weaponKeyword(body));
    }
    if (out.isEmpty) {
      // Some profiles list them unbracketed and comma separated.
      for (final part in text.split(',')) {
        final body = part.trim();
        if (body.isNotEmpty) out.add(_weaponKeyword(body));
      }
    }
    return out;
  }

  Map<String, Object?> _weaponKeyword(String body) {
    final anti =
        RegExp(r'^ANTI-(.+?)\s+(\d+)\+$', caseSensitive: false).firstMatch(body);
    if (anti != null) {
      return {
        'keyword_id': 'anti',
        'parameters': {
          'target_keyword': anti.group(1)!.toLowerCase(),
          'threshold': int.parse(anti.group(2)!),
        },
      };
    }
    final valued = RegExp(r'^(.+?)\s+(\d+)\+?$').firstMatch(body);
    if (valued != null) {
      return {
        'keyword_id': bsSlug(valued.group(1)!),
        'parameters': {'value': int.parse(valued.group(2)!)},
      };
    }
    return {'keyword_id': bsSlug(body)};
  }
}

/// How many models of one kind a datasheet fields.
class _ModelGroup {
  final String name;
  final int min;
  final int max;

  const _ModelGroup(this.name, this.min, this.max);
}
