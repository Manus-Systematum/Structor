import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/screens/turn_screen.dart';

void main() {
  late Army army;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
  });

  Widget host() => MaterialApp(
        home: Scaffold(body: TurnScreen(army: army)),
      );

  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a rule opens in full on a tap', (tester) async {
    tall(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final chip = find.text('Deep Strike');
    expect(chip, findsWidgets, reason: 'the reference army has Deep Strike');
    await tester.tap(chip.first);
    await tester.pumpAndSettle();

    // The sheet carries the rule's own text, which the chip never showed.
    // findRichText, because RuleText renders spans rather than a plain Text.
    expect(find.textContaining('Deep Strike', findRichText: true),
        findsWidgets);
    expect(find.byType(Scrollable), findsWidgets);
  });

  testWidgets('the whole set is one scroll away', (tester) async {
    tall(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final all = find.textContaining(RegExp(r'^All \d+$'));
    expect(all, findsWidgets,
        reason: 'a unit with more than one rule offers all of them at once');

    await tester.tap(all.first);
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^\d+ rules$')), findsOneWidget);
  });

  // `**bold**` is the convention every other rule surface renders. The single
  // rule sheet printed the asterisks, which is the exact failure RuleText
  // exists to prevent.
  testWidgets('rule markup is rendered, not printed', (tester) async {
    tall(tester);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deep Strike').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('**', findRichText: true), findsNothing);
  });
}
