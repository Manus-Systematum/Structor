import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/screens/army_screen.dart';
import 'package:wh40k_app/src/screens/turn_screen.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// Wraps a screen so it can be pumped without the app's FutureBuilder, whose
/// indeterminate spinner never lets `pumpAndSettle` reach a steady state.
Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late Army army;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
  });

  group('what a play-test found wrong', () {
    CombatUnit unitWith(String instanceId) => army.combatUnits
        .firstWhere((u) => u.group.any((g) => g.instanceId == instanceId));

    test('an invulnerable save granted by an ability reaches the statline',
        () {
      // The Coldstar's 4+ lives in its shield-generator ability, not in
      // invuln_sv. Reading the profile alone left the INV column empty.
      final coldstar = unitWith('u03');
      final commander = coldstar.profiles
          .firstWhere((p) => p.name.contains('Coldstar'));
      expect(commander.profile.invulnSv, '4');

      // …and it does not leak onto the suits it leads.
      final suits = coldstar.profiles
          .firstWhere((p) => p.name.contains('Starscythe'));
      expect(suits.profile.invulnSv, isNull);
    });

    test("an attached unit's abilities say which half owns them", () {
      final coldstar = unitWith('u03');
      expect(coldstar.isAttached, isTrue);
      final rules = {
        for (final r in coldstar.attributedRules) r.rule.abilityId: r.source,
      };
      // The Commander's, not the Crisis suits'.
      expect(rules['shield-generator'], 'Commander in Coldstar Battlesuit');
      expect(rules['starscythe'], 'Crisis Starscythe Battlesuits');
      // Both halves Deep Strike, and both bought drones, so naming a half
      // would be wrong as well as noisy.
      expect(rules['deep-strike'], isEmpty);
      expect(rules['gun-drone'], isEmpty);
    });

    test('a single-datasheet unit is not attributed', () {
      final broadside = unitWith('u10');
      expect(broadside.isAttached, isFalse);
      expect(broadside.attributedRules.map((r) => r.source), everyElement(''));
    });

    test('a drone is shown only on the units that bought one', () {
      // Crisis suits may take a Gun, Marker or Shield Drone. This list takes
      // Gun and Shield; listing Marker too would be a rule that is not there.
      final fireknife = unitWith('u02');
      final ids = fireknife.rules.map((r) => r.abilityId).toSet();
      expect(ids, containsAll(['gun-drone', 'shield-drone']));
      expect(ids, isNot(contains('marker-drone')));
    });

    test("a Gun Drone's carbine reaches the shooting table", () {
      // Drones are wargear, and this one brings a gun (§7.3.7). The import
      // used to recognise the drone and then discard it.
      final fireknife = unitWith('u02');
      final carbines = fireknife
          .weapons(WeaponKind.ranged)
          .weapons
          .where((w) => w.displayName.contains('Twin pulse carbine'));
      expect(carbines, hasLength(1));
      // One on the Commander, three on the Crisis suits.
      expect(carbines.single.weaponCount, 4);
      expect(carbines.single.keywords.map((k) => k.label),
          containsAll(['ASSAULT', 'TWIN LINKED']));
    });

    test('the Coldstar sets Move to 12 rather than adding 12', () {
      final rule = unitWith('u03')
          .rules
          .firstWhere((r) => r.abilityId == 'coldstar-commander');
      expect(
        rule.text,
        'While leading a unit: Move set to 12; ranged weapons gain ASSAULT.',
      );
    });

    test('weapon keywords keep their values through the snapshot', () {
      // Ghostkeel's fusion collider. The snapshot round trip was dropping
      // the parameter, so MELTA 2 arrived as MELTA.
      final ghostkeel = unitWith('u12');
      final labels = ghostkeel
          .weapons(WeaponKind.ranged)
          .weapons
          .expand((w) => w.keywords)
          .map((k) => k.label)
          .toSet();
      expect(labels, contains('MELTA 2'));
    });
  });

  group('army loads from its snapshot alone', () {
    test('no faction dataset is involved', () {
      // Everything below is served by assets/reference_snapshot.json, which is
      // the same path an imported or QR-scanned list takes (DESIGN.md §6.4).
      expect(army.roster.name, '2k ret');
      expect(army.points, 2000);
      expect(army.combatUnits, hasLength(12));
      expect(army.validation.isLegal, isTrue,
          reason: army.validation.errors.join('\n'));
    });
  });

  testWidgets('the army screen shows points, findings and units',
      (tester) async {
    await tester.pumpWidget(host(ArmyScreen(army: army)));

    expect(find.text('2k ret'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    // Units carry their datasheet names, and an attached unit names both
    // halves. This list fields the same pairing twice, which is legal and
    // shown as-is rather than disambiguated.
    expect(
      find.text('Commander in Enforcer Battlesuit + Crisis Fireknife '
          'Battlesuits'),
      findsNWidgets(2),
    );

    // Informational findings are surfaced, not hidden: these are the two the
    // design predicted for this list.
    expect(find.textContaining('Detachment Point'), findsOneWidget);
    expect(find.textContaining('slots unused'), findsOneWidget);
  });

  testWidgets('the turn page renders phase sections in order', (tester) async {
    await tester.pumpWidget(host(TurnScreen(army: army)));

    for (final phase in ['COMMAND', 'MOVEMENT', 'SHOOTING']) {
      expect(find.text(phase), findsOneWidget);
    }
    expect(find.text('YOUR TURN'), findsOneWidget);
  });

  testWidgets('the shooting section shows the split attack totals',
      (tester) async {
    await tester.pumpWidget(host(TurnScreen(army: army)));

    // The number the table exists for: four Commander pods at BS3+ give 8
    // attacks, six Crisis pods at BS4+ give 12 (§7.3.5).
    expect(find.text('8 atk'), findsWidgets);
    expect(find.text('12 atk'), findsWidgets);
    expect(find.text('3+'), findsWidgets);
    expect(find.text('4+'), findsWidgets);

    // Torrent weapons merge into one auto-hitting pool instead of splitting.
    expect(find.text('10D6 atk'), findsWidgets);
    expect(find.text('auto'), findsWidgets);
  });

  testWidgets('rendered rules appear next to the weapons they modify',
      (tester) async {
    await tester.pumpWidget(host(TurnScreen(army: army)));

    expect(find.textContaining('Fireknife:', findRichText: true), findsWidgets);
    expect(
      find.textContaining('re-roll Hit rolls of 1', findRichText: true),
      findsWidgets,
      reason: 'generated from the structured effect, not transcribed',
    );
  });
}
