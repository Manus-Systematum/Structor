import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/battle_record.dart';
import 'package:wh40k_core/wh40k_core.dart';

void main() {
  const setup = MissionSetup(
    myDisposition: 'a',
    opponentDisposition: 'b',
    myMissionId: 'm',
    opponentMissionId: 'n',
    opponentName: 'Kara',
  );

  Widget host(BattleLog log, {String Function(String)? unit}) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BattleRecord(
              log: log,
              unitName: unit,
              cardName: (id) => id == 'overwatch' ? 'Fire Overwatch' : id,
              opponentName: 'Kara',
            ),
          ),
        ),
      );

  BattleLog gameOf(List<BattleEvent> events) => BattleLog(
        events: <BattleEvent>[const ConfigureBattle(setup), ...events],
      );

  testWidgets('an empty game says so rather than showing an empty list',
      (tester) async {
    await tester.pumpWidget(host(const BattleLog()));
    expect(find.text('Nothing recorded yet.'), findsOneWidget);
  });

  testWidgets('scores are grouped under the round they happened in',
      (tester) async {
    await tester.pumpWidget(host(gameOf(const [
      ScoreVp(side: Player.me, kind: ScoreKind.primary, round: 1, vp: 4),
      EndTurn(),
      EndTurn(),
      ScoreVp(side: Player.opponent, kind: ScoreKind.primary, round: 2, vp: 5),
    ])));

    expect(find.text('ROUND 1'), findsOneWidget);
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(find.text('+4 primary'), findsOneWidget);
    expect(find.text('+5 primary'), findsOneWidget);
    // Whose points they were, since both sides are recorded here.
    expect(find.text('you'), findsOneWidget);
    expect(find.text('Kara'), findsOneWidget);
  });

  testWidgets('an event carrying no round takes it from the ones before',
      (tester) async {
    await tester.pumpWidget(host(gameOf(const [
      EndTurn(),
      EndTurn(),
      DrawSecondary('overwatch'),
    ])));
    // Drawn after a full round of turns, so it belongs to round 2.
    expect(find.text('ROUND 2'), findsOneWidget);
    expect(find.text('ROUND 1'), findsNothing,
        reason: 'round 1 recorded nothing worth showing');
    expect(find.text('Drew Fire Overwatch'), findsOneWidget);
  });

  testWidgets('bookkeeping is left out', (tester) async {
    // Correcting a command point by hand is how the log stays honest, not
    // something that happened in the game. Printing it makes a record into
    // an audit.
    await tester.pumpWidget(host(gameOf(const [
      AdjustCp(3),
      SetRound(3),
      SetActivePlayer(Player.opponent),
    ])));
    expect(find.text('Nothing recorded yet.'), findsOneWidget);
  });

  testWidgets('a stratagem records what it cost and where', (tester) async {
    await tester.pumpWidget(host(
      gameOf(const [
        UseStratagem(
          stratagemId: 'overwatch',
          targetInstanceId: 'u02',
          round: 1,
          phase: 'shooting',
          cp: 1,
        ),
      ]),
      unit: (id) => id == 'u02' ? 'Crisis Fireknife Battlesuits' : id,
    ));
    expect(find.textContaining('Fire Overwatch', findRichText: true),
        findsOneWidget);
    expect(find.text('1 CP · shooting'), findsOneWidget);
  });

  testWidgets('a unit deleted since is shown as the log holds it',
      (tester) async {
    // A finished battle outlives the roster it was played with. Blanking the
    // line would lose the only record that the casualty happened.
    await tester.pumpWidget(host(gameOf(const [
      SetModelsRemaining(instanceId: 'u07', models: 0),
    ])));
    expect(find.text('u07 destroyed'), findsOneWidget);
  });

  testWidgets('casualties short of destruction are recorded too',
      (tester) async {
    await tester.pumpWidget(host(
      gameOf(const [SetModelsRemaining(instanceId: 'u02', models: 2)]),
      unit: (id) => 'Riptide',
    ));
    expect(find.text('Riptide down to 2'), findsOneWidget);
  });
}
