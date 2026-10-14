import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bộ nhận diện của MediBook: màu chủ đạo #1D4ED8, font Manrope, bo góc 12.
class AppTheme {
  static const Color mauChinh = Color(0xFF1D4ED8);
  static const Color mauChuDam = Color(0xFF0F172A);
  static const Color mauChuNhat = Color(0xFF64748B);
  static const Color mauNen = Color(0xFFF8FAFC);
  static const Color mauCam = Color(0xFFF97316);
  static const double boGoc = 12;
  static const double boGocThe = 16; // thẻ lớn trên dashboard
  static const Color mauChinhNhat = Color(
    0xFFEEF2FF,
  ); // nền xanh rất nhạt cho ô biểu tượng
  static const Color mauVien = Color(0xFFE2E8F0);

  static ThemeData get theme {
    final khung = ThemeData(
      useMaterial3: true,
      // Font Manrope: chỉ lấy tên font từ google_fonts rồi áp cho toàn app
      fontFamily: GoogleFonts.manrope().fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mauChinh,
        primary: mauChinh,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: mauNen,
    );

    final hinhDangNut = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(boGoc),
    );

    final hinhThe = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(boGocThe),
    );

    return khung.copyWith(
      // Chuyển trang mờ dần + trượt nhẹ cho mọi màn hình trong app
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _ChuyenTrangMem(),
          TargetPlatform.iOS: _ChuyenTrangMem(),
        },
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: hinhThe.copyWith(side: const BorderSide(color: mauVien)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: mauChinhNhat,
        elevation: 8,
        shadowColor: const Color(0x220F172A),
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? mauChinh : mauChuNhat,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: mauChuDam,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(boGoc),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: mauChinh),
      dividerTheme: const DividerThemeData(color: mauVien, space: 1),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: khung.textTheme.apply(
        bodyColor: mauChuDam,
        displayColor: mauChuDam,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.white,
        foregroundColor: mauChuDam,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: mauChuDam,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: hinhDangNut,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: hinhDangNut,
          side: const BorderSide(color: mauChinh),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(boGoc),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(boGoc),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(boGoc),
          borderSide: const BorderSide(color: mauChinh, width: 2),
        ),
      ),
    );
  }
}

/// Hiệu ứng chuyển trang: trang mới mờ dần hiện ra và trượt nhẹ từ phải sang.
class _ChuyenTrangMem extends PageTransitionsBuilder {
  const _ChuyenTrangMem();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final c = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: c,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(c),
        child: child,
      ),
    );
  }
}
