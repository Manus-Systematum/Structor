import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/screens/objectives_screen.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  const setup = MissionSetup(
    myDisposition: 'take-and-hold',
    opponentDisposition: 'reconnaissance',
    myMissionId: 'battlefield-dominance',
    opponentMissionId: 'reconnaissance-sweep',
    iAmAttacker: true,
    iGoFirst: true,
    opponentName: 'Kara',
  );

  const pack = MissionPack(cards: {
    'battlefield-dominance': MissionCard(
      id: 'battlefield-dominance',
      name: 'Battlefield Dominance',
      cardType: 'primary',
      text: 'Hold more objectives than your opponent.',
      awards: [
        {
          'trigger': {
            'timing': 'end-of-phase',
            'phase': 'command',
            'battle_round': {'min': 2},
          },
          'vp': 4,
        },
      ],
    ),
    'reconnaissance-sweep': MissionCard(
      id: 'reconnaissance-sweep',
      name: 'Reconnaissance Sweep',
      cardType: 'primary',
      text: 'Spread out across the table quarters.',
      awards: [
        {
          'trigger': {'timing': 'end-of-turn'},
          'vp': 3,
        },
      ],
    ),
  });

  Widget host(
    BattleState state, {
    VoidCallback? onFinish,
    void Function(BattleEvent)? onEvent,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: ObjectivesScreen(
            state: state,
            pack: pack,
            onFinish: onFinish,
            onEvent: onEvent ?? (_) {},
          ),
        ),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  BattleState stateWith(List<BattleEvent> events) =>
      BattleLog(events: [const ConfigureBattle(setup), ...events]).state;

  testWidgets('before setup it says what it needs', (tester) async {
    tall(tester);
    await tester.pumpWidget(host(const BattleState()));
    expect(find.text('No battle set up.'), findsOneWidget);
  });

  testWidgets('it shows the margin, not just two totals', (tester) async {
    tall(tester);
    await tester.pumpWidget(host(stateWith(const [
      ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 10),
      ScoreVp(side: Player.opponent, kind: ScoreKind.primary, round: 1, vp: 6),
    ])));

    // The number that decides the game is the difference, and two bare totals
    // make the player do the subtraction.
    expect(find.text('+4 you'), findsOneWidget);
  });

  testWidgets('the margin names the opponent when they lead', (tester) async {
    tall(tester);
    await tester.pumpWidget(host(stateWith(const [
      ScoreVp(side: Player.opponent, kind: ScoreKind.primary, round: 1, vp: 7),
    ])));
    expect(find.text('+7 Kara'), findsOneWidget);
  });

  testWidgets('the per-round history separates primary from secondary',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(host(stateWith(const [
      ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 5),
      ScoreVp(side: Player.me, kind: ScoreKind.secondary, round: 1, vp: 3),
    ])));

    expect(find.text('SCORE BY ROUND'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('3'), findsWidgets);
  });

  testWidgets('a round that scored nothing reads as blank, not zero',
      (tester) async {
    // Zero is a result; blank is "not yet". Printing 0 for an unplayed round
    // reads as a scoreless turn that never happened.
    tall(tester);
    await tester.pumpWidget(host(stateWith(const [])));
    expect(find.text('–'), findsWidgets);
  });

  // One block per side, holding the primary and that side's cards, named for
  // whose objectives they are (§7.3.19, §7.3.24).
  testWidgets('each side gets one block, named for whose it is',
      (tester) async {
    tall(tester);
    await tester.pumpWidget(host(stateWith(const [])));
    expect(find.text('MY OBJECTIVES'), findsOneWidget);
    expect(find.text('KARA OBJECTIVES'), findsOneWidget);
    expect(find.text('Battlefield Dominance'), findsWidgets);
  });

  testWidgets('scoring is on this page, not only the turn page',
      (tester) async {
    tall(tester);
    final events = <BattleEvent>[];
    await tester.pumpWidget(host(stateWith(const []), onEvent: events.add));

    // The first block is mine and open; its +1 is the primary line's.
    await tester.tap(find.text('+1').first);
    await tester.pumpAndSettle();

    final scored = events.single as ScoreVp;
    expect(scored.side, Player.me);
    expect(scored.kind, ScoreKind.primary);
    expect(scored.vp, 1);
  });

  testWidgets('it says where this round\'s points are available',
      (tester) async {
    tall(tester);
    // Round 1: the command-phase tier is not open yet.
    await tester.pumpWidget(host(stateWith(const [])));
    expect(find.textContaining('Nothing scores this round'), findsWidgets);

    await tester.pumpWidget(host(stateWith(const [SetRound(2)])));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Scores in your Command phase'),
      findsOneWidget,
    );
  });

  testWidgets('it says whose words the descriptions are', (tester) async {
    tall(tester);
    await tester.pumpWidget(host(stateWith(const [])));
    expect(
      find.textContaining('not the printed text', findRichText: true),
      findsOneWidget,
    );
  });

  group('finishing from this page', () {
    testWidgets('the button is offered when a game is in progress',
        (tester) async {
      // The other place a game ends: this page is where the standings are
      // read, and the END section is a long scroll away on the turn page.
      tall(tester);
      var finished = 0;
      await tester.pumpWidget(host(
        const BattleLog(events: [ConfigureBattle(setup), SetRound(5)]).state,
        onFinish: () => finished++,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish battle'));
      await tester.pumpAndSettle();
      expect(finished, 1);
    });

    testWidgets('and withheld when there is nothing to finish', (tester) async {
      tall(tester);
      await tester.pumpWidget(
          host(const BattleLog(events: [ConfigureBattle(setup)]).state));
      await tester.pumpAndSettle();
      expect(find.text('Finish battle'), findsNothing);
    });
  });
}
