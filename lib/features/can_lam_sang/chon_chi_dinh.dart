import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'dich_vu_cls.dart';
import 'mo_hinh_cls.dart';

/// Bảng chọn dịch vụ cận lâm sàng cho bác sĩ. Trả về danh sách id đã chọn (null nếu huỷ).
Future<List<int>?> chonChiDinhCls(BuildContext context) =>
    showModalBottomSheet<List<int>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BangChon(),
    );

class _BangChon extends StatefulWidget {
  const _BangChon();

  @override
  State<_BangChon> createState() => _BangChonState();
}

class _BangChonState extends State<_BangChon> {
  late final Future<List<DichVuClsMuc>> _ds = DichVuCls.danhMuc();
  final _chon = <int>{};

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: FutureBuilder<List<DichVuClsMuc>>(
          future: _ds,
          builder: (_, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Không tải được danh mục (đã chạy file SQL 14 chưa?)\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final ds = snap.data;
            if (ds == null) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final tong = ds.where((d) => _chon.contains(d.id)).fold<int>(0, (t, d) => t + d.gia);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                    'Chỉ định cận lâm sàng',
                    style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Bệnh nhân sẽ thanh toán trong app, đi theo lộ trình rồi quay lại phòng '
                    'với kết quả. Trong lúc đó bạn có thể gọi người tiếp theo.',
                    style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final d in ds)
                        CheckboxListTile(
                          value: _chon.contains(d.id),
                          activeColor: AppTheme.mauNhan,
                          onChanged: (v) => setState(
                            () => v == true ? _chon.add(d.id) : _chon.remove(d.id),
                          ),
                          title: Text(
                            d.ten,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${d.tenKhu} · Tầng ${d.tang} · ${tienVnd(d.gia)}'
                            '${d.canNhinAn ? ' · cần nhịn ăn' : ''}',
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.mauNhan),
                    onPressed: _chon.isEmpty
                        ? null
                        : () => Navigator.pop(context, _chon.toList()),
                    icon: const Icon(Icons.send_rounded),
                    label: Text(
                      _chon.isEmpty
                          ? 'Chọn ít nhất một dịch vụ'
                          : 'Gửi ${_chon.length} chỉ định · ${tienVnd(tong)}',
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
