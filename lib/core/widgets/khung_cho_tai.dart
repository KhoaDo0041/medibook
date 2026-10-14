import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Khung xương lấp lánh (skeleton) hiện trong lúc tải danh sách,
/// thay cho vòng tròn quay — người dùng thấy trước bố cục sắp hiện ra.
class KhungChoTai extends StatefulWidget {
  final int soThe;
  final double caoThe;
  final EdgeInsetsGeometry padding;

  const KhungChoTai({
    super.key,
    this.soThe = 3,
    this.caoThe = 96,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<KhungChoTai> createState() => _KhungChoTaiState();
}

class _KhungChoTaiState extends State<KhungChoTai>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: AnimatedBuilder(
        animation: _ac,
        builder: (context, _) {
          // Dải sáng chạy từ trái sang phải
          final t = _ac.value * 3 - 1; // -1 → 2
          final anhSang = LinearGradient(
            begin: Alignment(t - 1, 0),
            end: Alignment(t + 1, 0),
            colors: const [
              Color(0xFFE2E8F0),
              Color(0xFFF8FAFC),
              Color(0xFFE2E8F0),
            ],
            stops: const [0.3, 0.5, 0.7],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.soThe; i++)
                _TheXuong(cao: widget.caoThe, mau: anhSang),
            ],
          );
        },
      ),
    );
  }
}

class _TheXuong extends StatelessWidget {
  final double cao;
  final Gradient mau;

  const _TheXuong({required this.cao, required this.mau});

  @override
  Widget build(BuildContext context) {
    Widget khoi(double rong, double h, {double bo = 6}) => Container(
      width: rong,
      height: h,
      decoration: BoxDecoration(
        gradient: mau,
        borderRadius: BorderRadius.circular(bo),
      ),
    );

    return Container(
      height: cao,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
        border: Border.all(color: AppTheme.mauVien),
      ),
      child: Row(
        children: [
          khoi(48, 48, bo: 14),
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, kt) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  khoi(kt.maxWidth * 0.7, 14),
                  const SizedBox(height: 10),
                  khoi(kt.maxWidth * 0.45, 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
