import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/data/keyword_scope.dart';
import 'package:wh40k_app/src/widgets/weapon_table.dart';
import 'package:wh40k_core/wh40k_core.dart';

/// One profile carrying two keywords: one the data explains, one it does not.
AggregationResult _result() {
  final profile = WeaponProfile.fromJson({
    'name': 'T’au flamer',
    'range': '12',
    'attacks': 'D6',
    'strength': '4',
    'ap': '0',
    'damage': '1',
    'keywords': [
      {'keyword_id': 'torrent'},
      {'keyword_id': 'impaled'},
    ],
  });

  return AggregationResult(
    weapons: [
      AggregatedWeapon(
        displayName: 'T’au flamer',
        weaponId: 'flamer',
        profile: profile,
        weaponCount: 2,
        attacks: const AttackTotal('2D6'),
        skill: null,
        carrierInstanceIds: const ['u1'],
      ),
    ],
    unresolved: const [],
  );
}

void main() {
  Widget host({Map<String, WeaponKeywordText> keywords = const {}}) =>
      MaterialApp(
        home: Scaffold(
          body: WeaponKeywordScope(
            keywords: keywords,
            child: SingleChildScrollView(child: WeaponTable(result: _result())),
          ),
        ),
      );

  const torrent = WeaponKeywordText(
    id: 'torrent',
    name: 'Torrent',
    text: 'Each time an attack is made with a **[TORRENT]** weapon, that '
        'attack automatically hits the target.',
  );

  testWidgets('a keyword with published wording opens it', (tester) async {
    await tester.pumpWidget(host(keywords: {'torrent': torrent}));

    await tester.tap(find.text('TORRENT'));
    await tester.pumpAndSettle();
    expect(find.textContaining('automatically hits', findRichText: true),
        findsOneWidget);
  });

  // 40kdc ships every keyword with `effect: null`; BSData covers 33 of the 34
  // and the one it misses is used by no weapon. A chip with nothing behind it
  // must not invite a tap that opens an empty sheet.
  testWidgets('a keyword with none is not a tap', (tester) async {
    await tester.pumpWidget(host(keywords: {'torrent': torrent}));

    expect(find.text('IMPALED'), findsOneWidget);
    await tester.tap(find.text('IMPALED'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('with no scope at all, every chip is inert', (tester) async {
    await tester.pumpWidget(host());

    await tester.tap(find.text('TORRENT'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
