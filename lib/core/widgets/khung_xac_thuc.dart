import 'package:flutter/material.dart';

import '../app_theme.dart';
import 'duong_nhip_tim.dart';
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
    this.nhipTim = false,
  });

  /// Hiện đường điện tim chạy dưới tiêu đề (dùng ở màn đăng nhập).
  final bool nhipTim;

  @override
  Widget build(BuildContext context) {
    // Màn hình rộng (web trên máy tính, máy tính bảng ngang): chia đôi trang
    return LayoutBuilder(
      builder: (context, k) =>
          k.maxWidth >= 900 ? _manHinhRong(context) : _manHinhHep(context),
    );
  }

  /// Bố cục máy tính: bên trái nền xanh giới thiệu, bên phải form gọn ở giữa.
  Widget _manHinhRong(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final coTheQuayLai = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ----- Bên trái: thương hiệu -----
          Expanded(
            flex: 11,
            child: NenChuyenDong(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(48),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LogoMediBook(kichThuoc: 96),
                        const SizedBox(height: 28),
                        Text(
                          'MediBook',
                          textAlign: TextAlign.center,
                          style: chu.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tư vấn AI  –  Đặt lịch  –  Chỉ đường',
                          textAlign: TextAlign.center,
                          style: chu.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const SizedBox(
                          width: 240,
                          child: DuongNhipTim(cao: 34),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // ----- Bên phải: form -----
          Expanded(
            flex: 9,
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 48,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: _TheTruotLen(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (icon != null) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: AppTheme.mauChinhNhat,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    icon,
                                    color: AppTheme.mauChinh,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Text(
                              tieuDe,
                              style: chu.headlineMedium?.copyWith(
                                color: AppTheme.mauChuDam,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              moTa,
                              style: chu.bodyLarge?.copyWith(
                                color: AppTheme.mauChuNhat,
                              ),
                            ),
                            const SizedBox(height: 32),
                            LacKhiLoi(lanLac: lanLac, child: child),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (coTheQuayLai)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: IconButton(
                      tooltip: 'Quay lại',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bố cục điện thoại (giữ nguyên như cũ).
  Widget _manHinhHep(BuildContext context) {
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
                child: Navigator.of(context).canPop() ? IconButton(
                  tooltip: 'Quay lại',
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ) : const SizedBox(height: 48),
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
                    if (nhipTim && !coBanPhim) ...[
                      const SizedBox(height: 10),
                      const SizedBox(width: 170, child: DuongNhipTim(cao: 30)),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _TheTruotLen(
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
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: LacKhiLoi(lanLac: lanLac, child: child),
                        ),
                      ),
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

/// Thẻ form trượt lên từ dưới, nảy nhẹ khi dừng — hiệu ứng mở màn hình.
class _TheTruotLen extends StatelessWidget {
  final Widget child;

  const _TheTruotLen({required this.child});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 260),
          child: child,
        ),
      ),
    );
  }
}

/// Ô nhập sáng viền xanh dịu khi đang được gõ.
class SangKhiChon extends StatefulWidget {
  final Widget child;

  const SangKhiChon({super.key, required this.child});

  @override
  State<SangKhiChon> createState() => _SangKhiChonState();
}

class _SangKhiChonState extends State<SangKhiChon> {
  bool _dangChon = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _dangChon = v),
      child: AnimatedScale(
        scale: _dangChon ? 1.015 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Nút chính nền gradient:
/// - đang xử lý: co lại thành vòng tròn quay;
/// - thành công: chuyển xanh lá và hiện dấu tích.
class NutGradient extends StatelessWidget {
  final String nhan;
  final bool dangXuLy;
  final bool thanhCong;
  final VoidCallback onPressed;

  const NutGradient({
    super.key,
    required this.nhan,
    required this.dangXuLy,
    required this.onPressed,
    this.thanhCong = false,
  });

  @override
  Widget build(BuildContext context) {
    final tron = dangXuLy || thanhCong;
    final boGoc = BorderRadius.circular(tron ? 26 : AppTheme.boGoc);
    final mau = thanhCong
        ? const [Color(0xFF16A34A), Color(0xFF22C55E)]
        : const [Color(0xFF1D4ED8), Color(0xFF3B82F6)];

    final Widget noiDung;
    if (thanhCong) {
      noiDung = TweenAnimationBuilder<double>(
        key: const ValueKey('tich'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (context, v, _) => Transform.scale(
          scale: v,
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
        ),
      );
    } else if (dangXuLy) {
      noiDung = const SizedBox(
        key: ValueKey('quay'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
    } else {
      noiDung = Text(
        nhan,
        key: const ValueKey('chu'),
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, kt) => Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: tron ? 52 : kt.maxWidth,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: boGoc,
            gradient: LinearGradient(colors: mau),
            boxShadow: [
              BoxShadow(
                color: mau.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: boGoc,
              onTap: tron ? null : onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: noiDung,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ô nhập mật khẩu có nút con mắt ẩn/hiện — dùng chung cho đăng nhập, đăng ký,
/// đặt lại và đổi mật khẩu.
class OMatKhau extends StatefulWidget {
  final TextEditingController controller;
  final String nhan;
  final String? goiY;
  final IconData icon;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  const OMatKhau({
    super.key,
    required this.controller,
    required this.nhan,
    this.goiY,
    this.icon = Icons.lock_outline_rounded,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  State<OMatKhau> createState() => _OMatKhauState();
}

class _OMatKhauState extends State<OMatKhau> {
  bool _an = true;

  @override
  Widget build(BuildContext context) {
    return SangKhiChon(
      child: TextFormField(
        controller: widget.controller,
        obscureText: _an,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        validator: widget.validator,
        decoration: InputDecoration(
          labelText: widget.nhan,
          helperText: widget.goiY,
          prefixIcon: Icon(widget.icon),
          suffixIcon: IconButton(
            tooltip: _an ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
            onPressed: () => setState(() => _an = !_an),
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Icon(
                _an ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                key: ValueKey(_an),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
