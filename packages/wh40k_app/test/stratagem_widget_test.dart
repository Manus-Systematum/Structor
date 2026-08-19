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

    // No heading of its own: the turn page wraps this in a collapsible group
    // already titled STRATAGEMS, and carrying the CP.
    expect(find.text('STRATAGEMS'), findsNothing);
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

    await tester.tap(find.widgetWithText(FilledButton, 'Use').first);
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

    for (final phase in [
      'command',
      'movement',
      'shooting',
      'charge',
      'fight'
    ]) {
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

    await tester.tap(find.widgetWithText(FilledButton, 'Use').first);
    await tester.pumpAndSettle();

    // Listed, not dropped: a unit missing from the picker reads as a bug.
    expect(
      find.text('already used a Stratagem this phase'),
      findsOneWidget,
    );
  });

  testWidgets('the printed text keeps its list of conditions', (tester) async {
    // COMMAND RE-ROLL names the rolls it applies to as a bulleted list. The
    // first version of the merge stripped `<ul><li>` and left
    // `**Advance roll****Charge roll****Damage roll**` — one long line that
    // reads as nothing, in a card you consult mid-turn (§3.12).
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(list(
      state: const BattleState(cp: 3),
      onEvent: (_) {},
    ));
    // Folded until asked for.
    expect(find.textContaining('Advance roll'), findsNothing);
    await tester.tap(find.text('Command Re-roll'));
    await tester.pumpAndSettle();

    final rendered = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .firstWhere((t) => t.contains('Advance roll'));

    expect(rendered, contains('\u2022 Advance roll'));
    expect(rendered, isNot(contains('**')),
        reason: 'markup is applied, not shown');
    for (final line in rendered.split('\n')) {
      expect('\u2022 '.allMatches(line), hasLength(lessThan(2)),
          reason: 'two bullets on one line: $line');
    }
  });
  testWidgets('reading a stratagem does not spend it', (tester) async {
    // The whole row used to be the play action, so opening a card you were
    // only considering spent the CP. Reading one mid-turn is the common act
    // and playing it the rare one — and the rare one is what cannot be undone
    // by tapping again.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final events = <BattleEvent>[];
    await tester.pumpWidget(list(
      state: const BattleState(cp: 3),
      onEvent: events.add,
    ));

    await tester.tap(find.text('Command Re-roll'));
    await tester.pumpAndSettle();

    expect(events, isEmpty, reason: 'no CP spent by reading');
    expect(find.text('Spend 1 CP on which unit?'), findsNothing);
    expect(find.textContaining('Advance roll'), findsWidgets,
        reason: 'the tap opened the card instead');
  });

  testWidgets('an unaffordable stratagem can still be read', (tester) async {
    // Blocked is not hidden (§7.3): the reason is on screen, and the card it
    // refers to has to be readable or the reason is unarguable.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(list(
      state: const BattleState(cp: 0),
      onEvent: (_) {},
    ));

    final use = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Use').first);
    expect(use.onPressed, isNull, reason: 'cannot be played at 0 CP');

    await tester.tap(find.text('Command Re-roll'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Advance roll'), findsWidgets);
  });
}
