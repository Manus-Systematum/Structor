import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// An in-memory source, so resolution order can be tested without a server.
class FakeSource implements BundleSource {
  DatasetManifest? manifestValue;
  final Map<String, List<int>> files = {};
  int fetches = 0;

  @override
  Future<DatasetManifest?> manifest() async => manifestValue;

  @override
  Future<List<int>?> fetch(String file) async {
    fetches++;
    return files[file];
  }
}

DatasetBundle bundleOf(String id, {String revision = 'r1'}) => DatasetBundle(
      id: id,
      kind: id == 'core' ? BundleKind.core : BundleKind.faction,
      revision: revision,
      files: {
        'units': [
          {
            'id': 'grot',
            'name': 'Grot',
            'points': [
              {'models': 1, 'cost': 5},
            ]
          },
        ],
      },
    );

(FakeSource, DatasetManifest) sourceWith(DatasetBundle bundle) {
  final source = FakeSource();
  final bytes = bundle.encode();
  final entry = BundleEntry(
    id: bundle.id,
    kind: bundle.kind,
    name: bundle.id,
    file: '${bundle.id}.json.gz',
    sha256: sha256Of(bytes),
    bytes: bytes.length,
    revision: bundle.revision,
  );
  source.files[entry.file] = bytes;
  final manifest = DatasetManifest(
    generated: 'test',
    source: 'test',
    bundles: [entry],
  );
  source.manifestValue = manifest;
  return (source, manifest);
}

void main() {
  test('bundles round trip through gzip', () {
    final bundle = bundleOf('orks');
    final decoded = DatasetBundle.decode(bundle.encode());
    expect(decoded.id, 'orks');
    expect(decoded.revision, 'r1');
    expect(decoded.file('units'), hasLength(1));
    expect(decoded.file('missing'), isEmpty);
  });

  test('gzip earns its place on a real bundle', () async {
    // Measured on real data, not a fixture: on a few hundred bytes gzip's
    // header costs more than it saves, which is exactly why the loose JSON
    // assets this replaced were several times the size in the binary.
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = DatasetRepository();
    final entry = (await repo.manifest()).entry('tau-empire')!;
    final bundle = await repo.bundle('tau-empire');

    final uncompressed = jsonEncode(bundle.toJson()).length;
    expect(entry.bytes, lessThan(uncompressed ~/ 5),
        reason: 'compressed to under a fifth: '
            '\${entry.bytes} vs \$uncompressed bytes');
  });

  test('the shipped bundles serve the app offline', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = DatasetRepository();
    final manifest = await repo.manifest();

    expect(manifest.schema, bundleSchemaVersion);
    expect(manifest.factions.map((f) => f.id), contains('tau-empire'));

    final dataset = await repo.faction('tau-empire');
    expect(dataset.unit('crisis-fireknife-battlesuits'), isNotNull);

    final pack = await repo.missions();
    expect(pack.matchups, hasLength(25));
  });

  group('resolution order', () {
    test('a remote manifest wins over the shipped one', () async {
      final (remote, manifest) = sourceWith(bundleOf('orks', revision: 'r2'));
      final assets = FakeSource()
        ..manifestValue = const DatasetManifest(
            generated: 'old', source: 'test', bundles: []);

      final repo = DatasetRepository(assets: assets, remote: remote);
      expect((await repo.manifest()).generated, manifest.generated);
      expect((await repo.bundle('orks')).revision, 'r2');
    });

    test('the shipped manifest is used when the network is down', () async {
      final (assets, _) = sourceWith(bundleOf('orks'));
      final repo = DatasetRepository(assets: assets, remote: FakeSource());
      expect((await repo.bundle('orks')).id, 'orks');
    });

    test('a manifest from a newer builder is refused, not half-read', () async {
      final assets = FakeSource()
        ..manifestValue = const DatasetManifest(
            schema: bundleSchemaVersion + 1,
            generated: 'future',
            source: 'test',
            bundles: []);
      final repo = DatasetRepository(assets: assets);
      expect(repo.manifest(), throwsStateError);
    });

    test('an unknown bundle id fails loudly', () async {
      final (assets, _) = sourceWith(bundleOf('orks'));
      final repo = DatasetRepository(assets: assets);
      expect(repo.bundle('tyranids'), throwsStateError);
    });
  });

  group('cache', () {
    late Directory dir;
    late BundleCache cache;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('bundles');
      cache = BundleCache(dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('a verified download is cached and reused', () async {
      final (remote, manifest) = sourceWith(bundleOf('orks'));
      final repo = DatasetRepository(
        assets: FakeSource(),
        remote: remote,
        cache: cache,
      );

      expect((await repo.bundle('orks')).id, 'orks');
      expect(remote.fetches, 1);
      expect(
          cache.read(
              manifest.bundles.single.file, manifest.bundles.single.sha256),
          isNotNull);

      // A second repository reads the cache instead of the network.
      final second = DatasetRepository(
        assets: FakeSource()..manifestValue = manifest,
        remote: remote,
        cache: cache,
      );
      await second.bundle('orks');
      expect(remote.fetches, 1, reason: 'served from cache');
    });

    test('a corrupt cache entry is ignored rather than trusted', () async {
      final (remote, manifest) = sourceWith(bundleOf('orks'));
      final entry = manifest.bundles.single;
      cache.write(entry.file, [1, 2, 3]);

      expect(cache.read(entry.file, entry.sha256), isNull,
          reason: 'hash mismatch');

      final repo = DatasetRepository(
        assets: FakeSource()..manifestValue = manifest,
        remote: remote,
        cache: cache,
      );
      expect((await repo.bundle('orks')).id, 'orks',
          reason: 'falls through to the network and re-caches');
    });

    test('a download that fails its hash is not cached', () async {
      final (remote, manifest) = sourceWith(bundleOf('orks'));
      final entry = manifest.bundles.single;
      remote.files[entry.file] = [9, 9, 9];

      final repo = DatasetRepository(
        assets: FakeSource()..manifestValue = manifest,
        remote: remote,
        cache: cache,
      );
      expect(repo.bundle('orks'), throwsStateError);
      expect(cache.read(entry.file, entry.sha256), isNull);
    });
  });
}
