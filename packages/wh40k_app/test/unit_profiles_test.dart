import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/widgets/unit_profiles.dart';
import 'package:wh40k_core/wh40k_core.dart';

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

    // One per section now that the table is split (§4.16).
    expect(find.text('SKILL'), findsWidgets);
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

    // Read off the decoration as well as the bare colour: a taken row also
    // carries a border, and a Container cannot have both `color` and
    // `decoration`, so the tint moved inside the decoration when the left
    // bar arrived (§4.12).
    final tints = tester
        .widgetList<Container>(find.byType(Container))
        .map((c) =>
            c.color ??
            (c.decoration is BoxDecoration
                ? (c.decoration as BoxDecoration).color
                : null))
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

  group('what the unit could take, beside what it has', () {
    // Choosing between a burst cannon and a fusion blaster means comparing
    // them, and the one not taken used to be invisible until it was bought.
    //
    // Read from the faction bundle rather than the reference army: a saved
    // army's snapshot carries the wargear it took, not the options it chose
    // from, so there is nothing there to offer.
    late Dataset tau;

    Future<void> pumpTakeable(WidgetTester tester, String datasheetId) async {
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        tau = await DatasetRepository().faction('tau-empire');
      });
      final datasheet = tau.unit(datasheetId)!;
      final roster = RosterEditor(tau).addUnit(
        RosterEditor.blank(name: 'p', factionId: 'tau-empire'),
        datasheetId,
      );
      final loadout = UnitLoadout.forDatasheet(datasheet,
          catalogue: tau, vocabulary: datasheet.wargearVocabulary);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CarriedWeaponProfiles(
              dataset: tau,
              datasheet: datasheet,
              carried: {
                for (final item in roster.units.single.wargear)
                  item.itemId: item.count,
              },
              takeable: {
                ...loadout.fixed.keys,
                for (final group in loadout.groups) ...group.items,
                for (final counter in loadout.counters) counter.itemId,
              },
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('an untaken weapon is listed, without a count', (tester) async {
      await pumpTakeable(tester, 'stealth-battlesuits');

      // Carried, so it has one.
      expect(find.textContaining('× Burst cannon'), findsOneWidget);
      // Not carried, so it is named alone.
      expect(find.text('Fusion blaster'), findsOneWidget);
      expect(find.textContaining('× Fusion blaster'), findsNothing);
    });

    testWidgets('taken rows keep the top of the table', (tester) async {
      await pumpTakeable(tester, 'stealth-battlesuits');

      final taken = tester.getTopLeft(find.textContaining('× Burst cannon')).dy;
      final untaken = tester.getTopLeft(find.text('Fusion blaster')).dy;
      expect(taken, lessThan(untaken),
          reason: 'what is on the table is read before what could be');
    });

    testWidgets('the mark is a bar, and it is not the tint', (tester) async {
      await pumpTakeable(tester, 'stealth-battlesuits');

      Border? borderUnder(Finder text) {
        final container = tester.widget<Container>(
            find.ancestor(of: text, matching: find.byType(Container)).first);
        final decoration = container.decoration;
        return decoration is BoxDecoration
            ? decoration.border as Border?
            : null;
      }

      expect(borderUnder(find.textContaining('× Burst cannon'))?.left.width, 3,
          reason: 'a taken row carries the bar');
      expect(borderUnder(find.text('Fusion blaster'))?.left.width, isNot(3),
          reason: 'an untaken one does not');
    });

    testWidgets('without takeable, nothing changes for the reference screen',
        (tester) async {
      await pump(tester, 'stealth-battlesuits');

      expect(find.text('Fusion blaster'), findsNothing);
    });
  });

  group('shooting and fighting are read apart', () {
    testWidgets('the table is split, and a pistol stays with the shooting',
        (tester) async {
      await pump(tester, 'commander-in-enforcer-battlesuit');

      expect(find.text('RANGED'), findsOneWidget);
      expect(find.text('MELEE'), findsOneWidget);

      final ranged = tester.getTopLeft(find.text('RANGED')).dy;
      final melee = tester.getTopLeft(find.text('MELEE')).dy;
      expect(ranged, lessThan(melee), reason: 'shooting first, as a turn goes');

      // Battlesuit fists are the melee weapon, so they sit under it.
      expect(tester.getTopLeft(find.textContaining('Battlesuit fists')).dy,
          greaterThan(melee));
    });

    testWidgets('nothing to divide announces no division', (tester) async {
      // A loadout of one gun. Every T'au datasheet carries fists of some kind,
      // so the case is built rather than found.
      tester.view.physicalSize = const Size(1400, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CarriedWeaponProfiles(
            dataset: army.catalogue,
            datasheet: army.catalogue.unit('stealth-battlesuits')!,
            carried: const {'burst-cannon': 5},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('RANGED'), findsOneWidget);
      expect(find.text('MELEE'), findsNothing);
    });

    testWidgets('every row under MELEE is one', (tester) async {
      await pump(tester, 'commander-in-enforcer-battlesuit');

      final melee = tester.getTopLeft(find.text('MELEE')).dy;
      final ranges = tester
          .widgetList<Text>(find.textContaining('Melee'))
          .where((t) => t.data == 'Melee');
      expect(ranges, isNotEmpty);
      for (final finder in find.text('Melee').evaluate()) {
        final box = finder.renderObject! as RenderBox;
        expect(box.localToGlobal(Offset.zero).dy, greaterThan(melee));
      }
    });
  });
}
