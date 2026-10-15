import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_dimens.dart';

/// Material 3 mavzusi — light-first, minimal.
///
/// Shrift: Inter Variable (assets/fonts). `google_fonts` ataylab ishlatilmaydi:
/// u yo runtime'da yuklaydi (offline buziladi), yo butun oilani bundle qiladi.
/// Inter kirill qamroviga ega — `uz-Cyrl` uchun shart.
abstract final class AppTheme {
  static const String fontFamily = 'Inter';

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primarySoft,
          error: AppColors.danger,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          surfaceContainerLowest: AppColors.lightCanvas,
          surfaceContainerHighest: AppColors.lightSunken,
          outline: AppColors.lightBorder,
          outlineVariant: AppColors.lightBorderStrong,
        );

    const textPrimary = AppColors.lightTextPrimary;
    const textSecondary = AppColors.lightTextSecondary;
    const textTertiary = AppColors.lightTextTertiary;
    const canvas = AppColors.lightCanvas;
    const border = AppColors.lightBorder;

    final textTheme = _textTheme(textPrimary, textSecondary, textTertiary);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamily: fontFamily,
      textTheme: textTheme,

      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,

      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: AppSizes.appBarHeight,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: border),
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
          overlayColor: Colors.transparent,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
          side: const BorderSide(color: border),
          foregroundColor: textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
          overlayColor: Colors.transparent,
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          overlayColor: Colors.transparent,
        ),
      ),

      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          overlayColor: WidgetStatePropertyAll<Color>(Colors.transparent),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
        border: _inputBorder(border),
        enabledBorder: _inputBorder(border),
        focusedBorder: _inputBorder(scheme.primary, width: 1.5),
        errorBorder: _inputBorder(AppColors.danger),
        focusedErrorBorder: _inputBorder(AppColors.danger, width: 1.5),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        height: AppSizes.bottomNavHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : textTertiary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
          ),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSunken,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        labelStyle: textTheme.labelMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.lightTextPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(color: textSecondary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: color, width: width),
      );

  static TextTheme _textTheme(Color primary, Color secondary, Color tertiary) =>
      TextTheme(
        displaySmall: TextStyle(
          fontSize: 32,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: primary,
        ),
        headlineMedium: TextStyle(
          fontSize: 26,
          height: 1.25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: primary,
        ),
        headlineSmall: TextStyle(
          fontSize: 22,
          height: 1.3,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: primary,
        ),
        titleLarge: TextStyle(
          fontSize: 19,
          height: 1.35,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: primary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          height: 1.4,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: primary),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: primary),
        bodySmall: TextStyle(fontSize: 13, height: 1.45, color: secondary),
        labelLarge: const TextStyle(
          fontSize: 15,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: secondary,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w500,
          color: tertiary,
        ),
      );
}
