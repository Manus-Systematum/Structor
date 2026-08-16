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

/// A building placed inside a template's area — a ruin, a wall, a bastion.
///
/// This is the level the models actually stand in and shoot through. It is
/// nested one deeper than the piece: a layout places a *piece*, the piece's
/// template describes an **area terrain footprint**, and the buildings within
/// that area are its `features`. Drawing only the footprint gives you the
/// zone with nothing standing in it.
class TerrainFeature {
  final String id;

  /// The part template this feature's shape comes from.
  final String templateId;

  /// Placement within the parent template's local frame, not the board's.
  final BoardPoint position;
  final double rotationDegrees;

  const TerrainFeature({
    required this.id,
    required this.templateId,
    required this.position,
    this.rotationDegrees = 0,
  });

  factory TerrainFeature.fromJson(Object? v) {
    final j = asMap(v);
    return TerrainFeature(
      id: strOr(j['id'], ''),
      templateId: strOr(j['template'], ''),
      position: BoardPoint.fromJson(j['position']),
      rotationDegrees: dblOr(j['rotation_degrees'], 0),
    );
  }
}

/// A reusable piece shape, in inches, in its own local coordinates.
class TerrainTemplate {
  final String id;
  final String name;

  /// `area` for a terrain footprint, `feature` for a building part.
  final String kind;

  /// The area terrain boundary — the ground you are *within*, not the walls.
  final List<BoardPoint> footprint;

  /// The buildings standing in that area. 38 of the 69 templates have them.
  final List<TerrainFeature> features;

  const TerrainTemplate({
    required this.id,
    required this.name,
    this.kind = '',
    this.footprint = const [],
    this.features = const [],
  });

  factory TerrainTemplate.fromJson(Object? v) {
    final j = asMap(v);
    final kind = strOr(j['kind'], '');
    final isFeature = kind == 'feature';
    final footprint = _footprintOf(j['footprint'], centred: isFeature);
    return TerrainTemplate(
      id: strOr(j['id'], ''),
      name: strOr(j['name'], ''),
      kind: kind,
      // A feature's shape is already authored about its own origin. An area's
      // is anchored at a bounding-box corner and has to be recentred to join
      // the frame its buildings are placed in.
      footprint: isFeature ? footprint : _centreOnOrigin(footprint),
      features: asList(j['features']).map(TerrainFeature.fromJson).toList(),
    );
  }

  bool get isFeature => kind == 'feature';
}

/// Shifts a shape so its bounding box is centred on the origin.
///
/// **The two levels are authored in different frames.** A template's features
/// are placed around the origin — their cluster centre averages (0.5, 0.7)
/// across all 38 composites — while its area footprint is exported anchored
/// at a bounding-box *corner*, averaging (5.0, 3.3). Left as authored, every
/// base sits offset from the walls standing on it: only 20% of wall vertices
/// fall inside their own area, and the areas inflate 3.6″ past every board
/// edge while the walls stay within 3.5″..56.5″. Centring the footprint puts
/// the two in one frame — 84% containment, and an area extent of
/// 2.9″..57.1″ against the walls' 3.5″..56.5″.
List<BoardPoint> _centreOnOrigin(List<BoardPoint> points) {
  if (points.isEmpty) return points;
  var minX = points.first.x, maxX = points.first.x;
  var minY = points.first.y, maxY = points.first.y;
  for (final p in points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  final cx = (minX + maxX) / 2;
  final cy = (minY + maxY) / 2;
  return [for (final p in points) BoardPoint(p.x - cx, p.y - cy)];
}

/// Rotate about the origin, then translate. The one placement rule in this
/// file, applied at both levels: piece-within-board and feature-within-piece.
List<BoardPoint> _place(
  List<BoardPoint> points,
  BoardPoint origin,
  double degrees,
) {
  final radians = degrees * math.pi / 180.0;
  final cos = math.cos(radians);
  final sin = math.sin(radians);
  return [
    for (final p in points)
      BoardPoint(
        origin.x + p.x * cos - p.y * sin,
        origin.y + p.x * sin + p.y * cos,
      ),
  ];
}

/// A footprint, from either shape the source uses.
///
/// Nineteen of the sixty-nine templates are `width`/`height` rectangles
/// rather than polygons — the same split `BoardArea` handles for deployment
/// zones. Reading only `points` leaves those pieces with no outline, and a
/// piece with no outline is not an error anywhere: it simply does not appear
/// on the table.
///
/// **A rectangle's origin depends on what it is.** An `area` footprint is a
/// region authored from its corner, like a deployment zone. A `feature` is a
/// physical object — a wall, a container — and its placement names where the
/// object *sits*, so its rectangle is centred on the origin.
///
/// That is measured, not assumed: across all 46 layouts, centring feature
/// rectangles leaves 14 intersecting building pairs out of 17,010, and
/// corner-anchoring them leaves 152. Of the 14, twelve are parts of a single
/// composite ruin interlocking — which is how an L-shape is built out of
/// rectangles — and the remaining two are flush against each other at zero
/// depth.
List<BoardPoint> _footprintOf(Object? raw, {required bool centred}) {
  final shape = asMap(raw);
  if (strOr(shape['type'], '') == 'rectangle') {
    final w = dblOr(shape['width'], 0);
    final h = dblOr(shape['height'], 0);
    if (w <= 0 || h <= 0) return const [];
    if (centred) {
      return [
        BoardPoint(-w / 2, -h / 2),
        BoardPoint(w / 2, -h / 2),
        BoardPoint(w / 2, h / 2),
        BoardPoint(-w / 2, h / 2),
      ];
    }
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
      // A piece's own inline footprint is an area, never a building part, so
      // it is recentred like any other.
      footprint:
          _centreOnOrigin(_footprintOf(j['footprint'], centred: false)),
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
    return _place(local, position, rotationDegrees);
  }

  /// The buildings standing in this piece's area, in board coordinates.
  ///
  /// Two transforms composed: the feature sits in its template's local frame,
  /// and the template sits on the board. Empty for a piece whose template
  /// publishes no features — plenty of area terrain is just open ground.
  List<List<BoardPoint>> buildings(Map<String, TerrainTemplate> templates) {
    final template = templates[templateId];
    if (template == null) return const [];

    final out = <List<BoardPoint>>[];
    for (final feature in template.features) {
      final part = templates[feature.templateId]?.footprint;
      if (part == null || part.length < 3) continue;
      final inTemplate =
          _place(part, feature.position, feature.rotationDegrees);
      out.add(_place(inTemplate, position, rotationDegrees));
    }
    return out;
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
