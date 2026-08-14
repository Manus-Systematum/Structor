import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/widgets/stratagem_list.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  late Army army;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
  });

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  Widget list({
    required BattleState state,
    required void Function(BattleEvent) onEvent,
    String phase = 'shooting',
  }) =>
      host(StratagemList(
        army: army,
        phase: phase,
        state: state,
        onEvent: onEvent,
      ));

  testWidgets('the section shows this phase, attributed and priced',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(list(
      state: const BattleState(cp: 3),
      onEvent: (_) {},
    ));

    expect(find.text('STRATAGEMS'), findsOneWidget);
    expect(find.text('3 CP'), findsOneWidget);
    // Shouted upstream, title-cased here.
    expect(find.text('Command Re-roll'), findsOneWidget);
    // At two detachments, which one brings it is the thing you need to know.
    expect(find.textContaining('Experimental Prototype Cadre'), findsWidgets);
  });

  testWidgets('an unaffordable stratagem says so instead of vanishing',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(list(
      state: const BattleState(cp: 0),
      onEvent: (_) {},
    ));

    expect(find.text('Command Re-roll'), findsOneWidget);
    expect(find.text('not enough CP'), findsWidgets);
  });

  testWidgets('choosing a target commits the play', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final events = <BattleEvent>[];
    await tester.pumpWidget(list(
      state: const BattleState(cp: 3, round: 2),
      onEvent: events.add,
    ));

    await tester.tap(find.text('Command Re-roll'));
    await tester.pumpAndSettle();

    // The picker lists every combat unit, plus an escape hatch for the
    // stratagems that nominate nothing.
    expect(find.text('Spend 1 CP on which unit?'), findsOneWidget);
    expect(find.text('No specific unit'), findsOneWidget);

    await tester.tap(find.text('No specific unit'));
    await tester.pumpAndSettle();

    final played = events.single as UseStratagem;
    expect(played.stratagemId, 'command-re-roll');
    expect(played.cp, 1);
    expect(played.round, 2, reason: 'the round it was actually played in');
    expect(played.phase, 'shooting');
    expect(played.targetInstanceId, isNull);
  });

  testWidgets('it lays out on a phone held one-handed', (tester) async {
    // 375pt is the narrowest surface the app targets, and the turn page has
    // to stay readable one-handed (§7.3.8). A RenderFlex overflow throws in
    // tests, so this is the check.
    tester.view.physicalSize = const Size(375, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final phase in ['command', 'movement', 'shooting', 'charge',
        'fight']) {
      await tester.pumpWidget(list(
        phase: phase,
        state: const BattleState(cp: 1),
        onEvent: (_) {},
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: phase);
    }
  });

  testWidgets('a unit that already used one is offered with its reason',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = const BattleLog(events: [
      AdjustCp(4),
      UseStratagem(
        stratagemId: 'experimental-ammunition-experimental-prototype-cadre',
        targetInstanceId: 'u01',
        round: 1,
        phase: 'shooting',
        cp: 1,
      ),
    ]).state;

    await tester.pumpWidget(list(state: state, onEvent: (_) {}));

    await tester.tap(find.text('Command Re-roll'));
    await tester.pumpAndSettle();

    // Listed, not dropped: a unit missing from the picker reads as a bug.
    expect(
      find.text('already used a Stratagem this phase'),
      findsOneWidget,
    );
  });
}
