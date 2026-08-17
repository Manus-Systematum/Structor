/// What one datasheet may carry, arranged the way the editor asks about it
/// (DESIGN.md §4.5).
///
/// §2.3 settled that the builder is permissive and the validator is honest,
/// and that stands. What changed is that "permissive" was being read as
/// "unstructured": every item was a bare counter, so a Crisis suit offered its
/// Battlesuit Fists for removal — which no rule allows and no player wants —
/// and offered its drones as three independent numbers when the datasheet says
/// *up to two, of different kinds*.
///
/// The published data supports three statements, and this separates them by
/// how much they can be trusted:
///
///   * **Fixed.** A default weapon that no published option can replace. The
///     Crisis Fireknife's Battlesuit Fists are in every model's default
///     loadout and appear in no `replaces` list. Locking these takes nothing
///     away, because there was never a legal list without them.
///   * **Groups.** An option record whose bundles spell out whole selections
///     is a closed list, and picking one bundle is the whole interaction.
///   * **Loose.** Everything else stays a counter, including every item on the
///     roughly half of datasheets that publish no options at all. A bare
///     `max_count` rides along as a stated limit rather than a stop, because
///     the reference list — a validated 2,000 point export — carries four
///     T'au flamers on a Commander whose record caps them at three.
library;

import '../rules/catalogue.dart';
import '../source/source_models.dart';

/// One mutually exclusive selection: pick one bundle, or none.
class LoadoutGroup {
  final String optionId;

  /// The alternatives, each a complete legal selection. An item repeated
  /// inside a bundle means two of it, which some genuinely allow.
  final List<List<String>> bundles;

  /// What taking a bundle gives up, when the record says.
  final List<String> replaces;

  /// The model in the unit this applies to, when the record names one.
  final String? modelName;

  const LoadoutGroup({
    required this.optionId,
    required this.bundles,
    this.replaces = const [],
    this.modelName,
  });

  /// Every item any bundle can put on the unit.
  Set<String> get items => {for (final bundle in bundles) ...bundle};

  /// The bundle matching what the unit currently carries, or null when the
  /// selection is off-menu — which a hand-edited or imported list may well be,
  /// and which must be shown rather than silently corrected.
  int? selectedIndex(Map<String, int> carried) {
    for (final (index, bundle) in bundles.indexed) {
      final wanted = <String, int>{};
      for (final item in bundle) {
        wanted[item] = (wanted[item] ?? 0) + 1;
      }
      final matches = wanted.entries
              .every((e) => (carried[e.key] ?? 0) == e.value) &&
          items.every((i) => wanted.containsKey(i) || (carried[i] ?? 0) == 0);
      if (matches) return index;
    }
    return null;
  }
}

/// A counter, with the limit the data states where it states one.
class LoadoutCounter {
  final String itemId;

  /// The most the data says may be taken, or null when it says nothing.
  ///
  /// Advisory. It is surfaced and validated against, never used to disable
  /// the button — see the library comment.
  final int? statedMax;

  /// One per this many models, when the record says so.
  final int? perModels;

  /// Items this one replaces, so taking it can give the other back.
  final List<String> replaces;

  const LoadoutCounter({
    required this.itemId,
    this.statedMax,
    this.perModels,
    this.replaces = const [],
  });
}

class UnitLoadout {
  /// Items the unit always has, in default-loadout quantity. Not removable.
  final Map<String, int> fixed;

  final List<LoadoutGroup> groups;
  final List<LoadoutCounter> counters;

  const UnitLoadout({
    required this.fixed,
    required this.groups,
    required this.counters,
  });

  bool isFixed(String itemId) => fixed.containsKey(itemId);

  /// True when nothing is published for this datasheet, so the editor should
  /// stay entirely permissive rather than imply a rule it has not got.
  bool get isUnpublished => groups.isEmpty && counters.every((c) =>
      c.statedMax == null && c.perModels == null && c.replaces.isEmpty);

  /// Reads the published options for one datasheet.
  factory UnitLoadout.forDatasheet(
    SourceUnit datasheet, {
    required Catalogue catalogue,
    required Iterable<String> vocabulary,
  }) {
    final options = catalogue.wargearOptions(datasheet.id);
    final composition = catalogue.composition(datasheet.id);
    final defaults = composition?.defaultWargear() ?? const <String, int>{};

    // Anything any published option can take away is, by definition, not
    // fixed. A datasheet with no options published has no evidence either
    // way, so nothing is locked — locking on absence of data is exactly the
    // failure §2.3 warns about.
    final replaceable = <String>{
      for (final option in options) ...option.replaces,
    };
    final fixed = options.isEmpty
        ? const <String, int>{}
        : {
            for (final entry in defaults.entries)
              if (!replaceable.contains(entry.key)) entry.key: entry.value,
          };

    final groups = <LoadoutGroup>[];
    final constrained = <String, SourceWargearOption>{};
    for (final option in options) {
      if (option.isEnumeration) {
        groups.add(LoadoutGroup(
          optionId: option.id,
          bundles: option.choices,
          replaces: option.replaces,
          modelName: option.modelName,
        ));
        continue;
      }
      for (final item in option.offered) {
        // Where two records mention the same item, the tighter cap wins; a
        // record with no cap never loosens one that has it.
        final existing = constrained[item];
        if (existing == null ||
            (option.maxCount != null &&
                (existing.maxCount == null ||
                    option.maxCount! < existing.maxCount!))) {
          constrained[item] = option;
        }
      }
    }

    final grouped = {for (final group in groups) ...group.items};
    final counters = <LoadoutCounter>[
      for (final itemId in vocabulary)
        if (!fixed.containsKey(itemId) && !grouped.contains(itemId))
          LoadoutCounter(
            itemId: itemId,
            statedMax: constrained[itemId]?.maxCount,
            perModels: constrained[itemId]?.perModels,
            replaces: constrained[itemId]?.replaces ?? const [],
          ),
    ];

    return UnitLoadout(fixed: fixed, groups: groups, counters: counters);
  }
}
