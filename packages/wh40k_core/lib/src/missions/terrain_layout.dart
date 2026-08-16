/// Competitive terrain layouts — the actual table, not just the zones
/// (DESIGN.md §7.3.1).
///
/// A deployment pattern says where the two armies set up. It says nothing
/// about the ruins, and in 11e the terrain is what the game is played around:
/// the same pattern with different terrain is a different game. The layouts
/// place every piece by position and rotation against a shared library of
/// templates, so the table can be drawn rather than described.
///
/// **These are Battlemaster layouts, not Chapter Approved ones.** Upstream
/// publishes 45 from `battlemaster-11e` and one from `kotc`, and no Chapter
/// Approved set at all — the missions carry that source, the terrain does
/// not. The UI names the source rather than implying otherwise (§7.6).
library;

import 'dart:math' as math;

import '../source/json.dart';
import 'mission_pack.dart';

/// A reusable piece shape, in inches, in its own local coordinates.
class TerrainTemplate {
  final String id;
  final String name;

  /// `area`, `ruin`, `barricade` — what kind of terrain the piece is.
  final String kind;

  final List<BoardPoint> footprint;

  const TerrainTemplate({
    required this.id,
    required this.name,
    this.kind = '',
    this.footprint = const [],
  });

  factory TerrainTemplate.fromJson(Object? v) {
    final j = asMap(v);
    return TerrainTemplate(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      kind: strOr(j['kind'], ''),
      footprint: _footprintOf(j['footprint']),
    );
  }
}

/// A footprint, from either shape the source uses.
///
/// Nineteen of the sixty-nine templates are `width`/`height` rectangles
/// rather than polygons — the same split `BoardArea` handles for deployment
/// zones. Reading only `points` leaves those pieces with no outline, and a
/// piece with no outline is not an error anywhere: it simply does not appear
/// on the table.
List<BoardPoint> _footprintOf(Object? raw) {
  final shape = asMap(raw);
  if (strOr(shape['type'], '') == 'rectangle') {
    final w = dblOr(shape['width'], 0);
    final h = dblOr(shape['height'], 0);
    if (w <= 0 || h <= 0) return const [];
    return [
      const BoardPoint(0, 0),
      BoardPoint(w, 0),
      BoardPoint(w, h),
      BoardPoint(0, h),
    ];
  }
  return asList(shape['points']).map(BoardPoint.fromJson).toList();
}

/// One piece on the table.
///
/// Placement is **rotate about the template's own origin, then translate by
/// `position`** — verified against the shipped layouts, where that convention
/// lands every piece on the 60×44 board and rotating about the footprint's
/// centroid does not.
class TerrainPiece {
  final String id;
  final String name;
  final String pieceType;

  /// The shared shape this piece uses, or empty when it carries its own.
  final String templateId;

  /// A shape published inline instead of by reference. Seventeen pieces do
  /// this, so both paths have to work.
  final List<BoardPoint> footprint;

  final BoardPoint position;
  final double rotationDegrees;

  /// Some pieces *are* the objective markers, rather than terrain near one.
  final bool isObjective;

  const TerrainPiece({
    required this.id,
    required this.position,
    this.name = '',
    this.pieceType = '',
    this.templateId = '',
    this.footprint = const [],
    this.rotationDegrees = 0,
    this.isObjective = false,
  });

  factory TerrainPiece.fromJson(Object? v) {
    final j = asMap(v);
    return TerrainPiece(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      pieceType: strOr(j['piece_type'], ''),
      templateId: strOr(j['template'], ''),
      footprint: _footprintOf(j['footprint']),
      position: BoardPoint.fromJson(j['position']),
      // Absent on a quarter of the pieces, which simply means unrotated.
      rotationDegrees: dblOr(j['rotation_degrees'], 0),
      isObjective: j['is_objective'] == true,
    );
  }

  /// This piece's outline in board coordinates, given the template library.
  ///
  /// Empty when the shape cannot be resolved, so a caller draws nothing
  /// rather than a degenerate blob at the origin.
  List<BoardPoint> outline(Map<String, TerrainTemplate> templates) {
    final local =
        footprint.isNotEmpty ? footprint : templates[templateId]?.footprint;
    if (local == null || local.isEmpty) return const [];

    final radians = rotationDegrees * math.pi / 180.0;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return [
      for (final p in local)
        BoardPoint(
          position.x + p.x * cos - p.y * sin,
          position.y + p.x * sin + p.y * cos,
        ),
    ];
  }
}

/// One published table: a deployment pattern plus every piece on it.
class TerrainLayout {
  final String id;
  final String name;
  final String description;

  /// `battlemaster-11e` or `kotc`. Surfaced rather than hidden — a player
  /// choosing a table wants to know whose layout it is.
  final String source;

  /// The pairing this table is published for. **Unordered**: the physical
  /// table is the same whichever player declared which disposition, so
  /// `a-vs-b` covers `b-vs-a` too (see [MissionPack.layoutsFor]).
  final String missionMatchupId;

  final int variant;
  final String deploymentPatternId;
  final List<TerrainPiece> pieces;

  const TerrainLayout({
    required this.id,
    required this.name,
    this.description = '',
    this.source = '',
    this.missionMatchupId = '',
    this.variant = 0,
    this.deploymentPatternId = '',
    this.pieces = const [],
  });

  factory TerrainLayout.fromJson(Object? v) {
    final j = asMap(v);
    return TerrainLayout(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      description: strOr(j['description'], ''),
      source: strOr(j['source'], ''),
      missionMatchupId: strOr(j['mission_matchup_id'], ''),
      variant: intOr(j['variant'], 0),
      deploymentPatternId: strOr(j['deployment_pattern_id'], ''),
      pieces: asList(j['pieces']).map(TerrainPiece.fromJson).toList(),
    );
  }

  /// A short label for the source, for a UI that must not imply these are
  /// Games Workshop's own competitive layouts.
  String get sourceLabel => switch (source) {
        'battlemaster-11e' => 'Battlemaster',
        'kotc' => 'KOTC',
        '' => 'Unattributed',
        _ => source,
      };
}
