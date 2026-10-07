import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../auth/man_hinh_chao_mung.dart';

/// Trang chủ của bệnh nhân. Tạm thời chỉ có lời chào và nút đăng xuất,
/// các chức năng sẽ được thêm ở những bước sau.
class TrangChuBenhNhan extends StatelessWidget {
  final HoSo hoSo;

  const TrangChuBenhNhan({super.key, required this.hoSo});

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
            Text('Xin chào,',
                style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat)),
            const SizedBox(height: 4),
            Text(
              hoSo.hoTen.isEmpty ? 'Bệnh nhân' : hoSo.hoTen,
              style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            const Text('Trang chủ bệnh nhân: đặt lịch, lịch sử khám và AI tư vấn sẽ được thêm ở các bước sau.'),
          ],
        ),
      ),
    );
  }
}
