import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
import 'package:wh40k_app/src/screens/editor_screen.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  late AppDatabase db;
  late RosterStore store;
  late DatasetRepository datasets;

  setUpAll(() => TestWidgetsFlutterBinding.ensureInitialized());

  setUp(() {
    db = AppDatabase.memory();
    store = RosterStore(db);
    datasets = DatasetRepository();
  });

  tearDown(() => db.close());

  /// Pumps until the faction bundle has loaded.
  ///
  /// `pumpAndSettle` cannot be used while the loading spinner is up — an
  /// indeterminate `CircularProgressIndicator` never reaches a steady state,
  /// so it times out rather than waiting for the bundle.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    // Bounded pumping only. Something on this screen animates indefinitely,
    // so `pumpAndSettle` would time out rather than reach a steady state.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Starts on T'au, which is the faction the fixtures and corrections cover.
  Roster tau({String name = 'New army'}) =>
      RosterEditor.blank(name: name, factionId: 'tau-empire');

  Future<void> open(WidgetTester tester, {Roster? initial}) async {
    tester.view.physicalSize = const Size(500, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Warm the repository first. Reading and inflating a bundle is real async
    // I/O, and `pump` only advances fake time — without this the screen is
    // still showing its spinner when the test starts tapping.
    await tester.runAsync(() async {
      await datasets.availableFactions();
      await datasets.faction(initial?.factionId ?? 'adeptus-astartes');
    });

    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(
        store: store,
        datasets: datasets,
        initial: initial,
        rosterId: initial == null ? null : 'existing',
      ),
    ));
    await settle(tester);
  }

  testWidgets('a new army starts empty and says what it needs',
      (tester) async {
    await open(tester);

    expect(find.text('New army'), findsWidgets);
    expect(find.text('No units yet. Add one to get started.'), findsOneWidget);
    // The validator runs live and never gates (§2.3).
    expect(find.byIcon(Icons.error_outline), findsWidgets);
  });

  testWidgets('adding a datasheet puts it in the list with its points',
      (tester) async {
    await open(tester, initial: tau());

    await tester.tap(find.text('Add unit'));
    await settle(tester);

    await tester.enterText(find.byType(SearchBar), 'broadside');
    await settle(tester);
    await tester.tap(find.text('Broadside Battlesuits').last);
    await settle(tester);

    expect(find.text('Broadside Battlesuits'), findsOneWidget);
    // Arrived at its smallest legal size with a default loadout, so it costs
    // something the moment it lands.
    expect(find.textContaining('1 models'), findsOneWidget);
  });

  testWidgets('undo puts the army back', (tester) async {
    await open(tester, initial: tau());

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'ghostkeel');
    await settle(tester);
    await tester.tap(find.text('Ghostkeel Battlesuit').last);
    await settle(tester);
    expect(find.text('Ghostkeel Battlesuit'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo));
    await settle(tester);
    expect(find.text('No units yet. Add one to get started.'), findsOneWidget);
  });

  testWidgets('a detachment can be added and unlocks its enhancements',
      (tester) async {
    await open(tester, initial: tau());

    // The validator says what is missing before anything is chosen.
    expect(find.text('No detachment selected.'), findsOneWidget);

    await tester.tap(find.textContaining('Retaliation Cadre'));
    await settle(tester);

    // …and stops saying it once one is. Retaliation Cadre is 3 DP, which is
    // the whole Strike Force budget, so nothing is left unspent either.
    expect(find.text('No detachment selected.'), findsNothing);
    expect(find.textContaining('Detachment Point(s) unspent'), findsNothing);
  });

  testWidgets('the editor saves a buildable army', (tester) async {
    await open(tester, initial: tau());

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'riptide');
    await settle(tester);
    await tester.tap(find.text('Riptide Battlesuit').last);
    await settle(tester);

    await tester.tap(find.text('Save'));
    await settle(tester);

    final rows = await store.list();
    expect(rows, hasLength(1));
    expect(rows.single.unitCount, 1);
    expect(rows.single.points, greaterThan(0));

    // Saved with a snapshot, so the list renders without the faction dataset.
    final army = await store.load(rows.single.id);
    expect(army, isNotNull);
    expect(army!.combatUnits.single.label, 'Riptide Battlesuit');
    expect(army.snapshot.units, isNotEmpty);
  });

  testWidgets('editing an existing roster keeps its id', (tester) async {
    await open(tester, initial: tau(name: 'Second company'));

    expect(find.text('Edit army'), findsWidgets);
    await tester.tap(find.text('Save'));
    await settle(tester);

    final rows = await store.list();
    expect(rows.single.id, 'existing');
    expect(rows.single.name, 'Second company');
  });
}
