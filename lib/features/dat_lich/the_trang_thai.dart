import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'mo_hinh.dart';

/// Nhãn trạng thái lượt khám dùng chung: Chờ khám, Đang khám, Đã khám, Đã huỷ, Vắng mặt.
class NhanTrangThai extends StatelessWidget {
  final LuotKhamCuaToi luot;

  const NhanTrangThai({super.key, required this.luot});

  static (String, Color, Color) kieu(LuotKhamCuaToi l) {
    if (l.vangMat) return ('Vắng mặt', AppTheme.mauChuNhat, const Color(0xFFF1F5F9));
    return switch (l.trangThai) {
      TrangThaiLuot.choKham => ('Chờ khám', const Color(0xFF475569), const Color(0xFFE2E8F0)),
      TrangThaiLuot.dangKham => ('Đang khám', AppTheme.mauChinh, AppTheme.mauChinhNhat),
      TrangThaiLuot.tamHoan => ('Tạm hoãn', const Color(0xFFC2410C), const Color(0xFFFFEDD5)),
      TrangThaiLuot.daKham => ('Đã khám', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      TrangThaiLuot.daHuy => ('Đã huỷ', const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
      TrangThaiLuot.vangMat => ('Vắng mặt', AppTheme.mauChuNhat, const Color(0xFFF1F5F9)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (nhan, mau, nen) = kieu(luot);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: nen, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: mau, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(nhan, style: TextStyle(color: mau, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Ô vuông chữ cái đầu tên bác sĩ (thay cho ảnh).
class OChuCaiBacSi extends StatelessWidget {
  final String tenBacSi;
  final double kichThuoc;

  const OChuCaiBacSi({super.key, required this.tenBacSi, this.kichThuoc = 48});

  @override
  Widget build(BuildContext context) {
    final tu = tenBacSi.trim().split(' ').where((t) => t.isNotEmpty && !t.contains('.')).toList();
    final chu = tu.isEmpty ? '?' : tu.last.characters.first.toUpperCase();
    return Container(
      width: kichThuoc,
      height: kichThuoc,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.mauChinhNhat,
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
      ),
      child: Text(chu,
          style: TextStyle(
              color: AppTheme.mauChinh, fontSize: kichThuoc * 0.4, fontWeight: FontWeight.w800)),
    );
  }
}

/// Viên nhãn "Phòng 204 · Tầng 2".
class NhanPhong extends StatelessWidget {
  final String text;

  const NhanPhong({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const ShapeDecoration(color: AppTheme.mauChinhNhat, shape: StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.meeting_room_outlined, size: 16, color: AppTheme.mauChinh),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: AppTheme.mauChinh, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
