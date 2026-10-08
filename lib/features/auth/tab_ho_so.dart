import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/supabase_client.dart';
import '../../core/widgets/anh_dai_dien.dart';
import '../../core/widgets/the_trang.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_chao_mung.dart';

/// Tab "Hồ sơ" dùng chung cho bệnh nhân và bác sĩ: thông tin tài khoản + đăng xuất.
class TabHoSo extends StatelessWidget {
  final HoSo hoSo;

  const TabHoSo({super.key, required this.hoSo});

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
    final email = supabase.auth.currentUser?.email ?? '';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Hồ sơ', style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        TheTrang(
          child: Row(
            children: [
              AnhDaiDien(hoTen: hoSo.hoTen, banKinh: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hoSo.hoTen.isEmpty ? 'Chưa có tên' : hoSo.hoTen,
                        style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(email,
                        style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
                    const SizedBox(height: 4),
                    Text(hoSo.laBacSi ? 'Bác sĩ' : 'Bệnh nhân',
                        style: chu.labelMedium?.copyWith(color: AppTheme.mauChinh)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _dangXuat(context),
          icon: const Icon(Icons.logout),
          label: const Text('Đăng xuất'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
            side: BorderSide(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }
}
