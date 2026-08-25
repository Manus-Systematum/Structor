import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/secondary_cards.dart';
import 'package:wh40k_core/wh40k_core.dart';

MissionCard _card(String id, String name,
        {String text = 'Do the thing.',
        List<Object?> awards = const [],
        Object? drawn}) =>
    MissionCard.fromJson({
      'id': id,
      'name': name,
      'card_type': 'secondary',
      'text': text,
      'awards': awards,
      if (drawn != null) 'when_drawn': drawn,
    });

void main() {
  final deck = SecondaryDeck([
    // The figures come off the printed lines now, not the structured
    // awards — so the text is what a real card's text looks like (§7.3.22).
    _card('outflank', 'Outflank',
        text: 'ANY BATTLE ROUND · End of your turn\n'
            '3 VP: A unit is wholly within your opponent\'s half.\n'
            '5 VP: Two or more units are.',
        awards: [
          {'vp': 3},
          {'vp': 5},
        ]),
    _card('per-objective', 'Area Denial', awards: [
      {'vp_per': 2, 'per': 'controlled-objective'},
    ]),
    _card('forward-position', 'Forward Position', drawn: {
      'operation': 'redraw',
      'battle_round': {'max': 1},
    }),
  ]);

  Widget host(BattleState state, void Function(BattleEvent) onEvent) =>
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SecondaryPanel(state: state, deck: deck, onEvent: onEvent),
          ),
        ),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('drawing puts a card in hand and takes it out of the deck',
      (tester) async {
    tall(tester);
    final events = <BattleEvent>[];
    await tester.pumpWidget(host(const BattleState(), events.add));

    expect(find.text('3 left'), findsOneWidget);
    expect(find.text('No cards in hand.'), findsOneWidget);

    await tester.tap(find.text('Draw'));
    await tester.pump();
    expect(events.single, isA<DrawSecondary>());
  });

  testWidgets('a tactical mission can also pick the card by hand',
      (tester) async {
    // Drawing blind is the rule, but the app records what happened at the
    // table rather than refereeing it: cards get drawn by hand, missed or
    // corrected, and a player who cannot enter the card in front of them
    // stops using the app.
    tall(tester);
    final events = <BattleEvent>[];
    await tester.pumpWidget(host(const BattleState(), events.add));

    expect(find.text('Draw'), findsOneWidget);
    await tester.tap(find.text('Choose'));
    await tester.pumpAndSettle();

    expect(find.text('Choose secondaries'), findsOneWidget);
    // And the full description travels with it, not a three-line clamp.
    expect(
      find.textContaining('settles a rules dispute', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('a card offers the payouts it names, and a discard',
      (tester) async {
    tall(tester);
    final events = <BattleEvent>[];
    final state = const BattleLog(events: [DrawSecondary('outflank')]).state;
    await tester.pumpWidget(host(state, events.add));

    expect(find.text('Outflank'), findsOneWidget);
    // Outflank pays 3 or 5 depending on how well it went, and each figure is
    // on the line that earns it rather than in a row underneath.
    expect(find.text('Score 3'), findsOneWidget);
    expect(find.text('Score 5'), findsOneWidget);
    expect(find.textContaining('Two or more units', findRichText: true),
        findsOneWidget);

    await tester.tap(find.text('Score 5'));
    final scored = events.single as ScoreSecondaryCard;
    expect(scored.cardId, 'outflank');
    expect(scored.vp, 5);
  });

  testWidgets('a per-something card asks instead of guessing', (tester) async {
    tall(tester);
    final events = <BattleEvent>[];
    final state =
        const BattleLog(events: [DrawSecondary('per-objective')]).state;
    await tester.pumpWidget(host(state, events.add));

    // 2 VP per objective is a number only the player can see (§7.6).
    expect(find.text('Score…'), findsOneWidget);
    expect(find.textContaining('Score 2'), findsNothing);

    await tester.tap(find.text('Score…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Score'));
    await tester.pumpAndSettle();

    expect((events.single as ScoreSecondaryCard).cardId, 'per-objective');
  });

  testWidgets('a card drawn too early says so and stays put', (tester) async {
    tall(tester);
    final state =
        const BattleLog(events: [DrawSecondary('forward-position')]).state;
    await tester.pumpWidget(host(state, (_) {}));

    expect(find.textContaining('goes back in the deck'), findsOneWidget);
    // Said, not done: the card is still in hand for the player to discard.
    expect(find.text('Forward Position'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('it lays out on a phone held one-handed', (tester) async {
    // 375pt is the narrowest surface the app targets. Two VP steppers side by
    // side is the tight spot, and a RenderFlex overflow throws in tests.
    tester.view.physicalSize = const Size(375, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = const BattleLog(events: [
      ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 12),
      ScoreVp(side: Player.me, kind: ScoreKind.secondary, round: 1, vp: 8),
      ScoreVp(
          side: Player.opponent, kind: ScoreKind.secondary, round: 1, vp: 11),
      DrawSecondary('outflank'),
    ]).state;

    await tester.pumpWidget(host(state, (_) {}));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('discarding keeps the card out of the deck', (tester) async {
    tall(tester);
    final events = <BattleEvent>[];
    final state = const BattleLog(events: [DrawSecondary('outflank')]).state;
    await tester.pumpWidget(host(state, events.add));

    expect(find.text('2 left'), findsOneWidget, reason: 'one is in hand');
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    // It asks first: the chip sits a finger's width from Score 5 (§7.3.25).
    expect(events, isEmpty);
    expect(find.text('Discard Outflank?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(events.single, isA<DiscardSecondary>());
  });

  testWidgets('cancelling the discard leaves the card in hand', (tester) async {
    tall(tester);
    final events = <BattleEvent>[];
    final state = const BattleLog(events: [DrawSecondary('outflank')]).state;
    await tester.pumpWidget(host(state, events.add));

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(events, isEmpty);
    expect(find.text('Outflank'), findsOneWidget);
  });

  testWidgets('the CP trade asks too, and says what it spends', (tester) async {
    tall(tester);
    final events = <BattleEvent>[];
    final state = const BattleLog(events: [DrawSecondary('outflank')]).state;
    await tester.pumpWidget(host(state, events.add));

    await tester.tap(find.text('Discard for 1 CP'));
    await tester.pumpAndSettle();
    expect(events, isEmpty);
    expect(find.textContaining('once a battle round'), findsNothing);
    expect(find.textContaining('One card a battle round'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Discard for 1 CP'));
    await tester.pumpAndSettle();
    expect((events.single as DiscardSecondary).forCp, isTrue);
  });

  group('the picker edits the hand', () {
    testWidgets('it offers the whole deck, marking hand and discards',
        (tester) async {
      tall(tester);
      final state = const BattleLog(events: [
        DrawSecondary('outflank'),
        DiscardSecondary('per-objective'),
      ]).state;
      await tester.pumpWidget(host(state, (_) {}));

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();

      // All three, not only the one nobody has seen (§7.3.25). Outflank is
      // twice over — the panel underneath still holds it.
      expect(find.text('Outflank'), findsNWidgets(2));
      expect(find.text('Area Denial'), findsOneWidget);
      expect(find.text('Forward Position'), findsOneWidget);

      expect(find.text('in hand'), findsOneWidget);
      expect(find.text('discarded'), findsOneWidget);
      expect(find.text('Close (1 in hand)'), findsOneWidget);
    });

    testWidgets('closing it draws what was added and discards what was not',
        (tester) async {
      tall(tester);
      final events = <BattleEvent>[];
      final state = const BattleLog(events: [
        DrawSecondary('outflank'),
        DiscardSecondary('per-objective'),
      ]).state;
      await tester.pumpWidget(host(state, events.add));

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();

      // Put back a card discarded by mistake, and let go of the held one.
      await tester.tap(find.text('Area Denial'));
      await tester.tap(find.text('Outflank').last);
      await tester.pumpAndSettle();
      expect(find.text('Close (1 in hand)'), findsOneWidget);

      await tester.tap(find.textContaining('Close ('));
      await tester.pumpAndSettle();

      expect(events.length, 2);
      final drawn = events.whereType<DrawSecondary>().single;
      final put = events.whereType<DiscardSecondary>().single;
      expect(drawn.cardId, 'per-objective');
      expect(put.cardId, 'outflank');
      expect(put.forCp, isFalse, reason: 'a correction is not a trade');
    });

    testWidgets('a hand left alone emits nothing', (tester) async {
      // §7.7: opening a sheet and closing it is not a change.
      tall(tester);
      final events = <BattleEvent>[];
      final state = const BattleLog(events: [DrawSecondary('outflank')]).state;
      await tester.pumpWidget(host(state, events.add));

      await tester.tap(find.text('Choose'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Close ('));
      await tester.pumpAndSettle();

      expect(events, isEmpty);
    });
  });
}
