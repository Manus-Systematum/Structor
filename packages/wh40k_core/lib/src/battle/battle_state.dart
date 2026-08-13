/// Game state, derived from an event log (DESIGN.md §7.4).
///
/// Two decisions carry most of the weight here.
///
/// **There is no `phase`.** Phase is where the player is scrolled, not state
/// they maintain (§7.2). Six taps a turn to advance a state machine is rent
/// charged for something the player already knows. Only round and active
/// player are tracked, changing five and ten times a game respectively.
///
/// **`stratagemsUsed` stores `{round, phase}` per use** rather than a
/// "this phase" list that gets cleared on transition. With no transition there
/// is nothing to clear, so the one-per-phase rule becomes a query against
/// whichever phase the player is reading. Lists that reset on transition are
/// exactly where "why is this unit still greyed out" bugs live.
library;

import 'battle_event.dart';

/// A stratagem use, remembered with enough context to answer the rule.
class StratagemUse {
  final String stratagemId;
  final String? targetInstanceId;
  final int round;
  final String phase;
  final int cp;

  const StratagemUse({
    required this.stratagemId,
    required this.round,
    required this.phase,
    required this.cp,
    this.targetInstanceId,
  });
}

class UnitState {
  final UnitStatus status;

  /// Null until the player records a casualty; the weapon table then falls
  /// back to full strength rather than guessing (§7.3.5).
  final int? modelsRemaining;

  final Set<UnitFlag> flags;
  final Set<String> oncePerBattleUsed;

  const UnitState({
    this.status = UnitStatus.onBoard,
    this.modelsRemaining,
    this.flags = const {},
    this.oncePerBattleUsed = const {},
  });

  UnitState copyWith({
    UnitStatus? status,
    int? modelsRemaining,
    Set<UnitFlag>? flags,
    Set<String>? oncePerBattleUsed,
  }) =>
      UnitState(
        status: status ?? this.status,
        modelsRemaining: modelsRemaining ?? this.modelsRemaining,
        flags: flags ?? this.flags,
        oncePerBattleUsed: oncePerBattleUsed ?? this.oncePerBattleUsed,
      );

  bool get isDestroyed => status == UnitStatus.destroyed;
  bool get isInReserves => status == UnitStatus.reserves;
  bool has(UnitFlag flag) => flags.contains(flag);
}

/// Victory points for one side, kept per round so caps can be applied and a
/// round-by-round breakdown shown.
class SideScore {
  final Map<int, int> primary;
  final Map<int, int> secondary;

  const SideScore({this.primary = const {}, this.secondary = const {}});

  int get primaryTotal => primary.values.fold(0, (a, b) => a + b);
  int get secondaryTotal => secondary.values.fold(0, (a, b) => a + b);
  int get total => primaryTotal + secondaryTotal;
}

/// Round and game caps on victory points. Defaults are the secondary caps of
/// §7.3.2; a mission supplies its own for the primary.
class ScoreCaps {
  final int perRound;
  final int perGame;

  const ScoreCaps({this.perRound = 15, this.perGame = 45});

  static const none = ScoreCaps(perRound: 1 << 30, perGame: 1 << 30);
}

class SecondaryState {
  /// Cards drawn at any point, so a re-draw cannot repeat one.
  final Set<String> used;

  /// Held and not yet scored.
  final List<String> hand;

  final Map<String, int> scored;
  final List<String> discarded;

  const SecondaryState({
    this.used = const {},
    this.hand = const [],
    this.scored = const {},
    this.discarded = const [],
  });
}

class BattleState {
  final int round;
  final Player activePlayer;
  final int cp;
  final SideScore me;
  final SideScore opponent;
  final Map<String, UnitState> units;
  final List<StratagemUse> stratagemsUsed;
  final SecondaryState secondaries;

  const BattleState({
    this.round = 1,
    this.activePlayer = Player.me,
    this.cp = 0,
    this.me = const SideScore(),
    this.opponent = const SideScore(),
    this.units = const {},
    this.stratagemsUsed = const [],
    this.secondaries = const SecondaryState(),
  });

  UnitState unit(String instanceId) =>
      units[instanceId] ?? const UnitState();

  /// The one-per-phase rule as a **query**, not a lifecycle (§4.4).
  bool hasUsedStratagem(String instanceId, {required String phase, int? round}) {
    final r = round ?? this.round;
    return stratagemsUsed.any((u) =>
        u.targetInstanceId == instanceId && u.round == r && u.phase == phase);
  }

  /// Stratagems played this round and phase, whoever they targeted.
  List<StratagemUse> usesIn({required String phase, int? round}) {
    final r = round ?? this.round;
    return stratagemsUsed
        .where((u) => u.round == r && u.phase == phase)
        .toList();
  }

  /// Model counts the weapon aggregator reads, omitting units at full strength
  /// so it uses the roster figure rather than a recorded one.
  Map<String, int> get modelsRemaining => {
        for (final entry in units.entries)
          if (entry.value.modelsRemaining != null)
            entry.key: entry.value.modelsRemaining!,
      };
}

/// Applies an event log to produce state. Pure, so undo is a shorter log.
class BattleLog {
  final List<BattleEvent> events;
  final ScoreCaps secondaryCaps;

  const BattleLog({
    this.events = const [],
    this.secondaryCaps = const ScoreCaps(),
  });

  BattleLog add(BattleEvent event) =>
      BattleLog(events: [...events, event], secondaryCaps: secondaryCaps);

  /// Undo. A pop, because state is derived rather than mutated.
  BattleLog undo() => events.isEmpty
      ? this
      : BattleLog(
          events: events.sublist(0, events.length - 1),
          secondaryCaps: secondaryCaps,
        );

  bool get canUndo => events.isNotEmpty;

  List<Map<String, Object?>> toJson() =>
      [for (final event in events) event.toJson()];

  static BattleLog fromJson(
    Object? value, {
    ScoreCaps secondaryCaps = const ScoreCaps(),
  }) {
    final list = value is List ? value : const [];
    return BattleLog(
      events: [
        for (final raw in list)
          if (BattleEvent.fromJson(raw) case final event?) event,
      ],
      secondaryCaps: secondaryCaps,
    );
  }

  BattleState get state {
    var round = 1;
    var activePlayer = Player.me;
    var cp = 0;
    final primary = {Player.me: <int, int>{}, Player.opponent: <int, int>{}};
    final secondary = {Player.me: <int, int>{}, Player.opponent: <int, int>{}};
    final units = <String, UnitState>{};
    final uses = <StratagemUse>[];

    final secondaryUsed = <String>{};
    final hand = <String>[];
    final scoredCards = <String, int>{};
    final discarded = <String>[];

    UnitState of(String id) => units[id] ?? const UnitState();

    for (final event in events) {
      switch (event) {
        case final SetRound e:
          round = e.round;
        case final SetActivePlayer e:
          activePlayer = e.player;
        case final AdjustCp e:
          cp = (cp + e.delta).clamp(0, 1 << 30);
        case final ScoreVp e:
          final table = e.kind == ScoreKind.primary
              ? primary[e.side]!
              : secondary[e.side]!;
          table[e.round] = (table[e.round] ?? 0) + e.vp;
        case final SetUnitStatus e:
          units[e.instanceId] = of(e.instanceId).copyWith(status: e.status);
        case final SetModelsRemaining e:
          units[e.instanceId] =
              of(e.instanceId).copyWith(modelsRemaining: e.models);
          if (e.models <= 0) {
            units[e.instanceId] =
                units[e.instanceId]!.copyWith(status: UnitStatus.destroyed);
          }
        case final SetUnitFlag e:
          final current = of(e.instanceId);
          units[e.instanceId] = current.copyWith(
            flags: {
              ...current.flags,
              if (e.value) e.flag,
            }..removeWhere((f) => f == e.flag && !e.value),
          );
        case final UseStratagem e:
          uses.add(StratagemUse(
            stratagemId: e.stratagemId,
            targetInstanceId: e.targetInstanceId,
            round: e.round,
            phase: e.phase,
            cp: e.cp,
          ));
          cp = (cp - e.cp).clamp(0, 1 << 30);
        case final UseOncePerBattle e:
          final current = of(e.instanceId);
          units[e.instanceId] = current.copyWith(
            oncePerBattleUsed: {...current.oncePerBattleUsed, e.abilityId},
          );
        case final DrawSecondary e:
          secondaryUsed.add(e.cardId);
          if (!hand.contains(e.cardId)) hand.add(e.cardId);
        case final DiscardSecondary e:
          hand.remove(e.cardId);
          discarded.add(e.cardId);
        case final ScoreSecondaryCard e:
          hand.remove(e.cardId);
          scoredCards[e.cardId] = e.vp;
          final table = secondary[Player.me]!;
          table[e.round] = (table[e.round] ?? 0) + e.vp;
      }
    }

    return BattleState(
      round: round,
      activePlayer: activePlayer,
      cp: cp,
      me: SideScore(
        primary: Map.unmodifiable(primary[Player.me]!),
        secondary: Map.unmodifiable(_capped(secondary[Player.me]!)),
      ),
      opponent: SideScore(
        primary: Map.unmodifiable(primary[Player.opponent]!),
        secondary: Map.unmodifiable(_capped(secondary[Player.opponent]!)),
      ),
      units: Map.unmodifiable(units),
      stratagemsUsed: List.unmodifiable(uses),
      secondaries: SecondaryState(
        used: Set.unmodifiable(secondaryUsed),
        hand: List.unmodifiable(hand),
        scored: Map.unmodifiable(scoredCards),
        discarded: List.unmodifiable(discarded),
      ),
    );
  }

  /// Applies the per-round then per-game cap, in round order so an early round
  /// keeps its points and a later one is trimmed.
  Map<int, int> _capped(Map<int, int> byRound) {
    final rounds = byRound.keys.toList()..sort();
    final out = <int, int>{};
    var running = 0;
    for (final round in rounds) {
      var vp = byRound[round]!.clamp(0, secondaryCaps.perRound);
      if (running + vp > secondaryCaps.perGame) {
        vp = secondaryCaps.perGame - running;
      }
      if (vp < 0) vp = 0;
      out[round] = vp;
      running += vp;
    }
    return out;
  }
}
