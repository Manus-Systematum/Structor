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
  final outflank = _card('outflank', 'Outflank', 'Ends in enemy territory.',
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

  group('the mission each side is playing', () {
    // The buttons say what the card pays. Only the card says what it asks
    // for, and that is the part checked before tapping (§7.3.17).
    testWidgets('is named on the row that scores it', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(stateWith(const []), (_) {}));
      expect(find.text('Secure Asset'), findsOneWidget);
      expect(find.text('Inescapable Dominion'), findsOneWidget);
    });

    testWidgets('opens in full when the name is tapped', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(stateWith(const []), (_) {}));

      await tester.tap(find.text('Secure Asset'));
      await tester.pumpAndSettle();
      expect(find.textContaining('secured the asset'), findsOneWidget);
    });

    // Their mission is a different card, and how they score decides what you
    // contest — so it has to be readable too, not just named.
    testWidgets('theirs is readable as well as mine', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(stateWith(const []), (_) {}));

      await tester.tap(find.text('Inescapable Dominion'));
      await tester.pumpAndSettle();
      expect(find.textContaining('central objective'), findsOneWidget);
      expect(find.text('Kai'), findsWidgets,
          reason: 'the sheet says whose mission it is');
    });
  });

  group('secondary cards, per side', () {
    testWidgets('each row counts the hand it can reach', (tester) async {
      tall(tester);
      final state = stateWith(const [
        DrawSecondary('outflank'),
        DrawSecondary('outflank', side: Player.opponent),
      ]);
      await tester.pumpWidget(host(state, (_) {}));

      expect(find.text('Cards 1'), findsNWidgets(2),
          reason: 'the same card can be in both hands — the decks are copies');
    });

    testWidgets('an empty hand is still a way in', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(stateWith(const []), (_) {}));
      expect(find.text('Cards'), findsNWidgets(2));
    });

    testWidgets('drawing from their row is drawn for them', (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      await tester.pumpWidget(host(stateWith(const []), events.add));

      // The opponent's row is the second one.
      await tester.tap(find.text('Cards').last);
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

      await tester.tap(find.text('Cards 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Score 4'));
      await tester.pumpAndSettle();

      final scored = events.single as ScoreSecondaryCard;
      expect(scored.side, Player.opponent);
      expect(scored.cardId, 'outflank');
    });
  });
}
