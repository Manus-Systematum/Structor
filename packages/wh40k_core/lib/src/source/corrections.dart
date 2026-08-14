/// Corrections applied to upstream data at bundle time (DESIGN.md §3.6).
///
/// The cross-check of §3.5 finds where two sources *disagree*. This is the
/// other half of the same problem: where the data is simply wrong, or — more
/// often — incomplete in a way that makes the app state something stronger
/// than the rule says. Broadside Battlesuits' Advanced Armour is the founding
/// case: upstream encodes `feel-no-pain 4+` with no qualifier, so the play
/// screen promised an unrestricted 4+ against a rule that only applies to
/// mortal wounds.
///
/// The renderer must not paper over this — §7.6 forbids inventing rules text,
/// and a renderer that special-cased one ability would be lying about where
/// its knowledge came from. So the fix belongs to the data, and lives in a
/// file a person can read, with a reason attached.
///
/// Two rules keep this from becoming a private fork:
///
///  * a correction with no reason is not applied, exactly as with an accepted
///    divergence;
///  * a correction that matches nothing is **reported**, so one that upstream
///    has since adopted gets noticed and deleted rather than quietly shadowing
///    data that is now correct.
library;

import 'package:yaml/yaml.dart';

/// A replacement effect for one ability in one faction.
class AbilityCorrection {
  /// A faction id, or `*` for a core ability carried identically by several
  /// factions — Stealth is transcribed once per faction file, and wrong in
  /// each of them.
  final String faction;

  final String abilityId;
  final String reason;

  /// Where the problem has been reported upstream, for the record. Free text —
  /// 'not yet reported' is an honest value.
  final String? upstream;

  /// The effect that replaces the upstream one, in the source JSON shape.
  final Map<String, Object?> effect;

  const AbilityCorrection({
    required this.faction,
    required this.abilityId,
    required this.reason,
    required this.effect,
    this.upstream,
  });
}

class CorrectionResult {
  final List<Object?> records;

  /// Corrections that found their ability.
  final List<AbilityCorrection> applied;

  /// Corrections that matched nothing — a stale entry, or a typo in the id.
  final List<AbilityCorrection> unmatched;

  const CorrectionResult({
    required this.records,
    required this.applied,
    required this.unmatched,
  });
}

class DataCorrections {
  final List<AbilityCorrection> abilities;

  const DataCorrections({this.abilities = const []});

  static const empty = DataCorrections();

  bool get isEmpty => abilities.isEmpty;

  static const _anyFaction = '*';

  /// Corrections for one faction, applied to its raw `abilities.json` records.
  ///
  /// Returns fresh records; the input is not mutated, so a caller may bundle
  /// corrected data while a cross-check still reads the original.
  CorrectionResult applyToAbilities(
    String factionId,
    List<Object?> records,
  ) {
    final mine = abilities
        .where((c) => c.faction == factionId || c.faction == _anyFaction)
        .toList();
    if (mine.isEmpty) {
      return CorrectionResult(
        records: records,
        applied: const [],
        unmatched: const [],
      );
    }

    final byId = {for (final c in mine) c.abilityId: c};
    final applied = <AbilityCorrection>[];
    final out = <Object?>[];

    for (final record in records) {
      if (record is! Map) {
        out.add(record);
        continue;
      }
      final correction = byId[record['ability_id']?.toString()];
      if (correction == null) {
        out.add(record);
        continue;
      }
      applied.add(correction);
      out.add({
        for (final e in record.entries) e.key.toString(): e.value,
        'effect': correction.effect,
        // Kept in the shipped record so the provenance travels with the data
        // rather than living only in a build log.
        'corrected': {
          'reason': correction.reason,
          if (correction.upstream != null) 'upstream': correction.upstream,
        },
      });
    }

    return CorrectionResult(
      records: out,
      applied: applied,
      // A wildcard correction is not stale just because *this* faction has no
      // such ability — only if no faction anywhere has it, which only the
      // caller iterating every faction can know.
      unmatched: [
        for (final c in mine)
          if (c.faction != _anyFaction && !applied.contains(c)) c,
      ],
    );
  }

  /// Wildcard corrections that fired for no faction at all — the same "stale
  /// entry" check [CorrectionResult.unmatched] does, but across a whole run.
  List<AbilityCorrection> neverApplied(Iterable<AbilityCorrection> applied) {
    final fired = applied.toSet();
    return [
      for (final c in abilities)
        if (c.faction == _anyFaction && !fired.contains(c)) c,
    ];
  }

  static DataCorrections parse(String yamlSource) {
    final root = loadYaml(yamlSource);
    if (root is! Map) return empty;

    final abilities = <AbilityCorrection>[];
    final raw = root['abilities'];
    if (raw is List) {
      for (final node in raw) {
        if (node is! Map) continue;
        final reason = node['reason']?.toString().trim() ?? '';
        final effect = _plain(node['effect']);
        // A correction with no reason is indistinguishable from a private
        // edit, and one with no effect has nothing to say.
        if (reason.isEmpty || effect is! Map<String, Object?> || effect.isEmpty) {
          continue;
        }
        abilities.add(AbilityCorrection(
          faction: node['faction']?.toString() ?? '',
          abilityId: node['id']?.toString() ?? '',
          reason: reason,
          upstream: node['upstream']?.toString(),
          effect: effect,
        ));
      }
    }
    return DataCorrections(abilities: abilities);
  }

  /// YAML nodes are not JSON-encodable, so they are copied into plain maps and
  /// lists before being written into a bundle.
  static Object? _plain(Object? node) {
    if (node is Map) {
      return <String, Object?>{
        for (final e in node.entries) e.key.toString(): _plain(e.value),
      };
    }
    if (node is List) return [for (final e in node) _plain(e)];
    return node;
  }
}
