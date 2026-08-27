import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

void main() {
  test('AppTheme.light and AppTheme.dark build without throwing', () {
    expect(AppTheme.light, isA<ThemeData>());
    expect(AppTheme.dark, isA<ThemeData>());
    expect(AppTheme.light.useMaterial3, isTrue);
    expect(AppTheme.dark.useMaterial3, isTrue);
  });

  test('onSurface over surface meets 4.5:1 in both themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      final ratio = _contrastRatio(scheme.onSurface, scheme.surface);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: '${scheme.brightness} onSurface/surface was $ratio',
      );
    }
  });

  test('the pairs the screens actually paint meet 4.5:1 in both themes', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      final pairs = <String, (Color, Color)>{
        'onSurface/surface': (scheme.onSurface, scheme.surface),
        'onSurfaceVariant/surface': (scheme.onSurfaceVariant, scheme.surface),
        'onSurface/inputFill': (
          scheme.onSurface,
          scheme.surfaceContainerHighest,
        ),
        'hint/inputFill': (
          scheme.onSurfaceVariant,
          scheme.surfaceContainerHighest,
        ),
        'error/surface': (scheme.error, scheme.surface),
        'onError/error': (scheme.onError, scheme.error),
        'onPrimary/primary': (scheme.onPrimary, scheme.primary),
        'snackbar': (scheme.onInverseSurface, scheme.inverseSurface),
        'onPrimaryContainer/primaryContainer': (
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        ),
        'selectedNav/bar': (scheme.primary, scheme.surfaceContainer),
        'unselectedNav/bar': (scheme.onSurfaceVariant, scheme.surfaceContainer),
      };
      for (final entry in pairs.entries) {
        final ratio = _contrastRatio(entry.value.$1, entry.value.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '${scheme.brightness} ${entry.key} was ${ratio.toStringAsFixed(2)}',
        );
      }
    }
  });

  test('status chip foreground over background meets 4.5:1 in both themes', () {
    for (final status in AppStatus.values) {
      for (final brightness in Brightness.values) {
        final visual = statusColors(status, brightness);
        final ratio = _contrastRatio(visual.foreground, visual.background);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$brightness $status was ${ratio.toStringAsFixed(2)} '
              '(${visual.label})',
        );
      }
    }
  });

  test('statusColors covers every value of the four contract enums', () {
    const wiresByEnum = {
      'MaintenanceStatus': [
        'vencido',
        'vence_em_breve',
        'em_dia',
        'sem_baseline',
        'sem_periodicidade',
      ],
      'ObligationStatus': ['pago', 'vencido', 'vence_em_breve', 'pendente'],
      'SeguroStatus': ['futuro', 'vigente', 'vence_em_breve', 'vencido'],
      'AlertSeverity': ['vencido', 'vence_em_breve'],
    };
    const expected = {
      'vencido': AppStatus.vencido,
      'vence_em_breve': AppStatus.venceEmBreve,
      'em_dia': AppStatus.emDia,
      'sem_baseline': AppStatus.semBaseline,
      'sem_periodicidade': AppStatus.semPeriodicidade,
      'pago': AppStatus.pago,
      'pendente': AppStatus.pendente,
      'futuro': AppStatus.futuro,
      'vigente': AppStatus.vigente,
    };

    for (final entry in wiresByEnum.entries) {
      for (final wire in entry.value) {
        final status = AppStatus.fromWire(wire);
        expect(status, expected[wire], reason: '${entry.key}.$wire');
        for (final brightness in Brightness.values) {
          final visual = statusColors(status, brightness);
          expect(visual.foreground, isNot(visual.background));
          expect(visual.label, isNotEmpty);
        }
      }
    }

    expect(
      AppStatus.fromWire('valor_desconhecido'),
      AppStatus.semPeriodicidade,
    );
    expect(
      () => statusColors(AppStatus.semPeriodicidade, Brightness.light),
      returnsNormally,
    );
  });

  test('sem_baseline is not painted as an alert', () {
    final overdue = statusColors(AppStatus.vencido, Brightness.light);
    final dueSoon = statusColors(AppStatus.venceEmBreve, Brightness.light);
    final pending = statusColors(AppStatus.semBaseline, Brightness.light);

    expect(pending.foreground, isNot(overdue.foreground));
    expect(pending.foreground, isNot(dueSoon.foreground));
    expect(pending.background, isNot(overdue.background));
    expect(pending.background, isNot(dueSoon.background));
  });

  test('numeric text styles use tabular figures', () {
    final theme = AppTheme.light.textTheme;
    for (final style in [
      theme.displayLarge,
      theme.headlineLarge,
      theme.titleLarge,
      theme.bodyLarge,
      theme.bodyMedium,
    ]) {
      expect(style?.fontFeatures, AppTypography.tabular);
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}
