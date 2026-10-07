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

    return khung.copyWith(
      textTheme: khung.textTheme.apply(
        bodyColor: mauChuDam,
        displayColor: mauChuDam,
      ),
      appBarTheme: const AppBarThemeData(
        backgroundColor: Colors.white,
        foregroundColor: mauChuDam,
        elevation: 0,
        centerTitle: true,
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
