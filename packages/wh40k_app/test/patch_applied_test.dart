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
            {
              'id': u.id,
              'keywords': u.keywords,
              'ability_ids': u.abilityIds,
              'profiles': u.profiles.length,
              'points': u.points.length,
              'is_legend': u.isLegend,
              'base_size_mm': u.baseSizeMm,
            },
        ],
        'weapons': [
          for (final w in dataset.faction.weapons)
            {'id': w.id, 'profiles': w.profiles.length},
        ],
        'leader-attachments': [
          for (final a in dataset.faction.leaderAttachments)
            {
              'leader_id': a.leaderId,
              'eligible_bodyguard_ids': a.eligibleBodyguardIds,
            },
        ],
        'faqs': [
          for (final f in dataset.faction.faqs)
            {
              'id': f.id,
              'question': f.question,
              'answer': f.answer,
              'source': f.source
            },
        ],
        'enhancements': [
          for (final e in dataset.faction.enhancements)
            {'id': e.id, 'cost': e.cost.toString()},
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
              } else if (want is List && got is int && got != want.length) {
                // Profiles are compared by count: the model reshapes them, so
                // the raw list cannot be matched field for field, but a
                // profile that failed to apply changes the count or is absent.
                failures.add('${entry.key}: ${op.id}.$field has $got profiles, '
                    'the patch wrote ${want.length}');
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

  test('a fresh install needs the network only for layout pictures', () async {
    // §3.4. The app ships its bundles, its manifest and the correction patch,
    // so it is fully current offline on first launch. The only thing the
    // manifest names that is *not* in the binary is the 45 layout images,
    // which are eleven megabytes against six for everything else.
    TestWidgetsFlutterBinding.ensureInitialized();
    const assets = AssetBundleSource();
    final manifest = await assets.manifest();
    expect(manifest, isNotNull);

    final missing = <String>[];
    for (final file in [
      for (final b in manifest!.bundles) b.file,
      for (final p in manifest.patches) p.file,
    ]) {
      if (await assets.fetch(file) == null) missing.add(file);
    }
    expect(missing, isEmpty, reason: 'shipped in the binary');

    // And the pictures are deliberately not.
    expect(manifest.assets, isNotEmpty);
    for (final asset in manifest.assets) {
      expect(await assets.fetch(asset.file), isNull,
          reason: '${asset.file} is fetched, not bundled');
    }
  });

  // The Munitorum Field Manual marks a unit whose points changed *in this
  // update* with a red title bar and a `▲ (+10) 230 pts` row. The parser read
  // only the grey bars and only bare figures, so it skipped precisely the
  // units the update exists to carry — 36 of them, The Twin Lance among them,
  // which stayed at its old 220 while the published price was 230 (§3.15).
  test('a unit whose points changed carries the new price', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = DatasetRepository();

    int costOf(List<SourceUnit> units) => units
        .firstWhere((u) => u.id == 'the-twin-lance')
        .points
        .single
        .cost;

    final shipped = DatasetBundle.decode(
        (await const AssetBundleSource().fetch(
            (await repo.manifest()).entry('tau-empire')!.file))!);
    expect(
      costOf(shipped
          .file('units')
          .map(SourceUnit.fromJson)
          .toList()),
      220,
      reason: 'the bundle is what 40kdc published',
    );

    expect(costOf((await repo.faction('tau-empire')).faction.units), 230,
        reason: 'the patch carries the August price');
  });

  // The same failure at scale: a parser that silently stops matching leaves a
  // patch that still applies cleanly and corrects nothing.
  test('the patch carries points for the units that were repriced', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final patch = (await DatasetRepository().patches()).patches.single;
    final repriced = patch.operations
        .where((op) => op.values.containsKey('points'))
        .length;
    expect(repriced, greaterThan(65),
        reason: '73 units are repriced by the August manual');
  });

  // §3.19. Every published name carries a hash of the bytes under it, so an
  // updated file is a URL no cache has ever seen and an unchanged one keeps
  // the URL every cache already has. The check is that the name says what the
  // manifest says, because a name that drifted would be a permanent miss.
  test('every published name carries its own hash', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifest = await const AssetBundleSource().manifest();

    final files = <String, String>{
      for (final b in manifest!.bundles) b.file: b.sha256,
      for (final p in manifest.patches) p.file: p.sha256,
      for (final a in manifest.assets) a.file: a.sha256,
    };
    expect(files, hasLength(greaterThan(70)));

    for (final entry in files.entries) {
      final name = entry.key.split('/').last;
      final parts = name.split('.');
      expect(parts.length, greaterThan(2), reason: '$name has no hash in it');
      expect(parts[1], entry.value.substring(0, 12),
          reason: '$name does not carry its own digest');
    }

    // The manifest itself is not hashed: it is the entry point, and a name
    // that changed with its contents would be unfindable.
    expect(files.keys, isNot(contains(startsWith('manifest'))));
  });
}
