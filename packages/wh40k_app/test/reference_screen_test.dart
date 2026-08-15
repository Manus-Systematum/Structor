import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/screens/reference_screen.dart';

void main() {
  late Army army;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ReferenceScreen(army: army))),
    );
    await tester.pump();
  }

  group('at rest it files rules by reach', () {
    testWidgets('it opens on the three tiers', (tester) async {
      await open(tester);
      expect(find.textContaining('WHOLE ARMY'), findsOneWidget);
      expect(find.textContaining('SHARED RULES'), findsOneWidget);
      expect(find.textContaining('ONLY THIS UNIT'), findsOneWidget);
      // The flat sections belong to search now.
      expect(find.textContaining('UNIT ABILITIES'), findsNothing);
    });

    testWidgets('the army rule leads the whole-army tier', (tester) async {
      await open(tester);
      // Nothing read factions.json before, so this is the rule the page could
      // not previously show at all.
      expect(find.text('For the Greater Good'), findsOneWidget);
      // Both detachments contribute a rule under it.
      expect(find.text('Expert Fieldcraft'), findsOneWidget);
      expect(find.text('Superior Craftsmanship'), findsOneWidget);
    });

    testWidgets('a keyword every unit has is stated, not columned',
        (tester) async {
      await open(tester);
      // Every datasheet in the reference list is a Battlesuit, so a column
      // would be solid down its whole length.
      expect(find.textContaining('Every unit: Battlesuit'), findsOneWidget);
    });

    testWidgets('a rule several units share becomes a column', (tester) async {
      await open(tester);
      expect(find.text('Deep Strike'), findsWidgets);
      expect(find.text('Gun Drone'), findsWidgets);
    });

    testWidgets('a rule one unit has is printed under that unit',
        (tester) async {
      await open(tester);
      // Nova Charge belongs to the Riptide alone, so it is not a column and
      // needs no owner named beside it.
      expect(
        find.textContaining('Nova Charge', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('the plural duplicate is gone', (tester) async {
      await open(tester);
      // Battlesuit Support System(s) was one rule under two ids, which split
      // it across two tiers. The alias merged it into a shared column.
      expect(find.text('Battlesuit Support Systems'), findsNothing);
      expect(
        army.armyRules.columns
            .where((c) => c.name == 'Battlesuit Support System'),
        hasLength(1),
      );
    });
  });

  group('tracing a dot back to its headings', () {
    testWidgets('tapping a rule names it and lists who has it',
        (tester) async {
      await open(tester);
      expect(find.textContaining('Tap a rule or a unit'), findsOneWidget);

      await tester.tap(find.text('Shield Drone').first);
      await tester.pumpAndSettle();

      expect(find.textContaining('Tap a rule or a unit'), findsNothing);
      expect(find.textContaining('+1 Wound'), findsWidgets);
      expect(
        find.textContaining('Commander in Enforcer Battlesuit'),
        findsWidgets,
      );
    });

    testWidgets('tapping the same rule twice clears it', (tester) async {
      await open(tester);
      await tester.tap(find.text('Shield Drone').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shield Drone').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Tap a rule or a unit'), findsOneWidget);
    });

    testWidgets('tapping a unit lists the shared rules it has',
        (tester) async {
      await open(tester);
      await tester.tap(find.text('Ghostkeel Battlesuit').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ghostkeel Battlesuit:', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('searching still crosses every kind at once', () {
    testWidgets('searching narrows across kinds', (tester) async {
      await open(tester);

      await tester.enterText(find.byType(SearchBar), 'overwatch');
      await tester.pumpAndSettle();

      expect(find.text('Fire Overwatch'), findsOneWidget);
      expect(find.textContaining('matching'), findsOneWidget);
      // Sections with no match disappear rather than showing an empty heading.
      expect(find.textContaining('DETACHMENT RULES'), findsNothing);
      // And the tiers step aside while a query is live.
      expect(find.textContaining('WHOLE ARMY'), findsNothing);
    });

    testWidgets('a search with no hits says so', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(SearchBar), 'lasgun');
      await tester.pumpAndSettle();
      expect(find.text('Nothing matches that.'), findsOneWidget);
    });

    testWidgets('clearing the search restores the tiers', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(SearchBar), 'lasgun');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.textContaining('WHOLE ARMY'), findsOneWidget);
    });

    testWidgets('it says what it cannot tell you', (tester) async {
      await open(tester);
      await tester.enterText(find.byType(SearchBar), 'negation');
      await tester.pumpAndSettle();

      // The provenance note is the honest half of §7.6: core rules are absent
      // because the app has no licence to reproduce them.
      expect(
        find.textContaining('no licence to', findRichText: true),
        findsOneWidget,
      );
    });
  });

  testWidgets('a grid wider than the phone scrolls sideways, not the page',
      (tester) async {
    tester.view.physicalSize = const Size(375, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ReferenceScreen(army: army))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Twelve shared rules do not fit beside a unit name on a 375pt phone, so
    // the grid carries its own horizontal scroller rather than truncating.
    final horizontal = find.byWidgetPredicate((w) =>
        w is SingleChildScrollView && w.scrollDirection == Axis.horizontal);
    expect(horizontal, findsWidgets);

    await tester.drag(horizontal.first, const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
