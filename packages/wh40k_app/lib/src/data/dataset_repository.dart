import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// Somewhere bundles can come from (DESIGN.md §3.4).
///
/// The seam exists so the app has **one** code path whether data is baked into
/// the binary, cached on disk or downloaded. Before this, faction data was
/// read straight out of assets and a second faction meant a bigger binary and
/// a store release for every points update.
abstract interface class BundleSource {
  Future<DatasetManifest?> manifest();

  Future<List<int>?> fetch(BundleEntry entry);
}

/// Bundles shipped inside the app. Always present, so the app works on first
/// launch with no network.
class AssetBundleSource implements BundleSource {
  const AssetBundleSource();

  @override
  Future<DatasetManifest?> manifest() async {
    try {
      final raw = await rootBundle.loadString('assets/bundles/manifest.json');
      return DatasetManifest.fromJson(jsonDecode(raw));
    } on FlutterError {
      return null;
    }
  }

  @override
  Future<List<int>?> fetch(BundleEntry entry) async {
    try {
      final data = await rootBundle.load('assets/bundles/${entry.file}');
      return data.buffer.asUint8List();
    } on FlutterError {
      return null;
    }
  }
}

/// Bundles served over HTTP.
///
/// Inert until a base URL is configured — nothing is hosted yet. It exists now
/// so that publishing is a configuration change rather than an architecture
/// one.
class HttpBundleSource implements BundleSource {
  final Uri? baseUrl;
  final HttpClient _client;

  HttpBundleSource(this.baseUrl, {HttpClient? client})
      : _client = client ?? HttpClient();

  bool get isConfigured => baseUrl != null;

  Future<List<int>?> _get(String path) async {
    final base = baseUrl;
    if (base == null) return null;
    try {
      final request = await _client.getUrl(base.resolve(path));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
      }
      return bytes;
    } on Exception {
      return null;
    }
  }

  @override
  Future<DatasetManifest?> manifest() async {
    final bytes = await _get('manifest.json');
    if (bytes == null) return null;
    return DatasetManifest.fromJson(jsonDecode(utf8.decode(bytes)));
  }

  @override
  Future<List<int>?> fetch(BundleEntry entry) => _get(entry.file);
}

/// Downloaded bundles on disk.
class BundleCache {
  final Directory dir;

  BundleCache(this.dir);

  static Future<BundleCache> open() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'datasets'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return BundleCache(dir);
  }

  File _file(BundleEntry entry) => File(p.join(dir.path, entry.file));

  /// Returns the cached bytes only if they hash to what the manifest expects.
  /// A corrupt or superseded file is treated as absent rather than trusted.
  List<int>? read(BundleEntry entry) {
    final file = _file(entry);
    if (!file.existsSync()) return null;
    final bytes = file.readAsBytesSync();
    if (sha256Of(bytes) != entry.sha256) return null;
    return bytes;
  }

  void write(BundleEntry entry, List<int> bytes) =>
      _file(entry).writeAsBytesSync(bytes);

  void clear() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }
}

/// Resolves datasets from cache, then the shipped assets, then the network.
class DatasetRepository {
  final BundleSource assets;
  final BundleSource? remote;
  final BundleCache? cache;

  DatasetManifest? _manifest;
  final Map<String, DatasetBundle> _loaded = {};
  Dataset? _faction;
  MissionPack? _missions;

  DatasetRepository({
    this.assets = const AssetBundleSource(),
    this.remote,
    this.cache,
  });

  /// The manifest in force. Prefers the remote one when reachable, so a
  /// published update is picked up without shipping a build; falls back to
  /// what the binary carries.
  Future<DatasetManifest> manifest() async {
    final cached = _manifest;
    if (cached != null) return cached;

    final fromRemote = await remote?.manifest();
    if (fromRemote != null && !fromRemote.isFuture) {
      return _manifest = fromRemote;
    }

    final fromAssets = await assets.manifest();
    if (fromAssets == null) {
      throw StateError('no dataset manifest in assets or from the network');
    }
    // A manifest from a newer builder is refused rather than half-read.
    if (fromAssets.isFuture) {
      throw StateError(
          'manifest schema ${fromAssets.schema} is newer than this build');
    }
    return _manifest = fromAssets;
  }

  Future<List<BundleEntry>> availableFactions() async =>
      (await manifest()).factions;

  Future<DatasetBundle> bundle(String id) async {
    final loaded = _loaded[id];
    if (loaded != null) return loaded;

    final entry = (await manifest()).entry(id);
    if (entry == null) throw StateError('no bundle "$id" in the manifest');

    final bytes = cache?.read(entry) ??
        await assets.fetch(entry) ??
        await _download(entry);
    if (bytes == null) throw StateError('bundle "$id" is unavailable');

    return _loaded[id] = DatasetBundle.decode(bytes);
  }

  Future<List<int>?> _download(BundleEntry entry) async {
    final bytes = await remote?.fetch(entry);
    if (bytes == null) return null;
    // Verify before caching: a bad download must not become a bad cache.
    if (sha256Of(bytes) != entry.sha256) return null;
    cache?.write(entry, bytes);
    return bytes;
  }

  Future<Dataset> faction(String id) async {
    final cached = _faction;
    if (cached != null && cached.version.factionId == id) return cached;

    final data = await bundle(id);

    // The faction's own record. Sub-factions appear in the file, so the one
    // whose id matches is the one wanted — the same rule `DatasetLoader`
    // applies when reading the snapshot directly.
    final self = data
        .file('factions')
        .map((raw) => raw is Map ? raw : const {})
        .where((j) => j['id']?.toString() == id)
        .firstOrNull;

    // A Space Marine chapter publishes detachments, stratagems and
    // enhancements but no datasheets — a Blood Angels army fields Adeptus
    // Astartes units. The datasheets come from the parent; everything the
    // chapter publishes stays the chapter's own, since its own files already
    // carry the parent's entries plus its own.
    final parentId = self?['parent_faction_id']?.toString();
    final parent = parentId == null ? null : await bundle(parentId);

    List<Object?> file(String name) => data.file(name);
    List<Object?> sheets(String name) {
      final own = data.file(name);
      return own.isEmpty && parent != null ? parent.file(name) : own;
    }

    final faction = FactionData(
      factionId: id,
      // Without these the army rule is dropped on the way through the bundle,
      // and a roster built in the app loses the one rule its whole army has.
      // A chapter keeps *its own* — The Red Thirst, not Oath of Moment.
      factionRuleId: self?['faction_rule_id']?.toString(),
      factionName: self?['name']?.toString(),
      parentFactionId: parentId,
      units: sheets('units').map(SourceUnit.fromJson).toList(),
      weapons: sheets('weapons').map(SourceWeapon.fromJson).toList(),
      detachments: file('detachments').map(SourceDetachment.fromJson).toList(),
      stratagems: file('stratagems').map(SourceStratagem.fromJson).toList(),
      abilities: sheets('abilities').map(SourceAbility.fromJson).toList(),
      phaseMappings:
          sheets('phase-mappings').map(PhaseMapping.fromJson).toList(),
      leaderAttachments:
          sheets('leader-attachments').map(LeaderAttachment.fromJson).toList(),
      enhancementIds: {
        for (final raw in file('enhancements'))
          if (raw is Map && raw['id'] != null) raw['id'].toString(),
      },
      enhancements: file('enhancements')
          .map(SourceEnhancement.fromJson)
          .where((e) => e.id.isNotEmpty)
          .toList(),
      // The builder needs a datasheet's default loadout; nothing else does.
      compositions: sheets('unit-compositions')
          .map(UnitComposition.fromJson)
          .where((c) => c.unitId.isNotEmpty)
          .toList(),
      // The bundle has carried these since the first build and nothing read
      // them, so the editor saw every datasheet as publishing no options at
      // all — which is the permissive path, but for the wrong reason (§4.5).
      wargearOptions: sheets('wargear-options')
          .map(SourceWargearOption.fromJson)
          .where((o) => o.unitId.isNotEmpty)
          .toList(),
      missingFiles: const [],
    );

    return _faction = Dataset.of(faction, revision: data.revision);
  }

  /// A snapshot builder over the bundled faction, for rosters the app builds
  /// rather than imports.
  ///
  /// The play surfaces read a **snapshot**, never the faction dataset (§2.2),
  /// so an edited roster has to be re-snapshotted before it is saved — the
  /// alternative is a list whose datasheets silently change under it at the
  /// next dataset update.
  Future<SnapshotBuilder> snapshotBuilder(String factionId) async {
    final dataset = await faction(factionId);
    final data = await bundle(factionId);
    final core = await bundle('core');

    // The snapshot keeps records in **source form** (§2.2), so it reads the
    // raw bundle rather than the parsed dataset — and therefore has to follow
    // the chapter's parent for datasheets exactly as `faction()` does. Miss
    // this and a Blood Angels roster snapshots with no units in it.
    final parentId = dataset.faction.parentFactionId;
    final parent = parentId == null ? null : await bundle(parentId);

    List<Object?> sheets(String name) {
      final own = data.file(name);
      return own.isEmpty && parent != null ? parent.file(name) : own;
    }

    Map<String, Object?> index(List<Object?> records, {String key = 'id'}) => {
          for (final record in records)
            if (record is Map && record[key] != null)
              record[key].toString(): record,
        };

    return SnapshotBuilder(
      dataset: dataset,
      rawUnits: index(sheets('units')),
      rawWeapons: index(sheets('weapons')),
      rawDetachments: index(data.file('detachments')),
      rawAbilities: index(sheets('abilities'), key: 'ability_id'),
      rawStratagems: {
        ...index(core.file('stratagems')),
        ...index(data.file('stratagems')),
      },
      rawEnhancements: index(data.file('enhancements')),
    );
  }

  Future<MissionPack> missions() async {
    final cached = _missions;
    if (cached != null) return cached;

    final data = await bundle('core');
    return _missions = MissionPack.fromJson(
      dispositions: data.file('force-dispositions'),
      missions: data.file('missions'),
      matchups: data.file('mission-matchups'),
      cards: data.file('secondary-cards'),
      deployments: data.file('deployment-patterns'),
      terrainLayouts: data.file('terrain-layouts'),
      terrainTemplates: data.file('terrain-templates'),
    );
  }
}
