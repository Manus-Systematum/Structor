import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/deployment_diagram.dart';

/// §7.3.28. Below the hold, zooming spreads the numbers apart without
/// enlarging them; above it they grow with the board.
void main() {
  /// What a 10pt label ends up measuring on screen at this magnification.
  double onScreen(double zoom) => 10 / letteringDivisor(zoom) * zoom;

  test('lettering holds its size while there is crowding to undo', () {
    for (final zoom in [1.0, 2.0, 3.0, 3.9]) {
      expect(onScreen(zoom), closeTo(10, 0.001),
          reason: 'at ${zoom}x it is still paper-sized');
    }
  });

  test('past the hold it grows with the zoom', () {
    expect(onScreen(4), closeTo(10, 0.001), reason: 'the hold itself');
    expect(onScreen(5), closeTo(12.5, 0.001));
    expect(onScreen(6), closeTo(15, 0.001));
  });

  test('it never shrinks as the reader zooms in', () {
    var last = 0.0;
    for (var zoom = 1.0; zoom <= 6.0; zoom += 0.25) {
      final size = onScreen(zoom);
      expect(size, greaterThanOrEqualTo(last - 0.001));
      last = size;
    }
  });
}
