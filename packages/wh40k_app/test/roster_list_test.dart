import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
import 'package:wh40k_app/src/screens/editor_screen.dart';
import 'package:wh40k_app/src/screens/roster_list_screen.dart';

void main() {
  late AppDatabase db;
  late RosterStore store;
  late Army reference;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    reference = await Army.loadReference();
  });

  setUp(() {
    db = AppDatabase.memory();
    store = RosterStore(db);
  });

  tearDown(() => db.close());

  Future<List<String>> names(WidgetTester tester) async {
    late List<RosterRow> rows;
    await tester.runAsync(() async => rows = await store.list());
    return rows.map((r) => r.name).toList();
  }

  /// Draws the list from a plain read.
  ///
  /// The view is pumped rather than the screen: a database *stream* in a
  /// widget test leaves a timer pending when the tree is disposed, and the
  /// test then fails on that invariant instead of on what it was checking.
  /// As [open], but with a dataset repository, so the copy can open the
  /// builder rather than stopping at the save.
  Future<void> openWithDatasets(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late List<RosterRow> rows;
    final datasets = DatasetRepository();
    await tester.runAsync(() async {
      await store.save(reference);
      rows = await store.list();
      // Warmed here, as the editor tests do. Reading and inflating a bundle
      // is real I/O and `pump` only advances fake time, so an action that
      // loads one has not finished by the time the test looks at the screen.
      await datasets.snapshotBuilder(reference.roster.factionId);
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RosterListView(
          store: store,
          datasets: datasets,
          rows: rows,
          onOpen: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late List<RosterRow> rows;
    await tester.runAsync(() async {
      await store.save(reference);
      rows = await store.list();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RosterListView(store: store, rows: rows, onOpen: (_) {}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('2k ret'), findsOneWidget);
  }

  /// Lets the real database write behind a tap actually run.
  ///
  /// The tester must not be driven from inside `runAsync` — tapping there
  /// deadlocks the test rather than failing it — so the two are kept apart:
  /// pump for the widget work, a real delay for the database.
  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }

  group('deleting an army', () {
    testWidgets('asks first', (tester) async {
      // Hours of work with no undo behind it.
      await open(tester);
      await openMenu(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete 2k ret?'), findsOneWidget);
      expect(await names(tester), ['2k ret'],
          reason: 'nothing is removed before the answer');
    });

    testWidgets('cancelling keeps it', (tester) async {
      await open(tester);
      await openMenu(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await names(tester), ['2k ret']);
    });

    testWidgets('confirming removes it', (tester) async {
      await open(tester);
      await openMenu(tester);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await flush(tester);

      expect(await names(tester), isEmpty);
    });

    testWidgets('a swipe asks the same question', (tester) async {
      // The swipe is easy to make by accident while scrolling the list.
      await open(tester);
      await tester.drag(find.text('2k ret'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(find.text('Delete 2k ret?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await names(tester), ['2k ret']);
    });
  });

  group('duplicating an army', () {
    testWidgets('offers a name to type over', (tester) async {
      await open(tester);
      await openMenu(tester);
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      expect(
          find.widgetWithText(AlertDialog, 'Duplicate army'), findsOneWidget);
      expect(find.text('2k ret Copy'), findsOneWidget);
    });

    testWidgets('dismissing cancels it', (tester) async {
      await open(tester);
      await openMenu(tester);
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await names(tester), ['2k ret']);
    });

    testWidgets('the typed name is the one it is saved under', (tester) async {
      await open(tester);
      await openMenu(tester);
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Melee variant');
      await tester.tap(find.widgetWithText(FilledButton, 'Duplicate'));
      await flush(tester);

      expect(await names(tester), containsAll(['2k ret', 'Melee variant']));
    });
  });

  testWidgets('a copy opens in the builder', (tester) async {
    // A copy is made to become a variant — the same list with one thing
    // swapped — so the edit is the point of it. Left on the list the reader
    // has two near-identical names and no way to tell which is which.
    await openWithDatasets(tester);
    await openMenu(tester);
    await tester.tap(find.text('Duplicate'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Melee variant');
    await tester.tap(find.widgetWithText(FilledButton, 'Duplicate'));
    await flush(tester);

    expect(find.byType(EditorScreen), findsOneWidget);
    expect(find.text('Melee variant'), findsWidgets);
  });
  group('updating an army to current data', () {
    testWidgets('asks first, and says what does not change', (tester) async {
      // §2.2 freezes a saved list on purpose. Undoing that quietly would
      // re-cost somebody's army the night before a game, so it is asked for
      // and the question says what is at stake.
      await openWithDatasets(tester);
      await openMenu(tester);
      await tester.tap(find.text('Update to current data'));
      await tester.pumpAndSettle();

      expect(find.text('Update 2k ret?'), findsOneWidget);
      expect(find.textContaining('units, loadouts and detachments do not'),
          findsOneWidget);
    });

    testWidgets('cancelling leaves the stored copy alone', (tester) async {
      await openWithDatasets(tester);
      await openMenu(tester);
      await tester.tap(find.text('Update to current data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await flush(tester);

      expect(await names(tester), ['2k ret']);
    });

    testWidgets('confirming reports what it did', (tester) async {
      // Silence after an action the reader asked for reads as nothing having
      // happened, so the result is stated either way.
      await openWithDatasets(tester);
      await openMenu(tester);
      await tester.tap(find.text('Update to current data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Update'));

      // Pumped deliberately rather than settled: `pumpAndSettle` runs past
      // the snack bar's four-second life and dismisses the thing being
      // asserted, which passes or fails on timing.
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Updated.'), findsOneWidget);
      expect(await names(tester), ['2k ret'],
          reason: 'the same army, not a copy');

      // Let it go before teardown, or the pending timer fails the test on an
      // invariant rather than on what it was checking.
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the refreshed army carries stratagems', (tester) async {
      // The reason this exists: an army saved before stratagem text existed
      // shows none in play mode however often the app is updated.
      await openWithDatasets(tester);
      await openMenu(tester);
      await tester.tap(find.text('Update to current data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Update'));
      await flush(tester);

      late Army? reloaded;
      await tester.runAsync(() async {
        final rows = await store.list();
        reloaded = await store.load(rows.single.id);
      });
      expect(reloaded!.snapshot.stratagems, isNotEmpty);
      expect(
        reloaded!.stratagems.stratagems.any((s) => (s.text ?? '').isNotEmpty),
        isTrue,
        reason: 'and the stratagems it carries have their printed text',
      );
    });
  });
}
