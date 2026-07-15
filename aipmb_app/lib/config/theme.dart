import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aipmb_app/providers/theme_provider.dart';

/// 三套主题配色定义
class _ThemeColors {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color divider;
  final Color surface;

  const _ThemeColors({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.divider,
    required this.surface,
  });
}

// ---- 三套配色定义 ----

const _sciFi = _ThemeColors(
  primary: Color(0xFF6C4DFF),
  secondary: Color(0xFF3B82F6),
  accent: Color(0xFFE040FB),
  background: Color(0xFFF0F0FF),
  primaryContainer: Color(0xFFEDE7FF),
  onPrimaryContainer: Color(0xFF4A148C),
  secondaryContainer: Color(0xFFDBE4FF),
  onSecondaryContainer: Color(0xFF1A237E),
  tertiaryContainer: Color(0xFFFCE4FF),
  onTertiaryContainer: Color(0xFF6A1B9A),
  divider: Color(0xFFD1C4E9),
  surface: Colors.white,
);

const _anime = _ThemeColors(
  primary: Color(0xFFFF6B9D),
  secondary: Color(0xFF7C4DFF),
  accent: Color(0xFFFFAB40),
  background: Color(0xFFFFF0F5),
  primaryContainer: Color(0xFFFFE0EB),
  onPrimaryContainer: Color(0xFF880E4F),
  secondaryContainer: Color(0xFFEDE7FF),
  onSecondaryContainer: Color(0xFF4A148C),
  tertiaryContainer: Color(0xFFFFF3E0),
  onTertiaryContainer: Color(0xFFE65100),
  divider: Color(0xFFF8BBD0),
  surface: Colors.white,
);

const _vibrant = _ThemeColors(
  primary: Color(0xFFDC2626),
  secondary: Color(0xFFF59E0B),
  accent: Color(0xFF8B5CF6),
  background: Color(0xFFFFF7ED),
  primaryContainer: Color(0xFFFEE2E2),
  onPrimaryContainer: Color(0xFF7F1D1D),
  secondaryContainer: Color(0xFFFEF3C7),
  onSecondaryContainer: Color(0xFF78350F),
  tertiaryContainer: Color(0xFFEDE7FF),
  onTertiaryContainer: Color(0xFF4A148C),
  divider: Color(0xFFFECACA),
  surface: Colors.white,
);

// ---- AppTheme ----

class AppTheme {
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color cardColor = Colors.white;

  static _ThemeColors _colorsFor(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.sciFi:
        return _sciFi;
      case AppThemeMode.anime:
        return _anime;
      case AppThemeMode.vibrant:
        return _vibrant;
    }
  }

  static ThemeData buildTheme(AppThemeMode mode) {
    final c = _colorsFor(mode);
    final textTheme = GoogleFonts.notoSansScTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: c.primary,
        onPrimary: Colors.white,
        primaryContainer: c.primaryContainer,
        onPrimaryContainer: c.onPrimaryContainer,
        secondary: c.secondary,
        onSecondary: Colors.white,
        secondaryContainer: c.secondaryContainer,
        onSecondaryContainer: c.onSecondaryContainer,
        tertiary: c.accent,
        onTertiary: Colors.white,
        tertiaryContainer: c.tertiaryContainer,
        onTertiaryContainer: c.onTertiaryContainer,
        surface: c.surface,
        onSurface: textPrimary,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 1,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: c.primary,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.primary,
          side: BorderSide(color: c.primary.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _CustomPageTransitionBuilder(),
          TargetPlatform.iOS: _CustomPageTransitionBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: c.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: c.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),
    );
  }
}

/// 自定义页面转场：fade + 轻微上移，使用 easeOutQuart 曲线
class _CustomPageTransitionBuilder extends PageTransitionsBuilder {
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 使用 easeOutQuart 曲线，比默认 FadeUpwards 更柔顺
    const curve = Curves.easeOutQuart;
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.6, curve: curve)),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: curve)),
        child: child,
      ),
    );
  }
}
