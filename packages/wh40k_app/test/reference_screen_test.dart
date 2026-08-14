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

  testWidgets('it opens on every section, counted', (tester) async {
    await open(tester);
    expect(find.textContaining('DETACHMENT RULES'), findsOneWidget);
    expect(find.textContaining('ENHANCEMENTS & UPGRADES'), findsOneWidget);
    expect(find.textContaining('UNIT ABILITIES'), findsOneWidget);
    // Both detachments contribute a rule.
    expect(find.textContaining('DETACHMENT RULES  ·  2'), findsOneWidget);
  });

  testWidgets('searching narrows across kinds at once', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(SearchBar), 'overwatch');
    await tester.pumpAndSettle();

    expect(find.text('Fire Overwatch'), findsOneWidget);
    expect(find.textContaining('matching'), findsOneWidget);
    // Sections with no match disappear rather than showing an empty heading.
    expect(find.textContaining('DETACHMENT RULES'), findsNothing);
  });

  testWidgets('a search with no hits says so', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(SearchBar), 'lasgun');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches that.'), findsOneWidget);
  });

  testWidgets('clearing the search restores everything', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(SearchBar), 'lasgun');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.textContaining('UNIT ABILITIES'), findsOneWidget);
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

  testWidgets('it lays out on a phone held one-handed', (tester) async {
    tester.view.physicalSize = const Size(375, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ReferenceScreen(army: army))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
