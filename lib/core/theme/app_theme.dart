import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meu_auto/core/theme/app_colors.dart';
import 'package:meu_auto/core/theme/app_radius.dart';
import 'package:meu_auto/core/theme/app_spacing.dart';
import 'package:meu_auto/core/theme/app_tones.dart';
import 'package:meu_auto/core/theme/app_typography.dart';

/// The one place stock Material widgets are told what Meu Auto looks like.
///
/// Screens build from `lib/shared/widgets`, which read the same tokens; this
/// keeps whatever Material draws on its own — a date picker, a dialog, a
/// switch — in the same identity, so nothing on screen looks borrowed.
abstract final class AppTheme {
  static ThemeData get light => _build(AppColors.light, AppTones.light);

  static ThemeData get dark => _build(AppColors.dark, AppTones.dark);

  static ThemeData _build(ColorScheme scheme, AppTones tones) {
    final textTheme = AppTypography.textTheme(scheme);
    final dark = scheme.brightness == Brightness.dark;
    const shapeM = RoundedRectangleBorder(borderRadius: AppRadius.borderM);
    const shapeL = RoundedRectangleBorder(borderRadius: AppRadius.borderL);
    const tapTarget = Size(AppSpacing.minTapTarget, AppSpacing.minTapTarget);
    const buttonHeight = Size(64, 52);

    final buttonBase = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(buttonHeight),
      tapTargetSize: MaterialTapTargetSize.padded,
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(shapeM),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.s20),
      ),
      textStyle: WidgetStatePropertyAll(
        textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
      overlayColor: WidgetStatePropertyAll(tones.overlayPressed),
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: AppRadius.borderM,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: kAppFontFamily,
      extensions: [tones],
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: tones.divider,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 60,
        titleSpacing: AppSpacing.s4,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scheme.surfaceContainer,
                systemNavigationBarIconBrightness: Brightness.light,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: scheme.surfaceContainer,
                systemNavigationBarIconBrightness: Brightness.dark,
              ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderM,
          side: BorderSide(color: tones.stroke),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        helperMaxLines: 3,
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        disabledBorder: inputBorder(
          scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        focusedBorder: inputBorder(scheme.primary, width: 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, width: 1.5),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          final base = textTheme.labelMedium!;
          if (states.contains(WidgetState.error)) {
            return base.copyWith(color: scheme.error);
          }
          if (states.contains(WidgetState.focused)) {
            return base.copyWith(color: scheme.primary);
          }
          return base.copyWith(color: scheme.onSurfaceVariant);
        }),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        suffixStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonBase.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.primary.withValues(alpha: 0.32);
            }
            return scheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onPrimary.withValues(alpha: 0.6);
            }
            return scheme.onPrimary;
          }),
          overlayColor: WidgetStatePropertyAll(
            scheme.onPrimary.withValues(alpha: 0.1),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonBase.copyWith(
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return BorderSide(color: tones.stroke);
            }
            return BorderSide(color: tones.strokeStrong);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: buttonBase.copyWith(
          minimumSize: const WidgetStatePropertyAll(tapTarget),
          foregroundColor: WidgetStatePropertyAll(scheme.primary),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonBase),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: tapTarget,
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: scheme.onSurfaceVariant,
          highlightColor: tones.overlayPressed,
        ),
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        pressElevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderPill),
        side: BorderSide(color: tones.stroke),
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        checkmarkColor: scheme.onPrimaryContainer,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: AppSpacing.s12,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderS),
      ),
      dividerTheme: DividerThemeData(
        color: tones.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(36, 4),
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: scheme.scrim.withValues(alpha: dark ? 0.6 : 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.l),
          ),
          side: BorderSide(color: tones.stroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.primary,
        closeIconColor: scheme.onInverseSurface,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.s16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderM,
          side: BorderSide(color: tones.strokeStrong),
        ),
      ),
      // A flat bar with no indicator pill: selection is carried by the filled
      // icon and the accent. The bar itself is one step off the page with a
      // hairline along its top, drawn by AppShell.
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        overlayColor: WidgetStatePropertyAll(tones.overlayPressed),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderL,
          side: BorderSide(color: tones.stroke),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 20),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.5,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s12,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderM,
          side: BorderSide(color: tones.stroke),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      datePickerTheme: DatePickerThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.surfaceContainerHighest,
        headerForegroundColor: scheme.onSurface,
        shape: shapeL,
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        todayBorder: BorderSide(color: scheme.primary),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        shape: shapeL,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return scheme.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderXs),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return scheme.outline;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: tones.track,
        circularTrackColor: Colors.transparent,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.3),
        selectionHandleColor: scheme.primary,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: AppRadius.borderS,
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        shape: Border(),
        collapsedShape: Border(),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
      ),
    );
  }
}
