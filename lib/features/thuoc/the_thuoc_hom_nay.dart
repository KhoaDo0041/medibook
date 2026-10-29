import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import 'lich_uong.dart';
import 'man_hinh_lich_uong_hom_nay.dart';
import 'thoi_quen.dart';

/// Thẻ trên trang chủ bệnh nhân: cữ uống thuốc tiếp theo hôm nay (ẩn nếu không có lịch).
class TheThuocHomNay extends StatefulWidget {
  const TheThuocHomNay({super.key});

  @override
  State<TheThuocHomNay> createState() => _TheThuocHomNayState();
}

class _TheThuocHomNayState extends State<TheThuocHomNay> {
  List<LichUong>? _ds;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final ds = await KhoLichUong.danhSach();
    if (mounted) setState(() => _ds = ds);
  }

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now();
    final homNay = DateTime(n.year, n.month, n.day);
    final phut = n.hour * 60 + n.minute;
    final ds = [for (final l in _ds ?? <LichUong>[]) if (l.conHieuLuc(homNay)) l];
    if (ds.isEmpty) return const SizedBox.shrink();

    (int, List<String>)? tiepTheo;
    var conLai = 0;
    for (final l in ds) {
      for (final (gio, thuoc) in l.cacCu(homNay)) {
        if (gio < phut) continue;
        conLai++;
        if (tiepTheo == null || gio < tiepTheo.$1) {
          tiepTheo = (gio, [for (final t in thuoc) '${t.dong.thuoc.ten} ${t.dong.lieuChu} ${t.dong.thuoc.donVi}']);
        }
      }
    }
    final chu = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TheTrang(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManHinhLichUongHomNay()),
          );
          _tai();
        },
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.medication_rounded, color: AppTheme.mauCam),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uống thuốc hôm nay',
                    style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    tiepTheo == null
                        ? 'Đã hết cữ uống hôm nay'
                        : 'Tiếp theo ${chuPhut(tiepTheo.$1)} · ${tiepTheo.$2.join(', ')}'
                              '${conLai > 1 ? ' · còn $conLai cữ' : ''}',
                    style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.mauChuNhat),
          ],
        ),
      ),
    );
  }
}
