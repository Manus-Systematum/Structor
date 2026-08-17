import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
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

      expect(find.widgetWithText(AlertDialog, 'Duplicate army'), findsOneWidget);
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
}
