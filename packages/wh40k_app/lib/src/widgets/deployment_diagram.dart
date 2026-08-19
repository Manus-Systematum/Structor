import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// The table, drawn (DESIGN.md §7.3.1).
///
/// A deployment pattern is a *shape*, and "Short edge deployment with L-shaped
/// zones" is a sentence describing one. The source publishes the actual
/// polygons, so the picture is data rather than an illustration somebody has
/// to keep in step with the rules.
///
/// **Your zone is named, not just coloured.** The pattern is symmetric under
/// attacker/defender, so the only thing that makes one half yours is the
/// declaration made two steps earlier in the wizard — and that is exactly what
/// nobody remembers while unpacking models.
class DeploymentDiagram extends StatefulWidget {
  final DeploymentPattern pattern;

  /// Which half is yours. Flips the labels, never the geometry.
  final bool iAmAttacker;

  /// The table's terrain, when a published layout has been chosen. Without
  /// one the diagram is still the zones, which is what it was before layouts
  /// were bundled.
  final TerrainLayout? layout;

  final Map<String, TerrainTemplate> templates;

  /// Draws a ruler along the edges and a distance to each piece.
  ///
  /// Off in the inline diagram, which is a picture of the shape, and on in
  /// the full-screen one, which is the thing you set the table out from —
  /// where "roughly there" is not good enough and a tape measure is already
  /// in your hand.
  final bool measured;

  /// Turns the board a quarter so its long edge runs down the screen.
  ///
  /// A phone is tall and a table is wide, and the mismatch is expensive: the
  /// standard 60×44 board drawn upright in the full-screen dialog fills 44%
  /// of the height available to it and renders at 6.3 pixels to the inch.
  /// Turned, the same board fills 82% and renders at 8.6 — **1.36× larger,
  /// which is exactly the board's own aspect ratio**, on 45 of the 46 shipped
  /// layouts.
  ///
  /// **The geometry is turned, the writing is not.** The numbers are the point
  /// of the measured view, and a number you have to tilt your head to read is
  /// worse than a smaller upright one. Turning the phone instead was measured
  /// and is the worst of the three: the app bar and the caption eat the short
  /// dimension, leaving 5.1 pixels to the inch.
  ///
  /// Ignored for a square board — `kotc-colosseum` is 36×36, where a quarter
  /// turn is the identity and pretending otherwise would just relabel the
  /// edges.
  final bool turned;

  /// Lets the board be pinched and panned.
  ///
  /// Zoom is what makes the *labels* readable, and it is a different fix from
  /// turning. Across the 46 shipped layouts 33 pairs of measurement numbers
  /// overlap at the size they are first drawn; turning cuts that to 21, and
  /// **1.5× clears every one of them**.
  ///
  /// That only holds because the board magnifies and the writing does not.
  /// A plain transform scales the numbers along with the geometry, so two
  /// overlapping labels stay overlapping however far you zoom in — bigger,
  /// and still on top of each other.
  final bool zoomable;

  const DeploymentDiagram({
    super.key,
    required this.pattern,
    required this.iAmAttacker,
    this.layout,
    this.templates = const {},
    this.measured = false,
    this.turned = false,
    this.zoomable = false,
  });

  @override
  State<DeploymentDiagram> createState() => _DeploymentDiagramState();
}

class _DeploymentDiagramState extends State<DeploymentDiagram> {
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pattern = widget.pattern;
    final size = pattern.boardSize;
    if (!pattern.hasGeometry || size.x <= 0 || size.y <= 0) {
      return const SizedBox.shrink();
    }

    // A square table gains nothing from being turned, so it is not.
    final turned = widget.turned && size.x > size.y;

    Widget board(double zoom) => CustomPaint(
          painter: _BoardPainter(
            pattern: pattern,
            iAmAttacker: widget.iAmAttacker,
            layout: widget.layout,
            templates: widget.templates,
            measured: widget.measured,
            turned: turned,
            zoom: zoom,
            outline: scheme.outline,
            terrain: scheme.onSurfaceVariant,
            objectiveFill: scheme.onSurface,
            objectiveRing: scheme.surface,
            measure: scheme.primary,
          ),
          child: const SizedBox.expand(),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The board's own proportions, so a 60×44 table is not stretched to
        // whatever box the layout happens to give it.
        AspectRatio(
          aspectRatio: turned ? size.y / size.x : size.x / size.y,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.zoomable
                  ? InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1,
                      maxScale: 6,
                      child: AnimatedBuilder(
                        animation: _zoom,
                        // Repainted at the live scale rather than merely
                        // transformed, so the writing keeps its size while
                        // the table grows under it.
                        builder: (_, __) =>
                            board(_zoom.value.getMaxScaleOnAxis()),
                      ),
                    )
                  : board(1),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _Key(
              label: 'You',
              color: _zoneColor(widget.iAmAttacker),
              emphasised: true,
            ),
            const SizedBox(width: 14),
            _Key(label: 'Opponent', color: _zoneColor(!widget.iAmAttacker)),
            const Spacer(),
            Text(
              [
                '${_inches(size.x)}″ × ${_inches(size.y)}″',
                if (widget.layout case final table?) ...[
                  '${table.pieces.length} pieces',
                  '${table.pieces.where((p) => p.isObjective).length} '
                      'objectives',
                ] else if (pattern.objectives.isNotEmpty)
                  '${pattern.objectives.length} objectives',
              ].join(' · '),
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Color _zoneColor(bool attacker) {
    final raw = widget.pattern.zoneFor(attacker: attacker)?.color;
    return raw == null
        ? (attacker ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
        : Color(raw);
  }

  static String _inches(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Board inches to canvas pixels.
///
/// **Board `y` runs down the screen, not up** (DESIGN.md §7.3.1). This was
/// the other way round until it was checked against Battlemaster's published
/// picture of a table, and the whole map — terrain, deployment zones and
/// territories alike — came out mirrored. Three sources (`battlemaster-11e`,
/// `gw-11e`, `leviathan`) reflected the same way at once, which points at the
/// one thing they share rather than at any of them.
///
/// A mirrored map is the worst kind of wrong: it is a perfectly plausible
/// picture of a table that is not the one published, and the only way to find
/// out is to set the terrain out and lose the game.
///
/// **Turned, the board is rotated a quarter clockwise** — its `y = 0` edge
/// becomes the screen's right edge, its `x = 0` edge becomes the top.
///
/// The two projections must have the *same* handedness or one of them is a
/// mirror of the other. The test for that is the sign of the Jacobian
/// determinant, not where the corners land: several arrangements put the
/// board neatly in its box and only half of them are rotations.
@visibleForTesting
Offset projectOnto(
  BoardPoint p, {
  required Size canvas,
  required BoardPoint board,
  required bool turned,
}) {
  final scale = canvas.width / (turned ? board.y : board.x);
  return turned
      ? Offset(canvas.width - p.y * scale, p.x * scale)
      : Offset(p.x * scale, p.y * scale);
}

/// Where a piece's marking goes inside its own outline, or null for nowhere.
///
/// **The objective marker wins the middle.** An objective sitting in a ruin is
/// the one thing on the table you must still be able to find, so where the two
/// want the same spot the writing moves and the marker does not. Drawing the
/// label over the marker instead loses both: `Gen⊙tor`.
///
/// Centre first, then below the marker, then above it. Null when none of the
/// three fits, which is not a failure — a 0.5" barrier has never had room for
/// a word, and a label spilling past its own piece labels its neighbour.
@visibleForTesting
Offset? labelSpot({
  required Rect bounds,
  required Size label,
  required Offset? marker,
  required double markerRadius,
  required double margin,
}) {
  final half = Offset(label.width / 2, label.height / 2);
  final clear = markerRadius + label.height / 2 + margin;
  final room = bounds.deflate(margin / 2);
  for (final centre in [
    bounds.center,
    if (marker != null) ...[
      Offset(bounds.center.dx, marker.dy + clear),
      Offset(bounds.center.dx, marker.dy - clear),
    ],
  ]) {
    final at = centre - half;
    final box = Rect.fromLTWH(at.dx, at.dy, label.width, label.height);
    if (marker != null && box.inflate(margin).contains(marker)) continue;
    if (!room.contains(box.topLeft) || !room.contains(box.bottomRight)) {
      continue;
    }
    return at;
  }
  return null;
}

class _BoardPainter extends CustomPainter {
  final DeploymentPattern pattern;
  final bool iAmAttacker;
  final TerrainLayout? layout;
  final Map<String, TerrainTemplate> templates;
  final bool measured;

  /// Board x runs down the screen and board y runs across it.
  final bool turned;

  /// The magnification the board is currently being viewed at.
  ///
  /// Everything on this diagram is one of two kinds of length: **board
  /// lengths**, which are inches and must grow with the zoom, and **paper
  /// lengths** — text, hairlines, the dashes in a leader line, the gap a
  /// number sits off its anchor — which are properties of the page and must
  /// not. Paper lengths go through [_px], which divides out the transform
  /// the viewer has already applied.
  final double zoom;

  final Color outline;
  final Color terrain;
  final Color objectiveFill;
  final Color objectiveRing;

  /// The measuring colour, used for nothing else on the board.
  ///
  /// A distance drawn in the terrain's own colour reads as part of the
  /// terrain. These lines are the one thing on the diagram that is not a
  /// physical object, so they say so.
  final Color measure;

  _BoardPainter({
    required this.pattern,
    required this.iAmAttacker,
    required this.layout,
    required this.templates,
    required this.measured,
    required this.turned,
    required this.zoom,
    required this.outline,
    required this.terrain,
    required this.objectiveFill,
    required this.objectiveRing,
    required this.measure,
  });

  /// A paper length: the same size on screen whatever the zoom.
  double _px(double v) => v / zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final board = pattern.boardSize;
    if (board.x <= 0 || board.y <= 0) return;

    Offset project(BoardPoint p) =>
        projectOnto(p, canvas: size, board: board, turned: turned);

    Path pathOf(BoardArea area) {
      final path = Path();
      for (var i = 0; i < area.points.length; i++) {
        final o = project(area.points[i]);
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      return path..close();
    }

    // Territories first and faint — they are the larger halves the deployment
    // zones sit inside, and drawn at equal weight they swamp the zones.
    for (final territory in pattern.territories) {
      final color = Color(territory.color ?? _fallback(territory.isAttacker));
      canvas.drawPath(
        pathOf(territory),
        Paint()..color = color.withValues(alpha: 0.10),
      );
    }

    for (final zone in pattern.zones) {
      final mine = zone.isAttacker == iAmAttacker;
      final color = Color(zone.color ?? _fallback(zone.isAttacker));
      final path = pathOf(zone);
      canvas.drawPath(
        path,
        Paint()..color = color.withValues(alpha: mine ? 0.34 : 0.20),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: mine ? 1 : 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _px(mine ? 2 : 1),
      );
      _label(
          canvas, _centroid(zone, project), mine ? 'YOU' : 'THEM', color, mine);
    }

    // Terrain sits above the zones and below the objective markers: it is what
    // the zones are *for*, and an objective inside a ruin is the one thing on
    // the table you must still be able to find.
    //
    // **Objective-bearing pieces are terrain too.** 275 of the 745 pieces
    // carry an objective and 270 of those are buildings — the objective sits
    // *in* the ruin. Skipping them because they are flagged as objectives
    // dropped a third of every table and left bare circles floating where the
    // ruins should be.
    final table = layout;
    if (table != null) {
      Path? pathOfPoints(List<BoardPoint> points) {
        if (points.length < 3) return null;
        final path = Path();
        for (var i = 0; i < points.length; i++) {
          final o = project(points[i]);
          i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
        }
        return path..close();
      }

      // Two levels, drawn in order. The area terrain footprint is the ground
      // you are *within* — faint, because it is a zone rather than an object.
      // The buildings standing in it are solid, because they are what blocks
      // line of sight and what the models climb.
      for (final piece in table.pieces) {
        if (pathOfPoints(piece.outline(templates)) case final area?) {
          canvas.drawPath(
            area,
            Paint()..color = terrain.withValues(alpha: 0.10),
          );
          canvas.drawPath(
            area,
            Paint()
              ..color = terrain.withValues(alpha: 0.30)
              ..style = PaintingStyle.stroke
              ..strokeWidth = _px(0.6),
          );
        }
      }

      for (final piece in table.pieces) {
        for (final building in piece.buildings(templates)) {
          if (pathOfPoints(building.outline) case final path?) {
            canvas.drawPath(
              path,
              Paint()..color = terrain.withValues(alpha: 0.55),
            );
            canvas.drawPath(
              path,
              Paint()
                ..color = terrain.withValues(alpha: 0.9)
                ..style = PaintingStyle.stroke
                ..strokeWidth = _px(0.8),
            );
            // The corner tick, showing which way the piece is turned. The
            // published footprint is a symmetric box, so without this the
            // rotation the data carries is invisible — and these pieces are
            // L-shaped, so the turn is the thing you need to copy.
            final mark = building.cornerMark;
            if (mark.length >= 3) {
              final tick = Path();
              for (var i = 0; i < mark.length; i++) {
                final o = project(mark[i]);
                i == 0 ? tick.moveTo(o.dx, o.dy) : tick.lineTo(o.dx, o.dy);
              }
              canvas.drawPath(
                tick,
                Paint()
                  ..color = objectiveRing
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = _px(1.8)
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round,
              );
            }

            // The letter the physical piece is marked with, so the diagram
            // can be followed while setting the real terrain out. Drawn only
            // where it fits: a 0.5"-thick barrier has no room for a word, and
            // a label spilling past its own piece labels its neighbour.
            _pieceLabel(
              canvas,
              path.getBounds(),
              building.label,
              // 270 of the 275 objective-bearing pieces are ruins, so a
              // marker landing on this label is the common case, not a
              // corner one.
              marker: piece.isObjective ? project(piece.position) : null,
            );
          }
        }
      }
    }

    // A layout places its own objective markers; the pattern's are the
    // fallback for a table with no layout chosen. Drawing both double-marks
    // every objective.
    final objectives = table == null
        ? pattern.objectives
        : [
            for (final piece in table.pieces)
              if (piece.isObjective) piece.position,
          ];

    // A grid, and every piece's distance to its two nearest edges.
    //
    // Setting a table out is done with a tape hooked over an edge, so the
    // number that helps is one you can actually pull: across to the nearer
    // side edge, and up or down to the nearer end. A centre coordinate — what
    // this printed first — names the one point on a piece you cannot put a
    // tape on.
    if (measured) {
      const step = 3.0;

      // Every 3", labelled every 6". The fine lines are for counting across;
      // a number on each of nineteen of them is unreadable at this size.
      final minor = Paint()
        ..color = outline.withValues(alpha: 0.10)
        ..strokeWidth = _px(0.5);
      final major = Paint()
        ..color = outline.withValues(alpha: 0.22)
        ..strokeWidth = _px(0.5);

      // Drawn end to end in **board** coordinates, so one expression serves
      // both orientations: a line of constant x is vertical upright and
      // horizontal turned, and `project` already knows which.
      // A ruler belongs to the canvas edge, not to a board edge — which one
      // of those is at the bottom depends on the orientation, and anchoring
      // on the board put the numbers off-screen when the projection flipped.
      void ruler(Offset a, Offset b, String text) {
        final vertical = (a.dx - b.dx).abs() < 0.5;
        _tick(
          canvas,
          vertical
              ? Offset(a.dx + _px(2), size.height - _px(11))
              : Offset(_px(3), a.dy - _px(11)),
          text,
        );
      }

      for (var x = step; x < board.x; x += step) {
        final a = project(BoardPoint(x, 0));
        final b = project(BoardPoint(x, board.y));
        final labelled = x % 6 == 0;
        canvas.drawLine(a, b, labelled ? major : minor);
        if (labelled) ruler(a, b, '${x.toInt()}');
      }
      for (var y = step; y < board.y; y += step) {
        final a = project(BoardPoint(0, y));
        final b = project(BoardPoint(board.x, y));
        final labelled = y % 6 == 0;
        canvas.drawLine(a, b, labelled ? major : minor);
        if (labelled) ruler(a, b, '${y.toInt()}');
      }

      if (table != null) {
        for (final piece in table.pieces) {
          final points = piece.outline(templates);
          if (points.isEmpty) continue;

          // **To the nearest edge, not always the same two.**
          //
          // Measuring everything from the left and the bottom meant a piece in
          // the far corner carried two lines most of the board long, and
          // sixteen pieces drew thirty-two of them across each other. The edge
          // you actually reach for is the one you are standing next to, and
          // the measurement is the same number either way.
          final minX = points.map((p) => p.x).reduce(math.min);
          final maxX = points.map((p) => p.x).reduce(math.max);
          final minY = points.map((p) => p.y).reduce(math.min);
          final maxY = points.map((p) => p.y).reduce(math.max);

          final fromLeft = minX <= board.x - maxX;
          final fromBottom = minY <= board.y - maxY;

          // The corner on the side being measured from, so the line leaves the
          // piece at a corner rather than crossing it.
          final acrossX = fromLeft ? minX : maxX;
          final acrossY = fromBottom ? minY : maxY;
          final atX = points
              .where((p) => p.x == acrossX)
              .reduce((a, b) => b.y < a.y ? b : a);
          final atY = points
              .where((p) => p.y == acrossY)
              .reduce((a, b) => b.x < a.x ? b : a);

          _leader(
            canvas,
            project(BoardPoint(fromLeft ? 0 : board.x, atX.y)),
            project(atX),
            fromLeft ? minX : board.x - maxX,
          );
          _leader(
            canvas,
            project(BoardPoint(atY.x, fromBottom ? 0 : board.y)),
            project(atY),
            fromBottom ? minY : board.y - maxY,
          );
        }
      }
    }

    for (final objective
        in objectives.isEmpty ? pattern.objectives : objectives) {
      final o = project(objective);
      canvas.drawCircle(o, _px(5), Paint()..color = objectiveRing);
      canvas.drawCircle(
        o,
        _px(4),
        Paint()
          ..color = objectiveFill.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _px(1.4),
      );
    }
  }

  static int _fallback(bool attacker) => attacker ? 0xFFEF4444 : 0xFF3B82F6;

  /// A distance from a board edge to a piece, with the number on the line.
  ///
  /// Dashed, so it reads as a measurement rather than as a wall — the board is
  /// already full of solid lines, and a solid one from the edge to a ruin
  /// looks like something you could walk into.
  void _leader(Canvas canvas, Offset from, Offset to, double inches) {
    if (inches < 0.5) return; // A piece against the edge needs no arrow.

    final paint = Paint()
      ..color = measure.withValues(alpha: 0.55)
      ..strokeWidth = _px(0.9)
      ..strokeCap = StrokeCap.round;

    final dx = to.dx - from.dx;
    final dy = to.dy - from.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    if (length <= 0) return;
    final ux = dx / length;
    final uy = dy / length;

    final dash = _px(3.0);
    final gap = _px(2.5);
    for (var at = 0.0; at < length; at += dash + gap) {
      final end = math.min(at + dash, length);
      canvas.drawLine(
        Offset(from.dx + ux * at, from.dy + uy * at),
        Offset(from.dx + ux * end, from.dy + uy * end),
        paint,
      );
    }

    // A stop at the edge end, so the line is visibly measured *from* there
    // rather than just passing through.
    canvas.drawLine(
      Offset(from.dx - uy * _px(2.5), from.dy + ux * _px(2.5)),
      Offset(from.dx + uy * _px(2.5), from.dy - ux * _px(2.5)),
      paint,
    );

    // The number sits at the **piece** end, not the middle of the line.
    //
    // A midpoint reads well for one measurement and not for thirty-two: on a
    // sixteen-piece table the lines all cross the middle of the board, and the
    // numbers landed in a heap there with no way to tell which line each
    // belonged to. Against its own piece, a number is attributable.
    final back = _px(12.0);
    _tick(
      canvas,
      Offset(to.dx - ux * back + _px(2), to.dy - uy * back - _px(11)),
      '${inches.round()}',
      measurement: true,
    );
  }

  /// A small measurement, drawn over whatever is beneath it.
  void _tick(Canvas canvas, Offset at, String text,
      {bool emphasis = false, bool measurement = false}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: _px(emphasis || measurement ? 8 : 8.5),
          fontWeight:
              emphasis || measurement ? FontWeight.w700 : FontWeight.w500,
          color: measurement
              ? measure
              : emphasis
                  ? objectiveFill.withValues(alpha: 0.85)
                  : outline.withValues(alpha: 0.8),
          // A halo, because these land on ruins as often as on bare board.
          shadows: [
            Shadow(color: objectiveRing, blurRadius: _px(2)),
            Shadow(color: objectiveRing, blurRadius: _px(2)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  /// Writes a piece's marking inside its own outline, or not at all. Where
  /// it goes, and whether it goes at all, is [labelSpot].
  void _pieceLabel(Canvas canvas, Rect bounds, String label, {Offset? marker}) {
    if (label.isEmpty) return;

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: _px(7),
          height: 1,
          letterSpacing: _px(0.2),
          fontWeight: FontWeight.w800,
          color: objectiveRing,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Its own box, with a hair of margin. Anything that does not fit is left
    // unlabelled rather than shrunk to illegibility or spilled onto a
    // neighbour.
    if (painter.width > bounds.width - _px(2) ||
        painter.height > bounds.height - _px(2)) {
      return;
    }

    final at = labelSpot(
      bounds: bounds,
      label: Size(painter.width, painter.height),
      marker: marker,
      markerRadius: _px(5),
      margin: _px(2),
    );
    if (at != null) painter.paint(canvas, at);
  }

  /// The polygon's area centroid, not its bounding-box centre. Every zone in
  /// the shipped patterns is an L or a bar, and a bounding box puts the label
  /// on the notch — over the boundary rather than inside the shape it names.
  static Offset _centroid(BoardArea area, Offset Function(BoardPoint) project) {
    final points = [for (final p in area.points) project(p)];
    if (points.length < 3) {
      return points.isEmpty ? Offset.zero : points.first;
    }

    var twiceArea = 0.0;
    var cx = 0.0;
    var cy = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final cross = a.dx * b.dy - b.dx * a.dy;
      twiceArea += cross;
      cx += (a.dx + b.dx) * cross;
      cy += (a.dy + b.dy) * cross;
    }
    // A degenerate ring would divide by zero; fall back to the mean vertex.
    if (twiceArea.abs() < 1e-6) {
      return points.reduce((a, b) => a + b) / points.length.toDouble();
    }
    return Offset(cx / (3 * twiceArea), cy / (3 * twiceArea));
  }

  void _label(
      Canvas canvas, Offset centre, String text, Color color, bool mine) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: _px(9),
          letterSpacing: _px(0.8),
          fontWeight: FontWeight.w800,
          color: color.withValues(alpha: mine ? 1 : 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      centre - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.pattern.id != pattern.id ||
      old.iAmAttacker != iAmAttacker ||
      old.layout?.id != layout?.id ||
      old.measured != measured ||
      old.turned != turned ||
      old.zoom != zoom ||
      old.measure != measure ||
      old.outline != outline;
}

class _Key extends StatelessWidget {
  final String label;
  final Color color;
  final bool emphasised;

  const _Key({
    required this.label,
    required this.color,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color.withValues(alpha: emphasised ? 0.34 : 0.20),
              border: Border.all(color: color, width: emphasised ? 2 : 1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: emphasised ? FontWeight.w700 : FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )),
        ],
      );
}
