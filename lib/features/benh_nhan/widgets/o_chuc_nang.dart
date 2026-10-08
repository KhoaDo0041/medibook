import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/widgets/the_trang.dart';

/// Ô chức năng lớn: "Đặt lịch khám", "Lịch sử khám".
class OChucNang extends StatelessWidget {
  final IconData icon;
  final String tieuDe;
  final String moTa;
  final VoidCallback onTap;

  const OChucNang({
    super.key,
    required this.icon,
    required this.tieuDe,
    required this.moTa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return TheTrang(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.mauChinhNhat,
              borderRadius: BorderRadius.circular(AppTheme.boGoc),
            ),
            child: Icon(icon, color: AppTheme.mauChinh, size: 28),
          ),
          const SizedBox(height: 20),
          Text(tieuDe, style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(children: [
            Text(moTa, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
            const Icon(Icons.chevron_right, size: 16, color: AppTheme.mauChuNhat),
          ]),
        ],
      ),
    );
  }
}
