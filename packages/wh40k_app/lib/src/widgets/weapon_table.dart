import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import '../theme.dart';

/// The aggregated weapon table (DESIGN.md §7.3.5).
///
/// The number that earns this screen its place is **total attacks per resolved
/// profile** — ten missile pods that split eight attacks at BS3+ and twelve at
/// BS4+, which no datasheet gives you. It is emphasised accordingly.
class WeaponTable extends StatelessWidget {
  final AggregationResult result;

  const WeaponTable({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (result.weapons.isEmpty && result.isComplete) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text('No weapons in this phase',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final weapon in result.weapons) _WeaponRow(weapon: weapon),
        // Unresolved wargear is shown, never dropped: a missing weapon makes a
        // unit look weaker than it is (§7.6).
        for (final gap in result.unresolved)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Row(
              children: [
                Icon(Icons.error_outline, size: 14, color: scheme.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Unresolved wargear: ${gap.itemId}',
                      style: TextStyle(color: scheme.error, fontSize: 12)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _WeaponRow extends StatelessWidget {
  final AggregatedWeapon weapon;

  const _WeaponRow({required this.weapon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final stats = weapon.profile.stats;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 30,
                child: Text('${weapon.weaponCount}×',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
              ),
              Expanded(
                child: Text(weapon.displayName,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              // The computed figure — the reason the table exists.
              _Pill(
                text: '${weapon.attacks.display} atk',
                background: scheme.primaryContainer,
                foreground: scheme.onPrimaryContainer,
                emphasised: true,
              ),
              const SizedBox(width: 6),
              _Pill(
                text: weapon.skill ?? 'auto',
                background: weapon.autoHits
                    ? scheme.tertiaryContainer
                    : scheme.surfaceContainerHighest,
                foreground: weapon.autoHits
                    ? scheme.onTertiaryContainer
                    : scheme.onSurface,
              ),
            ],
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Wrap(
              spacing: 10,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _stat(context, 'RNG', _range(weapon)),
                _stat(context, 'S', stats['S']),
                _stat(context, 'AP', stats['AP']),
                _stat(context, 'D', stats['D']),
                for (final keyword in weapon.keywords)
                  _KeywordChip(label: keyword.label),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _range(AggregatedWeapon weapon) {
    final range = weapon.range;
    if (range == null) return '—';
    return int.tryParse(range) != null ? '$range"' : range;
  }

  Widget _stat(BuildContext context, String label, String? value) {
    final scheme = Theme.of(context).colorScheme;
    return RichText(
      text: TextSpan(children: [
        TextSpan(
          text: '$label ',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        TextSpan(text: value ?? '—', style: AppTheme.numeric(context, size: 12)),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;
  final bool emphasised;

  const _Pill({
    required this.text,
    required this.background,
    required this.foreground,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: emphasised ? 13 : 12,
            fontWeight: FontWeight.w700,
            color: foreground,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
}

class _KeywordChip extends StatelessWidget {
  final String label;

  const _KeywordChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.replaceAll('-', ' ').toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
