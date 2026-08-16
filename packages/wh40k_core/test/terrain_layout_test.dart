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

    test('every piece resolves a shape, objective-bearing ones included', () {
      // Either by template reference or from its own inline footprint —
      // seventeen pieces publish the latter, so both paths have to work or
      // those pieces silently vanish from the drawing.
      //
      // **Counting objective pieces here is the point.** The first version of
      // this test skipped them, mirroring the renderer's own `continue`, and
      // so agreed with the bug: 275 of the 745 pieces carry an objective and
      // 270 of those are ruins, and every one was being dropped from the
      // table while the test stayed green.
      var pieces = 0;
      var withObjective = 0;
      for (final layout in pack.terrainLayouts) {
        for (final piece in layout.pieces) {
          if (piece.isObjective) withObjective++;
          if (piece.templateId.isEmpty && piece.footprint.isEmpty) continue;
          expect(piece.outline(pack.terrainTemplates), isNotEmpty,
              reason: '${layout.id}/${piece.id}');
          pieces++;
        }
      }
      // 740 of 745 at the current revision — five objective markers publish
      // no shape at all, which is the only legitimate reason to draw none.
      expect(pieces, greaterThan(700));
      expect(withObjective, greaterThan(250));
    }, skip: skip);

    test('an objective is usually a building, not a bare marker', () {
      // The user-visible symptom of getting this wrong: circles floating
      // where the ruins should be, and a third of the table missing.
      final objectives = [
        for (final layout in pack.terrainLayouts)
          for (final piece in layout.pieces)
            if (piece.isObjective) piece,
      ];
      final drawable = objectives
          .where((p) => p.outline(pack.terrainTemplates).length >= 3)
          .length;
      expect(objectives, hasLength(275));
      expect(drawable, greaterThan(250),
          reason: 'the objective sits *in* the ruin');
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

    test('buildings on separate pieces do not intersect', () {
      // The symptom that found this: ruins overlapping each other on screen.
      // A `feature` rectangle names where the object *sits*, so it is centred
      // on its origin; anchoring it at a corner shifts every wall by half its
      // own size and pushes 152 building pairs into each other.
      //
      // Parts *within* one composite are allowed to overlap — that is how an
      // L-shape is built out of rectangles — so only cross-piece pairs count.
      bool inside(BoardPoint p, List<BoardPoint> poly) {
        var hit = false;
        for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
          final a = poly[i];
          final b = poly[j];
          if ((a.y > p.y) != (b.y > p.y) &&
              p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
            hit = !hit;
          }
        }
        return hit;
      }

      var crossPieceOverlaps = 0;
      for (final layout in pack.terrainLayouts) {
        final walls = <(String, List<BoardPoint>)>[];
        for (final piece in layout.pieces) {
          for (final building in piece.buildings(pack.terrainTemplates)) {
            walls.add((piece.id, building));
          }
        }
        for (var i = 0; i < walls.length; i++) {
          for (var j = i + 1; j < walls.length; j++) {
            final (idA, a) = walls[i];
            final (idB, b) = walls[j];
            if (idA == idB) continue;
            if (a.any((p) => inside(p, b)) || b.any((p) => inside(p, a))) {
              crossPieceOverlaps++;
            }
          }
        }
      }
      // Two, both flush against a neighbour at zero penetration depth.
      expect(crossPieceOverlaps, lessThanOrEqualTo(2));
    }, skip: skip);

    test('a feature rectangle is centred, an area rectangle is not', () {
      final feature = TerrainTemplate.fromJson(const {
        'id': 'f',
        'name': 'wall',
        'kind': 'feature',
        'footprint': {'type': 'rectangle', 'width': 4, 'height': 2},
      });
      expect(feature.footprint.map((p) => p.x).reduce((a, b) => a < b ? a : b),
          -2);

      final area = TerrainTemplate.fromJson(const {
        'id': 'a',
        'name': 'ground',
        'kind': 'area',
        'footprint': {'type': 'rectangle', 'width': 4, 'height': 2},
      });
      expect(
          area.footprint.map((p) => p.x).reduce((a, b) => a < b ? a : b), 0);
    });

    test('a building is placed through both frames', () {
      // Feature-within-template, then template-within-board. Getting either
      // transform alone puts the walls somewhere plausible and wrong.
      final templates = {
        'area': TerrainTemplate.fromJson(const {
          'id': 'area',
          'kind': 'area',
          'footprint': {
            'points': [
              {'x': 0, 'y': 0},
              {'x': 10, 'y': 0},
              {'x': 10, 'y': 10},
            ],
          },
          'features': [
            {
              'id': 'f1',
              'template': 'wall',
              'position': {'x': 2, 'y': 0},
            },
          ],
        }),
        'wall': TerrainTemplate.fromJson(const {
          'id': 'wall',
          'kind': 'feature',
          'footprint': {'type': 'rectangle', 'width': 2, 'height': 2},
        }),
      };

      final piece = TerrainPiece.fromJson(const {
        'id': 'p',
        'template': 'area',
        'position': {'x': 100, 'y': 50},
      });
      final walls = piece.buildings(templates);
      expect(walls, hasLength(1));
      // Centred 2x2 at feature offset (2,0), piece offset (100,50).
      expect(walls.single.map((p) => p.x), containsAll([101.0, 103.0]));
      expect(walls.single.map((p) => p.y), containsAll([49.0, 51.0]));
    });

    test('a piece whose template has no features has no buildings', () {
      final piece = TerrainPiece.fromJson(const {
        'id': 'p',
        'template': 't',
        'position': {'x': 0, 'y': 0},
      });
      expect(
        piece.buildings({
          't': const TerrainTemplate(id: 't', name: 'T', footprint: [
            BoardPoint(0, 0),
            BoardPoint(1, 0),
            BoardPoint(1, 1),
          ]),
        }),
        isEmpty,
      );
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
