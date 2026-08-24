import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wh40k_app/src/widgets/collapsible.dart';

/// §7.7: nothing the player set changes without the player doing something.
///
/// The failure these guard is not theoretical. A `ListView` builds what is
/// near the screen and disposes the rest, so a block opened at the top of the
/// turn page had folded itself shut by the time the player scrolled back to
/// it — the app undoing a choice nobody undid.
void main() {
  Widget host() => MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const CollapsibleGroup(
                title: 'FIRST',
                initiallyOpen: false,
                child: Text('first body'),
              ),
              // Far taller than any cache extent, so the group above is really
              // disposed rather than merely off-screen.
              for (var i = 0; i < 12; i++)
                SizedBox(height: 900, child: Text('filler $i')),
              const CollapsibleGroup(
                title: 'LAST',
                initiallyOpen: false,
                child: Text('last body'),
              ),
            ],
          ),
        ),
      );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('a group stays open when it is scrolled away and back',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(host());

    await tester.tap(find.text('FIRST'));
    await tester.pumpAndSettle();
    expect(find.text('first body'), findsOneWidget);

    // Away, far enough to be thrown away…
    await tester.drag(find.byType(ListView), const Offset(0, -9000));
    await tester.pumpAndSettle();
    expect(find.text('FIRST'), findsNothing, reason: 'really disposed');

    // …and back.
    await tester.drag(find.byType(ListView), const Offset(0, 9000));
    await tester.pumpAndSettle();
    expect(find.text('FIRST'), findsOneWidget);
    expect(find.text('first body'), findsOneWidget,
        reason: 'the player opened it and never closed it');
  });

  testWidgets('a group left closed stays closed', (tester) async {
    phone(tester);
    await tester.pumpWidget(host());

    await tester.drag(find.byType(ListView), const Offset(0, -9000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 9000));
    await tester.pumpAndSettle();

    expect(find.text('first body'), findsNothing,
        reason: 'remembering must not mean opening');
  });

  testWidgets('two groups are remembered separately', (tester) async {
    phone(tester);
    await tester.pumpWidget(host());

    await tester.tap(find.text('FIRST'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('LAST'), 900);
    await tester.pumpAndSettle();
    await tester.tap(find.text('LAST'));
    await tester.pumpAndSettle();
    expect(find.text('last body'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('FIRST'), -900);
    await tester.pumpAndSettle();
    expect(find.text('first body'), findsOneWidget);
  });

  testWidgets('closing it again is remembered too', (tester) async {
    phone(tester);
    await tester.pumpWidget(host());

    await tester.tap(find.text('FIRST'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FIRST'));
    await tester.pumpAndSettle();
    expect(find.text('first body'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -9000));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 9000));
    await tester.pumpAndSettle();
    expect(find.text('first body'), findsNothing);
  });

  // Tab switching is not tested here on purpose. `ArmyPage` loads behind a
  // FutureBuilder whose spinner never settles, so pumping it hangs the suite
  // rather than failing it — a test that cannot fail is worse than none. What
  // keeps the tabs alive is the `IndexedStack` in `main.dart`, recorded in
  // §7.7; replacing it with a conditional is the regression to watch for, and
  // it is a code review rather than a test.
}
