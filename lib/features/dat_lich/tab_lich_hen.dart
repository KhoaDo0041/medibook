import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import '../auth/dich_vu_tai_khoan.dart';
import 'chi_duong.dart';
import 'dich_vu_dat_lich.dart';
import 'dinh_dang.dart';
import 'man_hinh_chon_bac_si.dart';
import 'man_hinh_chon_benh_vien.dart';
import 'man_hinh_ket_qua_kham.dart';
import 'mo_hinh.dart';
import 'the_trang_thai.dart';

enum _LocDaQua { tatCa, daKham, daHuy, vangMat }

/// Tab "Lịch hẹn": Sắp tới / Đã qua (đồng thời là lịch sử khám).
class TabLichHen extends StatefulWidget {
  final HoSo hoSo;
  final bool moDaQua;
  final ValueChanged<int> moTab;

  const TabLichHen({super.key, required this.hoSo, required this.moTab, this.moDaQua = false});

  @override
  State<TabLichHen> createState() => _TabLichHenState();
}

class _TabLichHenState extends State<TabLichHen> {
  final _dichVu = DichVuDatLich();

  late bool _daQua = widget.moDaQua;
  _LocDaQua _loc = _LocDaQua.tatCa;
  List<LuotKhamCuaToi> _ds = [];
  bool _dangTai = true;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _loi = null);
    try {
      final ds = await _dichVu.layLichHenCuaToi();
      if (!mounted) return;
      setState(() {
        _ds = ds;
        _dangTai = false;
      });
    } on LoiDatLich catch (e) {
      if (!mounted) return;
      setState(() {
        _loi = e.thongBao;
        _dangTai = false;
      });
    }
  }

  List<LuotKhamCuaToi> get _sapToi =>
      _ds.where((l) => l.sapToi).toList()
        ..sort((a, b) => a.ca.thoiDiemBatDau.compareTo(b.ca.thoiDiemBatDau));

  List<LuotKhamCuaToi> get _cacLuotDaQua => _ds.where((l) => !l.sapToi).toList();

  bool _hopLoc(LuotKhamCuaToi l, _LocDaQua loc) => switch (loc) {
        _LocDaQua.tatCa => true,
        _LocDaQua.daKham => l.trangThai == TrangThaiLuot.daKham,
        _LocDaQua.daHuy => l.trangThai == TrangThaiLuot.daHuy,
        _LocDaQua.vangMat => l.vangMat,
      };

  // ---------------- hành động ----------------

  Future<void> _datLichMoi() async {
    final kq = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => ManHinhChonBenhVien(hoSo: widget.hoSo)),
    );
    if (kq == 'mo_ai') widget.moTab(2);
    _taiDuLieu();
  }

  Future<void> _datLai(LuotKhamCuaToi l) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManHinhChonBacSi(
          hoSo: widget.hoSo,
          benhVien: l.benhVien,
          bacSiIdBanDau: l.ca.bacSiId,
        ),
      ),
    );
    _taiDuLieu();
  }

  Future<void> _xemKetQua(LuotKhamCuaToi l) async {
    final datLai = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ManHinhKetQuaKham(luot: l)),
    );
    if (datLai == true) _datLai(l);
  }

  Future<void> _huy(LuotKhamCuaToi l) async {
    final dongY = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _BangHuy(luot: l),
    );
    if (dongY != true || !mounted) return;

    final thongBao = ScaffoldMessenger.of(context);
    try {
      await _dichVu.huyLuotKham(l.id);
      thongBao.showSnackBar(const SnackBar(content: Text('Đã huỷ lịch khám')));
    } on LoiDatLich catch (e) {
      thongBao.showSnackBar(SnackBar(content: Text(e.thongBao)));
    }
    _taiDuLieu();
  }

  // ---------------- giao diện ----------------

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text('Lịch hẹn',
                    style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ThanhChon(
            daQua: _daQua,
            soSapToi: _sapToi.length,
            onChon: (v) => setState(() => _daQua = v),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _dangTai
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _taiDuLieu,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: _loi != null
                        ? [_loiWidget()]
                        : _daQua
                            ? _dsDaQua()
                            : _dsSapToi(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _loiWidget() => TheTrang(
        child: Column(
          children: [
            const Icon(Icons.wifi_off, size: 40, color: AppTheme.mauChuNhat),
            const SizedBox(height: 8),
            Text(_loi!, textAlign: TextAlign.center),
            TextButton(onPressed: _taiDuLieu, child: const Text('Thử lại')),
          ],
        ),
      );

  List<Widget> _dsSapToi() {
    final ds = _sapToi;
    if (ds.isEmpty) {
      return [
        _TrongRong(
          tieuDe: 'Bạn chưa có lịch hẹn nào',
          moTa: 'Chọn bệnh viện và bác sĩ phù hợp để nhận số thứ tự trước.',
          nut: FilledButton.icon(
            onPressed: _datLichMoi,
            icon: const Icon(Icons.add),
            label: const Text('Đặt lịch khám'),
          ),
        ),
      ];
    }
    return [
      for (final l in ds) ...[
        _TheSapToi(
          luot: l,
          onHuy: () => _huy(l),
          onChiDuong: () => moChiDuong(context, l.benhVien),
        ),
        const SizedBox(height: 12),
      ],
      const SizedBox(height: 4),
      TheTrang(
        onTap: _datLichMoi,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: const Icon(Icons.add_alarm, color: Color(0xFF15803D)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Đặt lịch khám mới', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Chọn bệnh viện, bác sĩ và ca khám',
                      style: TextStyle(color: AppTheme.mauChuNhat, fontSize: 13)),
                ],
              ),
            ),
            const CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.mauChinh,
              child: Icon(Icons.chevron_right, color: Colors.white),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _dsDaQua() {
    final tatCa = _cacLuotDaQua;
    if (tatCa.isEmpty) {
      return [
        const _TrongRong(
          tieuDe: 'Chưa có lịch sử khám',
          moTa: 'Các lượt khám đã qua và kết quả bác sĩ ghi sẽ hiện ở đây.',
        ),
      ];
    }
    final ds = tatCa.where((l) => _hopLoc(l, _loc)).toList();
    String ten(_LocDaQua loc) => switch (loc) {
          _LocDaQua.tatCa => 'Tất cả',
          _LocDaQua.daKham => 'Đã khám',
          _LocDaQua.daHuy => 'Đã huỷ',
          _LocDaQua.vangMat => 'Vắng mặt',
        };
    return [
      SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final loc in _LocDaQua.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${ten(loc)} (${tatCa.where((l) => _hopLoc(l, loc)).length})'),
                  selected: _loc == loc,
                  onSelected: (_) => setState(() => _loc = loc),
                  showCheckmark: false,
                  selectedColor: AppTheme.mauChinh,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _loc == loc ? Colors.white : AppTheme.mauChuDam,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(color: _loc == loc ? AppTheme.mauChinh : AppTheme.mauVien),
                  shape: const StadiumBorder(),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (ds.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Text('Không có lượt khám nào.',
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.mauChuNhat)),
        ),
      for (final l in ds) ...[
        _TheDaQua(
          luot: l,
          onXemKetQua: () => _xemKetQua(l),
          onDatLai: () => _datLai(l),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

// ============================ WIDGET CON ============================

class _ThanhChon extends StatelessWidget {
  final bool daQua;
  final int soSapToi;
  final ValueChanged<bool> onChon;

  const _ThanhChon({required this.daQua, required this.soSapToi, required this.onChon});

  @override
  Widget build(BuildContext context) {
    Widget nut(String text, bool giaTri, IconData icon) {
      final chon = daQua == giaTri;
      return Expanded(
        child: Material(
          color: chon ? AppTheme.mauChinh : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.boGoc),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.boGoc),
            onTap: () => onChon(giaTri),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: chon ? Colors.white : AppTheme.mauChuNhat),
                  const SizedBox(width: 6),
                  Text(text,
                      style: TextStyle(
                        color: chon ? Colors.white : AppTheme.mauChuNhat,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.mauChinhNhat,
        borderRadius: BorderRadius.circular(AppTheme.boGoc + 4),
      ),
      child: Row(
        children: [
          nut('Sắp tới ($soSapToi)', false, Icons.event_outlined),
          nut('Đã qua', true, Icons.history),
        ],
      ),
    );
  }
}

class _TheSapToi extends StatelessWidget {
  final LuotKhamCuaToi luot;
  final VoidCallback onHuy;
  final VoidCallback onChiDuong;

  const _TheSapToi({required this.luot, required this.onHuy, required this.onChiDuong});

  static const _thang = 'Th';

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final ca = luot.ca;
    return TheTrang(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Khối ngày
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.mauChinhNhat,
                    borderRadius: BorderRadius.circular(AppTheme.boGoc),
                  ),
                  child: Column(
                    children: [
                      Text(thuNgan(ca.ngay),
                          style: const TextStyle(color: AppTheme.mauChinh, fontWeight: FontWeight.w700)),
                      Text('${ca.ngay.day}',
                          style: const TextStyle(
                              color: AppTheme.mauChinh, fontSize: 26, fontWeight: FontWeight.w800)),
                      Text('$_thang${ca.ngay.month}',
                          style: const TextStyle(color: AppTheme.mauChuNhat, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Thông tin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NhanTrangThai(luot: luot),
                      const SizedBox(height: 6),
                      Text(luot.benhVien.ten,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.medical_services_outlined, size: 16, color: AppTheme.mauChinh),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(luot.tenBacSi,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ]),
                      Text(luot.tenKhoa, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.schedule, size: 16, color: AppTheme.mauChuNhat),
                        const SizedBox(width: 4),
                        Text('${ca.tenCa} ${ca.khungGio}',
                            style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                      ]),
                      if (ca.viTriPhong != null) ...[
                        const SizedBox(height: 8),
                        NhanPhong(text: ca.viTriPhong!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Số thứ tự
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.mauChinhNhat,
                    borderRadius: BorderRadius.circular(AppTheme.boGoc),
                  ),
                  child: Column(
                    children: [
                      const Text('STT',
                          style: TextStyle(
                              color: AppTheme.mauChuNhat, fontSize: 11, fontWeight: FontWeight.w700)),
                      Text(haiSo(luot.soThuTu),
                          style: const TextStyle(
                              color: AppTheme.mauChinh, fontSize: 26, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (luot.trangThai == TrangThaiLuot.tamHoan)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: Text(
                'Bác sĩ đã gọi số nhưng bạn chưa có mặt. Số của bạn vẫn được giữ — '
                'hãy đến ${ca.viTriPhong ?? 'phòng khám'} trước ${gioPhut(ca.thoiDiemKetThuc)}.',
                style: const TextStyle(color: Color(0xFF9A3412), fontSize: 13),
              ),
            ),
          // Chân thẻ
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            decoration: const BoxDecoration(
              color: AppTheme.mauNen,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppTheme.boGocThe)),
            ),
            child: Row(
              children: [
                if (luot.huyDuoc)
                  TextButton.icon(
                    onPressed: onHuy,
                    icon: const Icon(Icons.event_busy_outlined, size: 18),
                    label: const Text('Huỷ lịch'),
                    style: TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('Ca đã bắt đầu',
                        style: TextStyle(color: AppTheme.mauChuNhat, fontSize: 13)),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: onChiDuong,
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('Chỉ đường'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppTheme.mauChinhNhat,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.boGoc)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TheDaQua extends StatelessWidget {
  final LuotKhamCuaToi luot;
  final VoidCallback onXemKetQua;
  final VoidCallback onDatLai;

  const _TheDaQua({required this.luot, required this.onXemKetQua, required this.onDatLai});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final daKham = luot.trangThai == TrangThaiLuot.daKham;
    final chanDoan = luot.chanDoan?.trim();

    final String? ghiChu = luot.trangThai == TrangThaiLuot.daHuy
        ? 'Bạn đã huỷ lịch khám này'
        : luot.vangMat
            ? 'Bạn đã không đến khám ca này'
            : null;

    return TheTrang(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 18, color: AppTheme.mauChinh),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${ngayDayDu(luot.ca.ngay)} · ${luot.ca.tenCa}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              NhanTrangThai(luot: luot),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              OChuCaiBacSi(tenBacSi: luot.tenBacSi),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(luot.tenBacSi,
                        style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(luot.tenKhoa, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                    Row(children: [
                      const Icon(Icons.local_hospital_outlined, size: 14, color: AppTheme.mauChuNhat),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(luot.benhVien.ten,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                      ),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          if (daKham) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mauChinhNhat,
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('KẾT QUẢ CHẨN ĐOÁN',
                      style: TextStyle(
                          color: AppTheme.mauChinh, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    (chanDoan == null || chanDoan.isEmpty) ? 'Bác sĩ chưa nhập kết quả' : chanDoan,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
          if (ghiChu != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline, size: 16, color: AppTheme.mauChuNhat),
                const SizedBox(width: 8),
                Text(ghiChu, style: const TextStyle(color: AppTheme.mauChuNhat, fontSize: 13)),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (daKham)
            Row(
              children: [
                Expanded(
                  child: _NutNhe(icon: Icons.description_outlined, text: 'Xem kết quả', onTap: onXemKetQua),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onDatLai,
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('Đặt lại'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                  ),
                ),
              ],
            )
          else
            _NutNhe(icon: Icons.replay, text: 'Đặt lại', onTap: onDatLai),
        ],
      ),
    );
  }
}

class _NutNhe extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _NutNhe({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(text),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(46),
          backgroundColor: AppTheme.mauChinhNhat,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.boGoc)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TrongRong extends StatelessWidget {
  final String tieuDe;
  final String moTa;
  final Widget? nut;

  const _TrongRong({required this.tieuDe, required this.moTa, this.nut});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return TheTrang(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(color: AppTheme.mauChinhNhat, shape: BoxShape.circle),
            child: const Icon(Icons.calendar_month_outlined, size: 40, color: AppTheme.mauChinh),
          ),
          const SizedBox(height: 16),
          Text(tieuDe, style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(moTa,
              textAlign: TextAlign.center,
              style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
          if (nut != null) ...[const SizedBox(height: 16), nut!],
        ],
      ),
    );
  }
}

/// Bảng xác nhận huỷ lịch, trả về true nếu người dùng đồng ý huỷ.
class _BangHuy extends StatelessWidget {
  final LuotKhamCuaToi luot;

  const _BangHuy({required this.luot});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final ca = luot.ca;
    Widget dong(String nhan, String giaTri, {Color? mau}) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(nhan, style: const TextStyle(color: AppTheme.mauChuNhat)),
              ),
              Expanded(
                child: Text(giaTri,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.w700, color: mau)),
              ),
            ],
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppTheme.mauVien, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(color: Color(0xFFFEE2E2), shape: BoxShape.circle),
                  child: const Icon(Icons.event_busy_outlined, color: Color(0xFFB91C1C)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Huỷ lịch khám?',
                          style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Kiểm tra lại thông tin trước khi huỷ',
                          style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.mauChinhNhat,
                borderRadius: BorderRadius.circular(AppTheme.boGocThe),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(luot.benhVien.ten,
                            style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.mauChinh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('STT ${haiSo(luot.soThuTu)}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: AppTheme.mauVien),
                  dong('Bác sĩ', '${luot.tenBacSi}\n(${luot.tenKhoa})'),
                  dong('Ngày khám', ngayDayDu(ca.ngay)),
                  dong('Ca khám', '${ca.tenCa} ${ca.khungGio}', mau: AppTheme.mauChinh),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1EC),
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFC2410C)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Chỗ của bạn sẽ được trả lại cho người khác. Số thứ tự này không thể khôi phục.',
                      style: TextStyle(color: Color(0xFF9A3412)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Huỷ lịch khám'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Giữ lịch khám'),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: AppTheme.mauChinhNhat,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.boGoc)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
