import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/session/token_storage.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/main.dart';

import 'support/design_gallery.dart';

void main() {
  testWidgets('signed-out app reaches the login screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWith((ref) => TokenStorage.memory()),
        ],
        child: const MeuAutoApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('design gallery lays out in both themes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(theme: theme, home: const DesignGallery()),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Tentar de novo'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(find.text('Tentar de novo'), findsOneWidget);
    }
  });
}
