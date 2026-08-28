import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/database.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/data/roster_store.dart';
import 'package:wh40k_app/src/screens/about_screen.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// Downloading the current data, and offering it to the saved armies (§3.20).
///
/// Everything here is served from fakes rather than the shipped assets: a
/// widget test's clock is fake, so real asset I/O started by a tap never
/// finishes inside it.
class FakeSource implements BundleSource {
  DatasetManifest? manifestValue;
  final Map<String, List<int>> files = {};

  @override
  Future<DatasetManifest?> manifest() async => manifestValue;

  @override
  Future<List<int>?> fetch(String file) async => files[file];
}

DatasetBundle _core() => const DatasetBundle(
      id: 'core',
      kind: BundleKind.core,
      revision: 'r1',
      files: {},
    );

/// One faction, one datasheet, at whatever a Grot costs today.
DatasetBundle _orks(int cost) => DatasetBundle(
      id: 'orks',
      kind: BundleKind.faction,
      revision: 'r1',
      files: {
        'factions': [
          {'id': 'orks', 'name': 'Orks'},
        ],
        'units': [
          {
            'id': 'grot',
            'name': 'Grot',
            'role': 'battleline',
            'points': [
              {'models': 1, 'cost': cost},
            ],
          },
        ],
      },
    );

BundleEntry _entry(DatasetBundle bundle, List<int> bytes) => BundleEntry(
      id: bundle.id,
      kind: bundle.kind,
      name: bundle.id,
      // Content-named, as published (§3.19).
      file: '${bundle.id}.${sha256Of(bytes).substring(0, 12)}.json.gz',
      sha256: sha256Of(bytes),
      bytes: bytes.length,
      revision: bundle.revision,
    );

/// A source serving a core bundle and an Orks bundle at [cost] a Grot.
(FakeSource, DatasetManifest) sourceAt(int cost, {String revision = 'r1'}) {
  final source = FakeSource();
  final entries = <BundleEntry>[];
  for (final bundle in [_core(), _orks(cost)]) {
    final bytes = bundle.encode();
    final entry = _entry(bundle, bytes);
    source.files[entry.file] = bytes;
    entries.add(entry);
  }
  final manifest = DatasetManifest(
    generated: revision,
    source: 'test',
    bundles: entries,
  );
  source.manifestValue = manifest;
  return (source, manifest);
}

const _roster = Roster(
  name: 'Grots',
  factionId: 'orks',
  battleSizeId: 'strike-force',
  units: [RosterUnit(instanceId: 'u1', datasheetId: 'grot', models: 1)],
);

void main() {
  group('reload', () {
    test('says what changed, and the app is on the new bytes', () async {
      final (remote, _) = sourceAt(5);
      final repo = DatasetRepository(assets: FakeSource(), remote: remote);
      expect((await repo.faction('orks')).faction.units.single.points.single.cost, 5);

      // A correction is published. Same names for what did not change; a new
      // name for what did.
      final (updated, _) = sourceAt(8, revision: 'r2');
      remote
        ..manifestValue = updated.manifestValue
        ..files.addAll(updated.files);

      final result = await repo.reload();
      expect(result.fromNetwork, isTrue);
      expect(result.revision, 'r2');
      expect(result.changed, ['orks'], reason: 'core is byte-identical');
      expect(result.unavailable, isEmpty);

      expect((await repo.faction('orks')).faction.units.single.points.single.cost, 8,
          reason: 'reloaded, not just re-listed');
    });

    test('an unreachable server is said plainly, not reported as current',
        () async {
      final (assets, _) = sourceAt(5);
      final repo = DatasetRepository(assets: assets, remote: FakeSource());

      final result = await repo.reload();
      expect(result.fromNetwork, isFalse);
      expect(result.changed, isEmpty);
    });

    test('a file nothing can serve is named', () async {
      final (remote, manifest) = sourceAt(5);
      remote.files.remove(manifest.bundles.last.file);
      final repo = DatasetRepository(assets: FakeSource(), remote: remote);

      final result = await repo.reload();
      expect(result.unavailable, ['orks']);
    });

    test('nothing changed still reports the revision', () async {
      final (remote, _) = sourceAt(5);
      final repo = DatasetRepository(assets: FakeSource(), remote: remote);
      await repo.manifest();

      final result = await repo.reload();
      expect(result.fromNetwork, isTrue);
      expect(result.changed, isEmpty);
      expect(result.revision, 'r1');
    });
  });

  group('the saved armies are offered the new data', () {
    late AppDatabase db;
    late RosterStore store;
    late FakeSource remote;
    late DatasetRepository repo;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      db = AppDatabase.memory();
      store = RosterStore(db);

      final (source, _) = sourceAt(5);
      remote = source;
      repo = DatasetRepository(assets: FakeSource(), remote: remote);

      // A saved army at the old points, snapshotted the way the builder does.
      final builder = await repo.snapshotBuilder('orks');
      await store.save(
          Army.fromSnapshot(_roster, builder.build(_roster), id: 'a1'));
      expect((await store.list()).single.points, 5);
    });

    tearDown(() => db.close());

    Future<void> publish(int cost) async {
      final (updated, _) = sourceAt(cost, revision: 'r2');
      remote
        ..manifestValue = updated.manifestValue
        ..files.addAll(updated.files);
    }

    Future<void> pumpAbout(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          MaterialApp(home: AboutScreen(datasets: repo, store: store)));
      await tester.pumpAndSettle();
    }

    testWidgets('accepting rebuilds every saved army against it',
        (tester) async {
      await publish(8);
      await pumpAbout(tester);

      await tester.tap(find.text('Download the current data'));
      await tester.pumpAndSettle();

      expect(find.text('1 updated: orks.'), findsOneWidget);
      expect(find.text('Update Grots?'), findsOneWidget,
          reason: 'asked, not done — a saved army stops moving on purpose');

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      final row = (await store.list()).single;
      expect(row.points, 8, reason: 'one Grot, now at 8');
      expect(find.textContaining('1 updated. 1 changed points'),
          findsOneWidget);
    });

    testWidgets('declining leaves the army exactly as it was', (tester) async {
      await publish(8);
      await pumpAbout(tester);

      await tester.tap(find.text('Download the current data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect((await store.list()).single.points, 5);
      // The data itself did move, which is what the button was for.
      expect((await repo.faction('orks')).faction.units.single.points.single.cost, 8);
    });

    testWidgets('nothing changed asks nothing', (tester) async {
      await pumpAbout(tester);

      await tester.tap(find.text('Download the current data'));
      await tester.pumpAndSettle();

      expect(find.text('No change. Dataset r1.'), findsOneWidget);
      expect(find.text('Update Grots?'), findsNothing);
      expect((await store.list()).single.points, 5);
    });
  });
}
