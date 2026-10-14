import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'hieu_ung.dart';
import 'logo_medibook.dart';
import 'nen_chuyen_dong.dart';

/// Khung chung cho các màn đăng nhập / đăng ký / quên mật khẩu / nhập mã:
/// nền xanh chuyển động + logo + tiêu đề ở trên, thẻ trắng bo góc chứa form ở dưới.
class KhungXacThuc extends StatelessWidget {
  final String tieuDe;
  final String moTa;

  /// Biểu tượng thay cho logo (ví dụ biểu tượng email ở màn nhập mã).
  final IconData? icon;

  /// Đổi giá trị này để thẻ form lắc ngang (báo lỗi).
  final int lanLac;
  final Widget child;

  const KhungXacThuc({
    super.key,
    required this.tieuDe,
    required this.moTa,
    required this.child,
    this.icon,
    this.lanLac = 0,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    // Khi bàn phím bật lên thì ẩn logo để chừa chỗ cho form
    final coBanPhim = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      body: NenChuyenDong(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                child: coBanPhim
                    ? const SizedBox(width: double.infinity)
                    : Center(
                        child: icon == null
                            ? const LogoMediBook(kichThuoc: 72)
                            : _BieuTuongTron(icon: icon!),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 4, 28, 24),
                child: Column(
                  crossAxisAlignment: coBanPhim
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Text(
                      tieuDe,
                      textAlign: coBanPhim ? TextAlign.start : TextAlign.center,
                      style: chu.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      moTa,
                      textAlign: coBanPhim ? TextAlign.start : TextAlign.center,
                      style: chu.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: XuatHien(
                  thuTu: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(32),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        28,
                        24,
                        24 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: LacKhiLoi(lanLac: lanLac, child: child),
                    ),
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

/// Vòng tròn trắng chứa biểu tượng, nhịp nhẹ lên xuống.
class _BieuTuongTron extends StatelessWidget {
  final IconData icon;

  const _BieuTuongTron({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      margin: const EdgeInsets.only(bottom: 12, top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, size: 42, color: AppTheme.mauChinh),
    );
  }
}

/// Hộp thông báo: đỏ khi lỗi, xanh lá khi thành công. Hiện ra có hiệu ứng.
class HopThongBao extends StatelessWidget {
  final String? noiDung;
  final bool thanhCong;

  const HopThongBao({super.key, required this.noiDung, this.thanhCong = false});

  @override
  Widget build(BuildContext context) {
    final mau = thanhCong
        ? const Color(0xFF15803D)
        : Theme.of(context).colorScheme.error;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => SizeTransition(
        sizeFactor: a,
        child: FadeTransition(opacity: a, child: c),
      ),
      child: noiDung == null
          ? const SizedBox(width: double.infinity)
          : Container(
              key: ValueKey(noiDung),
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: mau.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
                border: Border.all(color: mau.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    thanhCong
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: mau,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(noiDung!, style: TextStyle(color: mau)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Nút chính nền gradient; khi đang xử lý thì co lại thành vòng tròn quay.
class NutGradient extends StatelessWidget {
  final String nhan;
  final bool dangXuLy;
  final VoidCallback onPressed;

  const NutGradient({
    super.key,
    required this.nhan,
    required this.dangXuLy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final boGoc = BorderRadius.circular(dangXuLy ? 26 : AppTheme.boGoc);
    return LayoutBuilder(
      builder: (context, kt) => Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: dangXuLy ? 52 : kt.maxWidth,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: boGoc,
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.mauChinh.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: boGoc,
              onTap: dangXuLy ? null : onPressed,
              child: Center(
                child: dangXuLy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        nhan,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
