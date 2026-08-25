import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/score_board.dart';
import 'package:wh40k_core/wh40k_core.dart';

MissionCard _card(String id, String name, String text,
        {String type = 'primary'}) =>
    MissionCard.fromJson({
      'id': id,
      'name': name,
      'card_type': type,
      'text': text,
      'awards': [
        {
          'vp': 4,
          'trigger': {'timing': 'end-of-turn'},
        }
      ],
    });

void main() {
  final mine = _card('secure-asset', 'Secure Asset',
      'ANY BATTLE ROUND\n4 VP: A friendly unit **secured the asset**.');
  final theirs = _card('inescapable-dominion', 'Inescapable Dominion',
      '4 VP: You control the **central objective**.');
  final outflank = _card(
      'outflank',
      'Outflank',
      'ANY BATTLE ROUND · End of your turn\n'
          '3 VP: A unit ends in your opponent\'s deployment zone.',
      type: 'secondary');

  final pack = MissionPack(cards: {
    mine.id: mine,
    theirs.id: theirs,
    outflank.id: outflank,
  });
  final deck = SecondaryDeck([outflank]);

  const setup = MissionSetup(
    myDisposition: 'priority-assets',
    opponentDisposition: 'take-and-hold',
    myMissionId: 'secure-asset',
    opponentMissionId: 'inescapable-dominion',
    opponentName: 'Kai',
  );

  Widget host(BattleState state, void Function(BattleEvent) onEvent) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScoreBoard(
              state: state,
              pack: pack,
              deck: deck,
              onEvent: onEvent,
            ),
          ),
        ),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  BattleState stateWith(List<BattleEvent> events) =>
      BattleLog(events: [const ConfigureBattle(setup), ...events]).state;

  group('one fold per side', () {
    // The primary and the cards are the same question — what can I score —
    // so they are one door rather than two (§7.3.24).
    testWidgets('each side has one, named for whose it is', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(stateWith(const []), (_) {}));
      expect(find.text('MY OBJECTIVES'), findsOneWidget);
      expect(find.text('KAI OBJECTIVES'), findsOneWidget);
    });

    testWidgets('folded, it still says what is inside', (tester) async {
      tall(tester);
      await tester.pumpWidget(
          host(stateWith(const [DrawSecondary('outflank')]), (_) {}));
      expect(find.text('Secure Asset · 1 card'), findsOneWidget);
      expect(find.textContaining('secured the asset', findRichText: true),
          findsNothing);
    });

    testWidgets('opening it gives the card and the hand together',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(
          host(stateWith(const [DrawSecondary('outflank')]), (_) {}));

      await tester.tap(find.text('MY OBJECTIVES'));
      await tester.pumpAndSettle();

      expect(find.textContaining('secured the asset', findRichText: true),
          findsOneWidget);
      expect(find.text('Outflank'), findsOneWidget,
          reason: 'the hand opens with the mission, not behind a second tap');
    });

    // Their mission is a different card, and how they score decides what you
    // contest — so it is readable too.
    testWidgets('theirs opens on its own', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(stateWith(const []), (_) {}));

      await tester.tap(find.text('KAI OBJECTIVES'));
      await tester.pumpAndSettle();
      expect(find.textContaining('central objective', findRichText: true),
          findsOneWidget);
      expect(find.textContaining('secured the asset', findRichText: true),
          findsNothing,
          reason: 'mine stays folded');
    });
  });

  group('command points, per side', () {
    // The bar carries mine because the bar is mine — round, my points, the
    // control that ends my turn. Theirs belong beside their score, which is
    // the other thing about them worth knowing (§7.3.21).
    testWidgets('each row carries its own', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(
        stateWith(const [AdjustCp(2), AdjustCp(5, side: Player.opponent)]),
        (_) {},
      ));

      // Each side starts on 1: the first turn grants a point to both, before
      // anything is entered by hand. So 1+2 and 1+5.
      expect(find.text('3 CP'), findsOneWidget);
      expect(find.text('6 CP'), findsOneWidget);
    });

    testWidgets('adding on their row adds to theirs', (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      await tester.pumpWidget(host(stateWith(const []), events.add));

      // Two rows, two plus buttons; the opponent's is the second.
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump();

      final adjusted = events.single as AdjustCp;
      expect(adjusted.side, Player.opponent);
      expect(adjusted.delta, 1);
    });

    testWidgets('nothing to spend, nothing to press', (tester) async {
      tall(tester);
      // Both open on one, so both can spend. Take one side to zero and its
      // minus goes with it.
      await tester.pumpWidget(host(stateWith(const []), (_) {}));
      expect(find.byIcon(Icons.remove), findsNWidgets(2));

      await tester.pumpWidget(host(
        stateWith(const [AdjustCp(-1, side: Player.opponent)]),
        (_) {},
      ));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });

  group('secondary cards, per side', () {
    testWidgets('each side counts the hand it can reach', (tester) async {
      tall(tester);
      final state = stateWith(const [
        DrawSecondary('outflank'),
        DrawSecondary('outflank', side: Player.opponent),
      ]);
      await tester.pumpWidget(host(state, (_) {}));

      expect(find.text('Secure Asset · 1 card'), findsOneWidget);
      expect(find.text('Inescapable Dominion · 1 card'), findsOneWidget,
          reason: 'the same card can be in both hands — the decks are copies');
    });

    testWidgets('drawing from their fold is drawn for them', (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      await tester.pumpWidget(host(stateWith(const []), events.add));

      await tester.tap(find.text('KAI OBJECTIVES'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();

      expect(events, hasLength(1));
      expect((events.single as DrawSecondary).side, Player.opponent);
    });

    testWidgets('scoring their card credits them', (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      final state =
          stateWith(const [DrawSecondary('outflank', side: Player.opponent)]);
      await tester.pumpWidget(host(state, events.add));

      await tester.tap(find.text('KAI OBJECTIVES'));
      await tester.pumpAndSettle();
      // Score 3 is the secondary's own line; the primary beside it pays 4.
      // Reading the figure off the text rather than the structured awards is
      // the point — this card's awards say 4 (§7.3.22).
      await tester.tap(find.text('Score 3'));
      await tester.pumpAndSettle();

      final scored = events.single as ScoreSecondaryCard;
      expect(scored.side, Player.opponent);
      expect(scored.cardId, 'outflank');
    });
  });
}
