/// Turning BattleScribe names into this project's ids (DESIGN.md §3.10).
///
/// BattleScribe ids are opaque — `4d0d-af9d-53c2-bc31` — and nothing else in
/// the project speaks them: saved rosters, corrections, the reference fixture
/// and every 40kdc record are keyed by slug. Mapping names into that same id
/// space is therefore not cosmetic. It is what lets the two sources be
/// compared at all, and what stops a source swap invalidating every list a
/// player has already saved.
///
/// Measured on T'au: 43 of 47 40kdc datasheets are hit by slugifying the
/// BSData name. The four that are not are Combat Patrol formations 40kdc
/// carries and BSData does not, so they are absences rather than mismatches.
library;

/// Suffixes BSData appends to a name to mark which pool a datasheet is in.
///
/// They are shelf labels, not part of the datasheet's identity: `Longstrike
/// [Legends]` is the same unit 40kdc files as `longstrike`. The flag is not
/// discarded — [isLegends] reads it — only kept out of the id.
final _bracketed = RegExp(r'\s*\[[^\]]*\]\s*');

final _apostrophes = RegExp(r"[’‘ʼ']");
final _separators = RegExp(r'[^a-z0-9]+');

/// `Commander in Coldstar Battlesuit` -> `commander-in-coldstar-battlesuit`.
///
/// Apostrophes are deleted rather than turned into separators, so `T'au` folds
/// to `tau` and `Shas'vre` to `shasvre` — the same rule `normalise` uses for
/// import matching, and the one 40kdc's own ids follow.
String bsSlug(String name) {
  final bare = name
      .replaceAll(_bracketed, ' ')
      .replaceAll(_apostrophes, '')
      .toLowerCase();
  return bare.replaceAll(_separators, '-').replaceAll(RegExp(r'^-|-$'), '');
}

/// Whether BSData has shelved this datasheet away from matched play.
///
/// `[Legends]` and `[Crucible]` are both out of the tournament pool; the app
/// already filters on the same distinction 40kdc records as `is_legend`.
bool isLegends(String name) {
  final lower = name.toLowerCase();
  return lower.contains('[legends]') || lower.contains('[crucible]');
}

/// The name with the shelf label removed, for display.
String bsDisplayName(String name) => name.replaceAll(_bracketed, ' ').trim();
