import 'package:wh40k_core/wh40k_core.dart';

import 'army.dart';

/// How much of a unit's detail the turn page carries (DESIGN.md §7.3.13).
///
/// Measured, not guessed. Rendering the old page for a 2,000 point T'au army
/// scrolled **32,732 logical pixels — 41.7 screens — per turn**, of which 94%
/// of the strings drawn were repeats of something already on it. Almost all of
/// that was rules text: printed rules run a median of 180 characters and up to
/// 993, so putting them inline costs 330–686 lines whatever the faction, while
/// the *names* cost 15–30 lines.
///
/// So the page carries names and the card carries text — and this is the one
/// axis that varies between players, because how much you need in front of you
/// depends on how well you know the army rather than on anything in the data.
enum PlayDensity {
  /// Unit rows and rule names. Weapon tables fold away.
  names,

  /// Adds the weapon statlines, which is what you read while playing.
  full,

  /// Adds the phase prompts — every stratagem and rule that fires this phase,
  /// counted once — for an army you have not played before.
  guided;

  bool get showsWeapons => this != PlayDensity.names;
  bool get showsPrompts => this == PlayDensity.guided;

  String get label => switch (this) {
        PlayDensity.names => 'Names',
        PlayDensity.full => 'Full',
        PlayDensity.guided => 'Guided',
      };

  String get note => switch (this) {
        PlayDensity.names => 'Unit names and rule names.',
        PlayDensity.full => 'Adds weapon profiles.',
        PlayDensity.guided => 'Adds what fires in each phase.',
      };

  static PlayDensity parse(String? raw) => PlayDensity.values
      .firstWhere((d) => d.name == raw, orElse: () => PlayDensity.full);

  /// What to open a roster at when the player has not chosen.
  ///
  /// Derived from the roster rather than asked. A Space Marine list renders
  /// seven weapon rows across sixteen units — free, so show them. A T'au one
  /// renders fifty-seven, which is where folding starts to earn its place.
  /// Either way this is a starting point the player can move.
  static PlayDensity defaultFor(Army army) {
    var rows = 0;
    for (final unit in army.combatUnits) {
      rows += unit.weapons(WeaponKind.ranged).weapons.length +
          unit.weapons(WeaponKind.melee).weapons.length;
    }
    return rows > 40 ? PlayDensity.names : PlayDensity.full;
  }
}
