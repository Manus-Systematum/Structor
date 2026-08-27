import 'package:flutter/material.dart';

/// Said where a stratagem has no rules text, instead of nothing (§7.6, §3.14).
///
/// **116 of 2,246 stratagems** carry a name, a cost and a timing and no text —
/// every one of them on a `pre-launch-provisional` detachment, and none of the
/// three sources has it: 40kdc publishes structure without wording, BSData has
/// the detachment but not its cards, and Wahapedia has not written them up
/// yet. Nothing here is filled in from memory (§3.14).
///
/// The row used to draw a name, a cost, and a blank where the card goes, and
/// gave the player nothing to distinguish *this app is missing it* from *this
/// stratagem is a one-liner*. Saying which one it is costs a line.
class MissingRulesNote extends StatelessWidget {
  const MissingRulesNote({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        'No rules text published. Read it off the card.',
        style: TextStyle(
          fontSize: 11,
          height: 1.3,
          fontStyle: FontStyle.italic,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
