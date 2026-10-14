import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/duong_nhip_tim.dart';
import '../../core/widgets/hieu_ung.dart';
import '../../core/widgets/logo_medibook.dart';
import '../../core/widgets/nen_chuyen_dong.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_dang_nhap.dart';

/// Màn hình đầu tiên: người dùng chọn mình là Bệnh nhân hay Bác sĩ.
class ManHinhChaoMung extends StatelessWidget {
  const ManHinhChaoMung({super.key});

  void _moDangNhap(BuildContext context, String vaiTro) {
    Navigator.of(context).push(trangMem(ManHinhDangNhap(vaiTro: vaiTro)));
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final dayAnToan = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: NenChuyenDong(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const XuatHien(thuTu: 0, child: LogoMediBook()),
                        const SizedBox(height: 8),
                        XuatHien(
                          thuTu: 1,
                          child: Text(
                            'MediBook',
                            style: chu.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        XuatHien(
                          thuTu: 2,
                          child: Text(
                            'Tư vấn AI · Đặt lịch · Chỉ đường',
                            textAlign: TextAlign.center,
                            style: chu.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const XuatHien(
                          thuTu: 3,
                          child: SizedBox(
                            width: 240,
                            child: DuongNhipTim(cao: 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              XuatHien(
                thuTu: 4,
                child: Container(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 24 + dayAnToan),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Bạn là ai?',
                        style: chu.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chọn vai trò để đăng nhập',
                        style: chu.bodyMedium?.copyWith(
                          color: AppTheme.mauChuNhat,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _TheVaiTro(
                        noiBat: true,
                        icon: Icons.person_rounded,
                        tieuDe: 'Tôi là Bệnh nhân',
                        moTa: 'Hỏi trợ lý AI, đặt lịch ở bệnh viện gần bạn',
                        onTap: () => _moDangNhap(context, VaiTro.benhNhan),
                      ),
                      const SizedBox(height: 12),
                      _TheVaiTro(
                        noiBat: false,
                        icon: Icons.medical_services_rounded,
                        tieuDe: 'Tôi là Bác sĩ',
                        moTa: 'Xem ca khám, gọi số và ghi kết quả',
                        onTap: () => _moDangNhap(context, VaiTro.bacSi),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ chọn vai trò; khi nhấn sẽ lún nhẹ xuống.
class _TheVaiTro extends StatefulWidget {
  final bool noiBat;
  final IconData icon;
  final String tieuDe;
  final String moTa;
  final VoidCallback onTap;

  const _TheVaiTro({
    required this.noiBat,
    required this.icon,
    required this.tieuDe,
    required this.moTa,
    required this.onTap,
  });

  @override
  State<_TheVaiTro> createState() => _TheVaiTroState();
}

class _TheVaiTroState extends State<_TheVaiTro> {
  bool _dangNhan = false;

  @override
  Widget build(BuildContext context) {
    final noiBat = widget.noiBat;
    final mauChu = noiBat ? Colors.white : AppTheme.mauChuDam;

    return GestureDetector(
      onTapDown: (_) => setState(() => _dangNhan = true),
      onTapCancel: () => setState(() => _dangNhan = false),
      onTapUp: (_) {
        setState(() => _dangNhan = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _dangNhan ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.boGocThe),
            gradient: noiBat
                ? const LinearGradient(
                    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                  )
                : null,
            color: noiBat ? null : Colors.white,
            border: noiBat ? null : Border.all(color: AppTheme.mauVien),
            boxShadow: noiBat
                ? [
                    BoxShadow(
                      color: AppTheme.mauChinh.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: noiBat
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppTheme.mauChinhNhat,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.icon,
                  color: noiBat ? Colors.white : AppTheme.mauChinh,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tieuDe,
                      style: TextStyle(
                        color: mauChu,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.moTa,
                      style: TextStyle(
                        color: noiBat
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppTheme.mauChuNhat,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: mauChu),
            ],
          ),
        ),
      ),
    );
  }
}
