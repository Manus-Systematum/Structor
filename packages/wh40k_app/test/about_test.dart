import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wh40k_app/src/data/dataset_repository.dart';
import 'package:wh40k_app/src/screens/about_screen.dart';

void main() {
  late DatasetRepository repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Structor',
      packageName: 'dev.structor.app',
      version: '0.1.0',
      buildNumber: '2',
      buildSignature: '',
    );
    // Pre-warm so the screen's futures resolve in a microtask; pumpAndSettle
    // waits for frames and timers, not for arbitrary async work.
    repo = DatasetRepository();
    await repo.manifest();
    await repo.faction('tau-empire');
  });

  Future<void> pumpAbout(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: AboutScreen(datasets: repo)));
    await tester.pumpAndSettle();
  }

  testWidgets('the required attribution is present verbatim', (tester) async {
    await pumpAbout(tester);

    // 40kdc-data's licence obliges any public deployment to show this exact
    // phrase and a link. If this test fails, the app is out of compliance —
    // fix the screen, not the test.
    expect(find.text('Powered by 40kdc-data'), findsOneWidget);
    // Wahapedia's export asks for this phrase in return for the stratagem
    // text; it is the only thing the source asks for (§3.12).
    expect(find.text('Powered by Wahapedia'), findsOneWidget);
    expect(find.text('https://40kdc.alpacasoft.dev'), findsOneWidget);
    expect(find.textContaining('CC BY 4.0'), findsOneWidget);
    expect(find.textContaining('Alpaca Software'), findsOneWidget);
  });

  testWidgets('the Games Workshop disclaimer is present', (tester) async {
    await pumpAbout(tester);
    expect(find.textContaining('unofficial'), findsOneWidget);
    expect(find.textContaining('Games Workshop Limited'), findsOneWidget);
  });

  testWidgets('provisional data is disclosed, not presented as current',
      (tester) async {
    await pumpAbout(tester);
    // T'au content is still on a pre-launch dataslate (DESIGN.md §3.0).
    expect(find.textContaining('provisional'), findsOneWidget);
  });

  testWidgets('the build number is shown, for bug reports', (tester) async {
    await pumpAbout(tester);
    expect(find.textContaining('build'), findsOneWidget);
  });
}
