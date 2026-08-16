import 'package:flutter/material.dart';

/// The title row of a full-height modal sheet, carrying an explicit way out.
///
/// A sheet opened `isScrollControlled` grows to fill the screen, which leaves
/// no scrim to tap, and a scrollable body swallows the downward drag that
/// would otherwise dismiss it. The drag handle is a few pixels at the very top
/// and it is not an exit anyone finds. Every sheet that can reach full height
/// carries this instead.
class SheetHeader extends StatelessWidget {
  final String title;

  /// Shown before the close button — a points total, a cost, a count.
  final Widget? trailing;

  const SheetHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 6, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 6),
            ],
            IconButton(
              tooltip: 'Close',
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
      );
}
