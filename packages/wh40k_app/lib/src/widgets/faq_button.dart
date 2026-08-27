import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

import 'sheet_header.dart';

/// The published questions about one mission card, where there are any.
///
/// **It is not shown unless the card has some.** Five of the mission deck's
/// eight questions name a card — Plunder, Beacon, Death Trap, Surveil the
/// Foe, Vital Link — and a player reading that card is the only person who
/// wants them. A button on every card, most of them opening nothing, would be
/// worse than no button at all (§3.16).
class FaqButton extends StatelessWidget {
  /// The card being read.
  final String cardId;

  /// Every question the app holds; this picks its own out.
  final List<FactionFaq> faqs;

  const FaqButton({super.key, required this.cardId, required this.faqs});

  /// Both ids must be real: a question about the deck as a whole carries no
  /// card id, and neither does a card the app has not named — matching empty
  /// against empty would have shown the general questions on it.
  List<FactionFaq> get _mine => cardId.isEmpty
      ? const []
      : [
          for (final faq in faqs)
            if (faq.cardId == cardId) faq
        ];

  @override
  Widget build(BuildContext context) {
    final mine = _mine;
    if (mine.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => _CardFaqs(faqs: mine),
      ),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 13, color: scheme.primary),
            const SizedBox(width: 3),
            Text(
              mine.length == 1 ? 'FAQ' : 'FAQ (${mine.length})',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardFaqs extends StatelessWidget {
  final List<FactionFaq> faqs;

  const _CardFaqs({required this.faqs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const SheetHeader(title: 'About this card'),
          for (final faq in faqs) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(faq.question,
                  style: const TextStyle(
                      fontSize: 13, height: 1.35, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 4),
            Text(faq.answer,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant)),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              'Games Workshop’s answers, quoted. They are not applied to '
              'anything the app shows.',
              style: TextStyle(
                  fontSize: 10.5, height: 1.35, color: scheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}
