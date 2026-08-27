import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_button.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget button, {
    Size surface = const Size(400, 200),
  }) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: Center(child: button)),
      ),
    );
  }

  testWidgets('renders the four variants', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              AppButton(label: 'Primário', onPressed: () {}),
              const AppButton(
                label: 'Secundário',
                variant: AppButtonVariant.secondary,
                onPressed: _noop,
              ),
              const AppButton(
                label: 'Excluir',
                variant: AppButtonVariant.destructive,
                onPressed: _noop,
              ),
              const AppButton(
                label: 'Auxiliar',
                variant: AppButtonVariant.tertiary,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Primário'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Secundário'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Excluir'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Auxiliar'), findsOneWidget);
  });

  testWidgets('loading disables the press and shows a spinner', (tester) async {
    var pressed = 0;
    await pump(
      tester,
      AppButton(
        label: 'Salvar',
        loading: true,
        onPressed: () => pressed++,
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    expect(pressed, 0);
  });

  testWidgets('disabled has no press handler and no spinner', (tester) async {
    await pump(
      tester,
      const AppButton(label: 'Salvar', onPressed: null),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('tertiary loading and disabled match the other variants', (
    tester,
  ) async {
    await pump(
      tester,
      const AppButton(
        label: 'Mais detalhes',
        variant: AppButtonVariant.tertiary,
        loading: true,
        onPressed: _noop,
      ),
    );

    final loading = tester.widget<TextButton>(find.byType(TextButton));
    expect(loading.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await pump(
      tester,
      const AppButton(
        label: 'Mais detalhes',
        variant: AppButtonVariant.tertiary,
        onPressed: null,
      ),
    );

    final disabled = tester.widget<TextButton>(find.byType(TextButton));
    expect(disabled.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('every variant meets the minimum tap target', (tester) async {
    for (final variant in AppButtonVariant.values) {
      await pump(
        tester,
        AppButton(label: 'Ação', variant: variant, onPressed: () {}),
      );
      final size = tester.getSize(find.byType(AppButton));
      expect(
        size.height,
        greaterThanOrEqualTo(AppSpacing.minTapTarget),
        reason: '$variant is shorter than the tap target',
      );
      expect(
        size.width,
        greaterThanOrEqualTo(AppSpacing.minTapTarget),
        reason: '$variant is narrower than the tap target',
      );
    }
  });
}

void _noop() {}
