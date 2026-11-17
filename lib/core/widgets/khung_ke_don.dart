import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../dinh_dang.dart';
import '../don_thuoc.dart';

/// Kê đơn thuốc mẫu + chọn ngày tái khám (dùng trên app bác sĩ điện thoại).
/// Màn hình cha giữ dữ liệu; widget báo thay đổi qua [onDoiDon] và [onDoiNgay].
class KhungKeDon extends StatelessWidget {
  final List<DongDonThuoc> don;
  final DateTime ngayKham;
  final DateTime? ngayTaiKham;
  final ValueChanged<List<DongDonThuoc>> onDoiDon;
  final ValueChanged<DateTime?> onDoiNgay;

  const KhungKeDon({
    super.key,
    required this.don,
    required this.ngayKham,
    required this.ngayTaiKham,
    required this.onDoiDon,
    required this.onDoiNgay,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final mauNgay = ngayTaiKham == null ? AppTheme.mauChuNhat : AppTheme.mauNhan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Đơn thuốc (thuốc mẫu dùng cho demo)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton.icon(
              onPressed: don.length >= 10 ? null : () => _themThuoc(context),
              icon: const Icon(Icons.add),
              label: const Text('Thêm thuốc'),
            ),
          ],
        ),
        if (don.isEmpty)
          Text(
            'Chưa kê thuốc nào.',
            style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
          )
        else
          for (var i = 0; i < don.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              decoration: BoxDecoration(
                color: AppTheme.mauNen,
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
                border: Border.all(color: AppTheme.mauVien),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medication_outlined, color: AppTheme.mauChinh, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(don[i].thuoc.ten, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(don[i].moTa, style: chu.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xoá',
                    onPressed: () => onDoiDon([...don]..removeAt(i)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 14),
        const Text('Ngày tái khám', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final soNgay in const [3, 7, 14, 30])
              ChoiceChip(
                label: Text('Sau $soNgay ngày'),
                selected: ngayTaiKham != null && ngayTaiKham!.difference(ngayKham).inDays == soNgay,
                onSelected: (_) => onDoiNgay(ngayKham.add(Duration(days: soNgay))),
              ),
            ActionChip(
              avatar: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Chọn ngày'),
              onPressed: () async {
                final chon = await showDatePicker(
                  context: context,
                  initialDate: ngayTaiKham ?? ngayKham.add(const Duration(days: 7)),
                  firstDate: ngayKham.add(const Duration(days: 1)),
                  lastDate: ngayKham.add(const Duration(days: 180)),
                );
                if (chon != null) onDoiNgay(chon);
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.event_repeat_rounded, size: 18, color: mauNgay),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                ngayTaiKham == null ? 'Không hẹn tái khám' : 'Tái khám: ${ngayDayDu(ngayTaiKham!)}',
                style: TextStyle(fontWeight: FontWeight.w600, color: mauNgay),
              ),
            ),
            if (ngayTaiKham != null)
              TextButton(onPressed: () => onDoiNgay(null), child: const Text('Bỏ hẹn')),
          ],
        ),
      ],
    );
  }

  Future<void> _themThuoc(BuildContext context) async {
    List<ThuocMau> danhMuc;
    try {
      danhMuc = await DichVuDonThuoc.danhMuc();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tải được danh mục thuốc. Vui lòng thử lại.')),
        );
      }
      return;
    }
    if (!context.mounted || danhMuc.isEmpty) return;

    var thuoc = danhMuc.first;
    var lieu = 1.0;
    var soLan = 2;
    var thoiDiem = ThoiDiemUong.sauAn;
    var soNgay = 5;
    const cacLieu = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0];
    const cacSoNgay = [3, 5, 7, 10, 14, 30];

    final dong = await showModalBottomSheet<DongDonThuoc>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, capNhat) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thêm thuốc vào đơn',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ThuocMau>(
                  initialValue: thuoc,
                  decoration: const InputDecoration(labelText: 'Thuốc'),
                  items: [
                    for (final t in danhMuc)
                      DropdownMenuItem(value: t, child: Text('${t.ten} (${t.donVi})')),
                  ],
                  onChanged: (t) => capNhat(() => thuoc = t ?? thuoc),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<double>(
                        initialValue: lieu,
                        decoration: InputDecoration(labelText: 'Mỗi lần (${thuoc.donVi})'),
                        items: [
                          for (final l in cacLieu)
                            DropdownMenuItem(
                              value: l,
                              child: Text(l == l.roundToDouble() ? '${l.toInt()}' : '$l'),
                            ),
                        ],
                        onChanged: (v) => capNhat(() => lieu = v ?? lieu),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: soNgay,
                        decoration: const InputDecoration(labelText: 'Số ngày dùng'),
                        items: [
                          for (final n in cacSoNgay)
                            DropdownMenuItem(value: n, child: Text('$n ngày')),
                        ],
                        onChanged: (v) => capNhat(() => soNgay = v ?? soNgay),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Số lần mỗi ngày'),
                const SizedBox(height: 6),
                SegmentedButton<int>(
                  segments: [
                    for (final n in const [1, 2, 3, 4])
                      ButtonSegment(value: n, label: Text('$n lần')),
                  ],
                  selected: {soLan},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => capNhat(() => soLan = v.first),
                ),
                const SizedBox(height: 12),
                const Text('Thời điểm uống'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in ThoiDiemUong.values)
                      ChoiceChip(
                        label: Text(t.nhan),
                        selected: thoiDiem == t,
                        onSelected: (_) => capNhat(() => thoiDiem = t),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    ctx,
                    DongDonThuoc(
                      thuoc: thuoc,
                      lieu: lieu,
                      soLan: soLan,
                      thoiDiem: thoiDiem,
                      soNgay: soNgay,
                    ),
                  ),
                  child: const Text('Thêm vào đơn'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (dong != null) onDoiDon([...don, dong]);
  }
}
