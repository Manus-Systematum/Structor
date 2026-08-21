import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// A roster plus everything needed to render it.
///
/// Content comes from the roster's **snapshot**, not from a faction dataset.
/// That is the same path an imported or QR-scanned list takes (DESIGN.md §6.4),
/// so the offline case is the default case rather than a fallback bolted on
/// later.
class Army {
  /// Stable identity for storage. Not part of the roster document itself,
  /// which is portable and may be shared or re-imported.
  final String id;

  final Roster roster;
  final RosterSnapshot snapshot;
  final Catalogue catalogue;
  final ValidationResult validation;

  Army._({
    required this.id,
    required this.roster,
    required this.snapshot,
    required this.catalogue,
    required this.validation,
  });

  factory Army.fromSnapshot(Roster roster, RosterSnapshot snapshot,
      {required String id}) {
    final catalogue = MapCatalogue(
      snapshot.units.values.map(SourceUnit.fromJson),
      weapons: snapshot.weapons.values.map(SourceWeapon.fromJson),
      detachments: snapshot.detachments.values.map(SourceDetachment.fromJson),
      // Wargear can be an ability: a Gun Drone resolves to a twin pulse
      // carbine only by following the grant (§7.3.7).
      abilities: snapshot.abilities.values.map(SourceAbility.fromJson),
      enhancements:
          snapshot.enhancements.values.map(SourceEnhancement.fromJson),
    );
    return Army._(
      id: id,
      roster: roster,
      snapshot: snapshot,
      catalogue: catalogue,
      validation: RosterValidator(catalogue).validate(roster),
    );
  }

  /// The reference army, from the bundled assets. **A test fixture only** —
  /// nothing pre-installs it, so a fresh install starts with no armies.
  static Future<Army> loadReference() async {
    final rosterJson =
        await rootBundle.loadString('assets/reference_roster.json');
    final snapshotJson =
        await rootBundle.loadString('assets/reference_snapshot.json');
    return Army.fromSnapshot(
      Roster.fromJson(jsonDecode(rosterJson)),
      RosterSnapshot.fromJson(jsonDecode(snapshotJson)),
      id: 'reference',
    );
  }

  BattleSize? get battleSize => BattleSize.byId(roster.battleSizeId);

  int get points => validation.cost.total;

  int get pointsLimit =>
      roster.pointsLimitOverride ?? battleSize?.points ?? points;

  /// Combat units — a leader and the unit it joined are one entry (§2.2).
  List<CombatUnit> get combatUnits => [
        for (final group in roster.combatUnits())
          CombatUnit(group: group, army: this),
      ];

  /// Abilities carried by a unit, rendered to English (§7.3.6). Abilities are
  /// only present when the snapshot captured them.
  List<RenderedRule> rulesFor(RosterUnit unit) {
    const renderer = RulesRenderer();
    final datasheet = catalogue.unit(unit.datasheetId);
    if (datasheet == null) return const [];

    final rules = <RenderedRule>[];
    for (final abilityId in _activeAbilityIds(unit)) {
      final raw = snapshot.abilities[abilityId];
      if (raw == null) continue;
      rules.add(renderer.render(SourceAbility.fromJson(raw)));
    }
    return rules;
  }

  /// An invulnerable save a unit gets from an **ability** rather than from its
  /// statline.
  ///
  /// The two encodings coexist upstream: most profiles carry `invuln_sv`, but
  /// the Commander in Coldstar Battlesuit's 4+ lives in its `shield-generator`
  /// ability and its profile says nothing. Reading only the profile left the
  /// INV column empty on a unit that has one.
  String? grantedInvulnerableSave(RosterUnit unit) {
    int? best;
    // Over the abilities the unit actually has, not every one its datasheet
    // could carry — otherwise the INV column and the rules list disagree
    // about whether a Shield Generator was bought.
    for (final abilityId in _activeAbilityIds(unit)) {
      final raw = snapshot.abilities[abilityId];
      if (raw == null) continue;
      final save = SourceAbility.fromJson(raw).unconditionalInvulnerableSave;
      if (save == null) continue;
      // Best available, since two grants do not stack — the lower wins.
      if (best == null || save < best) best = save;
    }
    return best?.toString();
  }

  /// Ability ids in force for [unit]: its datasheet's, minus optional wargear
  /// it did not take.
  ///
  /// Wargear the datasheet *could* take is not wargear it has. A Crisis suit
  /// may take a Gun, Marker or Shield Drone; listing all three on a unit that
  /// bought two is three rules to read and one of them false (§7.3.7).
  List<String> _activeAbilityIds(RosterUnit unit) {
    final datasheet = catalogue.unit(unit.datasheetId);
    if (datasheet == null) return const [];

    final optional = <String>{
      for (final budget in datasheet.wargearBudgets) ...budget.items,
    };
    final taken = {for (final item in unit.wargear) item.itemId};
    return [
      for (final id in datasheet.ruleVocabulary)
        if (!optional.contains(id) || taken.contains(id)) id,
    ];
  }

  String detachmentName(String id) => catalogue.detachment(id)?.name ?? id;

  /// Detachment Points the taken detachments cost between them.
  int get detachmentPointsSpent => roster.detachments.fold(
        0,
        (sum, taken) =>
            sum +
            (catalogue.detachment(taken.detachmentId)?.detachmentPoints ?? 0),
      );

  /// What the battle size allows.
  ///
  /// At Incursion the budget rises from 2 to 3 when a 3 DP detachment is
  /// taken, so a single large detachment is always legal (§4.4) — the same
  /// rule the validator applies, read from the same place.
  int get detachmentPointsBudget {
    final size = BattleSize.byId(roster.battleSizeId);
    if (size == null) return 0;
    final hasThreeDp = roster.detachments.any((t) =>
        (catalogue.detachment(t.detachmentId)?.detachmentPoints ?? 0) >= 3);
    return size.budgetFor(includesThreeDpDetachment: hasThreeDp);
  }

  /// The stratagems this army can play, already scoped to its detachments
  /// (§7.3). Built from the snapshot, so a scanned list brings its own.
  late final StratagemBook stratagems = StratagemBook.forRoster(
    roster,
    all: snapshot.stratagems.values.map(SourceStratagem.fromJson),
    catalogue: catalogue,
  );

  /// Everything the army carries, in one searchable list (§7.3.8). Still the
  /// index search runs over — a query crosses all four kinds at once.
  late final ReferenceIndex reference = ReferenceIndex.forRoster(
    roster,
    catalogue: catalogue,
    book: stratagems,
  );

  /// The same rules, filed by how widely each applies (§7.3.9). What the
  /// reference page shows when nothing is being searched for.
  ///
  /// Sharedness comes from the snapshot rather than from [catalogue]: the
  /// catalogue here holds only this roster's datasheets, so counting owners in
  /// it would decide sharedness per list.
  late final ArmyRules armyRules = ArmyRules.forRoster(
    roster,
    catalogue: catalogue,
    sharedAbilityIds:
        snapshot.sharedAbilities.isEmpty ? null : snapshot.sharedAbilities,
    factionRuleId: snapshot.factionRuleId,
  );

  /// Everything the roster's copies of [datasheetId] carry between them.
  ///
  /// Merged across copies because the rules summary shows one row per
  /// datasheet, not per squad: two Stealth teams with different drones are one
  /// entry, and the profiles under it are the union of what the army fields.
  Map<String, int> carriedBy(String datasheetId) {
    final tally = <String, int>{};
    for (final unit in roster.units) {
      if (unit.datasheetId != datasheetId) continue;
      for (final item in unit.wargear) {
        tally[item.itemId] = (tally[item.itemId] ?? 0) + item.count;
      }
    }
    return tally;
  }

  /// Units that may make a Scout move before the first turn, with how far.
  ///
  /// A pre-game step that pays for itself: a Scout move forgotten before
  /// deployment finishes cannot be taken later, and nothing else in the app
  /// was asking the question (§7.3.10). Read from the ability's effect rather
  /// than its name — a Necron Enlivened Sentinels grants 5" and never says
  /// "Scouts".
  List<({CombatUnit unit, int distance})> get scoutMoves {
    int? scoutOf(RosterUnit rosterUnit) {
      int? best;
      for (final abilityId in _activeAbilityIds(rosterUnit)) {
        final raw = snapshot.abilities[abilityId];
        if (raw == null) continue;
        final distance = SourceAbility.fromJson(raw).scoutDistance;
        if (distance != null && (best == null || distance > best)) {
          best = distance;
        }
      }
      return best;
    }

    final out = <({CombatUnit unit, int distance})>[];
    for (final combat in combatUnits) {
      // A led unit moves as one, and Scouts is worded "if every model in this
      // unit has this ability". So a character without it takes the move away
      // from the squad it joined, and where both have it the shorter distance
      // governs. Listing a move the unit cannot make is worse than listing
      // none — it is the kind of thing a player acts on and cannot undo.
      final distances = [for (final unit in combat.group) scoutOf(unit)];
      if (distances.isEmpty || distances.any((d) => d == null)) continue;
      final shortest = distances.cast<int>().reduce((a, b) => a < b ? a : b);
      if (shortest > 0) out.add((unit: combat, distance: shortest));
    }
    return out;
  }

  /// Units a stratagem may be played on, with a reason against each that
  /// cannot be.
  List<StratagemTarget> targetsFor(
    SourceStratagem stratagem, {
    required String phase,
    required BattleState state,
  }) =>
      stratagems.targetsFor(
        stratagem,
        roster: roster,
        catalogue: catalogue,
        phase: phase,
        state: state,
      );
}

/// A leader and its bodyguard presented as the single unit they fight as.
class CombatUnit {
  final List<RosterUnit> group;
  final Army army;

  const CombatUnit({required this.group, required this.army});

  RosterUnit get head => group.first;

  /// The character leads, so it is named first: *Commander in Enforcer
  /// Battlesuit with Crisis Fireknife Battlesuits*.
  String get label => head.customName ?? army.catalogue.labelFor(group);

  int get points => army.validation.cost.units
      .where((c) => group.any((u) => u.instanceId == c.instanceId))
      .fold(0, (sum, c) => sum + c.total);

  int get models => group.fold(0, (sum, u) => sum + u.models);

  /// The heading this unit files under, taken from whichever member sorts
  /// earliest — a Commander leading a squad is a Character, because the
  /// Commander is the entry you go looking for (§4.8).
  String get battlefieldRole {
    var best = SourceUnit.roleOrder.length;
    for (final member in group) {
      final role = army.catalogue.unit(member.datasheetId)?.battlefieldRole;
      final rank = SourceUnit.roleOrder.indexOf(role ?? 'Other');
      if (rank >= 0 && rank < best) best = rank;
    }
    return best < SourceUnit.roleOrder.length
        ? SourceUnit.roleOrder[best]
        : 'Other';
  }

  /// Distinct model profiles across the group. Divergent statlines within one
  /// attached unit are the norm, not an edge case (§7.3.6).
  ///
  /// An invulnerable save granted by an ability is folded in here, so the INV
  /// column reflects what the model actually saves on rather than only what
  /// the statline happened to record.
  List<({String name, ModelProfile profile})> get profiles {
    final seen = <String>{};
    final out = <({String name, ModelProfile profile})>[];
    for (final unit in group) {
      final datasheet = army.catalogue.unit(unit.datasheetId);
      if (datasheet == null) continue;
      final granted = army.grantedInvulnerableSave(unit);
      for (final raw in datasheet.profiles) {
        final profile = granted == null || raw.invulnSv != null
            ? raw
            : raw.withInvulnerableSave(granted);
        if (seen.add(profile.statKey)) {
          out.add((name: profile.name, profile: profile));
        }
      }
    }
    return out;
  }

  AggregationResult weapons(
    WeaponKind kind, {
    Map<String, int> modelsRemaining = const {},
  }) =>
      WeaponAggregator(army.catalogue).aggregate(
        group,
        kind: kind,
        modelsRemaining: modelsRemaining,
      );

  /// Whether the group is a leader plus a bodyguard rather than one datasheet.
  /// When it is, a rule needs saying *whose* it is.
  bool get isAttached => group.length > 1;

  /// Abilities with the datasheets they belong to.
  ///
  /// An attached unit's abilities are not shared. The Commander in Coldstar
  /// Battlesuit carries a Shield Generator; the Crisis Starscythe suits it
  /// leads do not. Listing the union unattributed reads as though they did.
  ///
  /// A rule both halves have needs no attribution — Deep Strike twice, once
  /// per datasheet, is noise. [source] is empty in that case.
  List<({String source, RenderedRule rule})> get attributedRules {
    final order = <String>[];
    final rules = <String, RenderedRule>{};
    final owners = <String, List<String>>{};

    for (final unit in group) {
      final name =
          army.catalogue.unit(unit.datasheetId)?.name ?? unit.datasheetId;
      for (final rule in army.rulesFor(unit)) {
        if (rules.putIfAbsent(rule.abilityId, () => rule) == rule) {
          order.add(rule.abilityId);
        }
        (owners[rule.abilityId] ??= []).add(name);
      }
    }

    return [
      for (final id in order)
        (
          source:
              owners[id]!.length == group.length ? '' : owners[id]!.join(', '),
          rule: rules[id]!,
        ),
    ];
  }

  List<RenderedRule> get rules {
    final seen = <String>{};
    final out = <RenderedRule>[];
    for (final unit in group) {
      for (final rule in army.rulesFor(unit)) {
        if (seen.add(rule.abilityId)) out.add(rule);
      }
    }
    return out;
  }
}
