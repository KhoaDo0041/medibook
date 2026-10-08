import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Ảnh đại diện tạm: chữ cái đầu của tên trên nền xanh.
class AnhDaiDien extends StatelessWidget {
  final String hoTen;
  final double banKinh;

  const AnhDaiDien({super.key, required this.hoTen, this.banKinh = 24});

  @override
  Widget build(BuildContext context) {
    // Bỏ các danh xưng có dấu chấm như "BS.", "PGS.TS."
    final cacTu = hoTen
        .trim()
        .split(' ')
        .where((t) => t.isNotEmpty && !t.contains('.'))
        .toList();
    final chu = cacTu.isEmpty ? '?' : cacTu.last.characters.first.toUpperCase();
    return CircleAvatar(
      radius: banKinh,
      backgroundColor: AppTheme.mauChinh,
      child: Text(chu,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: banKinh * 0.8)),
    );
  }
}
