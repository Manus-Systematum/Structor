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
(FakeSource, DatasetManifest) sourceAt(int cost,
    {String revision = 'r1', int manifestRevision = 0, int schema = 1}) {
  final source = FakeSource();
  final entries = <BundleEntry>[];
  for (final bundle in [_core(), _orks(cost)]) {
    final bytes = bundle.encode();
    final entry = _entry(bundle, bytes);
    source.files[entry.file] = bytes;
    entries.add(entry);
  }
  final manifest = DatasetManifest(
    schema: schema,
    revision: manifestRevision,
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
  // §3.38. "Not from the network" had three causes and the screen named one:
  // a server that answered with older data was reported as unreachable.
  group('why the app stays on its own data', () {
    test('a server that does not answer is unreachable', () async {
      final (built, _) = sourceAt(5, manifestRevision: 20260912193942);
      final result =
          await DatasetRepository(assets: built, remote: FakeSource()).reload();
      expect(result.fromNetwork, isFalse);
      expect(result.stayedBecause, StayedOnBuiltIn.unreachable);
      expect(result.revision, 20260912193942);
    });

    test('a server that answers with older data is not unreachable', () async {
      final (built, _) = sourceAt(8, manifestRevision: 20260912193942);
      final (published, _) = sourceAt(5, manifestRevision: 20260828000000);
      final result =
          await DatasetRepository(assets: built, remote: published).reload();
      expect(result.fromNetwork, isFalse);
      expect(result.stayedBecause, StayedOnBuiltIn.serverOlder,
          reason: 'it answered; its data lost the comparison');
    });

    test('a server this build cannot read says so', () async {
      final (built, _) = sourceAt(8, manifestRevision: 20260912193942);
      final (published, _) =
          sourceAt(5, manifestRevision: 20270101000000, schema: 99);
      final result =
          await DatasetRepository(assets: built, remote: published).reload();
      expect(result.stayedBecause, StayedOnBuiltIn.serverNeedsNewerApp);
    });

    test('and a server whose data is taken leaves no reason', () async {
      final (built, _) = sourceAt(5, manifestRevision: 20260828000000);
      final (published, _) = sourceAt(8, manifestRevision: 20260912193942);
      final result =
          await DatasetRepository(assets: built, remote: published).reload();
      expect(result.fromNetwork, isTrue);
      expect(result.stayedBecause, isNull);
      expect(result.revision, 20260912193942);
    });
  });

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
      expect(result.stayedBecause, isNull);
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
      final (remote, _) = sourceAt(5, manifestRevision: 20260912193942);
      final repo = DatasetRepository(assets: FakeSource(), remote: remote);
      await repo.manifest();

      final result = await repo.reload();
      expect(result.fromNetwork, isTrue);
      expect(result.changed, isEmpty);
      // The manifest's ordering revision, not `generated` — which is the
      // builder's placeholder and read "Dataset local" on the About screen.
      expect(result.revision, 20260912193942);
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

      final (source, _) = sourceAt(5, manifestRevision: 20260828000000);
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
      final (updated, _) =
          sourceAt(cost, revision: 'r2', manifestRevision: 20260912193942);
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

    // The one that was missed: the app picked the update up at launch, so
    // pressing the button downloads nothing — and the saved army is exactly
    // as stale as it was. What is offered is decided by the armies, not by
    // whether bytes moved just now (§3.22).
    testWidgets('an army behind current data is offered it, download or not',
        (tester) async {
      await publish(8);
      await repo.reload();
      await pumpAbout(tester);

      await tester.tap(find.text('Download the current data'));
      await tester.pumpAndSettle();

      expect(find.text('No change. Data from 12 Sep 2026.'), findsOneWidget,
          reason: 'this device already had it');
      expect(find.text('Update Grots?'), findsOneWidget);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      expect((await store.list()).single.points, 8);
    });

    // §3.38. The line that was false: a server that answered, with data older
    // than the app's, was reported as one that could not be reached.
    testWidgets('a server with older data is not called unreachable',
        (tester) async {
      final (built, _) = sourceAt(5, manifestRevision: 20260912193942);
      final (published, _) = sourceAt(5, manifestRevision: 20260828000000);
      repo = DatasetRepository(assets: built, remote: published);
      await pumpAbout(tester);

      await tester.tap(find.text('Download the current data'));
      await tester.pumpAndSettle();

      expect(
          find.text("The app's data is newer than the server's. "
              'Data from 12 Sep 2026.'),
          findsOneWidget);
      expect(find.textContaining('Could not reach'), findsNothing);
    });

    testWidgets('nothing changed asks nothing', (tester) async {
      await pumpAbout(tester);

      await tester.tap(find.text('Download the current data'));
      await tester.pumpAndSettle();

      expect(find.text('No change. Data from 28 Aug 2026.'), findsOneWidget);
      expect(find.text('Update Grots?'), findsNothing);
      expect((await store.list()).single.points, 5);
    });
  });
}
