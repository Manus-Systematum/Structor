/// Builds distributable dataset bundles from a 40kdc snapshot (DESIGN.md §3.4).
///
///     dart run bin/bundle.dart [--data <dir>] [--out <dir>] [--revision <rev>]
///
/// Writes one gzipped bundle per faction plus a shared core bundle, and a
/// manifest listing them with sizes and SHA-256 hashes. The output directory
/// is a complete static site: copy it to Pages, a Release or a bucket.
library;

import 'dart:convert';
import 'dart:io';

import 'package:wh40k_core/wh40k_core.dart';

const _coreFiles = [
  'force-dispositions',
  'missions',
  'mission-matchups',
  'secondary-cards',
  'deployment-patterns',
  // The competitive terrain layouts and the piece shapes they place. ~21 KB
  // gzipped together, against a 10 KB core bundle — the layouts are what turn
  // the deployment diagram from a picture of two zones into the actual table.
  'terrain-layouts',
  'terrain-templates',
  'weapon-keywords',
  'unit-keywords',
  'stratagems',
];

const _factionFiles = [
  // The faction's own record: its display name, its army rule, and the
  // aliases the importer matches an export's faction line against. Bundling
  // it was overlooked, so `factionRuleId` arrived null in the app and every
  // roster built or imported there lost For the Greater Good / Oath of
  // Moment — while the CLI, which reads the snapshot directly, kept it.
  'factions',
  'units',
  'weapons',
  'wargear',
  'wargear-options',
  'unit-compositions',
  'detachments',
  'enhancements',
  'leader-attachments',
  'stratagems',
];

const _enrichmentFiles = ['abilities', 'phase-mappings'];

void main(List<String> args) {
  var dataDir = '../../data/40kdc';
  var outDir = '../../dist';
  var revision = 'local';
  var correctionsPath = '../../data-corrections.yaml';

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--data':
        if (i + 1 < args.length) dataDir = args[++i];
      case '--out':
        if (i + 1 < args.length) outDir = args[++i];
      case '--revision':
        if (i + 1 < args.length) revision = args[++i];
      case '--corrections':
        if (i + 1 < args.length) correctionsPath = args[++i];
      case '-h':
      case '--help':
        stdout.writeln('usage: dart run bin/bundle.dart '
            '[--data <dir>] [--out <dir>] [--revision <rev>] '
            '[--corrections <file>]');
        return;
    }
  }

  final loader = DatasetLoader(
    dataDir,
    corrections: DatasetLoader.correctionsAt(correctionsPath),
  );
  if (!loader.root.existsSync()) {
    stderr.writeln('no snapshot at $dataDir - run tools/fetch-40kdc.sh first');
    exit(2);
  }

  final out = Directory(outDir);
  if (!out.existsSync()) out.createSync(recursive: true);

  List<Object?> read(String path) {
    final file = File('$dataDir/$path.json');
    if (!file.existsSync()) return const [];
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is List ? decoded : const [];
  }

  final entries = <BundleEntry>[];
  final correctionNotes = <String>[];
  final staleCorrections = <String>[];
  final appliedCorrections = <Correction>[];

  BundleEntry write(DatasetBundle bundle, String displayName,
      {String? parentId, List<String> aliases = const []}) {
    final compressed = bundle.encode();
    final file = '${bundle.id}.json.gz';
    File('$outDir/$file').writeAsBytesSync(compressed);
    return BundleEntry(
      id: bundle.id,
      kind: bundle.kind,
      name: displayName,
      file: file,
      sha256: sha256Of(compressed),
      bytes: compressed.length,
      revision: bundle.revision,
      parentId: parentId,
      aliases: aliases,
    );
  }

  stdout.writeln('bundling from $dataDir\n');

  entries.add(write(
    DatasetBundle(
      id: 'core',
      kind: BundleKind.core,
      revision: revision,
      files: {for (final f in _coreFiles) f: read('core/$f')},
    ),
    'Core rules data',
  ));

  for (final factionId in loader.availableFactions()) {
    final files = <String, List<Object?>>{
      for (final f in _factionFiles) f: read('core/$factionId/$f'),
      for (final f in _enrichmentFiles) f: read('enrichment/$factionId/$f'),
    };

    for (final corrected in [
      loader.correctedAbilities(factionId),
      loader.correctedUnits(factionId),
      loader.correctedWeapons(factionId),
    ]) {
      for (final c in corrected.applied) {
        correctionNotes.add('$factionId/${c.subject}');
        appliedCorrections.add(c);
      }
      for (final c in corrected.unmatched) {
        staleCorrections.add('$factionId/${c.subject}');
      }
    }
    files['abilities'] = loader.correctedAbilities(factionId).records;
    files['units'] = loader.correctedUnits(factionId).records;
    files['weapons'] = loader.correctedWeapons(factionId).records;

    final self = files['factions']!
        .whereType<Map<String, Object?>>()
        .where((j) => j['id']?.toString() == factionId)
        .firstOrNull;
    final displayName = self?['name']?.toString();
    final parentId = self?['parent_faction_id']?.toString();

    // No datasheets and no parent is a faction that cannot field an army —
    // an upstream stub rather than something to offer in the picker. With a
    // parent it is a chapter, whose datasheets are the parent's.
    if (files['units']!.isEmpty && parentId == null) {
      stdout.writeln('  skip $factionId (no units, no parent)');
      continue;
    }
    // The faction's published name — `T’au Empire`, not the `Tau Empire` that
    // title-casing the id produces. Falls back to the id when the record is
    // absent, so a faction still lists rather than vanishing.
    entries.add(write(
      DatasetBundle(
        id: factionId,
        kind: BundleKind.faction,
        revision: revision,
        files: files,
      ),
      displayName == null || displayName.isEmpty
          ? _title(factionId)
          : displayName,
      parentId: parentId,
      aliases: [
        for (final a in (self?['aliases'] as List? ?? const []))
          if (a != null && a.toString().isNotEmpty) a.toString(),
      ],
    ));
  }

  final manifest = DatasetManifest(
    // Stamped by the caller rather than read from the clock, so a rebuild of
    // the same revision produces byte-identical bundles.
    generated: revision,
    source: '40kdc-data',
    bundles: entries,
  );
  File('$outDir/manifest.json')
      .writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n');

  var total = 0;
  for (final entry in entries) {
    total += entry.bytes;
    stdout.writeln('  ${entry.file.padRight(34)} '
        '${_kb(entry.bytes).padLeft(8)}  ${entry.sha256.substring(0, 12)}');
  }
  stdout
    ..writeln()
    ..writeln('${entries.length} bundles, ${_kb(total)} total')
    ..writeln('manifest: $outDir/manifest.json');

  for (final c in loader.corrections.neverApplied(appliedCorrections)) {
    staleCorrections.add('*/${c.subject}');
  }

  if (correctionNotes.isNotEmpty) {
    stdout.writeln('\ncorrections applied: ${correctionNotes.join(', ')}');
  }
  // A correction that matches nothing is either a typo or one upstream has
  // since adopted. Either way it is now shadowing nothing and should go.
  if (staleCorrections.isNotEmpty) {
    stderr.writeln('\nWARNING: corrections matched no ability — remove them '
        'from $correctionsPath if upstream has fixed the data:\n'
        '  ${staleCorrections.join('\n  ')}');
  }
}

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';

String _title(String id) => id
    .split('-')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
