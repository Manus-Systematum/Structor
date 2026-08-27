import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/faq_button.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  const faqs = [
    FactionFaq(
      id: 'a',
      question: 'Does the terrain area have to be trapped already?',
      answer: 'No.',
      cardId: 'death-trap',
    ),
    FactionFaq(id: 'b', question: 'General one?', answer: 'Yes.'),
  ];

  Widget host(String cardId) => MaterialApp(
        home: Scaffold(body: FaqButton(cardId: cardId, faqs: faqs)),
      );

  testWidgets('a card with a question offers it', (tester) async {
    await tester.pumpWidget(host('death-trap'));
    expect(find.text('FAQ'), findsOneWidget);

    await tester.tap(find.text('FAQ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('trapped already'), findsOneWidget);
    expect(find.text('No.'), findsOneWidget);
  });

  testWidgets('a card with none shows nothing at all', (tester) async {
    // Not a disabled button: a control that opens nothing on most cards is
    // worse than no control (§3.16).
    await tester.pumpWidget(host('battlefield-dominance'));
    expect(find.textContaining('FAQ'), findsNothing);
  });

  testWidgets('a question about no card belongs to no card', (tester) async {
    await tester.pumpWidget(host(''));
    expect(find.textContaining('FAQ'), findsNothing);
  });
}
