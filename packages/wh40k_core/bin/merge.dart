/// Builds data/merged from data/bsdata over data/40kdc (DESIGN.md §3.10).
///
/// Everything downstream — the bundler, the coverage report, the snapshot
/// writer — reads a 40kdc-shaped tree. This writes one, so the source swap is
/// a change of input directory rather than a rewrite of every consumer.
///
///   dart run bin/merge.dart                 # every faction
///   dart run bin/merge.dart tau-empire      # one
///   dart run bin/merge.dart --report        # conflicts only, write nothing
library;

import 'dart:convert';
import 'dart:io';

import 'package:wh40k_core/src/source/bsdata/bs_document.dart';
import 'package:wh40k_core/src/source/bsdata/bs_mapper.dart';
import 'package:wh40k_core/src/source/bsdata/bs_merge.dart';

const _root = '../..';
const _bsRoot = '$_root/data/bsdata';
const _dcRoot = '$_root/data/40kdc';
const _outRoot = '$_root/data/merged';
const _conflictsPath = '$_root/data-conflicts.json';

/// Which BSData-derived list replaces which 40kdc file, and which fields of it
/// are worth diffing when both sources state one.
const _files = {
  'units': (
    path: 'core/%s/units.json',
    idField: 'id',
    compare: {'name', 'points', 'is_legend'},
    fillOnly: false,
  ),
  'weapons': (
    path: 'core/%s/weapons.json',
    idField: 'id',
    compare: {'name', 'type', 'profiles'},
    fillOnly: false,
  ),
  // Fill-only. A 40kdc composition carries `default_weapon_ids` and
  // `base_size_mm`, and BSData has neither — so letting its record win
  // replaced a datasheet's starting loadout with nothing, and every new unit
  // arrived on the builder's table unarmed.
  'compositions': (
    path: 'core/%s/unit-compositions.json',
    idField: 'unit_id',
    compare: <String>{},
    fillOnly: true,
  ),
  'abilities': (
    path: 'enrichment/%s/abilities.json',
    idField: 'ability_id',
    compare: {'name'},
    fillOnly: false,
  ),
};

void main(List<String> args) {
  final reportOnly = args.contains('--report');
  final wanted = args.where((a) => !a.startsWith('--')).toList();

  final factions = wanted.isNotEmpty
      ? wanted
      : (Directory(_bsRoot).listSync().whereType<Directory>().toList()
            ..sort((a, b) => a.path.compareTo(b.path)))
          .map((d) => d.path.split('/').last)
          .where((n) => n != 'shared')
          .toList();

  final allConflicts = <Map<String, Object?>>[];
  var totalUnits = 0;
  var totalAdded = 0;

  for (final factionId in factions) {
    final index = BsIndex();
    final shared = Directory('$_bsRoot/shared');
    if (shared.existsSync()) {
      for (final f in shared.listSync().whereType<File>()) {
        if (f.path.endsWith('.json')) index.add(f, asRoot: false);
      }
    }
    final dir = Directory('$_bsRoot/$factionId');
    if (!dir.existsSync()) continue;
    for (final f in dir.listSync().whereType<File>()) {
      if (f.path.endsWith('.json')) index.add(f);
    }

    // 40kdc's weapons decide which variant of a repeated weapon keeps the
    // plain id, so they are read before the mapping rather than at merge time.
    final mapped = BsMapper(index).faction(
      factionId,
      anchors: _readArray('$_dcRoot/core/$factionId/weapons.json'),
    );
    final produced = {
      'units': mapped.units,
      'weapons': mapped.weapons,
      'compositions': mapped.compositions,
      'abilities': mapped.abilities,
    };

    var added = 0;
    for (final entry in _files.entries) {
      final spec = entry.value;
      final relative = spec.path.replaceFirst('%s', factionId);
      final existing = _readArray('$_dcRoot/$relative');

      final result = mergeRecords(
        faction: factionId,
        kind: entry.key,
        idField: spec.idField,
        bsdata: produced[entry.key]!,
        fortykdc: existing,
        compare: spec.compare,
        fillOnly: spec.fillOnly,
      );

      allConflicts.addAll([for (final c in result.conflicts) c.toJson()]);
      if (entry.key == 'units') {
        totalUnits += result.records.length;
        added = result.addedByBsdata.length;
        totalAdded += added;
      }

      if (!reportOnly) _write('$_outRoot/$relative', result.records);
    }

    for (final collision in mapped.collisions) {
      stderr.writeln('  COLLISION $factionId: $collision');
    }
    stdout.writeln('  $factionId: ${mapped.units.length} BSData datasheets, '
        '$added new');
  }

  if (!reportOnly) {
    _copyRemaining(factions);
    File(_conflictsPath).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({
              'note': 'BSData over 40kdc; BSData wins every row here. '
                  'DESIGN.md §3.10.',
              'conflicts': allConflicts,
            })}\n');
  }

  stdout.writeln('\n$totalUnits datasheets, $totalAdded added by BSData');
  stdout.writeln('${allConflicts.length} conflicts'
      '${reportOnly ? '' : ' -> ${_conflictsPath.replaceFirst('$_root/', '')}'}');
}

/// Copies every 40kdc file the merge did not rewrite.
///
/// Missions, terrain, stratagems, detachments, dispositions, phase mappings,
/// leader attachments, wargear options — BSData has none of them, and the
/// merged tree has to be complete or nothing downstream can read it.
void _copyRemaining(List<String> factions) {
  final source = Directory(_dcRoot);
  final rewritten = <String>{
    for (final faction in factions)
      for (final spec in _files.values) spec.path.replaceFirst('%s', faction),
  };

  for (final entity in source.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.json')) continue;
    final relative = entity.path.substring(source.path.length + 1);
    if (rewritten.contains(relative)) continue;
    final target = File('$_outRoot/$relative');
    target.parent.createSync(recursive: true);
    entity.copySync(target.path);
  }
}

List<Object?> _readArray(String path) {
  final file = File(path);
  if (!file.existsSync()) return const [];
  final decoded = jsonDecode(file.readAsStringSync());
  return decoded is List ? decoded : const [];
}

void _write(String path, List<Object?> records) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(records)}\n');
}
