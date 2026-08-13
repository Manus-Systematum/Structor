/// The pre-game decisions, recorded once the setup wizard completes
/// (DESIGN.md §7.3.1).
///
/// Setup is a **mandatory wizard**: every question is answered before the
/// battle screen opens, so play mode can assume a fully specified game rather
/// than handle partial state everywhere.
///
/// Both missions are stored, because the matchup table is asymmetric and the
/// opponent is playing a different primary. Knowing theirs is what lets the
/// app say how they score (§7.3.3), which is how a player decides what to
/// contest.
library;

import '../source/json.dart';

enum SecondaryMode { fixed, tactical }

class MissionSetup {
  final String myDisposition;
  final String opponentDisposition;

  /// Resolved from the matchup table: mine is (mine × theirs), theirs is
  /// (theirs × mine) — different cells.
  final String myMissionId;
  final String opponentMissionId;

  final String? deploymentId;

  /// Free text. There is no twist data upstream, and the twist is optional
  /// anyway, so the player records what they drew rather than picking from a
  /// list that does not exist.
  final String? twist;

  final bool iAmAttacker;
  final SecondaryMode secondaryMode;
  final String? opponentName;

  const MissionSetup({
    required this.myDisposition,
    required this.opponentDisposition,
    required this.myMissionId,
    required this.opponentMissionId,
    this.deploymentId,
    this.twist,
    this.iAmAttacker = true,
    this.secondaryMode = SecondaryMode.tactical,
    this.opponentName,
  });

  factory MissionSetup.fromJson(Object? v) {
    final j = asMap(v);
    return MissionSetup(
      myDisposition: strOr(j['myDisposition'], ''),
      opponentDisposition: strOr(j['opponentDisposition'], ''),
      myMissionId: strOr(j['myMissionId'], ''),
      opponentMissionId: strOr(j['opponentMissionId'], ''),
      deploymentId: str(j['deploymentId']),
      twist: str(j['twist']),
      iAmAttacker: j['iAmAttacker'] != false,
      secondaryMode: strOr(j['secondaryMode'], 'tactical') == 'fixed'
          ? SecondaryMode.fixed
          : SecondaryMode.tactical,
      opponentName: str(j['opponentName']),
    );
  }

  Map<String, Object?> toJson() => {
        'myDisposition': myDisposition,
        'opponentDisposition': opponentDisposition,
        'myMissionId': myMissionId,
        'opponentMissionId': opponentMissionId,
        if (deploymentId != null) 'deploymentId': deploymentId,
        if (twist != null) 'twist': twist,
        'iAmAttacker': iAmAttacker,
        'secondaryMode': secondaryMode.name,
        if (opponentName != null) 'opponentName': opponentName,
      };

  /// True when both players ended up on the same disposition — the diagonal of
  /// the matchup table, where the mission is a mirror.
  bool get isMirror => myDisposition == opponentDisposition;
}
