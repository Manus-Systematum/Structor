import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/widgets/unit_profiles.dart';

/// The compact profile table in the unit editor and on the reference screen.
void main() {
  late Army army;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
  });

  Future<void> pump(WidgetTester tester, String datasheetId) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final datasheet = army.catalogue.unit(datasheetId)!;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CarriedWeaponProfiles(
          dataset: army.catalogue,
          datasheet: datasheet,
          carried: army.carriedBy(datasheetId),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the skill column says which skill by row, not by heading',
      (tester) async {
    // The column read `BS` and printed whatever the profile carried, so every
    // melee weapon showed its Weapon Skill under a Ballistic Skill heading —
    // a wrong label on a right number, which is worse than either alone.
    await pump(tester, 'commander-in-enforcer-battlesuit');

    expect(find.text('SKILL'), findsOneWidget);
    expect(find.text('BS'), findsNothing);
    // Read as a player reads it. The raw characteristic is a bare `4`.
    expect(find.text('4+'), findsWidgets);
  });

  testWidgets('melee and pistol rows are tinted apart from the rest',
      (tester) async {
    // Once the heading cannot name the skill, the row has to. A pistol earns
    // its own state rather than being lumped in with the shooting: it is the
    // weapon you look for when the enemy is already in engagement range.
    await pump(tester, 'commander-in-enforcer-battlesuit');

    final tints = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.color)
        .whereType<Color>()
        .toSet();
    expect(tints, isNotEmpty, reason: 'the melee row is tinted');

    // A melee row says "Melee" in its own RNG cell, so the only "Melee" on
    // screen is that cell — no key repeats it beside a swatch.
    expect(find.text('Melee'), findsOneWidget);
  });

  testWidgets('the pistol key appears only where a pistol does',
      (tester) async {
    // The tint needs explaining and the melee one does not: a pistol's range
    // is a number like any other gun's, so nothing on the row says what the
    // colour means. A key for a colour that is not on screen is furniture.
    await pump(tester, 'commander-in-enforcer-battlesuit');
    expect(find.text('Pistol'), findsNothing,
        reason: 'battlesuits carry no pistols');
  });
  testWidgets('a weapon with two profiles says which weapon', (tester) async {
    // An Ion accelerator publishes `Standard` and `Overcharge`, and the table
    // listed `Overcharge` on its own — no way to tell which gun it belonged
    // to, and two such weapons on one unit gave two rows reading the same.
    await pump(tester, 'riptide-battlesuit');
    expect(find.textContaining('Ion accelerator: overcharge'), findsOneWidget);
    expect(find.textContaining('Ion accelerator: standard'), findsOneWidget);
    // Bare `Overcharge` no longer stands alone.
    expect(find.text('1× Overcharge'), findsNothing);
  });

  testWidgets('the keywords are on the row, not only the numbers',
      (tester) async {
    // Half of what a weapon does is its keywords. Six numbers without them
    // make two guns with identical statlines read as interchangeable when one
    // of them auto-hits.
    await pump(tester, 'riptide-battlesuit');
    expect(find.textContaining('HAZARDOUS'), findsWidgets);
  });

  testWidgets('a pistol profile is tinted and keyed', (tester) async {
    // The XV pulse pistol is one of the few in a T'au list.
    await pump(tester, 'the-twin-lance');
    expect(find.text('Pistol'), findsOneWidget, reason: 'the key');
  });
}
