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
import 'package:wh40k_core/src/source/bsdata/bs_slug.dart';
import 'package:wh40k_core/src/source/json.dart';

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
  // Fill-only, and this one is a reversal. BSData declares a weapon entry on
  // every datasheet that can reach the gun, but for T'au almost all of them
  // are BS5+ — the BS3+/BS4+ distinction between a Commander's missile pod,
  // a Crisis suit's and a drone's exists **only in 40kdc**, which curates
  // carrier-scoped records for exactly that. Letting BSData win replaced
  // richer data with poorer and cost the reference list 60 points.
  'weapons': (
    path: 'core/%s/weapons.json',
    idField: 'id',
    compare: {'name', 'type', 'profiles'},
    fillOnly: true,
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

  /// Ability ids harvested from each faction's shared groups — detachment
  /// rules and enhancements — used below to give an enhancement its wording.
  final harvested = <String, Set<String>>{};
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

    // Catalogues borrow from one another. `Aeldari - Drukhari.json` holds no
    // entries at all — its datasheets are entry links into the Aeldari
    // library, which is filed under a different faction. Without the other
    // factions' files in the index those links resolve to nothing, and
    // Drukhari came through with zero BSData datasheets.
    //
    // Added as targets, never as roots: the Aeldari library holds Craftworlds'
    // datasheets too, and Drukhari fields the ones it links to, not all of
    // them.
    for (final other in Directory(_bsRoot).listSync().whereType<Directory>()) {
      if (other.path.endsWith('/$factionId')) continue;
      for (final f in other.listSync().whereType<File>()) {
        if (f.path.endsWith('.json')) index.add(f, asRoot: false);
      }
    }
    index.resolveRootLinks();

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
        keepFrom40kdc: entry.key == 'units' ? const {'weapon_ids'} : const {},
        union: entry.key == 'units' ? const {'wargear_budgets'} : const {},
      );

      allConflicts.addAll([for (final c in result.conflicts) c.toJson()]);
      if (entry.key == 'units') {
        totalUnits += result.records.length;
        added = result.addedByBsdata.length;
        totalAdded += added;
      }

      if (!reportOnly) _write('$_outRoot/$relative', result.records);
    }

    // An enhancement's wording, now that there is some. 40kdc leaves
    // `ability_id` null on most of them, so the record naming the rule and the
    // record holding its text were never connected — the app could show an
    // enhancement's name and cost and nothing about what it does.
    if (!reportOnly) {
      final enhPath = 'core/$factionId/enhancements.json';
      final abilityIds = {
        for (final raw in produced['abilities']!)
          if (str(asMap(raw)['ability_id']) case final id?) id,
      };
      final enhancements = _readArray('$_outRoot/$enhPath');
      var linked = 0;
      final updated = [
        for (final raw in enhancements)
          if (asMap(raw) case final record)
            if (str(record['ability_id']) == null &&
                abilityIds.contains(bsSlug(strOr(record['name'], ''))))
              () {
                linked++;
                return {
                  ...record,
                  'ability_id': bsSlug(strOr(record['name'], '')),
                };
              }()
            else
              record,
      ];
      if (linked > 0) _write('$_outRoot/$enhPath', updated);
    }

    harvested[factionId] = {
      for (final raw in mapped.abilities)
        if (str(raw['ability_id']) case final abilityId?) abilityId,
    };

    for (final collision in mapped.collisions) {
      stderr.writeln('  COLLISION $factionId: $collision');
    }
    stdout.writeln('  $factionId: ${mapped.units.length} BSData datasheets, '
        '$added new');
  }

  if (!reportOnly) {
    _copyRemaining(factions);
    stdout.writeln('\n${_linkEnhancementText(factions, harvested)} '
        'enhancements linked to their printed text');
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

/// Gives each enhancement the id of the ability holding its printed wording.
///
/// 40kdc leaves `ability_id` null on most enhancements, so the record naming
/// the rule and the record holding its text were never connected — the app
/// could show an enhancement's name and its cost and nothing about what it
/// does. BSData publishes the wording, and the two meet at the slug.
///
/// Runs **after** `_copyRemaining`, which is what puts the enhancements file
/// in the merged tree at all; doing it inside the per-faction loop read
/// whatever a previous build had left there.
int _linkEnhancementText(
    List<String> factions, Map<String, Set<String>> harvested) {
  var total = 0;
  for (final factionId in factions) {
    final path = '$_outRoot/core/$factionId/enhancements.json';

    // A chapter's enhancements are the parent's, and only the parent's
    // catalogue was harvested — Blood Angels linked 1 of 83 without this.
    final parentId = _parentOf(factionId);
    final ids = {
      ...?harvested[factionId],
      ...?harvested[parentId],
    };
    if (ids.isEmpty) continue;

    final records = _readArray(path);
    if (records.isEmpty) continue;

    // An enhancement already pointing at an ability is not necessarily
    // pointing at one with any text: 40kdc names the rule and publishes no
    // wording for it, which is the whole gap being closed here.
    final described = _describedAbilities(factionId, parentId);

    var linked = 0;
    final updated = [
      for (final raw in records)
        if (asMap(raw) case final record)
          if (_textIdFor(record, ids, described) case final id?)
            () {
              linked++;
              return {...record, 'ability_id': id};
            }()
          else
            record,
    ];
    if (linked > 0) {
      _write(path, updated);
      total += linked;
    }
  }
  return total;
}

/// `Hagiomnifex (Upgrade)` and `Fear Made Manifest (Aura)`.
///
/// 40kdc appends what kind of enhancement it is to the name; BSData does not.
/// Slugging the whole string missed 42 of them over a parenthesis.
final _nameSuffix = RegExp(r'\s*\([^)]*\)\s*$');

/// The ability id holding this enhancement's wording, or null.
String? _textIdFor(
    Map<String, dynamic> record, Set<String> ids, Set<String> described) {
  final existing = str(record['ability_id']);
  if (existing != null && described.contains(existing)) return null;

  final name = strOr(record['name'], '');
  for (final candidate in [
    bsSlug(name),
    bsSlug(name.replaceAll(_nameSuffix, '')),
  ]) {
    if (candidate.isNotEmpty && ids.contains(candidate)) return candidate;
  }
  return null;
}

/// Ability ids that actually carry text, for this faction and its parent.
Set<String> _describedAbilities(String factionId, String? parentId) {
  final out = <String>{};
  for (final id in [factionId, if (parentId != null) parentId]) {
    for (final raw in _readArray('$_outRoot/enrichment/$id/abilities.json')) {
      final record = asMap(raw);
      final text = str(record['description']);
      if (text == null || text.trim().isEmpty) continue;
      if (str(record['ability_id']) case final abilityId?) out.add(abilityId);
    }
  }
  return out;
}

/// The faction whose datasheets and enhancements this one fields, if any.
String? _parentOf(String factionId) {
  for (final raw in _readArray('$_outRoot/core/$factionId/factions.json')) {
    final record = asMap(raw);
    if (str(record['id']) == factionId) return str(record['parent_faction_id']);
  }
  return null;
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
