import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/deployment_diagram.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  const board = BoardPoint(60, 44);
  const upright = Size(600, 440);
  const turned = Size(440, 600);

  /// Twice the signed area of the projected triangle.
  ///
  /// Its **sign** is the handedness of the mapping, and that is the whole
  /// question: a rotation preserves it, a reflection flips it, and both put
  /// the board neatly inside its box.
  double handedness(Size canvas, bool turn) {
    final a = projectOnto(const BoardPoint(0, 0),
        canvas: canvas, board: board, turned: turn);
    final b = projectOnto(const BoardPoint(60, 0),
        canvas: canvas, board: board, turned: turn);
    final c = projectOnto(const BoardPoint(0, 44),
        canvas: canvas, board: board, turned: turn);
    return (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
  }

  test('the upright board puts the origin at the bottom left', () {
    // Board coordinates count up from the bottom; screens count down.
    expect(
        projectOnto(const BoardPoint(0, 0),
            canvas: upright, board: board, turned: false),
        const Offset(0, 440));
    expect(
        projectOnto(const BoardPoint(60, 44),
            canvas: upright, board: board, turned: false),
        const Offset(600, 0));
  });

  test('turning fills the turned box exactly', () {
    final far = projectOnto(const BoardPoint(60, 44),
        canvas: turned, board: board, turned: true);
    expect(far.dx, closeTo(440, 0.001));
    expect(far.dy, closeTo(600, 0.001));
  });

  test('turning rotates the table and does not mirror it', () {
    // The failure this guards is silent and expensive: a mirrored map is a
    // perfectly plausible picture of a table that is not the one published,
    // and it is only found by setting the terrain out and losing the game.
    expect(handedness(upright, false).sign, handedness(turned, true).sign,
        reason: 'the turned board is the same table seen from the same side');
  });

  test('a square board still turns if it is asked to', () {
    // Deciding that a square table gains nothing from turning is the widget's
    // job, not this function's — `setup_test` covers it there. Here the point
    // is only that nothing special-cases the square and quietly does one
    // thing while reporting the other.
    const square = BoardPoint(36, 36);
    const box = Size(360, 360);
    expect(
      projectOnto(const BoardPoint(36, 0),
          canvas: box, board: square, turned: true),
      const Offset(0, 360),
    );
    expect(
      projectOnto(const BoardPoint(36, 0),
          canvas: box, board: square, turned: false),
      const Offset(360, 360),
    );
  });
}
