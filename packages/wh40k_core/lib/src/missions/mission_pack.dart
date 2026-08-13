/// Mission data and the matchup table (DESIGN.md §7.3.1).
///
/// The table is **asymmetric**: `(A vs B)` and `(B vs A)` are different cells
/// yielding different missions, so both players are playing their own primary
/// at the same time on the same table. Twenty-five ordered pairs, twenty-five
/// distinct missions, mirrors on the diagonal.
///
/// That is what makes force disposition a *decision* rather than a derivation
/// once an army has more than one detachment: each detachment offers one
/// disposition, the army declares one, and the declaration picks which mission
/// you play against whatever your opponent declares.
library;

import '../source/json.dart';
import '../source/source_models.dart';

class ForceDisposition {
  final String id;
  final String name;
  final String text;

  const ForceDisposition({
    required this.id,
    required this.name,
    required this.text,
  });

  factory ForceDisposition.fromJson(Object? v) {
    final j = asMap(v);
    return ForceDisposition(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      text: strOr(j['text'], ''),
    );
  }
}

class Mission {
  final String id;
  final String name;
  final int? vpPerRoundCap;
  final int? vpPerGameCap;

  const Mission({
    required this.id,
    required this.name,
    this.vpPerRoundCap,
    this.vpPerGameCap,
  });

  factory Mission.fromJson(Object? v) {
    final j = asMap(v);
    return Mission(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      vpPerRoundCap: asInt(j['vp_per_round_cap']),
      vpPerGameCap: asInt(j['vp_per_game_cap']),
    );
  }
}

class DeploymentPattern {
  final String id;
  final String name;
  final String description;

  const DeploymentPattern({
    required this.id,
    required this.name,
    required this.description,
  });

  factory DeploymentPattern.fromJson(Object? v) {
    final j = asMap(v);
    return DeploymentPattern(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      description: strOr(j['description'], ''),
    );
  }
}

/// A primary or secondary card.
///
/// [text] is an original paraphrase written by the data project, not GW's
/// printed wording (§7.3.4). Enough to play from; not authoritative for a
/// rules dispute, and the UI must not imply otherwise.
class MissionCard {
  final String id;
  final String name;
  final String cardType;
  final String text;
  final List<Object?> awards;
  final List<Object?> actions;

  const MissionCard({
    required this.id,
    required this.name,
    required this.cardType,
    required this.text,
    this.awards = const [],
    this.actions = const [],
  });

  factory MissionCard.fromJson(Object? v) {
    final j = asMap(v);
    return MissionCard(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      cardType: strOr(j['card_type'], ''),
      text: strOr(j['text'], ''),
      awards: asList(j['awards']),
      actions: asList(j['actions']),
    );
  }

  bool get isPrimary => cardType == 'primary';
  bool get isSecondary => cardType == 'secondary';
  bool get requiresAction => actions.isNotEmpty;
}

class MissionMatchupEntry {
  final String disposition;
  final String opponentDisposition;
  final String missionId;

  const MissionMatchupEntry({
    required this.disposition,
    required this.opponentDisposition,
    required this.missionId,
  });

  factory MissionMatchupEntry.fromJson(Object? v) {
    final j = asMap(v);
    return MissionMatchupEntry(
      disposition: strOr(j['disposition'], ''),
      opponentDisposition: strOr(j['opponent_disposition'], ''),
      missionId: strOr(j['mission_id'], ''),
    );
  }
}

/// One cell of the decision grid: declaring [disposition] against
/// [opponentDisposition] means playing [mission].
class MissionOutcome {
  final String disposition;
  final String opponentDisposition;
  final Mission? mission;
  final MissionCard? card;

  const MissionOutcome({
    required this.disposition,
    required this.opponentDisposition,
    this.mission,
    this.card,
  });
}

class MissionPack {
  final Map<String, ForceDisposition> dispositions;
  final Map<String, Mission> missions;
  final Map<String, MissionCard> cards;
  final List<DeploymentPattern> deployments;
  final List<MissionMatchupEntry> matchups;

  const MissionPack({
    this.dispositions = const {},
    this.missions = const {},
    this.cards = const {},
    this.deployments = const [],
    this.matchups = const [],
  });

  factory MissionPack.fromJson({
    required List<Object?> dispositions,
    required List<Object?> missions,
    required List<Object?> matchups,
    required List<Object?> cards,
    required List<Object?> deployments,
  }) {
    final parsedCards = cards.map(MissionCard.fromJson).toList();
    return MissionPack(
      dispositions: {
        for (final raw in dispositions)
          if (ForceDisposition.fromJson(raw) case final d when d.id.isNotEmpty)
            d.id: d,
      },
      missions: {
        for (final raw in missions)
          if (Mission.fromJson(raw) case final m when m.id.isNotEmpty) m.id: m,
      },
      cards: {
        for (final card in parsedCards)
          if (card.id.isNotEmpty) card.id: card,
      },
      deployments: deployments.map(DeploymentPattern.fromJson).toList(),
      matchups: matchups.map(MissionMatchupEntry.fromJson).toList(),
    );
  }

  bool get isEmpty => matchups.isEmpty;

  List<ForceDisposition> get allDispositions =>
      dispositions.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  List<MissionCard> get secondaryCards =>
      cards.values.where((c) => c.isSecondary).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  MissionCard? card(String id) => cards[id];

  /// The mission played by a player declaring [disposition] against an
  /// opponent declaring [opponentDisposition]. Order matters.
  Mission? missionFor({
    required String disposition,
    required String opponentDisposition,
  }) {
    for (final entry in matchups) {
      if (entry.disposition == disposition &&
          entry.opponentDisposition == opponentDisposition) {
        return missions[entry.missionId];
      }
    }
    return null;
  }

  MissionOutcome outcomeFor({
    required String disposition,
    required String opponentDisposition,
  }) {
    final mission = missionFor(
      disposition: disposition,
      opponentDisposition: opponentDisposition,
    );
    return MissionOutcome(
      disposition: disposition,
      opponentDisposition: opponentDisposition,
      mission: mission,
      card: mission == null ? null : cards[mission.id],
    );
  }

  /// Dispositions an army may declare, given the detachments it took. More
  /// than one means the player has a choice — the decision this screen exists
  /// to support.
  List<ForceDisposition> availableTo(Iterable<SourceDetachment> detachments) {
    final ids = <String>{
      for (final detachment in detachments) ...detachment.forceDispositions,
    };
    return [
      for (final id in ids)
        if (dispositions[id] case final d?) d,
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// The full decision grid: every disposition the army could declare, against
  /// every disposition the opponent might.
  ///
  /// Rendered as a matrix and never as a recommendation — the app knows
  /// neither the matchup, the terrain, nor how the player plays (§7.3.1).
  List<List<MissionOutcome>> grid(Iterable<ForceDisposition> mine) => [
        for (final ours in mine)
          [
            for (final theirs in allDispositions)
              outcomeFor(
                disposition: ours.id,
                opponentDisposition: theirs.id,
              ),
          ],
      ];
}
