import 'package:wh40k_core/wh40k_core.dart';

/// What a bearer may actually carry (DESIGN.md §4.7).
///
/// Offering everything and letting validation object afterwards produced
/// illegal armies quietly: an Epic Hero takes none at all, an Enhancement
/// wants a Character, and a Unit Upgrade often names one datasheet.
///
/// **Enhancements and Unit Upgrades are different mechanics** (§2.1) and the
/// difference is not "who is a Character": Symphonic Payload goes on an
/// Exorcist, which is a tank. Deciding whether to show the section by asking
/// `isCharacter` hid a legal upgrade on 428 datasheets across eight factions.
class EnhancementOffers {
  const EnhancementOffers._();

  static List<SourceEnhancement> of(
    Dataset dataset,
    Roster roster,
    SourceUnit? datasheet,
  ) {
    final taken = {for (final d in roster.detachments) d.detachmentId};
    return [
      for (final enhancement in dataset.enhancements)
        if (enhancement.detachmentId == null ||
            taken.contains(enhancement.detachmentId))
          if (datasheet == null ||
              enhancement.canBeTakenBy(datasheet,
                  factionName: dataset.faction.factionName))
            enhancement,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Whether the section is worth showing at all.
  static bool any(Dataset dataset, Roster roster, SourceUnit? datasheet) =>
      of(dataset, roster, datasheet).isNotEmpty;
}
