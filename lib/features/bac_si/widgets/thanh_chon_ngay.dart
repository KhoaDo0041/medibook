import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

/// Dải 7 ngày trong tuần (Thứ Hai → Chủ Nhật), ngày đang chọn được tô xanh.
class ThanhChonNgay extends StatelessWidget {
  final DateTime ngayDangChon;
  final ValueChanged<DateTime> onChon;

  const ThanhChonNgay({super.key, required this.ngayDangChon, required this.onChon});

  static const _tenThu = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  static bool cungNgay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final homNay = DateTime.now();
    final thuHai = DateTime(homNay.year, homNay.month, homNay.day)
        .subtract(Duration(days: homNay.weekday - 1));
    final cacNgay = List.generate(7, (i) => thuHai.add(Duration(days: i)));
    final chu = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 20, color: AppTheme.mauChuDam),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Lịch làm việc tuần',
                  style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text('THÁNG ${ngayDangChon.month} · ${ngayDangChon.year}',
                style: chu.labelMedium?.copyWith(
                    color: AppTheme.mauChinh, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cacNgay.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final ngay = cacNgay[i];
              final dangChon = cungNgay(ngay, ngayDangChon);
              final laHomNay = cungNgay(ngay, homNay);
              final mauChu = dangChon ? Colors.white : AppTheme.mauChuDam;

              return Material(
                color: dangChon ? AppTheme.mauChinh : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.boGoc),
                  onTap: () => onChon(ngay),
                  child: SizedBox(
                    width: laHomNay ? 72 : 56,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(laHomNay ? 'Hôm nay' : _tenThu[i],
                            style: TextStyle(
                                color: mauChu,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(ngay.day.toString().padLeft(2, '0'),
                            style: TextStyle(
                                color: mauChu,
                                fontSize: 20,
                                fontWeight: FontWeight.w800)),
                        if (laHomNay)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: dangChon ? Colors.greenAccent : AppTheme.mauChinh,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
