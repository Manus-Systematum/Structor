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
    terrainLayouts: read('core/terrain-layouts.json'),
    terrainTemplates: read('core/terrain-templates.json'),
  );
}

void main() {
  final root = Directory('../../data/40kdc');
  final available = root.existsSync();
  final pack = available ? loadPack(root.path) : const MissionPack();
  final skip = available ? null : 'no snapshot';

  group('the published tables', () {
    test('all forty-six load, from two community sources', () {
      expect(pack.terrainLayouts, hasLength(46));
      expect(pack.terrainLayouts.map((l) => l.sourceLabel).toSet(),
          {'Battlemaster', 'KOTC'});
    }, skip: skip);

    test('every piece resolves a shape', () {
      // Either by template reference or from its own inline footprint —
      // seventeen pieces publish the latter, so both paths have to work or
      // those pieces silently vanish from the drawing.
      var pieces = 0;
      for (final layout in pack.terrainLayouts) {
        for (final piece in layout.pieces) {
          if (piece.isObjective) continue;
          expect(piece.outline(pack.terrainTemplates), isNotEmpty,
              reason: '${layout.id}/${piece.id}');
          pieces++;
        }
      }
      // 470 at the current revision. The bound is loose enough to survive
      // upstream adding or trimming a layout, and tight enough to catch a
      // parse change that quietly empties the table.
      expect(pieces, greaterThan(400));
    }, skip: skip);

    test('every layout names a deployment pattern that exists', () {
      for (final layout in pack.terrainLayouts) {
        expect(pack.deployment(layout.deploymentPatternId), isNotNull,
            reason: layout.id);
      }
    }, skip: skip);
  });

  group('placement', () {
    test('pieces land on the board, which pins the transform', () {
      // Rotate about the template's own origin, *then* translate by position.
      // Rotating about the footprint's centroid instead shifts every layout
      // off the long edge, and the result still looks like a plausible table
      // — which is exactly why this is asserted rather than eyeballed.
      //
      // The tolerance is measured, not guessed: 633 of 745 pieces sit wholly
      // on the board, and the rest overhang an edge by at most 3.73", the
      // same figure repeating across layouts because it belongs to a handful
      // of edge templates. The diagram clips to the board, so an overhanging
      // piece is trimmed rather than drawn outside it.
      for (final layout in pack.terrainLayouts) {
        final board = pack.deployment(layout.deploymentPatternId)!.boardSize;
        for (final piece in layout.pieces) {
          for (final p in piece.outline(pack.terrainTemplates)) {
            expect(p.x, inInclusiveRange(-4, board.x + 4),
                reason: '${layout.id}/${piece.id}');
            expect(p.y, inInclusiveRange(-4, board.y + 4),
                reason: '${layout.id}/${piece.id}');
          }
        }
      }
    }, skip: skip);

    test('a rectangle template becomes four corners', () {
      // Nineteen templates publish width/height instead of points. Missing
      // this leaves those pieces invisible with nothing reporting an error.
      final piece = TerrainPiece.fromJson(const {
        'id': 'p',
        'template': 't',
        'position': {'x': 0, 'y': 0},
      });
      final outline = piece.outline({
        't': TerrainTemplate.fromJson(const {
          'id': 't',
          'name': 'T',
          'footprint': {'type': 'rectangle', 'width': 3.75, 'height': 4.5},
        }),
      });
      expect(outline, hasLength(4));
      expect(outline.map((p) => p.x).reduce((a, b) => a > b ? a : b), 3.75);
      expect(outline.map((p) => p.y).reduce((a, b) => a > b ? a : b), 4.5);
    });

    test('an unrotated piece is its template, moved', () {
      final piece = TerrainPiece.fromJson(const {
        'id': 'p',
        'template': 't',
        'position': {'x': 10, 'y': 5},
      });
      final outline = piece.outline({
        't': const TerrainTemplate(
          id: 't',
          name: 'T',
          footprint: [BoardPoint(0, 0), BoardPoint(2, 0), BoardPoint(2, 1)],
        ),
      });
      expect(outline.map((p) => '${p.x},${p.y}'),
          ['10.0,5.0', '12.0,5.0', '12.0,6.0']);
    });

    test('a quarter turn swaps the axes', () {
      final piece = TerrainPiece.fromJson(const {
        'id': 'p',
        'template': 't',
        'position': {'x': 0, 'y': 0},
        'rotation_degrees': 90,
      });
      final outline = piece.outline({
        't': const TerrainTemplate(
            id: 't', name: 'T', footprint: [BoardPoint(2, 0)]),
      });
      expect(outline.single.x, closeTo(0, 1e-9));
      expect(outline.single.y, closeTo(2, 1e-9));
    });

    test('an unresolvable shape draws nothing rather than a blob', () {
      final piece = TerrainPiece.fromJson(const {
        'id': 'p',
        'template': 'missing',
        'position': {'x': 3, 'y': 3},
      });
      expect(piece.outline(const {}), isEmpty);
    });
  });

  group('finding the table for a matchup', () {
    test('the lookup commutes, because the table does', () {
      // The mission table is asymmetric — (A vs B) and (B vs A) are different
      // missions — but the *terrain* is one physical table, and upstream
      // publishes each pairing once. Looking up only the declared order finds
      // nothing for ten of the twenty-five matchups.
      final forward = pack.layoutsFor(
          disposition: 'reconnaissance', opponentDisposition: 'take-and-hold');
      final reverse = pack.layoutsFor(
          disposition: 'take-and-hold', opponentDisposition: 'reconnaissance');

      expect(forward, isNotEmpty);
      expect(forward.map((l) => l.id), reverse.map((l) => l.id));
    }, skip: skip);

    test('every one of the twenty-five matchups has three tables', () {
      final dispositions = pack.allDispositions.map((d) => d.id).toList();
      expect(dispositions, hasLength(5));

      for (final mine in dispositions) {
        for (final theirs in dispositions) {
          final layouts = pack.layoutsFor(
              disposition: mine, opponentDisposition: theirs);
          expect(layouts, hasLength(3), reason: '$mine vs $theirs');
          expect(layouts.map((l) => l.variant), [1, 2, 3]);
        }
      }
    }, skip: skip);

    test('an unknown disposition finds nothing rather than throwing', () {
      expect(
        pack.layoutsFor(
            disposition: 'nonesuch', opponentDisposition: 'take-and-hold'),
        isEmpty,
      );
    }, skip: skip);
  });

  test('the chosen table is carried in the setup, and survives a round trip',
      () {
    const setup = MissionSetup(
      myDisposition: 'reconnaissance',
      opponentDisposition: 'take-and-hold',
      myMissionId: 'reconnaissance-sweep',
      opponentMissionId: 'purge-and-secure',
      deploymentId: 'tipping-point',
      terrainLayoutId: 'reconnaissance-vs-take-and-hold-2',
    );
    final restored =
        MissionSetup.fromJson(jsonDecode(jsonEncode(setup.toJson())));
    expect(restored.terrainLayoutId, 'reconnaissance-vs-take-and-hold-2');

    // Absent on a game set up before tables were bundled, which must read as
    // "no table chosen" rather than failing to load.
    final old = MissionSetup.fromJson(const {
      'myDisposition': 'a',
      'opponentDisposition': 'b',
      'myMissionId': 'm',
      'opponentMissionId': 'n',
    });
    expect(old.terrainLayoutId, isNull);
  });
}
