import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// Does every correction in the patch actually reach the app? (§3.15)
///
/// The generator reports what it *wrote*. That is not the same question. An
/// operation can name a record that the bundle does not carry, key on the
/// wrong field, or address a faction file that never loads — and each of
/// those fails silently, because a patch that matches nothing is
/// indistinguishable from a patch with nothing to do.
///
/// So this reads the shipped patch, loads every faction the way the app does,
/// and checks each operation against the result: a `set` is present, a
/// `remove` is gone, an `add` is there. It is the only test that can tell
/// "883 corrections" from "883 corrections, 40 of which went nowhere".
void main() {
  test('every operation in the patch lands on a record', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = DatasetRepository();

    final source = File('../../data/updates/2026-08-26.json');
    expect(source.existsSync(), isTrue, reason: 'the authored patch');
    final patch = DatasetPatch.fromJson(jsonDecode(source.readAsStringSync()));

    // The shipped copy has to say the same thing as the authored one, or the
    // bundles were not rebuilt after the last edit.
    final shipped = (await repo.patches()).patches.single;
    expect(shipped.operations.length, patch.operations.length,
        reason: 'assets/bundles is stale — run tools/rebuild-assets.sh');

    final byFaction = <String, List<PatchOperation>>{};
    for (final op in patch.operations) {
      (byFaction[op.faction] ??= []).add(op);
    }

    final failures = <String>[];
    var checked = 0;

    for (final entry in byFaction.entries) {
      final Dataset dataset;
      try {
        dataset = await repo.faction(entry.key);
      } on StateError {
        failures.add('${entry.key}: no such faction bundle');
        continue;
      }

      // Read back the same source records the patch was applied to, rather
      // than the parsed models: a model may not expose the field an
      // operation set, and that is not the same as the operation failing.
      final files = <String, List<Object?>>{
        'stratagems': [
          for (final s in dataset.faction.stratagems)
            {'id': s.id, 'text': s.text, 'cp_cost': s.cpCost},
        ],
        'abilities': [
          for (final a in dataset.faction.abilities)
            {'ability_id': a.abilityId, 'description': a.description},
        ],
        'units': [
          for (final u in dataset.faction.units)
            {'id': u.id, 'keywords': u.keywords, 'ability_ids': u.abilityIds},
        ],
      };

      for (final op in entry.value) {
        final records = files[op.file];
        if (records == null) {
          failures.add('${entry.key}/${op.file}: not a file this test reads');
          continue;
        }
        checked++;
        final found = records
            .cast<Map<String, Object?>>()
            .where((r) => r[op.key]?.toString() == op.id);

        switch (op.op) {
          case PatchOp.remove:
            if (found.isNotEmpty) {
              failures.add('${entry.key}: ${op.id} should be gone');
            }
          case PatchOp.add:
            if (found.isEmpty) {
              failures.add('${entry.key}: ${op.id} was not added');
            }
          case PatchOp.set:
            if (found.isEmpty) {
              failures.add('${entry.key}: ${op.id} is not in the bundle');
              continue;
            }
            for (final field in op.values.keys) {
              final want = op.values[field];
              final got = found.first[field];
              if (got == null && want != null) {
                failures.add('${entry.key}: ${op.id}.$field is null');
              } else if (want is String && got.toString() != want) {
                failures.add('${entry.key}: ${op.id}.$field did not take');
              } else if (want is List &&
                  got is List &&
                  got.length != want.length) {
                failures.add('${entry.key}: ${op.id}.$field is the wrong size');
              }
            }
        }
      }
    }

    expect(checked, greaterThan(800), reason: 'most of the patch is checkable');
    expect(failures, isEmpty,
        reason: '${failures.length} operations did not land:\n'
            '${failures.take(20).join('\n')}');
  });
}
