import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/screens/army_screen.dart';
import 'package:wh40k_app/src/screens/turn_screen.dart';

/// Wraps a screen so it can be pumped without the app's FutureBuilder, whose
/// indeterminate spinner never lets `pumpAndSettle` reach a steady state.
Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late Army army;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
  });

  group('army loads from its snapshot alone', () {
    test('no faction dataset is involved', () {
      // Everything below is served by assets/reference_snapshot.json, which is
      // the same path an imported or QR-scanned list takes (DESIGN.md §6.4).
      expect(army.roster.name, '2k ret');
      expect(army.points, 2000);
      expect(army.combatUnits, hasLength(12));
      expect(army.validation.isLegal, isTrue,
          reason: army.validation.errors.join('\n'));
    });
  });

  testWidgets('the army screen shows points, findings and units',
      (tester) async {
    await tester.pumpWidget(host(ArmyScreen(army: army)));

    expect(find.text('2k ret'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    // Units carry their datasheet names, and an attached unit names both
    // halves. This list fields the same pairing twice, which is legal and
    // shown as-is rather than disambiguated.
    expect(
      find.text('Commander in Enforcer Battlesuit + Crisis Fireknife '
          'Battlesuits'),
      findsNWidgets(2),
    );

    // Informational findings are surfaced, not hidden: these are the two the
    // design predicted for this list.
    expect(find.textContaining('Detachment Point'), findsOneWidget);
    expect(find.textContaining('slots unused'), findsOneWidget);
  });

  testWidgets('the turn page renders phase sections in order', (tester) async {
    await tester.pumpWidget(host(TurnScreen(army: army)));

    for (final phase in ['COMMAND', 'MOVEMENT', 'SHOOTING']) {
      expect(find.text(phase), findsOneWidget);
    }
    expect(find.text('YOUR TURN'), findsOneWidget);
  });

  testWidgets('the shooting section shows the split attack totals',
      (tester) async {
    await tester.pumpWidget(host(TurnScreen(army: army)));

    // The number the table exists for: four Commander pods at BS3+ give 8
    // attacks, six Crisis pods at BS4+ give 12 (§7.3.5).
    expect(find.text('8 atk'), findsWidgets);
    expect(find.text('12 atk'), findsWidgets);
    expect(find.text('3+'), findsWidgets);
    expect(find.text('4+'), findsWidgets);

    // Torrent weapons merge into one auto-hitting pool instead of splitting.
    expect(find.text('10D6 atk'), findsWidgets);
    expect(find.text('auto'), findsWidgets);
  });

  testWidgets('rendered rules appear next to the weapons they modify',
      (tester) async {
    await tester.pumpWidget(host(TurnScreen(army: army)));

    expect(find.textContaining('Fireknife:', findRichText: true), findsWidgets);
    expect(
      find.textContaining('re-roll Hit rolls of 1', findRichText: true),
      findsWidgets,
      reason: 'generated from the structured effect, not transcribed',
    );
  });
}
