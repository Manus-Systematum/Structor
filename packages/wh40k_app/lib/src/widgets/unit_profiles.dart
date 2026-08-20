import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';

/// Statlines and weapon profiles, shared by every screen that shows a unit.
///
/// Three surfaces ask the same question — the editor while you are choosing a
/// loadout, the turn page while you are resolving one, and the rules summary
/// while you are checking what a unit even has. They were diverging into three
/// half-implementations, so they are one here (DESIGN.md §7.3.11).

/// A statline, one line per distinct profile.
///
/// Takes **resolved** profiles rather than a datasheet, because the numbers a
/// player reads are not always the ones on the sheet: an invulnerable save
/// granted by an ability belongs in the INV column (§3.8), and only the
/// caller knows whether it applies. [UnitStatline.of] is the plain
/// datasheet case.
class UnitStatline extends StatelessWidget {
  final List<({String name, ModelProfile profile})> profiles;

  const UnitStatline({super.key, required this.profiles});

  UnitStatline.of(SourceUnit datasheet, {super.key})
      : profiles = [
          for (final p in datasheet.profiles) (name: p.name, profile: p),
        ];

  static const _columns = ['M', 'T', 'SV', 'W', 'LD', 'OC'];

  /// Characteristics rolled against are written with the `+` the rulebook
  /// gives them: a Save of 3 is `3+`, and printed bare it reads as a value
  /// rather than a threshold.
  static String? _threshold(String? value) {
    if (value == null || value.isEmpty) return value;
    return value.endsWith('+') ? value : '$value+';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (profiles.isEmpty) return const SizedBox.shrink();

    List<String?> valuesOf(ModelProfile p) =>
        [p.m, p.t, _threshold(p.sv), p.w, _threshold(p.ld), p.oc];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, entry) in profiles.indexed) ...[
            // One profile needs no name; several do, or the numbers are
            // ambiguous about which model they describe.
            if (profiles.length > 1)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 6, bottom: 1),
                child: Text(entry.name,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ),
            Row(
              children: [
                for (final (i, label) in _columns.indexed)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (index == 0)
                          Text(label,
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.6,
                                color: scheme.onSurfaceVariant,
                              )),
                        Text(valuesOf(entry.profile)[i] ?? '–',
                            style: AppTheme.numeric(context, size: 13)),
                      ],
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (index == 0)
                        Text('INV',
                            style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 0.6,
                              color: scheme.onSurfaceVariant,
                            )),
                      Text(_threshold(entry.profile.invulnSv) ?? '–',
                          style: AppTheme.numeric(context, size: 13).copyWith(
                              color: entry.profile.invulnSv == null
                                  ? scheme.outline
                                  : scheme.onSurface)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// What a profile is, for the one thing the table cannot say in words.
///
/// The `SKILL` column takes `BS` or `WS` per profile, so the heading can no
/// longer name which. The row carries that instead — and a pistol is worth a
/// third state rather than being lumped in with the rest of the shooting: it
/// is the weapon you are looking for when the enemy is already in engagement
/// range, which is exactly when nobody wants to read a table.
enum _Kind {
  ranged,
  melee,
  pistol;

  Color? tint(ColorScheme scheme) => switch (this) {
        _Kind.ranged => null,
        _Kind.melee => scheme.surfaceContainerHighest,
        _Kind.pistol => scheme.tertiaryContainer.withValues(alpha: 0.45),
      };
}

/// Profiles for the weapons this unit is actually carrying.
///
/// Only what is on the unit, because the point of showing them here is
/// deciding between the guns you are choosing between — a full datasheet's
/// worth of profiles is the Army page's job (§7.3.6).
class CarriedWeaponProfiles extends StatelessWidget {
  final Catalogue dataset;
  final SourceUnit datasheet;
  final Map<String, int> carried;

  const CarriedWeaponProfiles({
    super.key,
    required this.dataset,
    required this.datasheet,
    required this.carried,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final profiles = <(String, WeaponProfile, _Kind)>[];
    for (final entry in carried.entries) {
      if (entry.value <= 0) continue;
      final weapon = dataset.weaponFor(datasheet, entry.key) ??
          dataset.weapon(entry.key) ??
          // A drone is wargear whose rules are an ability, and the ability
          // names the gun it brings (§3.8).
          _granted(entry.key);
      if (weapon == null) continue;
      for (final profile in weapon.profiles) {
        profiles.add((
          '${entry.value}×',
          profile,
          // Per profile, not per weapon: a Fusion eliminator is typed ranged
          // and carries a melee profile too.
          profile.isMelee(weaponIsMelee: weapon.type == 'melee')
              ? _Kind.melee
              : profile.hasKeyword('pistol')
                  ? _Kind.pistol
                  : _Kind.ranged,
        ));
      }
    }
    if (profiles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ProfilesHeading('PROFILES'),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              const Expanded(flex: 5, child: SizedBox()),
              // **SKILL, not BS.** The column read `BS` and printed whatever
              // the profile had, so every melee weapon showed its Weapon
              // Skill under a Ballistic Skill heading — a wrong label on a
              // right number, which is worse than either.
              for (final label in ['RNG', 'A', 'SKILL', 'S', 'AP', 'D'])
                Expanded(
                  flex: 2,
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.6,
                          color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
        for (final (count, profile, kind) in profiles)
          Container(
            // The heading cannot say which skill a row is using once it says
            // both, so the row does: melee sits on its own ground, and a
            // pistol on its own again — it is a ranged weapon that can be
            // fired inside engagement range, which is the one thing you are
            // checking the list for when the enemy is already on you.
            color: kind.tint(scheme),
            padding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('$count ${profile.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
                for (final key in ['range', 'A', 'skill', 'S', 'AP', 'D'])
                  Expanded(
                    flex: 2,
                    child: Text(
                      switch (key) {
                        'range' => profile.range ?? '–',
                        // Through the same formatter the weapon tables use:
                        // a skill is read as `4+`, and the raw characteristic
                        // is a bare `4`. Null for Torrent-style weapons,
                        // which hit without rolling and have no skill.
                        'skill' => formatSkill(profile.skill) ?? '–',
                        _ => profile.stats[key] ?? '–',
                      },
                      textAlign: TextAlign.center,
                      style: AppTheme.numeric(context, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        // **Only the pistol is explained.** A melee row already says so in
        // its own RNG cell, and a key repeating the word beside a swatch is
        // furniture. A pistol's range is a number like any other gun's, so
        // nothing on the row says what the tint means.
        if (profiles.any((p) => p.$3 == _Kind.pistol))
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: _Kind.pistol.tint(scheme),
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 5),
                Text('Pistol',
                    style: TextStyle(
                        fontSize: 9.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }

  SourceWeapon? _granted(String itemId) {
    final grantedId = dataset.ability(itemId)?.grantedWeaponId;
    if (grantedId == null) return null;
    return dataset.weaponFor(datasheet, grantedId) ?? dataset.weapon(grantedId);
  }
}

class _ProfilesHeading extends StatelessWidget {
  final String label;

  const _ProfilesHeading(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
        child: Text(label,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
            )),
      );
}
