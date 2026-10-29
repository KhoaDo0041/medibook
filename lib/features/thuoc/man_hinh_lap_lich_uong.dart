import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/don_thuoc.dart';
import '../../core/widgets/the_trang.dart';
import 'lich_uong.dart';
import 'man_hinh_thoi_quen.dart';
import 'nhac_nho.dart';
import 'thoi_quen.dart';

/// AI xếp giờ uống thuốc theo đơn bác sĩ + giờ sinh hoạt; bệnh nhân xem, sửa giờ,
/// xác nhận thì mới đặt thông báo nhắc. Trả về true khi đã bật nhắc.
class ManHinhLapLichUong extends StatefulWidget {
  final int luotKhamId;
  final String tieuDe;
  final List<DongDonThuoc> don;
  final DateTime ngayKham;
  final DateTime? ngayTaiKham;
  final String noiKham;

  const ManHinhLapLichUong({
    super.key,
    required this.luotKhamId,
    required this.tieuDe,
    required this.don,
    required this.ngayKham,
    this.ngayTaiKham,
    required this.noiKham,
  });

  @override
  State<ManHinhLapLichUong> createState() => _ManHinhLapLichUongState();
}

class _ManHinhLapLichUongState extends State<ManHinhLapLichUong> {
  ThoiQuen? _tq;
  List<LichThuoc>? _lich;
  String? _giaiThich;
  NguonLich _nguon = NguonLich.ai;
  List<String> _saiLuat = [];
  bool _dangXep = true;
  bool _dangLuu = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _batDau());
  }

  Future<void> _batDau() async {
    var tq = await ThoiQuen.tai();
    if (tq == null && mounted) {
      // Lần đầu: khai giờ sinh hoạt trước
      tq = await Navigator.push<ThoiQuen>(
        context,
        MaterialPageRoute(builder: (_) => const ManHinhThoiQuen()),
      );
    }
    tq ??= ThoiQuen.macDinh;
    _tq = tq;
    await _xep();
  }

  int _soLanXep = 0;

  Future<void> _xep() async {
    setState(() => _dangXep = true);
    // Mỗi lần "Nhờ AI xếp lại" tăng độ sáng tạo để AI thử phương án khác
    final nhietDo = (0.2 + 0.25 * _soLanXep).clamp(0.2, 0.9).toDouble();
    _soLanXep++;
    final (lich, giaiThich, nguon, saiLuat) =
        await XepLich.xep(widget.don, _tq!, nhietDo: nhietDo);
    if (!mounted) return;
    setState(() {
      _lich = lich;
      _giaiThich = giaiThich;
      _nguon = nguon;
      _saiLuat = saiLuat;
      _dangXep = false;
    });
  }

  Future<void> _doiThoiQuen() async {
    final tq = await Navigator.push<ThoiQuen>(
      context,
      MaterialPageRoute(builder: (_) => ManHinhThoiQuen(banDau: _tq)),
    );
    if (tq != null) {
      _tq = tq;
      await _xep();
    }
  }

  /// Sửa một giờ uống: chọn theo bữa ăn (đúng "trước/sau ăn" của đơn) hoặc giờ khác.
  Future<void> _suaGio(int iThuoc, int iGio) async {
    final lich = _lich!;
    final t = lich[iThuoc];
    final tq = _tq!;
    final chu = Theme.of(context).textTheme;
    final luaChon = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                '${t.dong.thuoc.ten} · uống ${t.dong.thoiDiem.nhan.toLowerCase()}',
                style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Trước hay sau ăn do bác sĩ chỉ định trong đơn. Chọn bữa bạn muốn uống:',
                style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
              ),
            ),
            for (final (nhan, gio) in XepLich.goiYGio(t.dong, tq))
              ListTile(
                leading: const Icon(Icons.alarm, color: AppTheme.mauChinh),
                title: Text(nhan),
                trailing: Text(
                  chuPhut(gio),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () => Navigator.pop(c, 'gio:$gio'),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('Tôi ăn vào giờ khác'),
              subtitle: const Text('Sửa giờ sinh hoạt, lịch sẽ tự xếp lại'),
              onTap: () => Navigator.pop(c, 'thoi_quen'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Chọn giờ khác'),
              onTap: () => Navigator.pop(c, 'tu_chon'),
            ),
          ],
        ),
      ),
    );
    if (luaChon == null || !mounted) return;
    if (luaChon == 'thoi_quen') {
      await _doiThoiQuen();
      return;
    }
    if (luaChon.startsWith('gio:')) {
      final gio = int.parse(luaChon.substring(4));
      setState(() {
        lich[iThuoc] = lich[iThuoc].doiGio(iGio, gio);
        _giaiThich = null;
      });
      return;
    }
    final g = t.gio[iGio];
    final chon = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: g ~/ 60, minute: g % 60),
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: w!,
      ),
    );
    if (chon == null) return;
    setState(() {
      lich[iThuoc] = lich[iThuoc].doiGio(iGio, chon.hour * 60 + chon.minute);
      _giaiThich = null; // đã sửa tay, lời giải thích cũ có thể không còn khớp
    });
  }

  DateTime get _ngayBatDau {
    final n = DateTime.now();
    final homNay = DateTime(n.year, n.month, n.day);
    final k = DateTime(widget.ngayKham.year, widget.ngayKham.month, widget.ngayKham.day);
    return k.isAfter(homNay) ? k : homNay;
  }

  Future<void> _xacNhan() async {
    final lich = _lich;
    if (lich == null) return;
    setState(() => _dangLuu = true);
    final choPhep = await NhacNho.xinQuyen();
    final lu = LichUong(
      luotKhamId: widget.luotKhamId,
      tieuDe: widget.tieuDe,
      batDau: _ngayBatDau,
      thuoc: lich,
    );
    await KhoLichUong.luu(lu);
    final soNhac = await NhacNho.datNhacUongThuoc(lu);
    if (widget.ngayTaiKham != null) {
      await NhacNho.datNhacTaiKham(widget.luotKhamId, widget.ngayTaiKham!, widget.noiKham);
    }
    if (!mounted) return;
    setState(() => _dangLuu = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          choPhep
              ? 'Đã bật nhắc uống thuốc ($soNhac lần nhắc sắp tới)'
              : 'Đã lưu lịch, nhưng bạn chưa cho phép MediBook gửi thông báo',
        ),
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final lich = _lich;
    final tq = _tq;
    final loi = lich == null || tq == null
        ? <String?>[]
        : [for (final t in lich) XepLich.kiemTra(t.dong, t.gio, tq)];
    final coLoi = loi.any((e) => e != null);

    return Scaffold(
      appBar: AppBar(title: const Text('Lịch uống thuốc')),
      body: _dangXep || lich == null || tq == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('AI đang xếp giờ uống thuốc theo sinh hoạt của bạn…'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Nguồn lịch
                Row(
                  children: [
                    Icon(
                      switch (_nguon) {
                        NguonLich.ai => Icons.auto_awesome,
                        NguonLich.aiMotPhan => Icons.rule_rounded,
                        NguonLich.khongKetNoi => Icons.cloud_off_rounded,
                      },
                      size: 18,
                      color: _nguon == NguonLich.khongKetNoi ? AppTheme.mauCam : AppTheme.mauChinh,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        // Câu thân thiện cho bệnh nhân; chi tiết kỹ thuật chỉ hiện ở bản debug
                        switch (_nguon) {
                          NguonLich.ai => 'Trợ lý AI đã gợi ý giờ uống theo giờ sinh hoạt của bạn',
                          NguonLich.aiMotPhan =>
                            'Trợ lý AI đã gợi ý giờ uống, một vài giờ được điều chỉnh cho đúng chỉ định của đơn',
                          NguonLich.khongKetNoi =>
                            'Giờ uống được xếp theo bữa ăn của bạn (Trợ lý AI đang không kết nối)',
                        },
                        style: chu.bodySmall?.copyWith(
                          color: _nguon == NguonLich.khongKetNoi ? AppTheme.mauCam : AppTheme.mauChinh,
                        ),
                      ),
                    ),
                  ],
                ),
                if (kDebugMode && _saiLuat.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Text(
                      _saiLuat.join('\n'),
                      style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                    ),
                  ),
                if (kDebugMode && _nguon != NguonLich.ai)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: _xep,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Nhờ AI xếp lại'),
                    ),
                  ),
                const SizedBox(height: 4),
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _doiThoiQuen,
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(
                    'Giờ sinh hoạt: dậy ${chuPhut(tq.thucDay)} · sáng ${chuPhut(tq.anSang)} · '
                    'trưa ${chuPhut(tq.anTrua)} · tối ${chuPhut(tq.anToi)} · ngủ ${chuPhut(tq.diNgu)}',
                    style: chu.bodySmall,
                  ),
                ),
                if (_giaiThich != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.mauChinhNhat,
                      borderRadius: BorderRadius.circular(AppTheme.boGoc),
                    ),
                    child: Text(_giaiThich!),
                  ),
                ],
                const SizedBox(height: 12),
                for (var i = 0; i < lich.length; i++) ...[
                  TheTrang(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lich[i].dong.thuoc.ten,
                          style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(lich[i].dong.moTa, style: chu.bodySmall),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: const ShapeDecoration(
                            color: AppTheme.mauChinhNhat,
                            shape: StadiumBorder(),
                          ),
                          child: Text(
                            '${lich[i].dong.thoiDiem.nhan} · theo đơn bác sĩ',
                            style: const TextStyle(
                              color: AppTheme.mauChinh,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var j = 0; j < lich[i].gio.length; j++)
                              ActionChip(
                                avatar: const Icon(Icons.alarm, size: 18),
                                label: Text(
                                  [
                                    chuPhut(lich[i].gio[j]),
                                    XepLich.moTaGio(lich[i].gio[j], tq),
                                  ].where((x) => x.isNotEmpty).join(' · '),
                                ),
                                onPressed: () => _suaGio(i, j),
                              ),
                          ],
                        ),
                        if (loi[i] != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            '⚠ ${loi[i]}. Bấm vào giờ bị sai để chọn lại theo bữa ăn, '
                            'hoặc sửa giờ sinh hoạt nếu bạn ăn vào giờ khác.',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (widget.ngayTaiKham != null)
                  Row(
                    children: [
                      const Icon(Icons.event_repeat_rounded, color: AppTheme.mauCam, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sẽ nhắc tái khám lúc 19:00 hôm trước và 07:00 ngày '
                          '${widget.ngayTaiKham!.day.toString().padLeft(2, '0')}/'
                          '${widget.ngayTaiKham!.month.toString().padLeft(2, '0')}.',
                          style: const TextStyle(color: AppTheme.mauCam),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  'Bấm vào giờ để sửa. Lịch chỉ sắp xếp giờ uống theo đúng đơn bác sĩ, '
                  'không thay đổi thuốc hay liều. Thông tin chỉ mang tính tham khảo.',
                  style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                ),
              ],
            ),
      bottomNavigationBar: lich == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton.icon(
                  onPressed: coLoi || _dangLuu ? null : _xacNhan,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(_dangLuu ? 'Đang bật nhắc…' : 'Xác nhận và bật nhắc'),
                ),
              ),
            ),
    );
  }
}
