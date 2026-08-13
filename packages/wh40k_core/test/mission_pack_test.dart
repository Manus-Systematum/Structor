import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:wh40k_core/wh40k_core.dart';

MissionPack loadPack(String root) {
  List<Object?> read(String path) {
    final file = File('$root/$path');
    if (!file.existsSync()) return const [];
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is List ? decoded : const [];
  }

  return MissionPack.fromJson(
    dispositions: read('core/force-dispositions.json'),
    missions: read('core/missions.json'),
    matchups: read('core/mission-matchups.json'),
    cards: read('core/secondary-cards.json'),
    deployments: read('core/deployment-patterns.json'),
  );
}

void main() {
  final root = Directory('../../data/40kdc');
  final available = root.existsSync();
  final pack = available ? loadPack(root.path) : const MissionPack();

  group('the matchup table', () {
    test('covers every ordered pair of dispositions', () {
      expect(pack.allDispositions, hasLength(5));
      expect(pack.matchups, hasLength(25), reason: '5 × 5 ordered pairs');
      expect(
        pack.matchups.map((m) => m.missionId).toSet(),
        hasLength(25),
        reason: 'one distinct mission per cell',
      );
    }, skip: available ? null : 'no snapshot');

    test('is asymmetric — both players play different primaries', () {
      final mine = pack.missionFor(
        disposition: 'reconnaissance',
        opponentDisposition: 'take-and-hold',
      );
      final theirs = pack.missionFor(
        disposition: 'take-and-hold',
        opponentDisposition: 'reconnaissance',
      );

      expect(mine?.name, 'Reconnaissance Sweep');
      expect(theirs?.name, 'Purge and Secure');
      expect(mine!.id, isNot(theirs!.id),
          reason: 'the table is ordered, not symmetric');
    }, skip: available ? null : 'no snapshot');

    test('mirrors sit on the diagonal', () {
      for (final disposition in pack.allDispositions) {
        final mirror = pack.missionFor(
          disposition: disposition.id,
          opponentDisposition: disposition.id,
        );
        expect(mirror, isNotNull, reason: disposition.id);
      }
      expect(
        pack.missionFor(
                disposition: 'reconnaissance',
                opponentDisposition: 'reconnaissance')
            ?.name,
        'Gather Intel',
      );
    }, skip: available ? null : 'no snapshot');

    test('an outcome carries the card text the player reads', () {
      final outcome = pack.outcomeFor(
        disposition: 'reconnaissance',
        opponentDisposition: 'take-and-hold',
      );
      expect(outcome.card, isNotNull);
      expect(outcome.card!.text, isNotEmpty);
      expect(outcome.card!.isPrimary, isTrue);
    }, skip: available ? null : 'no snapshot');
  });

  group('the decision grid', () {
    SourceDetachment detachment(String id, List<String> dispositions) =>
        SourceDetachment.fromJson({
          'id': id,
          'name': id,
          'force_dispositions': dispositions,
        });

    test('two detachments with different dispositions offer a choice', () {
      // The reference army: Advanced Acquisition Cadre is Reconnaissance,
      // Experimental Prototype Cadre is Priority Assets (§7.3.1).
      final available = pack.availableTo([
        detachment('aac', ['reconnaissance']),
        detachment('epc', ['priority-assets']),
      ]);
      expect(available.map((d) => d.id),
          containsAll(['reconnaissance', 'priority-assets']));
      expect(available, hasLength(2), reason: 'a real decision');
    }, skip: available ? null : 'no snapshot');

    test('detachments sharing a disposition offer no choice', () {
      final options = pack.availableTo([
        detachment('a', ['take-and-hold']),
        detachment('b', ['take-and-hold']),
      ]);
      expect(options, hasLength(1));
    }, skip: available ? null : 'no snapshot');

    test('the grid is my options by every opponent declaration', () {
      final mine = pack.availableTo([
        detachment('aac', ['reconnaissance']),
        detachment('epc', ['priority-assets']),
      ]);
      final grid = pack.grid(mine);

      expect(grid, hasLength(2));
      expect(grid.first, hasLength(5));
      expect(
        grid.expand((row) => row).every((cell) => cell.mission != null),
        isTrue,
        reason: 'every cell resolves',
      );

      // The two choices genuinely differ against the same opponent.
      final row = {for (final r in grid) r.first.disposition: r.first};
      expect(row['reconnaissance']!.mission!.id,
          isNot(row['priority-assets']!.mission!.id));
    }, skip: available ? null : 'no snapshot');
  });

  group('mission setup', () {
    const setup = MissionSetup(
      myDisposition: 'reconnaissance',
      opponentDisposition: 'take-and-hold',
      myMissionId: 'reconnaissance-sweep',
      opponentMissionId: 'purge-and-secure',
      deploymentId: 'tipping-point',
      twist: 'drew nothing',
      iAmAttacker: false,
      secondaryMode: SecondaryMode.fixed,
      opponentName: 'Dave',
    );

    test('round trips through JSON', () {
      final restored =
          MissionSetup.fromJson(jsonDecode(jsonEncode(setup.toJson())));
      expect(restored.myMissionId, 'reconnaissance-sweep');
      expect(restored.opponentMissionId, 'purge-and-secure');
      expect(restored.iAmAttacker, isFalse);
      expect(restored.secondaryMode, SecondaryMode.fixed);
      expect(restored.opponentName, 'Dave');
      expect(restored.isMirror, isFalse);
    });

    test('setup is carried in the battle log', () {
      final log = const BattleLog().add(const ConfigureBattle(setup));
      expect(log.state.setup?.myMissionId, 'reconnaissance-sweep');

      final restored = BattleLog.fromJson(jsonDecode(jsonEncode(log.toJson())));
      expect(restored.state.setup?.opponentMissionId, 'purge-and-secure');
      expect(restored.state.setup?.deploymentId, 'tipping-point');
    });

    test('undo removes the setup', () {
      final log = const BattleLog().add(const ConfigureBattle(setup));
      expect(log.undo().state.setup, isNull);
    });

    test('a mirror matchup is flagged', () {
      const mirror = MissionSetup(
        myDisposition: 'reconnaissance',
        opponentDisposition: 'reconnaissance',
        myMissionId: 'gather-intel',
        opponentMissionId: 'gather-intel',
      );
      expect(mirror.isMirror, isTrue);
    });
  });

  group('deployments and secondaries', () {
    test('deployment patterns load with their descriptions', () {
      expect(pack.deployments, isNotEmpty);
      expect(pack.deployments.first.name, isNotEmpty);
      expect(pack.deployments.first.description, isNotEmpty);
    }, skip: available ? null : 'no snapshot');

    test('eighteen secondaries, some requiring an action', () {
      expect(pack.secondaryCards, hasLength(18));
      expect(pack.secondaryCards.where((c) => c.requiresAction), isNotEmpty);
      expect(pack.secondaryCards.every((c) => c.text.isNotEmpty), isTrue);
    }, skip: available ? null : 'no snapshot');
  });
}
