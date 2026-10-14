import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Dấu tích thành công: vòng tròn nảy ra, nét tích được vẽ dần,
/// kèm các chấm màu bung ra xung quanh như pháo giấy.
class DauTichThanhCong extends StatefulWidget {
  final double kichThuoc;

  const DauTichThanhCong({super.key, this.kichThuoc = 96});

  @override
  State<DauTichThanhCong> createState() => _DauTichThanhCongState();
}

class _DauTichThanhCongState extends State<DauTichThanhCong>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _ac.value = 1;
    } else if (_ac.value == 0) {
      _ac.forward();
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kichThuoc;
    return SizedBox.square(
      dimension: k * 1.8,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (context, _) => CustomPaint(painter: _VeDauTich(_ac.value, k)),
      ),
    );
  }
}

class _VeDauTich extends CustomPainter {
  final double t;
  final double k;

  _VeDauTich(this.t, this.k);

  static const _mauPhao = [
    Color(0xFF22C55E),
    Color(0xFF3B82F6),
    Color(0xFFF97316),
    Color(0xFFEAB308),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
  ];

  @override
  void paint(Canvas canvas, Size s) {
    final tam = s.center(Offset.zero);
    final r = k / 2;

    // 1. Vòng tròn nảy (0 → 0.45)
    final pNay = Curves.elasticOut.transform((t / 0.45).clamp(0.0, 1.0));
    canvas.drawCircle(
      tam,
      r * 1.0 * pNay,
      Paint()..color = const Color(0xFFDCFCE7),
    );
    canvas.drawCircle(
      tam,
      r * 0.72 * pNay,
      Paint()..color = const Color(0xFF16A34A),
    );

    // 2. Pháo giấy bung ra (0.25 → 1)
    final pPhao = ((t - 0.25) / 0.75).clamp(0.0, 1.0);
    if (pPhao > 0 && pPhao < 1) {
      final xa = Curves.easeOutCubic.transform(pPhao);
      for (var i = 0; i < 12; i++) {
        final goc = 2 * math.pi * i / 12 + 0.2;
        final d = r * (1.05 + 0.75 * xa);
        canvas.drawCircle(
          tam + Offset(math.cos(goc) * d, math.sin(goc) * d),
          (i.isEven ? 4.5 : 3) * (1 - pPhao),
          Paint()..color = _mauPhao[i % _mauPhao.length],
        );
      }
    }

    // 3. Nét tích vẽ dần (0.35 → 0.8)
    final pTich = ((t - 0.35) / 0.45).clamp(0.0, 1.0);
    if (pTich > 0) {
      final path = Path()
        ..moveTo(tam.dx - r * 0.32, tam.dy + r * 0.02)
        ..lineTo(tam.dx - r * 0.08, tam.dy + r * 0.26)
        ..lineTo(tam.dx + r * 0.36, tam.dy - r * 0.24);
      final m = path.computeMetrics().first;
      canvas.drawPath(
        m.extractPath(0, m.length * Curves.easeInOut.transform(pTich)),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.14
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(_VeDauTich old) => old.t != t;
}
