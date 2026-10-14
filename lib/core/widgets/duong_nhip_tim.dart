import 'package:flutter/material.dart';

/// Đường điện tim (ECG) chạy liên tục — dùng dưới logo.
class DuongNhipTim extends StatefulWidget {
  final double cao;
  final Color mau;

  const DuongNhipTim({super.key, this.cao = 40, this.mau = Colors.white});

  @override
  State<DuongNhipTim> createState() => _DuongNhipTimState();
}

class _DuongNhipTimState extends State<DuongNhipTim>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _ac.value = 1;
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
    return SizedBox(
      height: widget.cao,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (context, _) =>
            CustomPaint(painter: _VeNhipTim(_ac.value, widget.mau)),
      ),
    );
  }
}

class _VeNhipTim extends CustomPainter {
  final double t;
  final Color mau;

  _VeNhipTim(this.t, this.mau);

  // Một nhịp tim: (x 0..1 trong nhịp, y -1..1, âm là đi lên)
  static const _nhip = [
    (0.00, 0.0),
    (0.30, 0.0),
    (0.36, -0.15),
    (0.42, 0.0),
    (0.48, 0.0),
    (0.52, 0.25),
    (0.56, -1.0),
    (0.61, 0.6),
    (0.65, 0.0),
    (0.74, 0.0),
    (0.80, -0.25),
    (0.88, 0.0),
    (1.00, 0.0),
  ];

  @override
  void paint(Canvas canvas, Size s) {
    const soNhip = 2;
    final rongNhip = s.width / soNhip;
    final path = Path()..moveTo(0, s.height / 2);
    for (var i = 0; i < soNhip; i++) {
      for (final (x, y) in _nhip) {
        path.lineTo(
          i * rongNhip + x * rongNhip,
          s.height / 2 + y * s.height * 0.45,
        );
      }
    }

    // Đường mờ phía sau
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = mau.withValues(alpha: 0.18),
    );

    // Đoạn sáng đang chạy
    final m = path.computeMetrics().first;
    final cuoi = m.length * t;
    final dau = (cuoi - m.length * 0.35).clamp(0.0, m.length);
    final doan = m.extractPath(dau, cuoi);
    canvas.drawPath(
      doan,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = mau,
    );

    final diem = m.getTangentForOffset(cuoi)?.position;
    if (diem != null) {
      canvas.drawCircle(diem, 7, Paint()..color = mau.withValues(alpha: 0.25));
      canvas.drawCircle(diem, 3.5, Paint()..color = mau);
    }
  }

  @override
  bool shouldRepaint(_VeNhipTim old) => old.t != t;
}
