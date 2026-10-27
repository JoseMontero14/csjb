import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF6B48FF);
  static const primaryLight = Color(0xFFA78BFA);
  static const primaryLightBg = Color(0xFFEDE9FF);
  static const primaryBorder = Color(0xFFECEAFE);
  static const primaryDark = Color(0xFF4B2FD9);
  static const onPrimary = Colors.white;

  static const accent = Color(0xFFF47920);
  static const accentLight = Color(0xFFF69547);
  static const accentDark = Color(0xFFD4620F);
  static const onAccent = Colors.white;

  // Teal médico — usado en cards e ilustraciones
  static const teal = Color(0xFF00697A);
  static const tealLight = Color(0xFFD1EFEC);

  // Background / surface
  static const background = Color(0xFFF5F4F8);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF8F7FF);

  // Text
  static const textPrimary = Color(0xFF111111);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const textDisabled = Color(0xFFB0B0C0);
  static const textOnDark = Colors.white;

  // Urgency levels
  static const urgencyLow = Color(0xFF2E7D32);
  static const urgencyLowBg = Color(0xFFE8F5E9);
  static const urgencyMedium = Color(0xFFF47920);
  static const urgencyMediumBg = Color(0xFFFFF3E0);
  static const urgencyHigh = Color(0xFFC62828);
  static const urgencyHighBg = Color(0xFFFFEBEE);

  // Category colors
  static const catPurpleBg = Color(0xFFEDE9FF);
  static const catPurpleText = Color(0xFF6B48FF);
  static const catGreenBg = Color(0xFFE6F8F3);
  static const catGreenText = Color(0xFF0FA46E);
  static const catBlueBg = Color(0xFFE8F4FF);
  static const catBlueText = Color(0xFF2563EB);
  static const catYellowBg = Color(0xFFFEF3C7);
  static const catYellowText = Color(0xFFD97706);
  static const catRedBg = Color(0xFFFDEAEA);
  static const catRedText = Color(0xFFDC2626);
  static const catMintBg = Color(0xFFD1FAE5);
  static const catMintText = Color(0xFF059669);

  // Danger
  static const danger = Color(0xFFE8304A);

  // UI
  static const divider = Color(0xFFF0EEF8);
  static const shadow = Color(0x14000000);
  static const cardBorder = Color(0xFFECEAFE);
}

abstract final class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 32;
  static const double full = 999;

  static BorderRadius get xsBr => BorderRadius.circular(xs);
  static BorderRadius get smBr => BorderRadius.circular(sm);
  static BorderRadius get mdBr => BorderRadius.circular(md);
  static BorderRadius get lgBr => BorderRadius.circular(lg);
  static BorderRadius get xlBr => BorderRadius.circular(xl);
  static BorderRadius get xxlBr => BorderRadius.circular(xxl);
  static BorderRadius get fullBr => BorderRadius.circular(full);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class AppElevation {
  static const double none = 0;
  static const double card = 2;
  static const double modal = 8;
}

abstract final class AppDuration {
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);
}

abstract final class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.surfaceVariant,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.accent,
        onSecondary: AppColors.onAccent,
        secondaryContainer: Color(0xFFFFF0E5),
        onSecondaryContainer: AppColors.accentDark,
        tertiary: AppColors.urgencyLow,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.urgencyLowBg,
        onTertiaryContainer: AppColors.urgencyLow,
        error: AppColors.urgencyHigh,
        onError: Colors.white,
        errorContainer: AppColors.urgencyHighBg,
        onErrorContainer: AppColors.urgencyHigh,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.textSecondary,
        outline: AppColors.divider,
        outlineVariant: AppColors.cardBorder,
        shadow: AppColors.shadow,
        scrim: Color(0x80000000),
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.textOnDark,
        inversePrimary: AppColors.primaryLight,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    final poppins = GoogleFonts.poppinsTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: _buildTextTheme(poppins),
      appBarTheme: _appBarTheme(),
      cardTheme: _cardTheme(),
      filledButtonTheme: _filledButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      inputDecorationTheme: _inputDecorationTheme(),
      chipTheme: _chipTheme(),
      bottomNavigationBarTheme: _bottomNavTheme(),
      navigationBarTheme: _navigationBarTheme(),
      bottomSheetTheme: _bottomSheetTheme(),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: _snackBarTheme(),
      dialogTheme: _dialogTheme(),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(AppColors.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xsBr),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.textDisabled;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withAlpha(80);
          }
          return AppColors.divider;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  // ── Text theme ─────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      // Display
      displayLarge: base.displayLarge?.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      // Headline
      headlineLarge: base.headlineLarge?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      // Title
      titleLarge: base.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
      ),
      // Body
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      // Label
      labelLarge: base.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Component themes ────────────────────────────────────────────────────────

  static AppBarTheme _appBarTheme() => AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: AppElevation.none,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.shadow,
        centerTitle: false,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
        actionsIconTheme: const IconThemeData(color: AppColors.primary, size: 22),
        surfaceTintColor: Colors.transparent,
        shape: const Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      );

  static CardThemeData _cardTheme() => CardThemeData(
        elevation: AppElevation.card,
        shadowColor: AppColors.shadow,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lgBr,
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        margin: EdgeInsets.zero,
      );

  static FilledButtonThemeData _filledButtonTheme() => FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: AppElevation.none,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBr),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      );

  static OutlinedButtonThemeData _outlinedButtonTheme() =>
      OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBr),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      );

  static TextButtonThemeData _textButtonTheme() => TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
        ),
      );

  static InputDecorationTheme _inputDecorationTheme() => InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.lgBr,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgBr,
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgBr,
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgBr,
          borderSide: const BorderSide(color: AppColors.urgencyHigh),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.lgBr,
          borderSide:
              const BorderSide(color: AppColors.urgencyHigh, width: 2),
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textDisabled,
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
        floatingLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.primary,
          fontWeight: FontWeight.w500,
        ),
        errorStyle: GoogleFonts.poppins(
          fontSize: 12,
          color: AppColors.urgencyHigh,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
      );

  static ChipThemeData _chipTheme() => ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.divider,
        deleteIconColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        secondaryLabelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.onPrimary,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.fullBr),
        side: BorderSide.none,
        elevation: AppElevation.none,
        showCheckmark: false,
      );

  static BottomNavigationBarThemeData _bottomNavTheme() =>
      BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      );

  static NavigationBarThemeData _navigationBarTheme() =>
      NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withAlpha(22),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary, size: 24);
          }
          return const IconThemeData(color: AppColors.textSecondary, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          );
        }),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
      );

  static BottomSheetThemeData _bottomSheetTheme() => BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        elevation: AppElevation.modal,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: AppColors.divider,
      );

  static SnackBarThemeData _snackBarTheme() => SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white,
        ),
        actionTextColor: AppColors.accentLight,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smBr),
        behavior: SnackBarBehavior.floating,
      );

  static DialogThemeData _dialogTheme() => DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: AppElevation.modal,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xlBr),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textSecondary,
        ),
      );
}

// ── Urgency helpers ───────────────────────────────────────────────────────────

enum UrgencyLevel { low, medium, high }

extension UrgencyLevelX on UrgencyLevel {
  String get label => switch (this) {
        UrgencyLevel.low => 'Leve',
        UrgencyLevel.medium => 'Medio',
        UrgencyLevel.high => 'Alto',
      };

  Color get color => switch (this) {
        UrgencyLevel.low => AppColors.urgencyLow,
        UrgencyLevel.medium => AppColors.urgencyMedium,
        UrgencyLevel.high => AppColors.urgencyHigh,
      };

  Color get backgroundColor => switch (this) {
        UrgencyLevel.low => AppColors.urgencyLowBg,
        UrgencyLevel.medium => AppColors.urgencyMediumBg,
        UrgencyLevel.high => AppColors.urgencyHighBg,
      };

  IconData get icon => switch (this) {
        UrgencyLevel.low => Icons.check_circle_outline_rounded,
        UrgencyLevel.medium => Icons.warning_amber_rounded,
        UrgencyLevel.high => Icons.error_outline_rounded,
      };
}
