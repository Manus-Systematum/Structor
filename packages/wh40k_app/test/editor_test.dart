import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
import 'package:wh40k_app/src/screens/editor_screen.dart';
import 'package:wh40k_app/src/widgets/sheet_header.dart';
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

  testWidgets('a new army starts empty and says what it needs', (tester) async {
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

  testWidgets('the add-unit sheet can be left without adding anything',
      (tester) async {
    // It opens `isScrollControlled`, so it fills the screen: there is no scrim
    // left to tap, and the list swallows the drag that would dismiss it. The
    // close button is the only way out, and it has to stay.
    await open(tester, initial: tau());

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    expect(find.byType(SearchBar), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await settle(tester);

    expect(find.byType(SearchBar), findsNothing);
    expect(find.text('No units yet. Add one to get started.'), findsOneWidget);
  });

  testWidgets('reverting puts the army back, and asks first', (tester) async {
    // Edits are written as they are made, so leaving the screen already keeps
    // them and `Save` did what had happened anyway — while the undo arrow
    // beside it read as a second back button. What was missing is the
    // opposite: putting the army back as it was, which is what you want after
    // an experiment. It throws away work nothing else can recover, so it asks.
    await open(tester, initial: tau());

    // Nothing to revert to yet.
    final before = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Revert changes'));
    expect(before.onPressed, isNull);

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'ghostkeel');
    await settle(tester);
    await tester.tap(find.text('Ghostkeel Battlesuit').last);
    await settle(tester);
    expect(find.text('Ghostkeel Battlesuit'), findsOneWidget);

    await tester.tap(find.text('Revert changes'));
    await settle(tester);
    expect(find.text('Revert changes?'), findsOneWidget);

    // Cancelling keeps the work.
    await tester.tap(find.text('Keep editing'));
    await settle(tester);
    expect(find.text('Ghostkeel Battlesuit'), findsOneWidget);

    await tester.tap(find.text('Revert changes'));
    await settle(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Revert'));
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

    // No Save button: the edit is already written. Leaving is what commits,
    // so the test waits for the autosave rather than pressing anything.
    expect(find.text('Save'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
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

  testWidgets('the picker groups by role and folds', (tester) async {
    await open(tester, initial: tau());
    await tester.tap(find.text('Add unit'));
    await settle(tester);

    // Headings, not a flat 47-datasheet scroll.
    expect(find.text('CHARACTERS'), findsOneWidget);
    expect(find.text('INFANTRY'), findsOneWidget);

    // Folded by default, so the sheet opens on the headings.
    expect(find.text('Commander in Enforcer Battlesuit'), findsNothing);
    await tester.tap(find.text('CHARACTERS'));
    await settle(tester);
    expect(find.text('Commander in Enforcer Battlesuit'), findsWidgets);
  });

  testWidgets('searching flattens the groups', (tester) async {
    // A match behind a fold reads as no match.
    await open(tester, initial: tau());
    await tester.tap(find.text('Add unit'));
    await settle(tester);

    await tester.enterText(find.byType(SearchBar), 'broadside');
    await settle(tester);
    expect(find.text('CHARACTERS'), findsNothing);
    expect(find.text('Broadside Battlesuits'), findsOneWidget);
  });

  testWidgets('a datasheet lists every keyword, not the first two',
      (tester) async {
    // The subtitle took two, so a Canoness read "Infantry · Character" and
    // stopped — GRENADES looked absent when it is on the datasheet.
    await open(tester, initial: tau());
    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'ghostkeel');
    await settle(tester);

    final subtitle = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(ListTile), matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .firstWhere((d) => d.contains('·'));
    expect(subtitle.split(' · ').length, greaterThan(2));
  });

  testWidgets('edits survive leaving without tapping Save', (tester) async {
    // The bug: building an army and backing out lost the lot. Edits are now
    // written as they are made, so leaving keeps them.
    await open(tester, initial: tau());

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'riptide');
    await settle(tester);
    await tester.tap(find.text('Riptide Battlesuit').last);
    await settle(tester);

    // Past the debounce, without touching Save.
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    final rows = await store.list();
    expect(rows, hasLength(1));
    expect(rows.single.unitCount, 1);
  });

  testWidgets('autosave twice leaves one army, not two', (tester) async {
    // The trap in writing as you go: the explicit Save minted a fresh id and
    // the roster appeared twice. Opened with no `initial`, so there is no id
    // to start from and the autosave has to mint one — passing a rosterId
    // here would make this pass without testing anything.
    await open(tester);

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    // A new army defaults to the first faction in the manifest, which is
    // Adepta Sororitas — not the one `open` warms for the other tests.
    await tester.enterText(find.byType(SearchBar), 'canoness');
    await settle(tester);
    await tester.tap(find.text('Canoness').last);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(await store.list(), hasLength(1));

    // Leaving writes once more; the pending autosave must not add a second.
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(await store.list(), hasLength(1));
  });

  testWidgets('an untouched draft is not saved at all', (tester) async {
    // Opening the builder and backing out should not leave an empty
    // "New army" in the list.
    await open(tester, initial: tau());
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(await store.list(), isEmpty);
  });

  testWidgets('editing an existing roster keeps its id', (tester) async {
    await open(tester, initial: tau(name: 'Second company'));

    expect(find.text('Edit army'), findsWidgets);
    // No Save button: the edit is already written, and leaving commits. An
    // untouched draft is still not written at all, so this makes a real edit
    // — the point is that the write reuses the id rather than adding a second
    // copy of the army beside it.
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'ghostkeel');
    await settle(tester);
    await tester.tap(find.text('Ghostkeel Battlesuit').last);
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);

    final rows = await store.list();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'existing');
    expect(rows.single.name, 'Second company');
  });

  testWidgets('a unit can be duplicated from the list itself', (tester) async {
    // Three of the same squad is an ordinary list. The duplicate inside the
    // unit sheet made that four taps.
    await open(tester, initial: tau());

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'ghostkeel');
    await settle(tester);
    await tester.tap(find.text('Ghostkeel Battlesuit').last);
    await settle(tester);
    expect(find.text('Ghostkeel Battlesuit'), findsOneWidget);

    await tester.tap(find.byTooltip('Duplicate'));
    await settle(tester);

    expect(find.text('Ghostkeel Battlesuit'), findsNWidgets(2));
    // The duplicate is a change like any other, so it is revertible.
    final revert = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Revert changes'));
    expect(revert.onPressed, isNotNull);
  });

  testWidgets('the duplicate carries the loadout it was copied from',
      (tester) async {
    await open(tester, initial: tau());

    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'crisis sunforge');
    await settle(tester);
    await tester.tap(find.text('Crisis Sunforge Battlesuits').last);
    await settle(tester);

    final before = tester.widgetList<Text>(find.textContaining('models')).first;
    await tester.tap(find.byTooltip('Duplicate').first);
    await settle(tester);

    final rows = tester
        .widgetList<Text>(find.textContaining('models'))
        .map((t) => t.data)
        .toList();
    expect(rows, hasLength(2));
    expect(rows.first, before.data);
    expect(rows.last, before.data);
  });

  testWidgets('an attached squad is reachable, not just its character',
      (tester) async {
    // A row in the army list is a *combat unit* — the character and the squad
    // it joined — and tapping it opened the character. The squad's loadout,
    // its size and its removal had no route at all from the builder.
    await open(tester, initial: tau());

    Future<void> add(String search, String name) async {
      await tester.tap(find.text('Add unit'));
      await settle(tester);
      await tester.enterText(find.byType(SearchBar), search);
      await settle(tester);
      await tester.tap(find.text(name).last);
      await settle(tester);
    }

    await add('enforcer', 'Commander in Enforcer Battlesuit');
    await add('fireknife', 'Crisis Fireknife Battlesuits');

    // Attach through the character's own sheet, then reopen the row.
    await tester.tap(find.text('Commander in Enforcer Battlesuit').first);
    await settle(tester);
    final attach = find.text('Crisis Fireknife Battlesuits');
    if (attach.evaluate().isNotEmpty) {
      await tester.tap(attach.last);
      await settle(tester);
    }
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    await tester.tap(find.textContaining('Commander in Enforcer').first);
    await settle(tester);

    // The switcher names both halves, and picking the squad shows the squad.
    expect(find.text('THIS COMBAT UNIT'), findsOneWidget);
    // The attach picker further down offers the same name; the switcher
    // sits directly under the header.
    await tester.tap(
        find.widgetWithText(ChoiceChip, 'Crisis Fireknife Battlesuits').first);
    await settle(tester);
    expect(find.widgetWithText(SheetHeader, 'Crisis Fireknife Battlesuits'),
        findsOneWidget);
  });

  testWidgets('a detachment brings its rules and stratagems into the builder',
      (tester) async {
    // Picking a detachment was a decision made from a name and a points cost,
    // with the two things it actually buys a screen away — in a tab that only
    // opens once a battle is set up.
    late Roster roster;
    await tester.runAsync(() async {
      final dataset = await datasets.faction('tau-empire');
      roster = RosterEditor(dataset).addDetachment(tau(), 'retaliation-cadre');
    });
    await open(tester, initial: roster);

    expect(find.text('DETACHMENT RULES'), findsOneWidget);
    expect(find.text('DETACHMENT STRATAGEMS'), findsOneWidget);

    // Folded, so the bodies are not built. An army builder that opens on two
    // walls of rules text has buried the units.
    expect(find.textContaining('CP'), findsNothing);

    await tester.tap(find.text('DETACHMENT STRATAGEMS'));
    await settle(tester);
    expect(find.textContaining('CP'), findsWidgets);
  });

  testWidgets('with no detachment chosen there is nothing to preview',
      (tester) async {
    await open(tester, initial: tau());
    expect(find.text('DETACHMENT RULES'), findsNothing);
    expect(find.text('DETACHMENT STRATAGEMS'), findsNothing);
  });
  group('Legends datasheets', () {
    Future<List<String>> namesIn(WidgetTester tester, Dataset dataset,
        {required bool showLegends}) async {
      tester.view.physicalSize = const Size(500, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AddUnitSheet(dataset: dataset, showLegends: showLegends),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'crusaders');
      await tester.pumpAndSettle();
      return tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .toList();
    }

    testWidgets('are hidden by default', (tester) async {
      // 485 of 1,857 datasheets are shelved out of the tournament pool, and
      // offering them beside the rest makes the picker a third longer with
      // entries most events will not take.
      late Dataset sisters;
      await tester.runAsync(() async {
        sisters = await datasets.faction('adepta-sororitas');
      });
      expect(sisters.unit('crusaders')?.isLegend, isTrue);

      final without = await namesIn(tester, sisters, showLegends: false);
      expect(without.any((n) => n.contains('Crusaders')), isFalse);
    });

    testWidgets('are shown when the setting is on', (tester) async {
      // Hidden, not removed: a Legends game is a real game.
      late Dataset sisters;
      await tester.runAsync(() async {
        sisters = await datasets.faction('adepta-sororitas');
      });
      final with_ = await namesIn(tester, sisters, showLegends: true);
      expect(with_.any((n) => n.contains('Crusaders')), isTrue);
    });
  });
  testWidgets('removing a unit asks first', (tester) async {
    // A unit is a loadout, an attachment and an enhancement chosen one at a
    // time, and Remove sits beside Duplicate where a mis-tap costs all of it.
    await open(tester, initial: tau());
    await tester.tap(find.text('Add unit'));
    await settle(tester);
    await tester.enterText(find.byType(SearchBar), 'ghostkeel');
    await settle(tester);
    await tester.tap(find.text('Ghostkeel Battlesuit').last);
    await settle(tester);

    await tester.tap(find.text('Ghostkeel Battlesuit'));
    await settle(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
    await settle(tester);

    expect(find.text('Remove this unit?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await settle(tester);
    expect(find.text('Ghostkeel Battlesuit'), findsWidgets,
        reason: 'nothing removed before the answer');
  });
}
