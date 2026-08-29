import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/screens/army_screen.dart';
import 'package:wh40k_app/src/data/play_density.dart';
import 'package:wh40k_app/src/screens/turn_screen.dart';
import 'package:wh40k_app/src/widgets/score_board.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// Wraps a screen so it can be pumped without the app's FutureBuilder, whose
/// indeterminate spinner never lets `pumpAndSettle` reach a steady state.
Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Renders on a tall surface for the rest of the test.
///
/// The turn page is one long scroll of phase sections (§7.2) and a `ListView`
/// only builds what fits. On the default 800x600 the Shooting section is
/// never constructed, so `find.text` cannot see it — a property of the test
/// window, not of the page.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late Army army;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
  });

  group('what a play-test found wrong', () {
    CombatUnit unitWith(String instanceId) => army.combatUnits
        .firstWhere((u) => u.group.any((g) => g.instanceId == instanceId));

    test('an ability-granted invulnerable save follows the purchase', () {
      // The Coldstar's 4+ lives in its shield-generator ability rather than
      // in `invuln_sv`, so the statline has to read the abilities — but only
      // the ones the unit *has*. A correction written against 40kdc made the
      // Shield Generator standard, and the card then printed a 4+ and the
      // rule on a Commander that never bought one.
      final coldstar = unitWith('u03');
      final commander =
          coldstar.profiles.firstWhere((p) => p.name.contains('Coldstar'));
      expect(commander.profile.invulnSv, isNull,
          reason: 'the reference list buys no Shield Generator');

      // The other direction: buying one brings both back.
      final bought = army.roster.copyWith(units: [
        for (final unit in army.roster.units)
          if (unit.instanceId == 'u03')
            unit.copyWith(wargear: [
              ...unit.wargear,
              const WargearSelection(itemId: 'shield-generator', count: 1),
            ])
          else
            unit,
      ]);
      final withShield = Army.fromSnapshot(bought, army.snapshot, id: 't');
      final armed = withShield.combatUnits
          .firstWhere((u) => u.group.any((g) => g.instanceId == 'u03'));
      expect(
        armed.profiles
            .firstWhere((p) => p.name.contains('Coldstar'))
            .profile
            .invulnSv,
        '4',
      );

      // …and it does not leak onto the suits it leads, either way.
      expect(
        armed.profiles
            .firstWhere((p) => p.name.contains('Starscythe'))
            .profile
            .invulnSv,
        isNull,
      );
    });

    test("an attached unit's abilities say which half owns them", () {
      final coldstar = unitWith('u03');
      expect(coldstar.isAttached, isTrue);
      final rules = {
        for (final r in coldstar.attributedRules) r.rule.abilityId: r.source,
      };
      // The Commander's, not the Crisis suits'.
      expect(rules['coldstar-commander'], 'Commander in Coldstar Battlesuit');
      expect(rules['starscythe'], 'Crisis Starscythe Battlesuits');
      // An option nobody bought is not one of the unit's rules.
      expect(rules.containsKey('shield-generator'), isFalse);
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
          .where((w) => w.displayName.contains('twin pulse carbine'));
      expect(carbines, hasLength(1));
      // One on the Commander, three on the Crisis suits.
      expect(carbines.single.weaponCount, 4);
      expect(carbines.single.keywords.map((k) => k.label),
          containsAll(['ASSAULT', 'TWIN LINKED']));
      // The drone's skill, not the battlesuit's — the Crisis suits beside it
      // fire their missile pods at 4+.
      expect(carbines.single.skill, '5+');
    });

    test("a Missile Drone's pod reaches the shooting table", () {
      final broadside = unitWith('u10');
      final pods = broadside
          .weapons(WeaponKind.ranged)
          .weapons
          .where((w) => w.displayName.contains('Drone missile pod'));
      expect(pods.single.weaponCount, 2);
      expect(pods.single.skill, '5+');
      expect(pods.single.attacks.fixed, 4);
    });

    test('the Coldstar sets Move to 12 rather than adding 12', () {
      final rule = unitWith('u03')
          .rules
          .firstWhere((r) => r.abilityId == 'coldstar-commander');
      // The screen shows the printed rule. The `set` versus `add` distinction
      // this test was written for lives in the derivation — rendering `set 12`
      // as "+12 Move" on a suit that already moves 12 was the original bug
      // (§3.7), and the guard belongs on the sentence that can still make it.
      expect(rule.isPrinted, isTrue);
      expect(rule.text, contains('Move characteristic of 12"'));
      expect(
        rule.derived,
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

  testWidgets('the army screen offers a way back, when there is one',
      (tester) async {
    // The page has no app bar — the tabs under it are the navigation — so
    // leaving was a swipe nobody was told about (§4.17).
    var left = false;
    await tester.pumpWidget(host(ArmyScreen(army: army, onBack: () {
      left = true;
    })));

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();

    expect(left, isTrue);
  });

  testWidgets('and none where there is nothing to go back to', (tester) async {
    await tester.pumpWidget(host(ArmyScreen(army: army)));

    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('the army screen shows points, findings and units',
      (tester) async {
    await tester.pumpWidget(host(ArmyScreen(army: army)));

    expect(find.text('2k ret'), findsOneWidget);
    expect(find.text('2000'), findsOneWidget);
    // Units carry their datasheet names, and an attached unit reads as the
    // character leading what it joined. This list fields the same pairing
    // twice, which is legal and shown as-is rather than disambiguated.
    expect(
      find.text('Commander in Enforcer Battlesuit with Crisis Fireknife '
          'Battlesuits'),
      findsNWidgets(2),
    );

    // Informational findings are surfaced, not hidden: these are the two the
    // design predicted for this list.
    expect(find.textContaining('Detachment Point'), findsOneWidget);
    expect(find.textContaining('slots unused'), findsOneWidget);
  });

  group('the turn page', () {
    BattleLog gameAt(int round) => BattleLog(events: [
          const ConfigureBattle(MissionSetup(
            myDisposition: 'reconnaissance',
            opponentDisposition: 'take-and-hold',
            myMissionId: 'reconnaissance-sweep',
            opponentMissionId: 'purge-and-secure',
          )),
          SetRound(round),
        ]);

    testWidgets('it opens on the turn, the score and the units',
        (tester) async {
      // Sorted by unit, not by phase. The page this replaced repeated every
      // unit under six phase headings and scrolled 41.7 screens a turn.
      useTallSurface(tester);
      await tester.pumpWidget(host(TurnScreen(army: army, log: gameAt(1))));

      expect(find.text('ROUND 1'), findsOneWidget);
      expect(find.text('Your turn'), findsOneWidget);
      // In the bar and again at the foot (§7.3.20).
      expect(find.text('End turn'), findsNWidgets(2));
      expect(find.text('UNITS'), findsOneWidget);
      // Phase headings are gone from the page's spine.
      expect(find.text('SHOOTING'), findsNothing);
      expect(find.text('MOVEMENT'), findsNothing);
    });

    testWidgets('each rule is named once per unit, not once per phase',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(TurnScreen(army: army, log: gameAt(1))));

      // The reference army fields two Fireknife units, so the name appears
      // twice — once for each unit that has it. What is gone is the third
      // axis: the old page drew every rule again under every phase it
      // touched, which is how 21 distinct rules became 66 renderings.
      expect(find.text('Fireknife'), findsNWidgets(2));
      // And it is the *name*: the printed text is 174-198 characters on
      // average and belongs on the card behind it.
      expect(find.textContaining('re-roll a Hit roll of 1', findRichText: true),
          findsNothing);
    });

    testWidgets('tapping a rule name opens its printed text', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(TurnScreen(army: army, log: gameAt(1))));

      await tester.tap(find.text('Fireknife').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('re-roll a Hit roll of 1', findRichText: true),
          findsOneWidget,
          reason: 'the only thing on this page behind a tap');
    });

    testWidgets('weapon statlines stay on the page', (tester) async {
      // Not behind a tap: clicking into a unit and back out again for every
      // gun is what the design is against.
      useTallSurface(tester);
      await tester.pumpWidget(host(
          TurnScreen(army: army, log: gameAt(1), density: PlayDensity.full)));

      expect(find.text('8 atk'), findsWidgets);
      expect(find.text('12 atk'), findsWidgets);
      expect(find.text('10D6 atk'), findsWidgets);
      expect(find.text('auto hit'), findsWidgets);
    });

    testWidgets('the names density folds the weapons away', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(
          TurnScreen(army: army, log: gameAt(1), density: PlayDensity.names)));

      expect(find.text('Fireknife'), findsNWidgets(2),
          reason: 'rule names stay whatever the density');
      expect(find.text('8 atk'), findsNothing);
    });

    testWidgets('guided adds the phase prompts, each rule once',
        (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(
          TurnScreen(army: army, log: gameAt(1), density: PlayDensity.guided)));

      expect(find.text('THIS TURN'), findsOneWidget);
      // Four units carry Deep Strike; the prompt says so once rather than
      // printing the rule four times.
      expect(find.textContaining('Deep Strike \u2014', findRichText: true),
          findsOneWidget);
    });

    testWidgets('scouting shows in round 1 and is gone from round 2',
        (tester) async {
      // A Scout move not taken before the first turn cannot be taken later.
      useTallSurface(tester);
      await tester.pumpWidget(host(TurnScreen(army: army, log: gameAt(1))));
      expect(find.text('SCOUT MOVES'), findsOneWidget);

      await tester.pumpWidget(host(TurnScreen(army: army, log: gameAt(2))));
      expect(find.text('SCOUT MOVES'), findsNothing);
    });

    testWidgets('both controls end the turn, through the review',
        (tester) async {
      useTallSurface(tester);
      final events = <BattleEvent>[];
      await tester.pumpWidget(host(TurnScreen(
        army: army,
        log: gameAt(1),
        onEvent: events.add,
      )));

      // Two of them: the bar's, and the one at the foot of the page where a
      // turn actually ends (§7.3.20). Both open the review first (§7.3.29) —
      // otherwise the bar's would be a way past it.
      expect(find.text('End turn'), findsNWidgets(2));

      for (final control in [0, 1]) {
        await tester.tap(find.text('End turn').at(control));
        await tester.pumpAndSettle();
        expect(find.text('Nothing scored this turn.'), findsOneWidget,
            reason: 'the review opens rather than the turn ending');

        await tester.tap(find.text('End turn').last);
        await tester.pumpAndSettle();
        expect(events, hasLength(control + 1));
        expect(events.last, isA<EndTurn>());
      }
    });
  });

  /// The END section, pumped on its own.
  ///
  /// It is the last thing on the turn page, below twelve units of weapon
  /// tables, and a `ListView` only builds what fits — so reaching it through
  /// `TurnScreen` tests the scroll extent rather than the panel.
  group('the scoring panel', () {
    late MissionPack pack;

    setUpAll(() async {
      pack = await DatasetRepository().missions();
    });

    BattleState stateOf({required bool iGoFirst}) => BattleLog(events: [
          ConfigureBattle(MissionSetup(
            myDisposition: 'reconnaissance',
            opponentDisposition: 'take-and-hold',
            myMissionId: 'reconnaissance-sweep',
            opponentMissionId: 'purge-and-secure',
            iGoFirst: iGoFirst,
          )),
        ]).state;

    Future<void> pumpPanel(
      WidgetTester tester, {
      required BattleState state,
      MissionPack? pack,
    }) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(SingleChildScrollView(
        child: ScoreBoard(
          state: state,
          deck: const SecondaryDeck([]),
          pack: pack ?? const MissionPack(),
          onEvent: (_) {},
        ),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('names each side’s primary, and they are different',
        (tester) async {
      await pumpPanel(tester, state: stateOf(iGoFirst: true), pack: pack);

      // The matchup table is asymmetric, so the two rows are two missions.
      expect(find.text('Reconnaissance Sweep'), findsOneWidget);
      expect(find.text('Purge and Secure'), findsOneWidget);
    });

    testWidgets('and expands to the card, with a button on each payout',
        (tester) async {
      await pumpPanel(tester, state: stateOf(iGoFirst: true), pack: pack);

      // One line of the card, rather than the whole blob: the text renders a
      // widget per line now, so each payout can carry its own button
      // (§7.3.22).
      const line = 'Three or more friendly units are wholly within';
      expect(find.textContaining(line, findRichText: true), findsNothing,
          reason: 'closed by default — the row is a summary');

      await tester.tap(find.text('Reconnaissance Sweep'));
      await tester.pumpAndSettle();
      expect(find.textContaining(line, findRichText: true), findsOneWidget);

      // And the button that scores it sits on that line, not above the text.
      expect(find.textContaining(RegExp(r'^Score \d+$')), findsWidgets);
    });

    testWidgets('opening one side does not open the other', (tester) async {
      await pumpPanel(tester, state: stateOf(iGoFirst: true), pack: pack);
      await tester.tap(find.text('Reconnaissance Sweep'));
      await tester.pumpAndSettle();

      final theirs =
          pack.card('purge-and-secure')!.text.split('.').first.trim();
      expect(find.textContaining(theirs), findsNothing);
    });

    testWidgets('degrades to the bare steppers with no mission data',
        (tester) async {
      await pumpPanel(tester, state: stateOf(iGoFirst: true));

      expect(find.text('PRIMARY'), findsWidgets);
      expect(find.byIcon(Icons.flag_outlined), findsNothing,
          reason: 'no empty disclosure to tap');
    });
  });
}
