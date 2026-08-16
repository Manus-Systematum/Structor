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
class DeploymentDiagram extends StatelessWidget {
  final DeploymentPattern pattern;

  /// Which half is yours. Flips the labels, never the geometry.
  final bool iAmAttacker;

  const DeploymentDiagram({
    super.key,
    required this.pattern,
    required this.iAmAttacker,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = pattern.boardSize;
    if (!pattern.hasGeometry || size.x <= 0 || size.y <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The board's own proportions, so a 60×44 table is not stretched to
        // whatever box the layout happens to give it.
        AspectRatio(
          aspectRatio: size.x / size.y,
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _BoardPainter(
                  pattern: pattern,
                  iAmAttacker: iAmAttacker,
                  outline: scheme.outline,
                  objectiveFill: scheme.onSurface,
                  objectiveRing: scheme.surface,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _Key(
              label: 'You',
              color: _zoneColor(iAmAttacker),
              emphasised: true,
            ),
            const SizedBox(width: 14),
            _Key(label: 'Opponent', color: _zoneColor(!iAmAttacker)),
            const Spacer(),
            Text(
              '${_inches(size.x)}″ × ${_inches(size.y)}″'
              '${pattern.objectives.isEmpty ? '' : ' · ${pattern.objectives.length} objectives'}',
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  Color _zoneColor(bool attacker) {
    final raw = pattern.zoneFor(attacker: attacker)?.color;
    return raw == null
        ? (attacker ? const Color(0xFFEF4444) : const Color(0xFF3B82F6))
        : Color(raw);
  }

  static String _inches(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

class _BoardPainter extends CustomPainter {
  final DeploymentPattern pattern;
  final bool iAmAttacker;
  final Color outline;
  final Color objectiveFill;
  final Color objectiveRing;

  _BoardPainter({
    required this.pattern,
    required this.iAmAttacker,
    required this.outline,
    required this.objectiveFill,
    required this.objectiveRing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final board = pattern.boardSize;
    if (board.x <= 0 || board.y <= 0) return;

    final scale = size.width / board.x;

    // Board coordinates run from the bottom-left, canvas coordinates from the
    // top-left, so y is flipped once here rather than at every call site.
    Offset project(BoardPoint p) =>
        Offset(p.x * scale, size.height - p.y * scale);

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
          ..strokeWidth = mine ? 2 : 1,
      );
      _label(canvas, _centroid(zone, project), mine ? 'YOU' : 'THEM', color,
          mine);
    }

    for (final objective in pattern.objectives) {
      final o = project(objective);
      canvas.drawCircle(o, 5, Paint()..color = objectiveRing);
      canvas.drawCircle(
        o,
        4,
        Paint()
          ..color = objectiveFill.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  static int _fallback(bool attacker) => attacker ? 0xFFEF4444 : 0xFF3B82F6;

  /// The polygon's area centroid, not its bounding-box centre. Every zone in
  /// the shipped patterns is an L or a bar, and a bounding box puts the label
  /// on the notch — over the boundary rather than inside the shape it names.
  static Offset _centroid(
      BoardArea area, Offset Function(BoardPoint) project) {
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
          fontSize: 9,
          letterSpacing: 0.8,
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
