import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Nội dung tạm cho những phần chưa làm.
class ManHinhSapCo extends StatelessWidget {
  final IconData icon;
  final String tieuDe;
  final String moTa;

  const ManHinhSapCo({
    super.key,
    required this.icon,
    required this.tieuDe,
    required this.moTa,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.mauChinh),
            const SizedBox(height: 16),
            Text(tieuDe,
                style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(moTa,
                textAlign: TextAlign.center,
                style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
          ],
        ),
      ),
    );
  }
}

/// Hiện thông báo nhỏ "đang phát triển" ở đáy màn hình.
void baoSapCo(BuildContext context, String tenChucNang) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$tenChucNang đang được phát triển')));
}
