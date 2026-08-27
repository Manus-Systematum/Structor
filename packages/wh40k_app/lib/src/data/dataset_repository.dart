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

  /// By file name rather than by [BundleEntry]: a patch is fetched, cached
  /// and verified exactly like a bundle (§3.15), and it is not one.
  Future<List<int>?> fetch(String file);
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
  Future<List<int>?> fetch(String file) async {
    try {
      final data = await rootBundle.load('assets/bundles/$file');
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
  Future<List<int>?> fetch(String file) => _get(file);
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

  /// Returns the cached bytes only if they hash to what the manifest expects.
  /// A corrupt or superseded file is treated as absent rather than trusted.
  List<int>? read(String file, String sha256) {
    final at = File(p.join(dir.path, file));
    if (!at.existsSync()) return null;
    final bytes = at.readAsBytesSync();
    if (sha256Of(bytes) != sha256) return null;
    return bytes;
  }

  void write(String file, List<int> bytes) =>
      File(p.join(dir.path, file)).writeAsBytesSync(bytes);

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
  PatchSet? _patches;
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

    final bytes = await _bytes(entry.file, entry.sha256);
    if (bytes == null) throw StateError('bundle "$id" is unavailable');

    return _loaded[id] = DatasetBundle.decode(bytes);
  }

  /// Cache, then the shipped assets, then the network — and never bytes that
  /// do not hash to what the manifest says.
  Future<List<int>?> _bytes(String file, String sha256) async {
    final cached = cache?.read(file, sha256);
    if (cached != null) return cached;

    final shipped = await assets.fetch(file);
    if (shipped != null && sha256Of(shipped) == sha256) return shipped;

    final downloaded = await remote?.fetch(file);
    if (downloaded == null) return null;
    // Verify before caching: a bad download must not become a bad cache.
    if (sha256Of(downloaded) != sha256) return null;
    cache?.write(file, downloaded);
    return downloaded;
  }

  /// The corrections in force (§3.15).
  ///
  /// A patch the app cannot fetch is skipped rather than fatal. The bundles
  /// are the data; a patch corrects them, and a correction that did not
  /// arrive leaves the app where it was rather than unable to start.
  Future<PatchSet> patches() async {
    final cached = _patches;
    if (cached != null) return cached;

    final entries = (await manifest()).patches;
    final loaded = <DatasetPatch>[];
    for (final entry in entries) {
      final bytes = await _bytes(entry.file, entry.sha256);
      if (bytes == null) continue;
      try {
        loaded.add(DatasetPatch.decode(bytes));
      } on FormatException {
        continue;
      }
    }
    return _patches = PatchSet(loaded);
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

    // A Space Marine chapter fields its parent's datasheets **and its own**.
    // This used to be a fall-through — the chapter published none, so the
    // parent's were simply used instead. BSData gives Blood Angels twenty-six
    // of their own, and a fall-through then meant a Blood Angels army could
    // field Sanguinary Guard and not an Intercessor Squad (§3.10). The
    // parent's are still not copied into the chapter's bundle: that would add
    // roughly 840 KB across the twelve for data already downloaded.
    final parentId = self?['parent_faction_id']?.toString();
    final parent = parentId == null ? null : await bundle(parentId);

    // Corrections land on the **source records**, before any model has seen
    // them (§3.15), so a patch can set a field this build does not read yet
    // and a later one will. Applied per faction: a chapter's copy of a shared
    // detachment is corrected as the chapter's, not the parent's.
    final corrections = await patches();
    List<Object?> patched(String name, List<Object?> records, String owner) =>
        corrections.apply(records, faction: owner, file: name);

    List<Object?> file(String name) => patched(name, data.file(name), id);
    List<Object?> sheets(String name) => _merge(
          patched(name, data.file(name), id),
          parent == null
              ? const []
              : patched(name, parent.file(name), parentId!),
        );

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

    List<Object?> sheets(String name) =>
        _merge(data.file(name), parent == null ? const [] : parent.file(name));

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

  Map<String, WeaponKeywordText>? _keywords;

  /// What each weapon keyword does, by id.
  ///
  /// From the core bundle rather than the faction's: the keywords are the
  /// game's, not an army's. 40kdc ships them with no text and BSData supplies
  /// it at merge time (§3.14), so a keyword with no entry here is one nothing
  /// published — not an oversight in the app.
  Future<Map<String, WeaponKeywordText>> weaponKeywords() async {
    final cached = _keywords;
    if (cached != null) return cached;

    final data = await bundle('core');
    return _keywords = {
      for (final raw in data.file('weapon-keywords'))
        if (raw is Map)
          if (raw['id']?.toString() case final id?)
            if (raw['text']?.toString() case final text? when text.isNotEmpty)
              id: WeaponKeywordText(
                id: id,
                name: raw['name']?.toString() ?? id,
                text: text,
              ),
    };
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

/// A chapter's own records, plus its parent's that it does not restate.
///
/// The chapter's wins where both name an id: a chapter that republishes a
/// datasheet is saying something about it.
List<Object?> _merge(List<Object?> own, List<Object?> inherited) {
  if (own.isEmpty) return inherited;
  if (inherited.isEmpty) return own;
  String? idOf(Object? raw) {
    final map = raw is Map ? raw : const {};
    return (map['id'] ?? map['ability_id'] ?? map['unit_id'])?.toString();
  }

  final ids = {
    for (final raw in own)
      if (idOf(raw) case final id?) id,
  };
  return [
    ...own,
    for (final raw in inherited)
      if (idOf(raw) case final id?)
        if (!ids.contains(id)) raw,
  ];
}
