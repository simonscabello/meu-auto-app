import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meu_auto/core/theme/app_status_colors.dart';
import 'package:meu_auto/core/theme/app_theme.dart';
import 'package:meu_auto/shared/widgets/app_status_chip.dart';

void main() {
  testWidgets('every status is named in text and shown with an icon', (
    tester,
  ) async {
    for (final status in AppStatus.values) {
      final visual = statusColors(status, Brightness.light);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: AppStatusChip(status: status)),
        ),
      );

      expect(find.text(visual.label), findsOneWidget);
      expect(find.byIcon(visual.icon), findsOneWidget);
    }
  });
}
