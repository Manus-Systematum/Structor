import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/army.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/screens/setup_screen.dart';
import 'package:wh40k_app/src/widgets/deployment_diagram.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  late Army army;
  late MissionPack pack;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    army = await Army.loadReference();
    pack = await DatasetRepository().missions();
  });

  /// A tall surface so the whole form is laid out and hit-testable, rather
  /// than fighting scroll position in every test.
  Future<void> pumpSetup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(MaterialApp(home: SetupScreen(army: army, pack: pack)));
    await tester.pumpAndSettle();
  }

  Future<void> chooseMine(WidgetTester tester, String mission) async {
    final option = find.ancestor(
      of: find.textContaining('You would play $mission'),
      matching: find.byType(InkWell),
    );
    await tester.tap(option.first);
    await tester.pumpAndSettle();
  }

  testWidgets('the decision grid appears once the opponent declares',
      (tester) async {
    await pumpSetup(tester);
    expect(find.textContaining('Pick your opponent'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Take and Hold'));
    await tester.pumpAndSettle();

    // The reference army's detachments offer Reconnaissance or Priority
    // Assets, and the two lead to different missions — the decision.
    expect(find.textContaining('You would play Reconnaissance Sweep'),
        findsOneWidget);
    expect(find.textContaining('You would play Secure Asset'), findsOneWidget);
  });

  testWidgets('choosing reveals what the opponent is playing', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Take and Hold'));
    await tester.pumpAndSettle();
    await chooseMine(tester, 'Reconnaissance Sweep');

    // Asymmetric: they play a different primary simultaneously.
    expect(find.text('THEY PLAY'), findsOneWidget);
    expect(find.text('Purge and Secure'), findsOneWidget);
  });

  testWidgets(
      'the same choice yields a different mission against a '
      'different opponent', (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Disruption'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('You would play Surveil the Foe'), findsOneWidget);
  });

  testWidgets('start stays disabled until every question is answered',
      (tester) async {
    await pumpSetup(tester);

    FilledButton bottomButton() => tester.widget<FilledButton>(
          find
              .descendant(
                of: find.byType(Scaffold),
                matching: find.byType(FilledButton),
              )
              .last,
        );

    expect(bottomButton().onPressed, isNull);
    expect(find.text('Answer the questions above'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Take and Hold'));
    await tester.pumpAndSettle();
    await chooseMine(tester, 'Reconnaissance Sweep');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tipping Point'));
    await tester.pumpAndSettle();

    expect(find.text('Start battle'), findsOneWidget);
    expect(bottomButton().onPressed, isNotNull);
  });

  testWidgets('completing setup returns both missions', (tester) async {
    MissionSetup? captured;
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            captured = await Navigator.of(context).push<MissionSetup>(
              MaterialPageRoute(
                  builder: (_) => SetupScreen(army: army, pack: pack)),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Take and Hold'));
    await tester.pumpAndSettle();
    await chooseMine(tester, 'Reconnaissance Sweep');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tipping Point'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start battle'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.myMissionId, 'reconnaissance-sweep');
    expect(captured!.opponentMissionId, 'purge-and-secure',
        reason: 'the opponent plays their own cell of the table');
    expect(captured!.deploymentId, 'tipping-point');
    expect(captured!.isMirror, isFalse);
    expect(captured!.iGoFirst, isTrue, reason: 'the default is unchanged');
  });

  testWidgets('who takes the first turn is recorded, not assumed',
      (tester) async {
    MissionSetup? captured;
    tester.view.physicalSize = const Size(1200, 4200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            captured = await Navigator.of(context).push<MissionSetup>(
              MaterialPageRoute(
                  builder: (_) => SetupScreen(army: army, pack: pack)),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Take and Hold'));
    await tester.pumpAndSettle();
    await chooseMine(tester, 'Reconnaissance Sweep');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tipping Point'));
    await tester.pumpAndSettle();

    // The opponent going first is not implied by attacker/defender, and until
    // it could be said the app ran every game as though it opened.
    await tester.tap(
        find.widgetWithText(ButtonSegment<bool>, 'Opponent').evaluate().isEmpty
            ? find.text('Opponent').last
            : find.text('Opponent').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start battle'));
    await tester.pumpAndSettle();

    expect(captured, isNotNull);
    expect(captured!.iGoFirst, isFalse);

    // And the game opens in their turn rather than mine.
    final log = BattleLog(events: [ConfigureBattle(captured!)]);
    expect(log.state.activePlayer, Player.opponent);
  });

  testWidgets('picking a deployment draws the table', (tester) async {
    await pumpSetup(tester);
    expect(find.byType(DeploymentDiagram), findsNothing,
        reason: 'nothing to draw before one is chosen');

    await tester.tap(find.widgetWithText(ChoiceChip, 'Tipping Point'));
    await tester.pumpAndSettle();

    expect(find.byType(DeploymentDiagram), findsOneWidget);
    // The pattern is symmetric, so a colour alone does not say which half is
    // yours — the key names it.
    expect(find.text('You'), findsWidgets);
    expect(find.text('Opponent'), findsWidgets);
    expect(find.textContaining('60″ × 44″'), findsOneWidget);
    expect(find.textContaining('5 objectives'), findsOneWidget);
  });

  testWidgets('the table opens full screen with measurements', (tester) async {
    // The inline picture shows the shape; setting a table out needs numbers,
    // and "about there" is not a position.
    await pumpSetup(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tipping Point'));
    await tester.pumpAndSettle();

    expect(find.text('Tap the table for measurements'), findsOneWidget);
    await tester.tap(find.byType(DeploymentDiagram));
    await tester.pumpAndSettle();

    expect(find.textContaining('Grid every 3'), findsOneWidget);
    expect(find.textContaining('two nearest edges'), findsOneWidget);
    // Two diagrams now exist — the inline one behind the dialog and the
    // measured one in it.
    final measured = tester
        .widgetList<DeploymentDiagram>(find.byType(DeploymentDiagram))
        .where((d) => d.measured);
    expect(measured, hasLength(1));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.textContaining('Grid every 6'), findsNothing);
  });

  testWidgets('the full-screen table turns to fit a tall screen',
      (tester) async {
    // A phone is tall and a table is wide. Drawn upright the 60x44 board
    // fills 44% of the height it is given, at 6.3 pixels to the inch; turned
    // it fills 82%, at 8.6 — the board's own aspect ratio, 1.36x, and the
    // difference between reading a number and guessing it.
    await pumpSetup(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tipping Point'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DeploymentDiagram));
    await tester.pumpAndSettle();

    final measured = tester
        .widgetList<DeploymentDiagram>(find.byType(DeploymentDiagram))
        .firstWhere((d) => d.measured);
    expect(measured.turned, isTrue);
    expect(measured.zoomable, isTrue);

    // The inline one is not turned: it sits in a scrolling form, where a tall
    // picture pushes the questions below it off the screen.
    final inline = tester
        .widgetList<DeploymentDiagram>(find.byType(DeploymentDiagram))
        .firstWhere((d) => !d.measured);
    expect(inline.turned, isFalse);

    final box = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
    expect(box.map((a) => a.aspectRatio), contains(closeTo(44 / 60, 0.001)),
        reason: 'the long edge runs down the screen');
  });

  testWidgets('a square table is left alone', (tester) async {
    // kotc-colosseum is 36x36, where a quarter turn is the identity. Turning
    // it would relabel the edges and change nothing else.
    await pumpSetup(tester);
    await tester
        .tap(find.widgetWithText(ChoiceChip, 'KOTC Colosseum (9" edges)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DeploymentDiagram));
    await tester.pumpAndSettle();

    final box = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
    expect(box.map((a) => a.aspectRatio), everyElement(closeTo(1, 0.001)));
  });

  testWidgets('the measured table can be pinched, the inline one cannot',
      (tester) async {
    await pumpSetup(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tipping Point'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing,
        reason: 'a pinchable picture inside a scrolling form fights the form');

    await tester.tap(find.byType(DeploymentDiagram));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('a smaller table is drawn at its own size', (tester) async {
    await pumpSetup(tester);
    await tester
        .tap(find.widgetWithText(ChoiceChip, 'KOTC Colosseum (9" edges)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('36″ × 36″'), findsOneWidget);
    expect(find.textContaining('objectives'), findsNothing,
        reason: 'it publishes none, so none are claimed');
  });
}
