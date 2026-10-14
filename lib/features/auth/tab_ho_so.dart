import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/supabase_client.dart';
import '../../core/widgets/anh_dai_dien.dart';
import '../../core/widgets/the_trang.dart';
import '../../core/widgets/hieu_ung.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_chao_mung.dart';

/// Tab "Hồ sơ" dùng chung cho bệnh nhân và bác sĩ: thông tin tài khoản + đăng xuất.
class TabHoSo extends StatelessWidget {
  final HoSo hoSo;

  const TabHoSo({super.key, required this.hoSo});

  Future<void> _dangXuat(BuildContext context) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn sẽ cần đăng nhập lại để tiếp tục sử dụng.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (dongY != true) return;
    await DichVuTaiKhoan.dangXuat();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(trangMem(const ManHinhChaoMung()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final email = supabase.auth.currentUser?.email ?? '';
    final mauLoi = Theme.of(context).colorScheme.error;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: lanLuot([
        Text(
          'Hồ sơ',
          style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),

        // Thẻ thông tin nền gradient
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.boGocThe + 4),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.mauChinh.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: AnhDaiDien(hoTen: hoSo.hoTen, banKinh: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hoSo.hoTen.isEmpty ? 'Chưa có tên' : hoSo.hoTen,
                      style: chu.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: chu.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hoSo.laBacSi
                                ? Icons.medical_services_rounded
                                : Icons.person_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hoSo.laBacSi ? 'Bác sĩ' : 'Bệnh nhân',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        TheTrang(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DongThongTin(
                icon: Icons.mail_outline_rounded,
                tieuDe: 'Email',
                giaTri: email,
              ),
              const Divider(height: 1, indent: 56),
              _DongThongTin(
                icon: Icons.badge_outlined,
                tieuDe: 'Vai trò',
                giaTri: hoSo.laBacSi ? 'Bác sĩ' : 'Bệnh nhân',
              ),
              const Divider(height: 1, indent: 56),
              const _DongThongTin(
                icon: Icons.info_outline_rounded,
                tieuDe: 'Phiên bản',
                giaTri: 'MediBook 1.0.0',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => _dangXuat(context),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Đăng xuất'),
          style: OutlinedButton.styleFrom(
            foregroundColor: mauLoi,
            side: BorderSide(color: mauLoi),
          ),
        ),
      ]),
    );
  }
}

class _DongThongTin extends StatelessWidget {
  final IconData icon;
  final String tieuDe;
  final String giaTri;

  const _DongThongTin({
    required this.icon,
    required this.tieuDe,
    required this.giaTri,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.mauChinhNhat,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: AppTheme.mauChinh),
      ),
      title: Text(
        tieuDe,
        style: const TextStyle(fontSize: 13, color: AppTheme.mauChuNhat),
      ),
      subtitle: Text(
        giaTri,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.mauChuDam,
        ),
      ),
    );
  }
}
