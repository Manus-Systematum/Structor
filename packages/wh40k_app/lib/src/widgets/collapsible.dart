import 'package:flutter/material.dart';

/// A titled block the player can fold away (DESIGN.md §7.3.11).
///
/// The turn page works by scroll position: the phase you are in is the thing
/// under your thumb (§7.2). That breaks once a phase carries several kinds of
/// content — stratagems, profiles, scoring — because a phase you are not using
/// pushes the one you are off the screen. Folding is the cheapest fix that
/// keeps one scrolling page rather than introducing a second axis.
///
/// [initiallyOpen] is a judgement about what the player came for, not a
/// default to be applied uniformly: stratagems in the current phase are the
/// decision the phase turns on and open; profiles are a lookup and closed.
class CollapsibleGroup extends StatefulWidget {
  final String title;

  /// A count or short qualifier shown beside the title, so a folded group
  /// still says how much is inside. Folding something away must not hide that
  /// it exists.
  final String? trailing;

  final IconData? icon;
  final bool initiallyOpen;
  final Widget child;

  const CollapsibleGroup({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.icon,
    this.initiallyOpen = false,
  });

  @override
  State<CollapsibleGroup> createState() => _CollapsibleGroupState();
}

class _CollapsibleGroupState extends State<CollapsibleGroup> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            child: Row(
              children: [
                Icon(_open ? Icons.expand_more : Icons.chevron_right,
                    size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 14, color: scheme.primary),
                  const SizedBox(width: 6),
                ],
                // Titles are datasheet names as often as they are labels, and
                // "COMMANDER IN ENFORCER BATTLESUIT" does not fit a phone at
                // its natural width.
                Flexible(
                  child: Text(widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      )),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(widget.trailing!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: scheme.onSurfaceVariant)),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_open) widget.child,
      ],
    );
  }
}
