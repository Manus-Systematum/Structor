import 'dart:io';

import 'package:wh40k_core/wh40k_core.dart';

final snapshotDir = Directory('../../data/merged');

bool get snapshotAvailable => snapshotDir.existsSync();

/// A loader with the shipped corrections applied (DESIGN.md §3.6) — the same
/// view the bundler, the app and the snapshot writer get.
///
/// Tests that touch the reference roster need this, because the fixture is
/// produced by an importer reading corrected data: a Commander's Gun Drone is
/// only wargear it can take once the correction says so.
///
/// The cross-check deliberately does **not** use this. Its whole value is
/// comparing upstream against upstream.
DatasetLoader correctedLoader() => DatasetLoader(
      snapshotDir.path,
      corrections: DatasetLoader.correctionsAt('../../data-corrections.yaml'),
    );
