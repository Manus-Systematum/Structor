import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/turn_review.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// The review sheet (§7.3.29): what this turn scored, correctable while the
/// player still remembers it.
void main() {
  const setup = MissionSetup(
    myDisposition: 'priority-assets',
    opponentDisposition: 'take-and-hold',
    myMissionId: 'secure-asset',
    opponentMissionId: 'inescapable-dominion',
    opponentName: 'Kai',
  );

  BattleLog logWith(List<BattleEvent> events) =>
      BattleLog(events: [const ConfigureBattle(setup), ...events]);

  Widget host(BattleLog log, void Function(BattleEvent) onEvent) => MaterialApp(
        home: Scaffold(
          body: TurnReviewSheet(
            log: log,
            state: log.state,
            opponentName: 'Kai',
            onEvent: onEvent,
          ),
        ),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('what the turn scored', () {
    testWidgets('lists this turn, one row per entry', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(
        logWith(const [
          ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 5),
          ScoreSecondaryCard(cardId: 'outflank', round: 1, vp: 3),
        ]),
        (_) {},
      ));

      expect(find.text('+5'), findsOneWidget);
      expect(find.text('You · primary'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('You · Outflank'), findsOneWidget);
    });

    // The question the sheet answers is about *this* turn. What was scored
    // before it was reviewed at the time and is a question about the past now.
    testWidgets('earlier turns are not in it', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(
        logWith(const [
          ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 5),
          EndTurn(),
          ScoreVp(side: Player.me, kind: ScoreKind.secondary, round: 1, vp: 4),
        ]),
        (_) {},
      ));

      expect(find.text('+4'), findsOneWidget);
      expect(find.text('+5'), findsNothing);
    });

    testWidgets('a turn that scored nothing says so', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(logWith(const []), (_) {}));
      expect(find.text('Nothing scored this turn.'), findsOneWidget);
    });

    testWidgets('theirs is named for them', (tester) async {
      tall(tester);
      await tester.pumpWidget(host(
        logWith(const [
          ScoreVp(
              side: Player.opponent,
              kind: ScoreKind.primary,
              round: 1,
              vp: 10),
        ]),
        (_) {},
      ));
      expect(find.text('Kai · primary'), findsOneWidget);
    });
  });

  group('taking one back', () {
    // Appended, not cut out: the events are deltas, so undo still works one
    // pop at a time.
    testWidgets('a primary comes back as a negative delta', (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      await tester.pumpWidget(host(
        logWith(const [
          ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 5),
        ]),
        events.add,
      ));

      await tester.tap(find.text('Take back'));
      await tester.pumpAndSettle();

      expect(events, hasLength(1));
      final event = events.single as ScoreVp;
      expect(event.vp, -5);
      expect(event.kind, ScoreKind.primary);
      expect(event.side, Player.me);
    });

    testWidgets('a card comes back as an unscore', (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      await tester.pumpWidget(host(
        logWith(const [
          DrawSecondary('outflank'),
          ScoreSecondaryCard(cardId: 'outflank', round: 1, vp: 3),
        ]),
        events.add,
      ));

      await tester.tap(find.text('Take back'));
      await tester.pumpAndSettle();

      final event = events.single as UnscoreSecondary;
      expect(event.cardId, 'outflank');
      expect(event.vp, 3);
    });

    testWidgets('the take-back shows in the list, and is not itself undoable',
        (tester) async {
      tall(tester);
      await tester.pumpWidget(host(
        logWith(const [
          ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 5),
        ]),
        (_) {},
      ));

      await tester.tap(find.text('Take back'));
      await tester.pumpAndSettle();

      expect(find.text('-5'), findsOneWidget);
      expect(find.text('Take back'), findsOneWidget,
          reason: 'the original still offers one; the correction does not');
    });
  });

  group('adjusting what is there', () {
    testWidgets('the stepper writes to the round it is reviewing',
        (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      await tester.pumpWidget(host(logWith(const []), events.add));

      await tester.tap(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();

      final event = events.single as ScoreVp;
      expect(event.vp, 1);
      expect(event.round, 1);
      expect(event.side, Player.me);
    });
  });

  group('ending the turn', () {
    testWidgets('the button pops true', (tester) async {
      tall(tester);
      final log = logWith(const []);
      bool? ended;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                ended = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TurnReviewSheet(
                    log: log,
                    state: log.state,
                    opponentName: 'Kai',
                    onEvent: (_) {},
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('End turn'));
      await tester.pumpAndSettle();

      expect(ended, isTrue);
    });

    // Dismissing is not ending: the review is a stop on the way, and backing
    // out of it leaves the turn where it was.
    testWidgets('dismissing it does not end the turn', (tester) async {
      tall(tester);
      final log = logWith(const []);
      bool? ended = true;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                ended = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TurnReviewSheet(
                    log: log,
                    state: log.state,
                    opponentName: 'Kai',
                    onEvent: (_) {},
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(ended, isNull);
    });
  });
}
