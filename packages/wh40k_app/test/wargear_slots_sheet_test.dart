import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
import 'package:wh40k_app/src/screens/editor_screen.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// The unit sheet's weapon slots and counted swaps (DESIGN.md §4.20).
///
/// The reported bug: an Intercessor Sergeant offered two selectors for one
/// model, and a choice on one Vanguard row showed up on another. These drive
/// the real sheet over the shipped bundles.
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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> openUnit(WidgetTester tester, String factionId, String datasheetId) async {
    tester.view.physicalSize = const Size(500, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late Roster roster;
    late String name;
    await tester.runAsync(() async {
      await datasets.availableFactions();
      final dataset = await datasets.faction(factionId);
      roster = RosterEditor(dataset)
          .addUnit(RosterEditor.blank(name: 'Army', factionId: factionId), datasheetId);
      name = dataset.unit(datasheetId)!.name;
    });
    await tester.pumpWidget(MaterialApp(
      home: EditorScreen(store: store, datasets: datasets, initial: roster, rosterId: 'existing'),
    ));
    await settle(tester);
    await tester.tap(find.text(name).first);
    await settle(tester);
  }

  /// The +/- of the row whose label is [label].
  Finder button(String label, IconData icon) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
        matching: find.byIcon(icon),
      );

  group('Intercessor Squad', () {
    testWidgets('each model is named, and each slot is its own control', (tester) async {
      await openUnit(tester, 'adeptus-astartes', 'intercessor-squad');

      // The model's name leads its block, even with one model per block.
      expect(find.text('Intercessor Sergeant'), findsWidgets);
      expect(find.text('Intercessor'), findsWidgets);

      // Titled by the weapon the Sergeant starts with, not "Weapon 1".
      expect(find.text('Weapon 1'), findsNothing);
      // Five alternatives and four: both menus.
      expect(find.byType(DropdownButton<int>), findsNWidgets(2));

      // A grenade launcher is a counted swap, named by the loadout.
      expect(find.text('Grenade Launcher'), findsOneWidget);

      // And none of the fifteen pairings 40kdc made of the two slots.
      expect(find.textContaining('Plasma pistol + '), findsNothing);
      expect(find.textContaining('Power weapon + '), findsNothing);
    });

    testWidgets('a choice in one slot leaves the other where it was', (tester) async {
      await openUnit(tester, 'adeptus-astartes', 'intercessor-squad');
      final menus = find.byType(DropdownButton<int>);
      int valueOf(int i) => tester.widget<DropdownButton<int>>(menus.at(i)).value!;
      expect(valueOf(0), -1);
      expect(valueOf(1), -1);

      // Power weapon is offered in both slots, which is what let the rows move
      // together.
      await tester.tap(menus.at(0));
      await settle(tester);
      await tester.tap(find.text('Power weapon').last);
      await settle(tester);

      expect(valueOf(0), isNot(-1));
      expect(valueOf(1), -1, reason: 'the second slot changed with the first');
    });
  });

  group('Raptors', () {
    testWidgets('the control follows how many alternatives a slot has', (tester) async {
      await openUnit(tester, 'chaos-space-marines', 'raptors');

      expect(find.text('Raptor Champion'), findsWidgets);
      // One alternative: a switch, saying what it swaps for.
      expect(find.byType(Switch), findsOneWidget);
      expect(find.textContaining('Swap for plasma pistol'), findsOneWidget);
      // Two alternatives: all three options as chips.
      expect(find.widgetWithText(ChoiceChip, 'Accursed weapon'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Heavy melee weapon'), findsOneWidget);
    });

    testWidgets('a squad\'s swaps say how many models have taken one', (tester) async {
      await openUnit(tester, 'chaos-space-marines', 'raptors');

      expect(find.textContaining('Swapped: 0 of '), findsOneWidget);
      // The three special weapons share BSData's "2 selections per 5 models".
      expect(find.textContaining('0 of 4 between them'), findsOneWidget);

      await tester.tap(button('Plasma pistol', Icons.add));
      await settle(tester);
      expect(find.textContaining('Swapped: 1 of '), findsOneWidget);
    });
  });

  group('Stealth Battlesuits', () {
    testWidgets('a limit two controls share is shown when both break it', (tester) async {
      await openUnit(tester, 'tau-empire', 'stealth-battlesuits');
      expect(find.textContaining('limit 2'), findsNothing);

      // Printed: 2 models can each take a fusion blaster. The Shas'vre's slot
      // and two Shas'ui swaps make three.
      await tester.tap(find.byType(Switch).first);
      await settle(tester);
      await tester.tap(button('Fusion blaster', Icons.add));
      await settle(tester);
      await tester.tap(button('Fusion blaster', Icons.add));
      await settle(tester);

      expect(find.text('Fusion blaster: 3, limit 2'), findsOneWidget);
    });
  });
}
