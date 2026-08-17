import 'dart:convert';

import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

BattleLog logOf(List<BattleEvent> events) => BattleLog(events: events);

void main() {
  group('the log is the state', () {
    test('an empty log is the start of a game', () {
      const empty = BattleLog();
      expect(empty.state.round, 1);
      expect(empty.state.activePlayer, Player.me);
      expect(empty.state.cp, 0);
      expect(empty.canUndo, isFalse);
    });

    test('undo is a pop, and restores the previous state exactly', () {
      final log = logOf(const [
        SetRound(2),
        AdjustCp(3),
        SetActivePlayer(Player.opponent),
      ]);
      expect(log.state.cp, 3);
      expect(log.state.activePlayer, Player.opponent);

      final undone = log.undo();
      expect(undone.state.activePlayer, Player.me);
      expect(undone.state.cp, 3, reason: 'only the last event is removed');
      expect(undone.undo().state.cp, 0);
    });

    test('undoing an empty log is a no-op rather than an error', () {
      expect(const BattleLog().undo().events, isEmpty);
    });

    test('CP never goes negative', () {
      expect(logOf(const [AdjustCp(1), AdjustCp(-5)]).state.cp, 0);
    });
  });

  group('one stratagem per unit per phase', () {
    final log = logOf(const [
      SetRound(2),
      UseStratagem(
        stratagemId: 'overwatch',
        targetInstanceId: 'u01',
        round: 2,
        phase: 'shooting',
        cp: 1,
      ),
    ]);

    test('the rule is a query against round and phase', () {
      final state = log.state;
      expect(state.hasUsedStratagem('u01', phase: 'shooting'), isTrue);
      expect(state.hasUsedStratagem('u01', phase: 'fight'), isFalse,
          reason: 'a different phase in the same round is free');
      expect(state.hasUsedStratagem('u01', phase: 'shooting', round: 3), isFalse,
          reason: 'a later round is free');
      expect(state.hasUsedStratagem('u02', phase: 'shooting'), isFalse,
          reason: 'the rule is per unit');
    });

    test('nothing has to be cleared when the round advances', () {
      // The bug this design avoids: a "used this phase" list that must be
      // reset on transition, and greys a unit out forever when it is not.
      final later = log.add(const SetRound(3));
      expect(later.state.hasUsedStratagem('u01', phase: 'shooting'), isFalse);
      expect(later.state.stratagemsUsed, hasLength(1),
          reason: 'the history is kept; only the query moves on');
    });

    test('spending a stratagem deducts its CP', () {
      expect(logOf(const [
        AdjustCp(5),
        UseStratagem(
            stratagemId: 's', round: 1, phase: 'command', cp: 2),
      ]).state.cp, 3);
    });
  });

  group('units', () {
    test('casualties are recorded and feed the weapon table', () {
      final state = logOf(const [
        SetModelsRemaining(instanceId: 'u02', models: 2),
      ]).state;
      expect(state.unit('u02').modelsRemaining, 2);
      expect(state.modelsRemaining, {'u02': 2});
    });

    test('a unit at full strength is absent, not zero', () {
      // Absent means "use the roster figure"; recording a number would make
      // the aggregator scale against a guess.
      expect(const BattleLog().state.modelsRemaining, isEmpty);
      expect(const BattleLog().state.unit('u01').modelsRemaining, isNull);
    });

    test('losing the last model destroys the unit', () {
      final state =
          logOf(const [SetModelsRemaining(instanceId: 'u01', models: 0)]).state;
      expect(state.unit('u01').isDestroyed, isTrue);
    });

    test('flags set and clear', () {
      final on = logOf(const [
        SetUnitFlag(instanceId: 'u01', flag: UnitFlag.fellBack, value: true),
      ]);
      expect(on.state.unit('u01').has(UnitFlag.fellBack), isTrue);

      final off = on.add(const SetUnitFlag(
          instanceId: 'u01', flag: UnitFlag.fellBack, value: false));
      expect(off.state.unit('u01').has(UnitFlag.fellBack), isFalse);
    });

    test('once-per-battle abilities are remembered', () {
      final state = logOf(const [
        UseOncePerBattle(instanceId: 'u09', abilityId: 'homing-beacon'),
      ]).state;
      expect(state.unit('u09').oncePerBattleUsed, contains('homing-beacon'));
    });
  });

  group('scoring', () {
    test('both sides are tracked separately', () {
      final state = logOf(const [
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 10),
        ScoreVp(
            side: Player.opponent, kind: ScoreKind.primary, round: 1, vp: 6),
      ]).state;
      expect(state.me.total, 10);
      expect(state.opponent.total, 6);
    });

    test('secondaries cap per round', () {
      final state = logOf(const [
        ScoreVp(side: Player.me, kind: ScoreKind.secondary, round: 1, vp: 20),
      ]).state;
      expect(state.me.secondaryTotal, 15, reason: '15 per round');
    });

    test('secondaries cap per game, trimming later rounds', () {
      final state = logOf([
        for (var round = 1; round <= 5; round++)
          ScoreVp(
              side: Player.me,
              kind: ScoreKind.secondary,
              round: round,
              vp: 15),
      ]).state;
      expect(state.me.secondaryTotal, 45);
      expect(state.me.secondary[1], 15, reason: 'early rounds keep theirs');
      expect(state.me.secondary[4], 0, reason: 'the cap trims later rounds');
    });

    test('primary is not capped by the secondary limits', () {
      final state = logOf(const [
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 20),
      ]).state;
      expect(state.me.primaryTotal, 20);
    });

    test('a round cannot be driven below zero', () {
      // Scores are deltas so that undo and correction share one mechanism,
      // but correcting an over-count twice left the round owing points.
      final state = logOf(const [
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 5),
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: -5),
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: -5),
      ]).state;
      expect(state.me.primary[1], 0);
      expect(state.me.primaryTotal, 0);
    });

    test('a corrected round does not drag the total down', () {
      final state = logOf(const [
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 10),
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 2, vp: 3),
        ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 2, vp: -9),
      ]).state;
      expect(state.me.primary[2], 0, reason: 'round 2 bottoms out');
      expect(state.me.primaryTotal, 10, reason: 'round 1 is untouched');
    });

    test('a negative correction still works above zero', () {
      final state = logOf(const [
        ScoreVp(side: Player.me, kind: ScoreKind.secondary, round: 1, vp: 8),
        ScoreVp(side: Player.me, kind: ScoreKind.secondary, round: 1, vp: -3),
      ]).state;
      expect(state.me.secondary[1], 5);
    });
  });

  group('the secondary deck', () {
    test('draws accumulate in hand and are never re-drawn', () {
      final state = logOf(const [
        DrawSecondary('outflank'),
        DrawSecondary('cleanse'),
        DrawSecondary('outflank'),
      ]).state;
      expect(state.secondaries.hand, ['outflank', 'cleanse']);
      expect(state.secondaries.used, {'outflank', 'cleanse'});
    });

    test('a held card can be discarded at will', () {
      final state = logOf(const [
        DrawSecondary('plunder'),
        DiscardSecondary('plunder'),
      ]).state;
      expect(state.secondaries.hand, isEmpty);
      expect(state.secondaries.discarded, ['plunder']);
      expect(state.secondaries.used, contains('plunder'),
          reason: 'discarded is still drawn; it must not come back');
    });

    test('scoring a card removes it from hand and adds VP', () {
      final state = logOf(const [
        DrawSecondary('beacon'),
        ScoreSecondaryCard(cardId: 'beacon', round: 2, vp: 5),
      ]).state;
      expect(state.secondaries.hand, isEmpty);
      expect(state.secondaries.scored['beacon'], 5);
      expect(state.me.secondaryTotal, 5);
    });
  });

  group('persistence', () {
    test('a log round trips through JSON', () {
      final original = logOf(const [
        SetRound(3),
        SetActivePlayer(Player.opponent),
        AdjustCp(4),
        UseStratagem(
          stratagemId: 'overwatch',
          targetInstanceId: 'u01',
          round: 3,
          phase: 'shooting',
          cp: 1,
        ),
        SetModelsRemaining(instanceId: 'u02', models: 2),
        SetUnitFlag(
            instanceId: 'u03', flag: UnitFlag.battleShocked, value: true),
        DrawSecondary('cleanse'),
        ScoreSecondaryCard(cardId: 'cleanse', round: 3, vp: 4),
        ScoreVp(
            side: Player.opponent, kind: ScoreKind.primary, round: 3, vp: 8),
        UseOncePerBattle(instanceId: 'u09', abilityId: 'beacon'),
      ]);

      final restored =
          BattleLog.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored.events, hasLength(original.events.length));
      final a = original.state;
      final b = restored.state;
      expect(b.round, a.round);
      expect(b.activePlayer, a.activePlayer);
      expect(b.cp, a.cp);
      expect(b.me.total, a.me.total);
      expect(b.opponent.total, a.opponent.total);
      expect(b.unit('u02').modelsRemaining, 2);
      expect(b.unit('u03').has(UnitFlag.battleShocked), isTrue);
      expect(b.unit('u09').oncePerBattleUsed, contains('beacon'));
      expect(b.hasUsedStratagem('u01', phase: 'shooting'), isTrue);
    });

    test('an unrecognised event is skipped, not fatal', () {
      final log = BattleLog.fromJson([
        {'type': 'round', 'round': 4},
        {'type': 'from-a-later-version'},
      ]);
      expect(log.events, hasLength(1));
      expect(log.state.round, 4);
    });

    test('a game saved before the first-turn choice reads as "I went first"',
        () {
      // Every game played before the choice existed ran that way, so the old
      // default is the correct reading of the absent field rather than a
      // guess — and it keeps those games' rounds advancing on the right tap.
      final setup = MissionSetup.fromJson(const {
        'myDisposition': 'recon',
        'opponentDisposition': 'assault',
        'myMissionId': 'm1',
        'opponentMissionId': 'm2',
      });
      expect(setup.iGoFirst, isTrue);
    });
  });

  group('who goes first', () {
    MissionSetup setup({required bool iGoFirst}) => MissionSetup(
          myDisposition: 'recon',
          opponentDisposition: 'assault',
          myMissionId: 'm1',
          opponentMissionId: 'm2',
          iGoFirst: iGoFirst,
        );

    test('the opponent opening is the state the game starts in', () {
      final log = logOf([ConfigureBattle(setup(iGoFirst: false))]);
      expect(log.state.activePlayer, Player.opponent);
      expect(log.state.round, 1);
      expect(log.state.opener, Player.opponent);
    });

    test('and it survives a round trip', () {
      final log = logOf([ConfigureBattle(setup(iGoFirst: false))]);
      final restored =
          BattleLog.fromJson(jsonDecode(jsonEncode(log.toJson())));
      expect(restored.state.activePlayer, Player.opponent);
      expect(restored.state.setup?.iGoFirst, isFalse);
    });
  });

  group('the round advances on its own', () {
    BattleLog gameWhere({required bool iGoFirst}) => logOf([
          ConfigureBattle(MissionSetup(
            myDisposition: 'recon',
            opponentDisposition: 'assault',
            myMissionId: 'm1',
            opponentMissionId: 'm2',
            iGoFirst: iGoFirst,
          )),
        ]);

    test('a full cycle of turns is one battle round', () {
      var log = gameWhere(iGoFirst: true);
      expect(log.state.round, 1);

      // My turn ends: still round 1, because the opponent has not played.
      log = log.add(const SetActivePlayer(Player.opponent));
      expect(log.state.round, 1);

      // Theirs ends and the turn comes back to me — that is a battle round.
      log = log.add(const SetActivePlayer(Player.me));
      expect(log.state.round, 2);
      expect(log.state.activePlayer, Player.me);
    });

    test('and it counts from whoever opened, not from me', () {
      var log = gameWhere(iGoFirst: false);
      expect(log.state.activePlayer, Player.opponent);

      // Passing to me is the *first* half of round 1 here, not the end of it.
      log = log.add(const SetActivePlayer(Player.me));
      expect(log.state.round, 1,
          reason: 'the opponent opened, so my turn completes nothing');

      log = log.add(const SetActivePlayer(Player.opponent));
      expect(log.state.round, 2);
    });

    test('re-selecting the active player is not half a round', () {
      // A double tap on the toggle, or a rebuild replaying the same event.
      var log = gameWhere(iGoFirst: true)
          .add(const SetActivePlayer(Player.opponent))
          .add(const SetActivePlayer(Player.opponent));
      expect(log.state.round, 1);

      log = log.add(const SetActivePlayer(Player.me));
      expect(log.state.round, 2);
    });

    test('the game stops at five rounds rather than running on', () {
      var log = gameWhere(iGoFirst: true);
      for (var i = 0; i < 12; i++) {
        log = log.add(SetActivePlayer(
            log.state.activePlayer == Player.me
                ? Player.opponent
                : Player.me));
      }
      expect(log.state.round, 5);
    });

    test('the manual stepper still overrides, and counting resumes from it',
        () {
      // The correction path: the app and the table disagree, the player fixes
      // the number, and the automatic advance carries on from the new one
      // rather than snapping back.
      var log = gameWhere(iGoFirst: true).add(const SetRound(3));
      expect(log.state.round, 3);

      log = log
          .add(const SetActivePlayer(Player.opponent))
          .add(const SetActivePlayer(Player.me));
      expect(log.state.round, 4);
    });

    test('undo takes the round back with the turn', () {
      // The reason this is derived rather than stored: one pop puts both back,
      // with no inverse operation to get wrong.
      final log = gameWhere(iGoFirst: true)
          .add(const SetActivePlayer(Player.opponent))
          .add(const SetActivePlayer(Player.me));
      expect(log.state.round, 2);

      final undone = log.undo();
      expect(undone.state.round, 1);
      expect(undone.state.activePlayer, Player.opponent);
    });

    test('passing is announced before it is tapped', () {
      final log = gameWhere(iGoFirst: true);
      expect(log.state.passingEndsRound, isFalse,
          reason: 'my turn is the first half');

      final mid = log.add(const SetActivePlayer(Player.opponent));
      expect(mid.state.passingEndsRound, isTrue);
    });
  });
}
