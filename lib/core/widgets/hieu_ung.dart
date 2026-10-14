import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Hiện dần + trượt lên khi widget xuất hiện lần đầu.
/// [thuTu] càng lớn thì xuất hiện càng trễ, tạo hiệu ứng lần lượt.
class XuatHien extends StatelessWidget {
  final Widget child;
  final int thuTu;

  const XuatHien({super.key, required this.child, this.thuTu = 0});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    const buoc = 90; // ms giữa 2 phần tử
    final tong = 520 + thuTu * buoc;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: tong),
      curve: Interval(thuTu * buoc / tong, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 28),
          child: child,
        ),
      ),
    );
  }
}

/// Lắc ngang khi [lanLac] thay đổi — dùng báo sai mật khẩu.
class LacKhiLoi extends StatefulWidget {
  final int lanLac;
  final Widget child;

  const LacKhiLoi({super.key, required this.lanLac, required this.child});

  @override
  State<LacKhiLoi> createState() => _LacKhiLoiState();
}

class _LacKhiLoiState extends State<LacKhiLoi>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void didUpdateWidget(LacKhiLoi old) {
    super.didUpdateWidget(old);
    // 0 nghĩa là hết lỗi: không lắc
    if (old.lanLac != widget.lanLac && widget.lanLac != 0) {
      _ac.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ac,
      child: widget.child,
      builder: (context, child) {
        final v = _ac.value;
        return Transform.translate(
          offset: Offset(math.sin(v * math.pi * 6) * 10 * (1 - v), 0),
          child: child,
        );
      },
    );
  }
}

/// Chuyển trang mờ dần + trượt nhẹ, mượt hơn kiểu mặc định.
Route<T> trangMem<T>(Widget trang) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 650),
    reverseTransitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, _, _) => trang,
    transitionsBuilder: (_, a, _, child) {
      final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: c,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(c),
          child: child,
        ),
      );
    },
  );
}

/// Thay cho IndexedStack: giữ trạng thái mọi tab nhưng chuyển tab có hiệu ứng mờ dần.
class ChuyenTabMem extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const ChuyenTabMem({super.key, required this.index, required this.children});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: ExcludeSemantics(
              excluding: i != index,
              child: AnimatedOpacity(
                opacity: i == index ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: TickerMode(enabled: i == index, child: children[i]),
              ),
            ),
          ),
      ],
    );
  }
}

/// Bọc từng phần tử của danh sách trong [XuatHien] để chúng hiện ra lần lượt.
/// Khoảng trống (SizedBox) giữ nguyên, tối đa 8 bậc trễ để không chờ quá lâu.
List<Widget> lanLuot(List<Widget> ds) {
  var i = 0;
  return [
    for (final w in ds)
      if (w is SizedBox) w else XuatHien(thuTu: math.min(i++, 8), child: w),
  ];
}
