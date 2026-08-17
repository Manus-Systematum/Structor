import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';

/// Statlines and weapon profiles, shared by every screen that shows a unit.
///
/// Three surfaces ask the same question — the editor while you are choosing a
/// loadout, the turn page while you are resolving one, and the rules summary
/// while you are checking what a unit even has. They were diverging into three
/// half-implementations, so they are one here (DESIGN.md §7.3.11).

/// The datasheet's statline, one line per distinct profile.
class UnitStatline extends StatelessWidget {
  final SourceUnit datasheet;

  const UnitStatline({super.key, required this.datasheet});

  static const _columns = ['M', 'T', 'SV', 'W', 'LD', 'OC'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (datasheet.profiles.isEmpty) return const SizedBox.shrink();

    List<String?> valuesOf(ModelProfile p) =>
        [p.m, p.t, p.sv, p.w, p.ld, p.oc];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, profile) in datasheet.profiles.indexed) ...[
            // One profile needs no name; several do, or the numbers are
            // ambiguous about which model they describe.
            if (datasheet.profiles.length > 1)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 6, bottom: 1),
                child: Text(profile.name,
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
                        Text(valuesOf(profile)[i] ?? '–',
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
                      Text(profile.invulnSv ?? '–',
                          style: AppTheme.numeric(context, size: 13).copyWith(
                              color: profile.invulnSv == null
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
    final profiles = <(String, WeaponProfile)>[];
    for (final entry in carried.entries) {
      if (entry.value <= 0) continue;
      final weapon = dataset.weaponFor(datasheet, entry.key) ??
          dataset.weapon(entry.key) ??
          // A drone is wargear whose rules are an ability, and the ability
          // names the gun it brings (§3.8).
          _granted(entry.key);
      if (weapon == null) continue;
      for (final profile in weapon.profiles) {
        profiles.add(('${entry.value}×', profile));
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
              for (final label in ['RNG', 'A', 'BS', 'S', 'AP', 'D'])
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
        for (final (count, profile) in profiles)
          Padding(
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
                for (final key in ['range', 'A', 'BS', 'S', 'AP', 'D'])
                  Expanded(
                    flex: 2,
                    child: Text(
                      key == 'range'
                          ? (profile.range ?? '–')
                          : (profile.stats[key] ?? '–'),
                      textAlign: TextAlign.center,
                      style: AppTheme.numeric(context, size: 12),
                    ),
                  ),
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
