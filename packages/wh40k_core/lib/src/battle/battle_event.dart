/// Everything that can happen in a game (DESIGN.md §7.4).
///
/// State is **derived from the log**, never mutated in place. Mid-game
/// mistakes are constant — a wrong casualty, a stratagem on the wrong unit —
/// so undo has to be a pop rather than an inverse operation per event type.
/// It also means a finished game can be replayed for a summary at no extra
/// cost.
library;

import '../source/json.dart';

enum Player { me, opponent }

enum UnitStatus { onBoard, reserves, destroyed }

/// Status flags set in the Movement phase that decide what a unit may do
/// later. The eligibility engine of §7.3.7 reads these.
enum UnitFlag { advanced, fellBack, remainedStationary, battleShocked }

enum ScoreKind { primary, secondary }

sealed class BattleEvent {
  const BattleEvent();

  String get type;

  Map<String, Object?> toJson();

  static BattleEvent? fromJson(Object? value) {
    final j = asMap(value);
    return switch (strOr(j['type'], '')) {
      'round' => SetRound(intOr(j['round'], 1)),
      'turn' => SetActivePlayer(
          strOr(j['player'], 'me') == 'opponent' ? Player.opponent : Player.me),
      'cp' => AdjustCp(intOr(j['delta'], 0)),
      'score' => ScoreVp(
          side: strOr(j['side'], 'me') == 'opponent'
              ? Player.opponent
              : Player.me,
          kind: strOr(j['kind'], 'primary') == 'secondary'
              ? ScoreKind.secondary
              : ScoreKind.primary,
          round: intOr(j['round'], 1),
          vp: intOr(j['vp'], 0),
        ),
      'status' => SetUnitStatus(
          instanceId: strOr(j['unit'], ''),
          status: UnitStatus.values.firstWhere(
            (s) => s.name == strOr(j['status'], 'onBoard'),
            orElse: () => UnitStatus.onBoard,
          ),
        ),
      'models' => SetModelsRemaining(
          instanceId: strOr(j['unit'], ''),
          models: intOr(j['models'], 0),
        ),
      'flag' => SetUnitFlag(
          instanceId: strOr(j['unit'], ''),
          flag: UnitFlag.values.firstWhere(
            (f) => f.name == strOr(j['flag'], 'advanced'),
            orElse: () => UnitFlag.advanced,
          ),
          value: j['value'] == true,
        ),
      'stratagem' => UseStratagem(
          stratagemId: strOr(j['stratagem'], ''),
          targetInstanceId: str(j['unit']),
          round: intOr(j['round'], 1),
          phase: strOr(j['phase'], 'command'),
          cp: intOr(j['cp'], 0),
        ),
      'oncePerBattle' => UseOncePerBattle(
          instanceId: strOr(j['unit'], ''),
          abilityId: strOr(j['ability'], ''),
        ),
      'drawSecondary' => DrawSecondary(strOr(j['card'], '')),
      'discardSecondary' => DiscardSecondary(strOr(j['card'], '')),
      'scoreSecondary' => ScoreSecondaryCard(
          cardId: strOr(j['card'], ''),
          round: intOr(j['round'], 1),
          vp: intOr(j['vp'], 0),
        ),
      _ => null,
    };
  }
}

class SetRound extends BattleEvent {
  final int round;

  const SetRound(this.round);

  @override
  String get type => 'round';

  @override
  Map<String, Object?> toJson() => {'type': type, 'round': round};
}

class SetActivePlayer extends BattleEvent {
  final Player player;

  const SetActivePlayer(this.player);

  @override
  String get type => 'turn';

  @override
  Map<String, Object?> toJson() => {'type': type, 'player': player.name};
}

class AdjustCp extends BattleEvent {
  final int delta;

  const AdjustCp(this.delta);

  @override
  String get type => 'cp';

  @override
  Map<String, Object?> toJson() => {'type': type, 'delta': delta};
}

class ScoreVp extends BattleEvent {
  final Player side;
  final ScoreKind kind;
  final int round;
  final int vp;

  const ScoreVp({
    required this.side,
    required this.kind,
    required this.round,
    required this.vp,
  });

  @override
  String get type => 'score';

  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'side': side.name,
        'kind': kind.name,
        'round': round,
        'vp': vp,
      };
}

class SetUnitStatus extends BattleEvent {
  final String instanceId;
  final UnitStatus status;

  const SetUnitStatus({required this.instanceId, required this.status});

  @override
  String get type => 'status';

  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'unit': instanceId, 'status': status.name};
}

class SetModelsRemaining extends BattleEvent {
  final String instanceId;
  final int models;

  const SetModelsRemaining({required this.instanceId, required this.models});

  @override
  String get type => 'models';

  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'unit': instanceId, 'models': models};
}

class SetUnitFlag extends BattleEvent {
  final String instanceId;
  final UnitFlag flag;
  final bool value;

  const SetUnitFlag({
    required this.instanceId,
    required this.flag,
    required this.value,
  });

  @override
  String get type => 'flag';

  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'unit': instanceId, 'flag': flag.name, 'value': value};
}

/// Records both the CP spend and the fact that this unit has now used a
/// stratagem in this round and phase — which is what 11e's one-per-phase rule
/// is checked against (§4.4).
class UseStratagem extends BattleEvent {
  final String stratagemId;
  final String? targetInstanceId;
  final int round;
  final String phase;
  final int cp;

  const UseStratagem({
    required this.stratagemId,
    required this.round,
    required this.phase,
    required this.cp,
    this.targetInstanceId,
  });

  @override
  String get type => 'stratagem';

  @override
  Map<String, Object?> toJson() => {
        'type': type,
        'stratagem': stratagemId,
        if (targetInstanceId != null) 'unit': targetInstanceId,
        'round': round,
        'phase': phase,
        'cp': cp,
      };
}

class UseOncePerBattle extends BattleEvent {
  final String instanceId;
  final String abilityId;

  const UseOncePerBattle({required this.instanceId, required this.abilityId});

  @override
  String get type => 'oncePerBattle';

  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'unit': instanceId, 'ability': abilityId};
}

class DrawSecondary extends BattleEvent {
  final String cardId;

  const DrawSecondary(this.cardId);

  @override
  String get type => 'drawSecondary';

  @override
  Map<String, Object?> toJson() => {'type': type, 'card': cardId};
}

class DiscardSecondary extends BattleEvent {
  final String cardId;

  const DiscardSecondary(this.cardId);

  @override
  String get type => 'discardSecondary';

  @override
  Map<String, Object?> toJson() => {'type': type, 'card': cardId};
}

class ScoreSecondaryCard extends BattleEvent {
  final String cardId;
  final int round;
  final int vp;

  const ScoreSecondaryCard({
    required this.cardId,
    required this.round,
    required this.vp,
  });

  @override
  String get type => 'scoreSecondary';

  @override
  Map<String, Object?> toJson() =>
      {'type': type, 'card': cardId, 'round': round, 'vp': vp};
}
