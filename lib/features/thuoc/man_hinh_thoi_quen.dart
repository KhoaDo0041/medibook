import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import 'thoi_quen.dart';

/// Khai giờ sinh hoạt (một lần) để xếp giờ uống thuốc. Trả về [ThoiQuen] khi lưu.
class ManHinhThoiQuen extends StatefulWidget {
  final ThoiQuen? banDau;
  const ManHinhThoiQuen({super.key, this.banDau});

  @override
  State<ManHinhThoiQuen> createState() => _ManHinhThoiQuenState();
}

class _ManHinhThoiQuenState extends State<ManHinhThoiQuen> {
  late ThoiQuen _tq = widget.banDau ?? ThoiQuen.macDinh;
  final _oCau = TextEditingController();
  bool _dangHoiAi = false;
  String? _thongBao;

  @override
  void dispose() {
    _oCau.dispose();
    super.dispose();
  }

  Future<void> _chonGio(int hienTai, ThoiQuen Function(int) gan) async {
    final chon = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hienTai ~/ 60, minute: hienTai % 60),
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: w!,
      ),
    );
    if (chon != null) setState(() => _tq = gan(chon.hour * 60 + chon.minute));
  }

  Future<void> _aiDien() async {
    final cau = _oCau.text.trim();
    if (cau.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _dangHoiAi = true;
      _thongBao = null;
    });
    final kq = await ThoiQuen.tuCauNoi(cau, goc: _tq);
    if (!mounted) return;
    setState(() {
      _dangHoiAi = false;
      if (kq != null) {
        _tq = kq;
        _thongBao = 'AI đã điền giờ theo câu của bạn, hãy kiểm tra lại.';
      } else {
        _thongBao = 'AI chưa hiểu được (hoặc máy chủ AI đang tắt). Bạn chọn giờ bằng tay nhé.';
      }
    });
  }

  Future<void> _luu() async {
    final loi = _tq.loi;
    if (loi != null) {
      setState(() => _thongBao = loi);
      return;
    }
    await _tq.luu();
    if (mounted) Navigator.pop(context, _tq);
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final dong = <(IconData, String, int, ThoiQuen Function(int))>[
      (Icons.wb_twilight_rounded, 'Thức dậy', _tq.thucDay, (p) => _tq.copyWith(thucDay: p)),
      (Icons.free_breakfast_outlined, 'Ăn sáng', _tq.anSang, (p) => _tq.copyWith(anSang: p)),
      (Icons.lunch_dining_outlined, 'Ăn trưa', _tq.anTrua, (p) => _tq.copyWith(anTrua: p)),
      (Icons.dinner_dining_outlined, 'Ăn tối', _tq.anToi, (p) => _tq.copyWith(anToi: p)),
      (Icons.bedtime_outlined, 'Đi ngủ', _tq.diNgu, (p) => _tq.copyWith(diNgu: p)),
    ];
    final loi = _tq.loi;

    return Scaffold(
      appBar: AppBar(title: const Text('Giờ sinh hoạt của bạn')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            'MediBook dùng các mốc giờ này để xếp giờ uống thuốc cho hợp với sinh hoạt của bạn. '
            'Chỉ lưu trên điện thoại này.',
            style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
          ),
          const SizedBox(height: 16),
          TheTrang(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (icon, nhan, gio, gan) in dong)
                  ListTile(
                    leading: Icon(icon, color: AppTheme.mauChinh),
                    title: Text(nhan),
                    trailing: Text(
                      chuPhut(gio),
                      style: chu.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.mauChinh,
                      ),
                    ),
                    onTap: () => _chonGio(gio, gan),
                  ),
              ],
            ),
          ),
          if (loi != null) ...[
            const SizedBox(height: 8),
            Text(loi, style: TextStyle(color: Colors.red.shade700)),
          ],
          const SizedBox(height: 20),
          Text(
            'Hoặc kể bằng một câu, AI sẽ điền giúp',
            style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _oCau,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'VD: Tôi dậy 6 giờ, ăn sáng 6 rưỡi, trưa ăn ở công ty 11 rưỡi, tối 7 giờ, ngủ 11 giờ đêm',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: _dangHoiAi ? null : _aiDien,
              icon: _dangHoiAi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_dangHoiAi ? 'AI đang đọc…' : 'AI điền giúp'),
            ),
          ),
          if (_thongBao != null) ...[
            const SizedBox(height: 8),
            Text(_thongBao!, style: chu.bodySmall),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton(
            onPressed: loi == null ? _luu : null,
            child: const Text('Lưu giờ sinh hoạt'),
          ),
        ),
      ),
    );
  }
}
