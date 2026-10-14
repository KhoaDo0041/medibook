import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Nền xanh chuyển động: các đốm sáng trôi chậm và biểu tượng y tế bay lên.
/// Dùng cho màn hình chào mừng và đăng nhập.
class NenChuyenDong extends StatefulWidget {
  final Widget? child;

  const NenChuyenDong({super.key, this.child});

  @override
  State<NenChuyenDong> createState() => _NenChuyenDongState();
}

class _NenChuyenDongState extends State<NenChuyenDong>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  );

  // (biểu tượng, vị trí ngang 0..1, lệch pha 0..1, cỡ)
  static const _bieuTuong = <(IconData, double, double, double)>[
    (Icons.add_rounded, 0.08, 0.00, 34.0),
    (Icons.favorite_rounded, 0.82, 0.15, 26.0),
    (Icons.medication_rounded, 0.25, 0.42, 24.0),
    (Icons.monitor_heart_rounded, 0.65, 0.60, 30.0),
    (Icons.add_rounded, 0.45, 0.78, 22.0),
    (Icons.local_pharmacy_rounded, 0.92, 0.88, 22.0),
    (Icons.vaccines_rounded, 0.15, 0.70, 22.0),
    (Icons.healing_rounded, 0.55, 0.30, 20.0),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tôn trọng cài đặt "giảm chuyển động" của điện thoại
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, kt) => AnimatedBuilder(
            animation: _ac,
            builder: (context, _) {
              final t = _ac.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _VeNen(t)),
                  for (final b in _bieuTuong)
                    _bieuTuongBay(b, t, kt.maxWidth, kt.maxHeight),
                ],
              );
            },
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _bieuTuongBay(
    (IconData, double, double, double) b,
    double t,
    double w,
    double h,
  ) {
    final (icon, xf, pha, co) = b;
    final p = (t * 2 + pha) % 1.0; // mỗi biểu tượng bay 2 vòng / chu kỳ
    final y = h * (1.05 - 1.2 * p);
    final x = w * xf + math.sin(2 * math.pi * (p * 1.5 + pha)) * 18;
    final mo = math.sin(math.pi * p) * 0.28;
    return Positioned(
      left: x - co / 2,
      top: y,
      child: Transform.rotate(
        angle: math.sin(2 * math.pi * p) * 0.35,
        child: Icon(
          icon,
          size: co,
          color: Colors.white.withValues(alpha: mo),
        ),
      ),
    );
  }
}

class _VeNen extends CustomPainter {
  final double t;

  _VeNen(this.t);

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF1D4ED8), Color(0xFF0EA5E9)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );

    final g = 2 * math.pi * t;
    void dom(Offset tam, double bk, double mo) {
      canvas.drawCircle(
        tam,
        bk,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: mo),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: tam, radius: bk)),
      );
    }

    dom(
      Offset(
        s.width * (0.2 + 0.15 * math.sin(g)),
        s.height * (0.18 + 0.08 * math.cos(g)),
      ),
      s.width * 0.7,
      0.20,
    );
    dom(
      Offset(
        s.width * (0.9 - 0.12 * math.cos(g)),
        s.height * (0.45 + 0.1 * math.sin(g)),
      ),
      s.width * 0.55,
      0.14,
    );
    dom(
      Offset(
        s.width * (0.4 + 0.2 * math.sin(g + 2)),
        s.height * (0.85 - 0.06 * math.cos(g)),
      ),
      s.width * 0.6,
      0.12,
    );
  }

  @override
  bool shouldRepaint(_VeNen old) => old.t != t;
}
