import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design tokens for TripSplit World.
///
/// Palette intent: deep navy for text/surfaces, emerald-teal for primary
/// actions, warm neutral canvas, amber/red reserved for warnings and risk.
/// Contrast ratios of the foreground/background pairs below were chosen to
/// meet WCAG AA (4.5:1) for body text in both themes.
class AppColors {
  const AppColors._();

  // Brand
  static const Color navy = Color(0xFF0B1F3A);
  static const Color navy700 = Color(0xFF16324F);
  static const Color navy500 = Color(0xFF2A4A6B);
  static const Color teal = Color(0xFF0F766E);
  static const Color teal600 = Color(0xFF0D9488);
  static const Color emerald = Color(0xFF10B981);
  static const Color mint = Color(0xFFD1FAE5);

  // Warm neutrals
  static const Color canvas = Color(0xFFF8F7F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1EFEA);
  static const Color border = Color(0xFFE2DED5);
  static const Color borderStrong = Color(0xFFCBC5B8);

  // Text
  static const Color ink = Color(0xFF0B1F3A);
  static const Color inkMuted = Color(0xFF5A6B7F);
  static const Color inkFaint = Color(0xFF8A97A6);

  // Status
  static const Color positive = Color(0xFF047857);
  static const Color positiveSoft = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFB91C1C);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFDBEAFE);
  static const Color verified = Color(0xFF166534);
  static const Color unverified = Color(0xFF92400E);

  // Dark theme surfaces
  static const Color darkCanvas = Color(0xFF0B1420);
  static const Color darkSurface = Color(0xFF121E2C);
  static const Color darkSurfaceMuted = Color(0xFF1B2938);
  static const Color darkBorder = Color(0xFF24374B);
  static const Color darkInk = Color(0xFFE8EEF5);
  static const Color darkInkMuted = Color(0xFF9BAEC2);
}

/// Spacing scale (4pt base).
class AppSpacing {
  const AppSpacing._();
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// Corner radii.
class AppRadius {
  const AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 22;
  static const double pill = 999;
}

/// Elevation — restrained on purpose; depth comes from borders not shadows.
class AppShadow {
  const AppShadow._();
  static const List<BoxShadow> none = <BoxShadow>[];
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: Color(0x0D0B1F3A), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(color: Color(0x140B1F3A), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(color: Color(0x1A0B1F3A), blurRadius: 32, offset: Offset(0, 12)),
  ];
}

/// Minimum interactive size. 48dp keeps every control comfortably above the
/// 44dp iOS / 48dp Android accessibility guidance.
class AppHitTarget {
  const AppHitTarget._();
  static const double minimum = 48;
}

class AppDurations {
  const AppDurations._();
  static const Duration fast = Duration(milliseconds: 140);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);
  static const Duration aiTimeout = Duration(seconds: 45);
}

class AppBreakpoints {
  const AppBreakpoints._();
  static const double smallPhone = 360;
  static const double phone = 600;
  static const double tablet = 900;
  static const double desktop = 1280;
  static const double wideDesktop = 1600;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phone;
  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktop;
}

/// Central place to register the Material 3 light and dark themes.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.teal,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? AppColors.emerald : AppColors.teal,
          onPrimary: Colors.white,
          secondary: AppColors.navy500,
          surface: isDark ? AppColors.darkSurface : AppColors.surface,
          onSurface: isDark ? AppColors.darkInk : AppColors.ink,
          error: AppColors.danger,
          outline: isDark ? AppColors.darkBorder : AppColors.border,
          outlineVariant: isDark ? AppColors.darkBorder : AppColors.border,
        );

    final Color canvas = isDark ? AppColors.darkCanvas : AppColors.canvas;
    final Color inkMuted = isDark ? AppColors.darkInkMuted : AppColors.inkMuted;

    final TextTheme base = isDark
        ? Typography.material2021().white
        : Typography.material2021().black;
    final TextTheme text = base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.5, color: inkMuted),
      bodySmall: base.bodySmall?.copyWith(height: 1.45, color: inkMuted),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      textTheme: text,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: isDark ? AppColors.darkInk : AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          color: isDark ? AppColors.darkInk : AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceMuted : AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        labelStyle: TextStyle(color: inkMuted),
        helperMaxLines: 2,
        errorMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, AppHitTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppHitTarget.minimum),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: text.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outline),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary.withValues(alpha: 0.12),
        labelStyle: text.labelMedium ?? const TextStyle(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStatePropertyAll<TextStyle?>(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: inkMuted),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(color: inkMuted),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
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
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkSurfaceMuted : AppColors.navy,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        linearTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceMuted : AppColors.navy,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
