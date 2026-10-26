import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'the_trang.dart';
import 'tuong_tac.dart';

/// Khung "danh sách trống": icon lơ lửng, tiêu đề, mô tả và nút (tuỳ chọn).
class TrangThaiTrong extends StatelessWidget {
  final IconData icon;
  final String tieuDe;
  final String? moTa;
  final Widget? nut;

  const TrangThaiTrong({
    super.key,
    required this.icon,
    required this.tieuDe,
    this.moTa,
    this.nut,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return TheTrang(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          BieuTuongTrong(icon: icon, co: 36),
          const SizedBox(height: 14),
          Text(
            tieuDe,
            textAlign: TextAlign.center,
            style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (moTa != null) ...[
            const SizedBox(height: 4),
            Text(
              moTa!,
              textAlign: TextAlign.center,
              style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
            ),
          ],
          if (nut != null) ...[const SizedBox(height: 16), nut!],
        ],
      ),
    );
  }
}

/// Khung báo lỗi tải dữ liệu (thường do mất mạng) kèm nút "Thử lại".
class TheLoi extends StatelessWidget {
  final String thongBao;
  final VoidCallback onThuLai;

  const TheLoi({super.key, required this.thongBao, required this.onThuLai});

  @override
  Widget build(BuildContext context) {
    return TrangThaiTrong(
      icon: Icons.wifi_off_rounded,
      tieuDe: 'Chưa tải được dữ liệu',
      moTa: thongBao,
      nut: OutlinedButton.icon(
        onPressed: onThuLai,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Thử lại'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(140, 44)),
      ),
    );
  }
}
