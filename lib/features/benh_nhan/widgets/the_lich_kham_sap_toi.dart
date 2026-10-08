import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/widgets/the_trang.dart';
import '../mo_hinh.dart';

/// Thẻ "Lịch khám sắp tới". Chưa có lịch thì hiện lời mời đặt lịch.
class TheLichKhamSapToi extends StatelessWidget {
  final LichKhamSapToi? lich;
  final VoidCallback onDatLich;
  final VoidCallback onChiDuong;

  const TheLichKhamSapToi({
    super.key,
    required this.lich,
    required this.onDatLich,
    required this.onChiDuong,
  });

  static const _thu = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];

  String _ngay(DateTime d) =>
      '${_thu[d.weekday - 1]}, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final l = lich;

    return TheTrang(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NhanXanh(text: 'Lịch khám sắp tới'),
              const Spacer(),
              if (l != null)
                TextButton.icon(
                  onPressed: onChiDuong,
                  icon: const Icon(Icons.near_me_outlined, size: 18),
                  label: const Text('Chỉ đường'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.mauChinhNhat,
                    visualDensity: VisualDensity.compact,
                    shape: const StadiumBorder(),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (l == null) ...[
            Text('Bạn chưa có lịch khám nào',
                style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Đặt lịch để nhận số thứ tự trước, không phải chờ lâu ở bệnh viện.',
                style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onDatLich,
              icon: const Icon(Icons.add),
              label: const Text('Đặt lịch khám'),
            ),
          ] else ...[
            Text(l.tenBenhVien,
                style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.medical_services_outlined,
                    size: 18, color: AppTheme.mauChinh),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${l.tenKhoa} · ${l.tenBacSi}',
                      style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
                ),
              ],
            ),
            if (l.phongKham != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.meeting_room_outlined, size: 18, color: AppTheme.mauChinh),
                  const SizedBox(width: 6),
                  Text(l.phongKham!,
                      style: chu.bodyMedium?.copyWith(
                          color: AppTheme.mauChinh, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.mauChinhNhat,
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.schedule, size: 18, color: AppTheme.mauChuNhat),
                          const SizedBox(width: 6),
                          Text(l.tenCa,
                              style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
                        ]),
                        const SizedBox(height: 6),
                        Text(_ngay(l.ngayKham),
                            style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.mauChinh,
                      borderRadius: BorderRadius.circular(AppTheme.boGoc),
                    ),
                    child: Column(
                      children: [
                        const Text('SỐ THỨ TỰ',
                            style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                        Text(l.soThuTu.toString().padLeft(2, '0'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NhanXanh extends StatelessWidget {
  final String text;
  const _NhanXanh({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const ShapeDecoration(
        color: AppTheme.mauChinhNhat,
        shape: StadiumBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppTheme.mauChinh, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(text,
              style: const TextStyle(
                  color: AppTheme.mauChinh, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
