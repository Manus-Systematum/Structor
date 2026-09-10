import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/deployment_diagram.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// §7.3.23. The zone shading belongs under the terrain — that is the whole
/// point of the layering — but the word naming the zone does not.
///
/// On `Purge vs Assets 02` a ruin sits on the centroid of both deployment
/// zones, and "THEM" was printed underneath a wall with `CD` stamped across
/// the M. The fixture below reproduces that arrangement rather than the
/// published table: one piece, centred exactly where the caption goes.
void main() {
  // `boardSize` is the bounding box of everything in the pattern, so a
  // territory covering the table is what makes it 60 by 44.
  DeploymentPattern patternWithZoneAt(BoardPoint centre) => DeploymentPattern(
        id: 'test',
        name: 'Test',
        description: '',
        territories: const [
          BoardArea(player: 'attacker', points: [
            BoardPoint(0, 0),
            BoardPoint(60, 0),
            BoardPoint(60, 44),
            BoardPoint(0, 44),
          ]),
        ],
        zones: [
          BoardArea(
            player: 'attacker',
            points: [
              BoardPoint(centre.x - 8, centre.y - 6),
              BoardPoint(centre.x + 8, centre.y - 6),
              BoardPoint(centre.x + 8, centre.y + 6),
              BoardPoint(centre.x - 8, centre.y + 6),
            ],
          ),
        ],
      );

  /// A single solid piece, sitting on the same spot as the caption.
  (TerrainLayout, Map<String, TerrainTemplate>) terrainAt(BoardPoint centre) {
    const template = TerrainTemplate(
      id: 'slab',
      name: 'Slab',
      kind: 'area',
      footprint: [
        BoardPoint(0, 0),
        BoardPoint(10, 0),
        BoardPoint(10, 8),
        BoardPoint(0, 8),
      ],
    );
    return (
      TerrainLayout(
        id: 'test-layout',
        name: 'Test Layout',
        pieces: [
          TerrainPiece.fromJson({
            'id': 'p1',
            'template': 'slab',
            'position': {'x': centre.x, 'y': centre.y},
          }),
        ],
      ),
      {'slab': template},
    );
  }

  testWidgets('the zone caption is drawn over the terrain, not under it',
      (tester) async {
    const centre = BoardPoint(30, 22);
    final (layout, templates) = terrainAt(centre);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            // Tall enough for the board plus the legend under it;
            // 440 leaves the diagram's own Column 22 pixels short.
            width: 600,
            height: 560,
            child: DeploymentDiagram(
              pattern: patternWithZoneAt(centre),
              iAmAttacker: true,
              layout: layout,
              templates: templates,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // **Recorded, because the `paints` matcher cannot say this.** It matches
    // a *subsequence*: the zone's own fill is a path drawn before the caption
    // either way, so `..path()..paragraph()` passes with the bug in place —
    // it did, which is how this test came to record the calls itself.
    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<CustomPainter>()
        .first;

    final calls = <String>[];
    painter.paint(_Recorder(calls), const Size(600, 440));

    expect(calls, contains('drawParagraph'));
    expect(calls, contains('drawPath'));
    expect(
      calls.lastIndexOf('drawPath'),
      lessThan(calls.indexOf('drawParagraph')),
      reason: 'the caption is painted under terrain drawn after it',
    );
  });
}

/// Notes which painting calls were made, in order, and does nothing else.
class _Recorder implements Canvas {
  final List<String> calls;

  _Recorder(this.calls);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      calls.add(invocation.memberName.toString().replaceAll(
          RegExp(r'^Symbol\("|"\)$'), ''));
    }
    return null;
  }
}
