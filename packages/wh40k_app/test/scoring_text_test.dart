import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/scoring_text.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  group('which lines carry a payout', () {
    // Parsed from the card's own composed text (§3.11), so the shapes here are
    // the shapes the shipped cards actually use.
    test('a plain payout', () {
      expect(
          ScoringText.payoutOf('4 VP: You control one or more objectives.'), 4);
    });

    test('a cumulative tier keeps its own figure', () {
      expect(ScoringText.payoutOf('+2 VP each: For each enemy model.'), 2);
    });

    test('a capped payout is the figure, not the cap', () {
      expect(ScoringText.payoutOf('5 VP, max 15 VP: Whatever it is.'), 5);
    });

    test('a section header is not a payout', () {
      expect(
          ScoringText.payoutOf('ANY BATTLE ROUND · End of your turn'), isNull);
      expect(ScoringText.payoutOf('SECOND BATTLE ROUND ONWARDS'), isNull);
    });

    test('the action block is not a payout', () {
      expect(ScoringText.payoutOf('ACTION · Secure Asset: Objective Action'),
          isNull);
      expect(ScoringText.payoutOf('When: your Shooting phase, once per turn.'),
          isNull);
    });

    // The merge briefly wrote `++1 VP each` where the source had already
    // supplied the plus. Fixed upstream; tolerated here so a doubled plus
    // costs a button rather than losing one silently.
    test('a doubled plus still names its figure', () {
      expect(ScoringText.payoutOf('++1 VP each: For each of those models.'), 1);
    });

    test('a card with no named figure says so', () {
      expect(
          ScoringText.hasPayout(
              'ANY BATTLE ROUND\n2 VP each: For each objective you hold.'),
          isTrue);
      expect(ScoringText.hasPayout('ANY BATTLE ROUND · End of your turn'),
          isFalse);
    });

    test('a sentence that merely mentions VP is not a payout', () {
      expect(ScoringText.payoutOf('Score the VP for this card at end of turn.'),
          isNull);
    });
  });

  testWidgets('the button sits on the line that earns it', (tester) async {
    final scored = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScoringText(
          text: 'ANY BATTLE ROUND · End of your turn\n'
              '4 VP: You hold the centre.\n'
              '2 VP: You hold your home objective.',
          onScore: scored.add,
        ),
      ),
    ));

    expect(find.text('Score 4'), findsOneWidget);
    expect(find.text('Score 2'), findsOneWidget);
    // The header earns nothing and offers nothing.
    expect(find.text('Score 0'), findsNothing);

    await tester.tap(find.text('Score 4'));
    await tester.pump();
    expect(scored, [4]);
  });

  testWidgets('with no scorer, it is only text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ScoringText(
          text: '4 VP: You hold the centre.',
          onScore: null,
        ),
      ),
    ));
    expect(find.textContaining('You hold the centre', findRichText: true),
        findsOneWidget);
    expect(find.text('Score 4'), findsNothing);
  });

  // §7.3.27. A line that pays per something and caps can only come to a few
  // totals, and the card leaves that arithmetic to the player.
  group('a capped per-something line offers every total it can reach', () {
    MissionCard cardOf(String text, List<Map<String, Object?>> awards) =>
        MissionCard.fromJson({
          'id': 'no-prisoners',
          'name': 'No Prisoners',
          'card_type': 'secondary',
          'text': text,
          'awards': awards,
        });

    testWidgets('2 a kill up to 5 is 2, 4 and 5 — never 6', (tester) async {
      final scored = <int>[];
      final card = cardOf(
        '2 VP: For each enemy unit destroyed this turn.',
        [
          {'vp_per': 2, 'vp_max': 5},
        ],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScoringText(
            text: card.text,
            card: card,
            onScore: scored.add,
          ),
        ),
      ));

      expect(find.text('Score 2'), findsOneWidget);
      expect(find.text('Score 4'), findsOneWidget);
      expect(find.text('Score 5'), findsOneWidget);
      expect(find.text('Score 6'), findsNothing);

      await tester.tap(find.text('Score 4'));
      expect(scored, [4]);
    });

    testWidgets('an uncapped rate keeps its single button', (tester) async {
      // `3 VP each: for each objective you control` runs as far as the board
      // allows; there is nothing to enumerate.
      final card = cardOf(
        '3 VP each: For each objective you control.',
        [
          {'vp_per': 3},
        ],
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ScoringText(text: card.text, card: card, onScore: (_) {}),
        ),
      ));
      expect(find.text('Score 3'), findsOneWidget);
      expect(find.text('Score 6'), findsNothing);
    });

    testWidgets('with no card it behaves as it always did', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ScoringText(
            text: '4 VP: One or more enemy units were surveilled.',
            onScore: _ignore,
          ),
        ),
      ));
      expect(find.text('Score 4'), findsOneWidget);
    });
  });
}

void _ignore(int vp) {}
