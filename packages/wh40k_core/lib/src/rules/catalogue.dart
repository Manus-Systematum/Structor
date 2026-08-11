/// Read-only content lookup used by pricing and validation.
///
/// Deliberately narrow. It is backed by source DTOs today; the normalised
/// domain model (DESIGN.md §2.1) can implement the same interface later
/// without touching the calculator or the validator.
library;

import '../source/dataset_loader.dart';
import '../source/source_models.dart';

abstract interface class Catalogue {
  SourceUnit? unit(String datasheetId);

  SourceDetachment? detachment(String detachmentId);

  /// Datasheets [leaderDatasheetId] may join. Empty when the datasheet is not
  /// a leader, or when no attachment rule is published for it.
  List<String> eligibleBodyguards(String leaderDatasheetId);
}

class MapCatalogue implements Catalogue {
  final Map<String, SourceUnit> _units;
  final Map<String, SourceDetachment> _detachments;
  final Map<String, List<String>> _attachments;

  MapCatalogue(
    Iterable<SourceUnit> units, {
    Iterable<SourceDetachment> detachments = const [],
    Iterable<LeaderAttachment> leaderAttachments = const [],
  })  : _units = {for (final u in units) u.id: u},
        _detachments = {for (final d in detachments) d.id: d},
        _attachments = {
          for (final a in leaderAttachments) a.leaderId: a.eligibleBodyguardIds,
        };

  /// Builds a catalogue over a loaded faction snapshot.
  factory MapCatalogue.ofFaction(FactionData faction) => MapCatalogue(
        faction.units,
        detachments: faction.detachments,
        leaderAttachments: faction.leaderAttachments,
      );

  @override
  SourceUnit? unit(String datasheetId) => _units[datasheetId];

  @override
  SourceDetachment? detachment(String detachmentId) =>
      _detachments[detachmentId];

  @override
  List<String> eligibleBodyguards(String leaderDatasheetId) =>
      _attachments[leaderDatasheetId] ?? const [];
}
