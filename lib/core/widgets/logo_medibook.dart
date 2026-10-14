import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Logo MediBook: vòng tròn trắng "đập" như nhịp tim, có sóng lan ra xung quanh.
/// Bọc trong Hero để bay mượt từ màn chào mừng sang màn đăng nhập.
class LogoMediBook extends StatefulWidget {
  final double kichThuoc;

  /// Tắt Hero khi logo chỉ đứng yên một chỗ (ví dụ màn chờ khởi động).
  final bool hero;

  const LogoMediBook({super.key, this.kichThuoc = 96, this.hero = true});

  @override
  State<LogoMediBook> createState() => _LogoMediBookState();
}

class _LogoMediBookState extends State<LogoMediBook>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _ac.stop();
    } else if (!_ac.isAnimating) {
      _ac.repeat();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  /// Hai nhịp đập nhanh rồi nghỉ, giống "thịch-thịch".
  double _nhipDap(double t) {
    double xung(double tam) =>
        math.exp(-math.pow((t - tam) / 0.05, 2).toDouble());
    return xung(0.10) + 0.6 * xung(0.28);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kichThuoc;
    final logo = SizedBox.square(
      dimension: k * 1.9,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (context, _) {
          final t = _ac.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Hai vòng sóng lan ra
              for (final lech in [0.0, 0.5])
                Builder(
                  builder: (_) {
                    final p = (t + lech) % 1.0;
                    return Container(
                      width: k * (1 + 0.9 * p),
                      height: k * (1 + 0.9 * p),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45 * (1 - p)),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
              Transform.scale(
                scale: 1 + 0.07 * _nhipDap(t),
                child: Container(
                  width: k,
                  height: k,
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
                  child: Icon(
                    Icons.local_hospital_rounded,
                    size: k * 0.55,
                    color: AppTheme.mauChinh,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    return widget.hero ? Hero(tag: 'logo-medibook', child: logo) : logo;
  }
}
