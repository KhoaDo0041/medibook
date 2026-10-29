import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dinh_dang.dart';
import '../../core/widgets/the_trang.dart';
import 'lich_uong.dart';
import 'man_hinh_thoi_quen.dart';
import 'nhac_nho.dart';
import 'thoi_quen.dart';

/// "Lịch uống thuốc hôm nay": các cữ uống trong ngày của mọi đơn còn hiệu lực.
/// Không có nút "Đã uống": chỉ để xem, sửa (tắt nhắc / xoá lịch).
class ManHinhLichUongHomNay extends StatefulWidget {
  const ManHinhLichUongHomNay({super.key});

  @override
  State<ManHinhLichUongHomNay> createState() => _ManHinhLichUongHomNayState();
}

class _ManHinhLichUongHomNayState extends State<ManHinhLichUongHomNay> {
  List<LichUong>? _ds;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    final ds = await KhoLichUong.danhSach();
    final homNay = _homNay;
    if (mounted) {
      setState(() => _ds = [for (final l in ds) if (!l.ketThuc.isBefore(homNay)) l]);
    }
  }

  DateTime get _homNay {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  Future<void> _batTatNhac(LichUong l, bool bat) async {
    final moi = l.copyWith(batNhac: bat);
    await KhoLichUong.luu(moi);
    if (bat) {
      await NhacNho.xinQuyen();
      await NhacNho.datNhacUongThuoc(moi);
    } else {
      await NhacNho.huyNhacUongThuoc(l.luotKhamId);
    }
    await _tai();
  }

  Future<void> _xoa(LichUong l) async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xoá lịch uống thuốc?'),
        content: Text('Dừng nhắc và xoá lịch của "${l.tieuDe}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (dongY != true) return;
    await NhacNho.huyNhacUongThuoc(l.luotKhamId);
    await KhoLichUong.xoa(l.luotKhamId);
    await _tai();
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final ds = _ds;
    final bayGio = TimeOfDay.now();
    final phutHienTai = bayGio.hour * 60 + bayGio.minute;

    // Gộp các cữ hôm nay của mọi lịch
    final cu = <int, List<String>>{};
    for (final l in ds ?? <LichUong>[]) {
      for (final (gio, thuoc) in l.cacCu(_homNay)) {
        cu.putIfAbsent(gio, () => []).addAll([
          for (final t in thuoc)
            '${t.dong.thuoc.ten} ${t.dong.lieuChu} ${t.dong.thuoc.donVi} (${t.dong.thoiDiem.nhan.toLowerCase()})',
        ]);
      }
    }
    final cacGio = cu.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch uống thuốc'),
        actions: [
          IconButton(
            tooltip: 'Giờ sinh hoạt',
            icon: const Icon(Icons.schedule),
            onPressed: () async {
              final tq = await ThoiQuen.tai();
              if (!context.mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ManHinhThoiQuen(banDau: tq)),
              );
            },
          ),
        ],
      ),
      body: ds == null
          ? const Center(child: CircularProgressIndicator())
          : ds.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Chưa có lịch uống thuốc.\nSau khi khám, vào Kết quả khám và bấm "Lập lịch nhắc uống thuốc".',
                  textAlign: TextAlign.center,
                  style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _tai,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    'Hôm nay · ${ngayThang(DateTime.now())}',
                    style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  if (cacGio.isEmpty)
                    const Text('Hôm nay không có cữ uống nào.')
                  else
                    for (final g in cacGio)
                      Opacity(
                        opacity: g < phutHienTai ? 0.45 : 1,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 64,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.mauChinh,
                                  borderRadius: BorderRadius.circular(AppTheme.boGoc),
                                ),
                                child: Text(
                                  chuPhut(g),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [for (final s in cu[g]!) Text('💊 $s')],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  const SizedBox(height: 20),
                  Text(
                    'Các đơn đang dùng',
                    style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  for (final l in ds) ...[
                    TheTrang(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.tieuDe, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                            'Từ ${ngayThang(l.batDau)} đến ${ngayThang(l.ketThuc)} · '
                            '${l.thuoc.map((t) => t.dong.thuoc.ten).join(', ')}',
                            style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Nhắc khi đến giờ uống'),
                            value: l.batNhac,
                            onChanged: (v) => _batTatNhac(l, v),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  await NhacNho.xinQuyen();
                                  await NhacNho.guiThu(l);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Thông báo thử sẽ hiện sau 10 giây')),
                                  );
                                },
                                icon: const Icon(Icons.notifications_outlined),
                                label: const Text('Gửi thử thông báo'),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () => _xoa(l),
                                style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                                child: const Text('Xoá lịch'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
    );
  }
}
