import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/features/update/application/app_update_provider.dart';
import 'package:meu_auto/features/update/domain/app_release.dart';
import 'package:meu_auto/features/update/presentation/app_update_notice.dart';

void main() {
  testWidgets('the row names the version and opens the download', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AppUpdateRow(version: '1.2.0', onUpdate: () => taps++),
        ),
      ),
    );

    expect(find.text('Atualizar o Meu Auto'), findsOneWidget);
    expect(find.text('Versão 1.2.0 disponível'), findsOneWidget);

    await tester.tap(find.text('Atualizar o Meu Auto'));
    expect(taps, 1);
  });

  testWidgets('a newer release reads without its build number', (tester) async {
    await _pumpNotice(
      tester,
      release: AppRelease(
        version: '1.2.0+7',
        apkUrl: Uri.parse('https://example.test/meu-auto.apk'),
      ),
    );

    expect(find.text('Versão 1.2.0 disponível'), findsOneWidget);
    expect(find.textContaining('+7'), findsNothing);
  });

  // Início must not grow a gap above the car while there is nothing to say.
  testWidgets('with nothing to offer the notice takes no room', (tester) async {
    await _pumpNotice(tester, release: null);

    expect(find.byType(AppUpdateRow), findsNothing);
    expect(tester.getSize(find.byType(AppUpdateNotice)).height, 0);
  });

  testWidgets('fits a small phone at large text', (tester) async {
    tester.view.physicalSize = const Size(360, 640) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pumpNotice(
      tester,
      textScale: 1.6,
      release: AppRelease(
        version: '10.12.3',
        apkUrl: Uri.parse('https://example.test/meu-auto.apk'),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Atualizar o Meu Auto'), findsOneWidget);
  });
}

Future<void> _pumpNotice(
  WidgetTester tester, {
  required AppRelease? release,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appUpdateProvider.overrideWith((ref) async => release)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [AppUpdateNotice(), Text('Prius · QAF5G33')],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
