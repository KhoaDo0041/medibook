import 'package:flutter/material.dart';

import '../../../core/widgets/the_trang.dart';

/// Ô thống kê nhỏ: "Tổng bệnh nhân", "Đã khám", "Đang chờ".
class OThongKe extends StatelessWidget {
  final String nhan;
  final int giaTri;
  final String donVi;
  final IconData icon;
  final Color mau;

  const OThongKe({
    super.key,
    required this.nhan,
    required this.giaTri,
    required this.donVi,
    required this.icon,
    required this.mau,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return TheTrang(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(nhan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: chu.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: mau.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: mau),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(giaTri.toString().padLeft(2, '0'),
                  style: TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w800, color: mau, height: 1)),
              const SizedBox(width: 4),
              Text(donVi, style: chu.bodySmall?.copyWith(color: mau)),
            ],
          ),
        ],
      ),
    );
  }
}
