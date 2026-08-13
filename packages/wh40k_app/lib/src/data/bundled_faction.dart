import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// Loads a faction dataset bundled as app assets.
///
/// **Temporary.** DESIGN.md §3.4 has datasets published as versioned bundles
/// the app downloads; that is not built yet. Import needs a full catalogue to
/// resolve names against — a roster snapshot is not enough, because a snapshot
/// only contains what some *other* list already referenced — so one faction
/// rides along in the binary until distribution exists.
///
/// The data is 40kdc-data, CC BY 4.0 © Alpaca Software and the 40kdc community
/// contributors; attribution is in the README and belongs in an about screen
/// before this ships.
class BundledFaction {
  static const factionId = 'tau-empire';

  static Dataset? _cached;

  static Future<Dataset> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    Future<List<Object?>> read(String file) async {
      final raw =
          await rootBundle.loadString('assets/data/$factionId/$file.json');
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : const [];
    }

    final enhancements = await read('enhancements');

    final faction = FactionData(
      factionId: factionId,
      units: (await read('units')).map(SourceUnit.fromJson).toList(),
      weapons: (await read('weapons')).map(SourceWeapon.fromJson).toList(),
      detachments:
          (await read('detachments')).map(SourceDetachment.fromJson).toList(),
      stratagems:
          (await read('stratagems')).map(SourceStratagem.fromJson).toList(),
      abilities: (await read('abilities')).map(SourceAbility.fromJson).toList(),
      phaseMappings: const [],
      leaderAttachments: (await read('leader-attachments'))
          .map(LeaderAttachment.fromJson)
          .toList(),
      enhancementIds: {
        for (final e in enhancements)
          if (e is Map && e['id'] != null) e['id'].toString(),
      },
      missingFiles: const [],
    );

    return _cached = Dataset.of(faction, revision: 'bundled');
  }
}
