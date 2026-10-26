import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_theme.dart';
import '../dinh_dang.dart';

/// Lún nhẹ khi ngón tay chạm vào, nảy lại khi nhả — phản hồi xúc giác bằng mắt.
/// Dùng Listener nên không "nuốt" sự kiện chạm của InkWell bên trong.
class NhanLun extends StatefulWidget {
  final Widget child;
  final bool batLun;
  final double tiLe;

  const NhanLun({
    super.key,
    required this.child,
    this.batLun = true,
    this.tiLe = 0.97,
  });

  @override
  State<NhanLun> createState() => _NhanLunState();
}

class _NhanLunState extends State<NhanLun> {
  bool _dangNhan = false;

  void _dat(bool v) {
    if (widget.batLun && _dangNhan != v) setState(() => _dangNhan = v);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _dat(true),
      onPointerUp: (_) => _dat(false),
      onPointerCancel: (_) => _dat(false),
      child: AnimatedScale(
        scale: _dangNhan ? widget.tiLe : 1,
        duration: Duration(milliseconds: _dangNhan ? 90 : 220),
        curve: _dangNhan ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Ô chọn được (chip, ngày…): màu nền, viền, bóng chuyển mượt khi được chọn.
class HopChon extends StatelessWidget {
  final bool chon;
  final VoidCallback onTap;
  final Widget child;
  final Color mauNen;
  final Color mauChon;
  final Color? mauVien;
  final BorderRadius? boGoc; // null = bo tròn kiểu viên thuốc

  const HopChon({
    super.key,
    required this.chon,
    required this.onTap,
    required this.child,
    this.mauNen = Colors.white,
    this.mauChon = AppTheme.mauChinh,
    this.mauVien,
    this.boGoc,
  });

  @override
  Widget build(BuildContext context) {
    final bo = boGoc ?? BorderRadius.circular(100);
    return NhanLun(
      tiLe: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: chon ? mauChon : mauNen,
          borderRadius: bo,
          border: Border.all(
            color: chon ? mauChon : (mauVien ?? Colors.transparent),
          ),
          boxShadow: chon
              ? [
                  BoxShadow(
                    color: mauChon.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: bo,
            onTap: () {
              HapticFeedback.selectionClick(); // rung nhẹ khi chọn
              onTap();
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Thanh chọn 2+ mục với "viên" nền trượt sang mục được chọn.
class ThanhChonTruot extends StatelessWidget {
  final List<(String, IconData)> cacMuc;
  final int dangChon;
  final ValueChanged<int> onChon;

  const ThanhChonTruot({
    super.key,
    required this.cacMuc,
    required this.dangChon,
    required this.onChon,
  });

  @override
  Widget build(BuildContext context) {
    final n = cacMuc.length;
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.mauChinhNhat,
        borderRadius: BorderRadius.circular(AppTheme.boGoc + 4),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * dangChon / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.mauChinh,
                  borderRadius: BorderRadius.circular(AppTheme.boGoc),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.mauChinh.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (i != dangChon) HapticFeedback.selectionClick();
                      onChon(i);
                    },
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: i == dangChon ? Colors.white : AppTheme.mauChuNhat,
                      ),
                      duration: const Duration(milliseconds: 220),
                      builder: (context, mau, _) => Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(cacMuc[i].$2, size: 18, color: mau),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              cacMuc[i].$1,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: mau,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Số chạy từ 0 lên giá trị thật (dùng cho số thứ tự), có 2 chữ số: 01, 02…
class SoChay extends StatelessWidget {
  final int so;
  final TextStyle? style;

  const SoChay({super.key, required this.so, this.style});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text(haiSo(so), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: so.toDouble()),
      duration: Duration(milliseconds: 500 + math.min(so, 20) * 25),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(haiSo(v.round()), style: style),
    );
  }
}

/// Biểu tượng nảy nhẹ khi xuất hiện — dùng cho icon tab đang chọn.
class IconNay extends StatelessWidget {
  final IconData icon;
  final Color? mau;

  const IconNay(this.icon, {super.key, this.mau});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Icon(icon, color: mau ?? AppTheme.mauChinh),
    );
  }
}

/// Biểu tượng cho trạng thái trống: lơ lửng lên xuống chậm trên nền tròn nhạt.
class BieuTuongTrong extends StatefulWidget {
  final IconData icon;
  final double co;

  const BieuTuongTrong({super.key, required this.icon, this.co = 40});

  @override
  State<BieuTuongTrong> createState() => _BieuTuongTrongState();
}

class _BieuTuongTrongState extends State<BieuTuongTrong>
    with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_ac.isAnimating) {
      _ac.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.co * 2.2;
    return AnimatedBuilder(
      animation: _ac,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_ac.value);
        return SizedBox(
          width: k,
          height: k + 10,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // bóng đổ co giãn theo độ cao
              Positioned(
                bottom: 0,
                child: Container(
                  width: k * (0.5 - 0.12 * t),
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.mauChinh.withValues(alpha: 0.10 - 0.04 * t),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Transform.translate(offset: Offset(0, -4 - 6 * t), child: child),
            ],
          ),
        );
      },
      child: Container(
        width: k * 0.85,
        height: k * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.mauChinhNhat,
          shape: BoxShape.circle,
        ),
        child: Icon(widget.icon, size: widget.co, color: AppTheme.mauChinh),
      ),
    );
  }
}
