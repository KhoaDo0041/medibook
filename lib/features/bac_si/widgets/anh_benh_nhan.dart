import 'package:flutter/material.dart';

/// Ảnh đại diện chữ cái đầu, mỗi bệnh nhân một màu cố định (theo id) để dễ nhận ra.
class AnhBenhNhan extends StatelessWidget {
  final String id;
  final String hoTen;
  final double kichThuoc;

  const AnhBenhNhan({super.key, required this.id, required this.hoTen, this.kichThuoc = 48});

  static const _bangMau = [
    (Color(0xFFDBEAFE), Color(0xFF1D4ED8)), // xanh dương
    (Color(0xFFCCFBF1), Color(0xFF0F766E)), // xanh ngọc
    (Color(0xFFEDE9FE), Color(0xFF6D28D9)), // tím
    (Color(0xFFFFEDD5), Color(0xFFC2410C)), // cam
    (Color(0xFFFCE7F3), Color(0xFFBE185D)), // hồng
    (Color(0xFFDCFCE7), Color(0xFF15803D)), // xanh lá
  ];

  @override
  Widget build(BuildContext context) {
    final (nen, chu) = _bangMau[id.hashCode.abs() % _bangMau.length];
    final tu = hoTen.trim().split(' ').where((t) => t.isNotEmpty).toList();
    final chuCai = tu.isEmpty ? '?' : tu.last.characters.first.toUpperCase();
    return Container(
      width: kichThuoc,
      height: kichThuoc,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: nen, shape: BoxShape.circle),
      child: Text(chuCai,
          style: TextStyle(color: chu, fontSize: kichThuoc * 0.42, fontWeight: FontWeight.w800)),
    );
  }
}
