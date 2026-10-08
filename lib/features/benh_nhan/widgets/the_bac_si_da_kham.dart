import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/widgets/the_trang.dart';
import '../mo_hinh.dart';

/// Thẻ nhỏ một bác sĩ bệnh nhân đã từng khám, có nút "Đặt lại".
class TheBacSiDaKham extends StatelessWidget {
  final BacSiDaKham bacSi;
  final VoidCallback onDatLai;

  const TheBacSiDaKham({super.key, required this.bacSi, required this.onDatLai});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return SizedBox(
      width: 220,
      child: TheTrang(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.mauChinhNhat,
              child: Text(_chuCaiDau(bacSi.hoTen),
                  style: const TextStyle(
                      color: AppTheme.mauChinh, fontWeight: FontWeight.w800, fontSize: 20)),
            ),
            const SizedBox(height: 10),
            Text(bacSi.hoTen,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(bacSi.tenKhoa,
                style: chu.bodySmall?.copyWith(color: AppTheme.mauChinh)),
            Text(bacSi.tenBenhVien,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onDatLai,
                icon: const Icon(Icons.replay, size: 18),
                label: const Text('Đặt lại'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lấy chữ cái đầu của tên (bỏ "BS.", "PGS.TS."...) để làm ảnh đại diện tạm.
String _chuCaiDau(String hoTen) {
  final cacTu = hoTen.split(' ').where((t) => t.isNotEmpty && !t.contains('.')).toList();
  if (cacTu.isEmpty) return '?';
  return cacTu.last.characters.first.toUpperCase();
}
