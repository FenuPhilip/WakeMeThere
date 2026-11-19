import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// WakeMeThere design tokens are taken from the Stitch light design system.
const kColorSafe = Color(0xFF006856);
const kColorAdvisory = Color(0xFF556160);
const kColorWake = Color(0xFF006856);
const kColorCritical = Color(0xFFBA1A1A);

const kAppBackground = Color(0xFFF0FAF9);
const kSurfaceLowest = Color(0xFFFFFFFF);
const kSurfaceLow = Color(0xFFE5F4F1);
const kSurface = Color(0xFFE5F0F1);
const kSurfaceHigh = Color(0xFFDFEAEB);
const kSurfaceHighest = Color(0xFFDAE5E5);
const kOnSurface = Color(0xFF172824);
const kOnSurfaceVariant = Color(0xFF3D4945);
const kSecondary = Color(0xFF64736F);
const kOutline = Color(0xFF6D7A75);
const kOutlineVariant = Color(0xFFBCC9C4);
const kPrimary = Color(0xFF087765);
const kPrimaryContainer = Color(0xFF075B50);
const kOnPrimary = Color(0xFFFFFFFF);
const kOnPrimaryContainer = Color(0xFFF4FFF9);
const kSecondaryContainer = Color(0xFFD6E2E1);
const kTertiary = Color(0xFF805200);
const kTertiaryContainer = Color(0xFFA06908);
const kTertiaryFixed = Color(0xFFFFDDB4);
const kError = Color(0xFFBA1A1A);
const kErrorContainer = Color(0xFFFFDAD6);
const kOnErrorContainer = Color(0xFF93000A);

// Stitch uses a 4px base unit, 16px gutters, and 20px page margins.
const kSpaceXs = 4.0;
const kSpaceSm = 8.0;
const kSpaceMd = 16.0;
const kSpaceLg = 24.0;
const kSpaceXl = 32.0;
const kGutter = 16.0;
const kMargin = 20.0;

const kRadiusSm = 4.0;
const kRadius = 8.0;
const kRadiusMd = 12.0;
const kRadiusLg = 16.0;
const kRadiusXl = 24.0;
const kRadiusFull = 9999.0;

/// Shared Material theme corresponding to the light Stitch design system.
class NocturneTransitTheme {
  NocturneTransitTheme._();

  static TextTheme _textTheme() {
    TextStyle display(double size, double lineHeight) =>
        GoogleFonts.plusJakartaSans(
          color: kOnSurface,
          fontSize: size,
          fontWeight: FontWeight.w700,
          height: lineHeight / size,
          letterSpacing: -size * 0.03,
        );
    TextStyle heading(double size, double lineHeight) =>
        GoogleFonts.plusJakartaSans(
          color: kOnSurface,
          fontSize: size,
          fontWeight: FontWeight.w600,
          height: lineHeight / size,
          letterSpacing: -size * 0.02,
        );
    final body = GoogleFonts.inter(color: kOnSurfaceVariant, height: 1.5);
    final labels = GoogleFonts.inter(color: kOnSurface, height: 1.43);

    return TextTheme(
      displayLarge: display(48, 56),
      displayMedium: display(36, 44),
      displaySmall: display(32, 40),
      headlineLarge: heading(28, 36),
      headlineMedium: heading(24, 32),
      headlineSmall: heading(20, 28),
      titleLarge: labels.copyWith(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: labels.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: labels.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: body.copyWith(fontSize: 16, height: 24 / 16),
      bodyMedium: body.copyWith(fontSize: 14, height: 20 / 14),
      bodySmall: body.copyWith(fontSize: 13, height: 18 / 13),
      labelLarge: labels.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.14,
      ),
      labelMedium: labels.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        letterSpacing: 0.48,
      ),
      labelSmall: labels.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.6,
      ),
    );
  }

  static ThemeData light() {
    final textTheme = _textTheme();
    final colorScheme =
        ColorScheme.light(
          primary: kPrimary,
          onPrimary: kOnPrimary,
          primaryContainer: kPrimaryContainer,
          onPrimaryContainer: kOnPrimaryContainer,
          secondary: kSecondary,
          onSecondary: kOnPrimary,
          secondaryContainer: kSecondaryContainer,
          onSecondaryContainer: Color(0xFF596564),
          tertiary: kTertiary,
          onTertiary: kOnPrimary,
          tertiaryContainer: kTertiaryContainer,
          onTertiaryContainer: kOnSurface,
          error: kError,
          onError: kOnPrimary,
          errorContainer: kErrorContainer,
          onErrorContainer: kOnErrorContainer,
          surface: kAppBackground,
          onSurface: kOnSurface,
          onSurfaceVariant: kOnSurfaceVariant,
          outline: kOutline,
          outlineVariant: kOutlineVariant,
          shadow: const Color(0xFF000000),
          scrim: const Color(0xFF000000),
          inverseSurface: const Color(0xFF283233),
          onInverseSurface: const Color(0xFFE8F3F4),
          inversePrimary: const Color(0xFF6FD9BD),
          surfaceTint: kPrimary,
        ).copyWith(
          surfaceDim: const Color(0xFFD1DCDD),
          surfaceBright: kAppBackground,
          surfaceContainerLowest: kSurfaceLowest,
          surfaceContainerLow: kSurfaceLow,
          surfaceContainer: kSurface,
          surfaceContainerHigh: kSurfaceHigh,
          surfaceContainerHighest: kSurfaceHighest,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      primaryColor: kPrimary,
      scaffoldBackgroundColor: kAppBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: kAppBackground,
        foregroundColor: kOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: kSurfaceLowest,
        elevation: 1,
        shadowColor: const Color(0x140D3732),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: kOnPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
          elevation: 1,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: kOnPrimary,
          minimumSize: const Size(double.infinity, 56),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
          elevation: 1,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimary,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: kOutlineVariant),
          shape: const StadiumBorder(),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kPrimary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kSurfaceLowest,
        foregroundColor: kPrimary,
        elevation: 3,
        shape: CircleBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSurfaceLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: kSecondary),
        hintStyle: textTheme.bodyLarge?.copyWith(color: kSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd,
          vertical: kSpaceSm + 4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kSurfaceLowest,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? kPrimary : kOnSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? kPrimary
                : kOnSurfaceVariant,
            size: 24,
          ),
        ),
        elevation: 0,
        height: 76,
      ),
      dividerTheme: const DividerThemeData(
        color: kSurfaceHighest,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kOnSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: kOnPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: kSurfaceLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusXl)),
        ),
        elevation: 8,
        showDragHandle: true,
        dragHandleColor: kOutlineVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: kSurfaceLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusLg),
        ),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kSurfaceHigh,
        labelStyle: textTheme.labelMedium?.copyWith(color: kOnSurfaceVariant),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: kSpaceSm),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? kOnPrimary : kOutline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? kPrimary : kSurfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: kPrimary,
        inactiveTrackColor: kSurfaceHighest,
        thumbColor: kPrimary,
        overlayColor: Color(0x1A006856),
        trackHeight: 6,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: kPrimary,
        linearTrackColor: kSurfaceHighest,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        textColor: kOnSurface,
        iconColor: kOnSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpaceMd,
          vertical: kSpaceXs,
        ),
      ),
      iconTheme: const IconThemeData(color: kOnSurfaceVariant, size: 24),
      popupMenuTheme: PopupMenuThemeData(
        color: kSurfaceLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusMd),
          side: const BorderSide(color: kOutlineVariant),
        ),
        textStyle: textTheme.bodyMedium,
        elevation: 4,
      ),
    );
  }

  /// Kept as a compatibility alias for the existing app entry point.
  static ThemeData dark() => light();
}

const kLayer1Decoration = BoxDecoration(
  color: kSurfaceLowest,
  borderRadius: BorderRadius.all(Radius.circular(kRadiusLg)),
  boxShadow: [
    BoxShadow(color: Color(0x140D3732), blurRadius: 8, offset: Offset(0, 2)),
  ],
);

const kLayer2Decoration = BoxDecoration(
  color: kSurfaceLowest,
  borderRadius: BorderRadius.all(Radius.circular(kRadiusLg)),
  boxShadow: [
    BoxShadow(color: Color(0x1A0D3732), blurRadius: 16, offset: Offset(0, 6)),
  ],
);

const kActiveGlowDecoration = BoxDecoration(
  boxShadow: [
    BoxShadow(color: Color(0x26006856), blurRadius: 16, spreadRadius: 0),
  ],
);

const kAlertGlowDecoration = BoxDecoration(
  boxShadow: [
    BoxShadow(color: Color(0x26A06908), blurRadius: 20, spreadRadius: 0),
  ],
);
