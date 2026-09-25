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
    const controlShape = RoundedRectangleBorder(
      borderRadius: AppRadius.borderControl,
    );
    const sheetShape = RoundedRectangleBorder(borderRadius: AppRadius.borderL);
    const tapTarget = Size(AppSpacing.minTapTarget, AppSpacing.minTapTarget);

    // The button hierarchy, top to bottom:
    //
    //   primary     FilledButton         the accent, filled — one per screen
    //   secondary   FilledButton.tonal   neutral fill — an alternative of
    //                                    equal weight, never competing
    //   tertiary    TextButton           text only — a way out, a rare choice
    //   destructive tonal red, and only where it has been confirmed
    //
    // Outlined is kept for the odd place that must sit on a card of the same
    // tone, and is not in the main hierarchy: a border with no fill sits
    // between tonal and text without being better than either.
    final buttonBase = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(64, AppSpacing.buttonHeight),
      ),
      tapTargetSize: MaterialTapTargetSize.padded,
      elevation: const WidgetStatePropertyAll(0),
      shape: const WidgetStatePropertyAll(controlShape),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: AppSpacing.s20),
      ),
      textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
      overlayColor: WidgetStatePropertyAll(tones.overlayPressed),
    );

    OutlineInputBorder inputBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: AppRadius.borderControl,
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
      splashFactory: InkRipple.splashFactory,
      // Visible focus for a hardware keyboard or switch access. Flutter's
      // default is a translucent black that disappears on the dark theme.
      focusColor: scheme.primary.withValues(alpha: 0.18),
      hoverColor: tones.overlayPressed,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        toolbarHeight: 56,
        titleSpacing: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 24),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        // A hairline instead of a shadow. The bar is the page's colour, and
        // without an edge the content simply vanished under it on scroll.
        shape: Border(bottom: BorderSide(color: tones.divider)),
        systemOverlayStyle: overlay(scheme.brightness),
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
        fillColor: scheme.surfaceContainer,
        helperMaxLines: 3,
        errorMaxLines: 3,
        // 16 of vertical padding makes a field as tall as the button under
        // it. A field and a button of different heights, touching, is the
        // detail that makes a form look assembled instead of drawn.
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        border: inputBorder(scheme.outline),
        enabledBorder: inputBorder(scheme.outline),
        disabledBorder: inputBorder(scheme.outline.withValues(alpha: 0.4)),
        focusedBorder: inputBorder(scheme.primary, width: 2),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, width: 2),
        hintStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          final base = textTheme.labelMedium!.copyWith(
            fontWeight: FontWeight.w600,
          );
          if (states.contains(WidgetState.error)) {
            return base.copyWith(color: scheme.error);
          }
          if (states.contains(WidgetState.focused)) {
            return base.copyWith(color: scheme.primary);
          }
          return base.copyWith(color: scheme.onSurfaceVariant);
        }),
        helperStyle: textTheme.bodySmall,
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        suffixStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        prefixStyle: textTheme.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: buttonBase.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.10);
            }
            return scheme.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
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
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.onSurface.withValues(alpha: 0.38);
            }
            return scheme.primary;
          }),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.borderS),
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
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerLow,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s8,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderS),
        side: BorderSide(color: tones.stroke),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        checkmarkColor: scheme.onPrimaryContainer,
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: AppSpacing.s12,
        minTileHeight: AppSpacing.minTapTarget,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderS),
      ),
      dividerTheme: DividerThemeData(
        color: tones.divider,
        thickness: 1,
        space: 1,
      ),
      // A sheet is the page again, lifted: the same tone as the screen behind
      // it (dimmed by the scrim), so groups inside it look exactly as they do
      // on a page — rather than a card-coloured sheet in which every card
      // turns into a hole.
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        showDragHandle: true,
        dragHandleColor: scheme.outline,
        dragHandleSize: const Size(36, 4),
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: scheme.scrim.withValues(alpha: dark ? 0.62 : 0.36),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.l),
          ),
          side: BorderSide(color: tones.stroke),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: scheme.inversePrimary,
        closeIconColor: scheme.onInverseSurface,
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.s16,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.borderControl,
        ),
      ),
      // The bar is one step off the page, with a hairline along its top drawn
      // by AppShell. The selected tab gets the accent pill Material users
      // already know — the owner asked for a navigation "de aplicativo", not
      // a reinvention of one.
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 68,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: const StadiumBorder(),
        overlayColor: WidgetStatePropertyAll(tones.overlayPressed),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderL,
          side: BorderSide(color: tones.stroke),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderControl,
          side: BorderSide(color: tones.stroke),
        ),
        textStyle: textTheme.bodyLarge,
        labelTextStyle: WidgetStatePropertyAll(textTheme.bodyLarge),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(controlShape),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: scheme.surfaceContainer,
        headerForegroundColor: scheme.onSurface,
        dividerColor: tones.divider,
        shape: sheetShape,
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        todayBorder: BorderSide(color: scheme.primary),
        confirmButtonStyle: TextButton.styleFrom(
          foregroundColor: scheme.primary,
        ),
        cancelButtonStyle: TextButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: sheetShape,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.onPrimary;
          return scheme.outline;
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

  /// The status and navigation bars for a theme of this [brightness].
  ///
  /// The app is drawn edge to edge (Android forces it from target SDK 35),
  /// so both bars are transparent and the page runs behind them; only the
  /// icons change with the theme. It used to ride on [AppBarTheme], which
  /// meant the four tabs — none of which has an app bar — never got it.
  /// `MeuAutoApp` applies it at the root.
  static SystemUiOverlayStyle overlay(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
    return base.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
  }
}
