import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
import 'package:wh40k_app/src/screens/battles_screen.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  late AppDatabase db;
  late RosterStore store;
  late Army army;
  late MissionPack pack;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
    pack = await DatasetRepository().missions();
  });

  setUp(() {
    db = AppDatabase.memory();
    store = RosterStore(db);
  });

  tearDown(() => db.close());

  BattleLog played() => const BattleLog(events: [
        ConfigureBattle(MissionSetup(
          myDisposition: 'reconnaissance',
          opponentDisposition: 'take-and-hold',
          myMissionId: 'reconnaissance-sweep',
          opponentMissionId: 'purge-and-secure',
          deploymentId: 'tipping-point',
          opponentName: 'Dave',
        )),
        SetRound(3),
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 10),
        ScoreVp(side: Player.me, kind: ScoreKind.secondary, round: 2, vp: 5),
        ScoreVp(
            side: Player.opponent, kind: ScoreKind.primary, round: 1, vp: 8),
      ]);

  group('finishing a battle', () {
    test('files the record and clears the board in one action', () async {
      // Two halves of one thing: a finished battle left in `battleLogJson`
      // would still be the roster's current game, and the Play tab would open
      // on a game that is over.
      await store.save(army);
      await store.saveBattle(army.id, played());
      expect((await store.loadBattle(army.id)).events, isNotEmpty);

      await store.finishBattle(army, played());

      expect((await store.loadBattle(army.id)).events, isEmpty);
      final records = await store.battles();
      expect(records, hasLength(1));
      expect(records.single.myScore, 15);
      expect(records.single.opponentScore, 8);
      expect(records.single.rounds, 3);
      expect(records.single.opponentName, 'Dave');
    });

    test('keeps the whole log, not a summary of it', () async {
      // The record is the same append-only history it was while being played,
      // so it can be replayed. Storing only the totals would make this page
      // cheap to build and impossible to extend.
      await store.finishBattle(army, played());
      final record = (await store.battles()).single;

      final replayed = BattleLog.fromJson(jsonDecode(record.logJson));
      expect(replayed.events, hasLength(played().events.length));
      expect(replayed.state.setup?.myMissionId, 'reconnaissance-sweep');
      expect(replayed.state.me.primary[1], 10);
      expect(replayed.state.opponent.primary[1], 8);
    });

    test('copies the army name rather than pointing at the roster', () async {
      // A roster can be renamed or deleted afterwards, and a finished battle
      // must not change with it.
      await store.save(army);
      await store.finishBattle(army, played());
      await store.delete(army.id);

      final record = (await store.battles()).single;
      expect(record.rosterName, '2k ret');
      expect(record.factionId, 'tau-empire');
    });

    test('a second battle does not overwrite the first', () async {
      await store.finishBattle(army, played());
      await store.finishBattle(army, played());
      expect(await store.battles(), hasLength(2));
    });
  });

  group('the battles page', () {
    // Driven from a plain list rather than the live stream. A widget test that
    // has to wait on a database stream spends its time proving the stream
    // works, and the spinner it waits behind never lets `pumpAndSettle`
    // finish — which is why the page is split into a pure view.
    Future<void> pump(WidgetTester tester, List<BattleRow>? rows) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BattlesView(rows: rows, pack: pack, onStart: () {}),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('offers to start one when there is no history', (tester) async {
      await pump(tester, const []);
      expect(find.text('Set up battle'), findsOneWidget);
      expect(find.textContaining('Battles you finish are kept here'),
          findsOneWidget);
    });

    testWidgets('lists a finished battle with its result', (tester) async {
      await store.finishBattle(army, played());
      await pump(tester, await store.battles());

      expect(find.text('2k ret vs Dave'), findsOneWidget);
      expect(find.text('15–8'), findsOneWidget);
      // Said outright: two totals side by side still leave the reader doing
      // the subtraction.
      expect(find.text('WON by 7'), findsOneWidget);
      // And starting the next one is still on offer.
      expect(find.text('Set up battle'), findsOneWidget);
    });

    testWidgets('expands to the declarations, the score table and the map',
        (tester) async {
      await store.finishBattle(army, played());
      await pump(tester, await store.battles());

      await tester.tap(find.text('2k ret vs Dave'));
      await tester.pumpAndSettle();

      expect(find.text('DECLARED'), findsOneWidget);
      expect(find.text('Reconnaissance Sweep'), findsOneWidget);
      expect(find.text('Purge and Secure'), findsOneWidget);
      expect(find.text('SCORE BY ROUND'), findsOneWidget);
      expect(find.text('Tipping Point'), findsOneWidget);
    });
  });

  group('a history belongs to one army', () {
    test('battles are filtered to the roster that played them', () async {
      // The page opens on the Play tab of one army. A list mixing in every
      // other army's games answers a question nobody asked there — and two
      // armies of the same faction produce rows that look interchangeable.
      final other = Army.fromSnapshot(
        army.roster.copyWith(name: 'Second list'),
        army.snapshot,
        id: 'r-other',
      );
      await store.save(army);
      await store.save(other);

      await store.finishBattle(army, played());
      await store.finishBattle(other, played());
      await store.finishBattle(other, played());

      expect(await store.battles(), hasLength(3), reason: 'every army');
      expect(await store.battles(rosterId: army.id), hasLength(1));
      expect(
        (await store.battles(rosterId: other.id)).map((r) => r.rosterName),
        ['Second list', 'Second list'],
      );
    });

    test('a copy starts with no history of its own', () async {
      // A copy is a new roster id, so it inherits nothing — which is right:
      // the games were played with the list it was copied from.
      await store.save(army);
      await store.finishBattle(army, played());

      final copy = (await store.duplicate(army.id, name: 'Variant'))!;
      expect(await store.battles(rosterId: copy.id), isEmpty);
      expect(await store.battles(rosterId: army.id), hasLength(1));
    });

    testWidgets('the army name is dropped where it is implied', (tester) async {
      // Repeating the army's own name on every row of its own history says
      // nothing; the opponent is what tells the rows apart.
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await store.finishBattle(army, played());
      final rows = await store.battles();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BattlesView(rows: rows, pack: pack, armyName: '2k ret'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('vs Dave'), findsOneWidget);
      expect(find.text('2k ret vs Dave'), findsNothing);
    });

    testWidgets('and kept where the army has been renamed since',
        (tester) async {
      // A record keeps the name it was *played under*. Once the list is
      // renamed that is the one thing on the row worth saying.
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await store.finishBattle(army, played());
      final rows = await store.battles();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: BattlesView(rows: rows, pack: pack, armyName: 'Renamed list'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('2k ret vs Dave'), findsOneWidget);
    });
  });
}
