import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Reads an asset this package ships, wherever the package is mounted.
///
/// The same Dart code is the whole of two apps: in the iOS repository it *is*
/// the root project, and its assets are at `assets/…`; in the Android
/// repository it is a dependency, and Flutter mounts a dependency's assets
/// under `packages/wh40k_app/…` instead. One path is right in one place and
/// wrong in the other, so both are tried and the one that answered is
/// remembered.
///
/// The order matters only for the first read: package-first, because the root
/// project of a shell repository could also declare an `assets/` of its own,
/// and this package's own file is the one meant here.
abstract final class AppAssets {
  static const _package = 'packages/wh40k_app/';

  /// Null until the first successful read decides which mounting is in force.
  static String? _prefix;

  static Future<ByteData?> load(String path) async {
    for (final prefix in _order) {
      try {
        final data = await rootBundle.load('$prefix$path');
        _prefix = prefix;
        return data;
      } on FlutterError {
        continue;
      }
    }
    return null;
  }

  static Future<String?> loadString(String path) async {
    for (final prefix in _order) {
      try {
        final raw = await rootBundle.loadString('$prefix$path');
        _prefix = prefix;
        return raw;
      } on FlutterError {
        continue;
      }
    }
    return null;
  }

  static List<String> get _order =>
      _prefix == null ? const [_package, ''] : [_prefix!];
}
