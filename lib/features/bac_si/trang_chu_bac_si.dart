import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../auth/man_hinh_chao_mung.dart';

/// Trang chủ của bác sĩ. Tạm thời chỉ có lời chào và nút đăng xuất,
/// các chức năng sẽ được thêm ở những bước sau.
class TrangChuBacSi extends StatelessWidget {
  final HoSo hoSo;

  const TrangChuBacSi({super.key, required this.hoSo});

  Future<void> _dangXuat(BuildContext context) async {
    await DichVuTaiKhoan.dangXuat();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ManHinhChaoMung()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediBook'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => _dangXuat(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Xin chào bác sĩ,',
                style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat)),
            const SizedBox(height: 4),
            Text(
              hoSo.hoTen.isEmpty ? 'Bác sĩ' : hoSo.hoTen,
              style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            const Text('Trang chủ bác sĩ: lịch khám theo ca trong ngày sẽ được thêm ở các bước sau.'),
          ],
        ),
      ),
    );
  }
}
