import 'package:flutter/material.dart';

/// Where a stratagem comes from, as a pill rather than a run of small text.
///
/// **At two or three detachments half the list is not yours to play.** The
/// source was already on the row, in the same grey as the phase and the type
/// and joined to them by a middle dot, so the one part that decides whether a
/// stratagem is even available read as a footnote. A pill is scannable down a
/// column of eight; a clause in a subtitle is not.
///
/// `Core` is deliberately plainer than a detachment's name: core stratagems
/// are always available, so which they are matters less than which of the
/// detachment ones you have.
class SourcePill extends StatelessWidget {
  final String label;

  const SourcePill(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final core = label.toLowerCase() == 'core';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: core
            ? scheme.surfaceContainerHighest
            : scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.5,
          height: 1.25,
          fontWeight: core ? FontWeight.w500 : FontWeight.w700,
          color: core ? scheme.onSurfaceVariant : scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
