import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import '../auth/dich_vu_tai_khoan.dart';
import 'chi_duong.dart';
import 'dich_vu_dat_lich.dart';
import 'dinh_dang.dart';
import 'man_hinh_xac_nhan.dart';
import 'mo_hinh.dart';

/// Bước 2: trong một bệnh viện, lọc theo khoa, chọn ngày, chọn bác sĩ + ca.
class ManHinhChonBacSi extends StatefulWidget {
  final HoSo hoSo;
  final BenhVien benhVien;

  /// Nếu có: chỉ hiện bác sĩ này (dùng cho "Đặt lại với bác sĩ").
  final String? bacSiIdBanDau;

  const ManHinhChonBacSi({
    super.key,
    required this.hoSo,
    required this.benhVien,
    this.bacSiIdBanDau,
  });

  @override
  State<ManHinhChonBacSi> createState() => _ManHinhChonBacSiState();
}

class _ManHinhChonBacSiState extends State<ManHinhChonBacSi> {
  static const _soNgay = 7;

  final _dichVu = DichVuDatLich();
  final _homNay = chiNgay(DateTime.now());

  List<KhoaBenhVien> _khoa = [];
  List<BacSi> _bacSi = [];
  List<CaKham> _ca = [];
  bool _dangTai = true;
  String? _loi;

  int? _chuyenKhoaChon; // null = tất cả
  late DateTime _ngayChon = _homNay;

  List<DateTime> get _cacNgay => List.generate(_soNgay, (i) => _homNay.add(Duration(days: i)));

  @override
  void initState() {
    super.initState();
    _taiDuLieu(chonNgayDauTien: true);
  }

  Future<void> _taiDuLieu({bool chonNgayDauTien = false}) async {
    setState(() {
      _dangTai = _bacSi.isEmpty;
      _loi = null;
    });
    try {
      final khoa = await _dichVu.layKhoa(widget.benhVien.id);
      final bacSi = await _dichVu.layBacSi(widget.benhVien.id);
      final ca = await _dichVu.layCaKham(
        bacSi.map((b) => b.id).toList(),
        _homNay,
        _homNay.add(const Duration(days: _soNgay - 1)),
      );
      if (!mounted) return;
      setState(() {
        _khoa = khoa;
        _bacSi = bacSi;
        _ca = ca;
        _dangTai = false;
        if (chonNgayDauTien) {
          // Mặc định: hôm nay nếu còn ca đặt được, không thì ngày gần nhất có ca
          _ngayChon = _cacNgay.firstWhere(
            (d) => _caTheoNgay(d).any((c) => c.datDuoc),
            orElse: () => _homNay,
          );
        }
      });
    } on LoiDatLich catch (e) {
      if (!mounted) return;
      setState(() {
        _loi = e.thongBao;
        _dangTai = false;
      });
    }
  }

  List<BacSi> get _bacSiLoc => _bacSi.where((b) {
        if (widget.bacSiIdBanDau != null) return b.id == widget.bacSiIdBanDau;
        return _chuyenKhoaChon == null || b.chuyenKhoaId == _chuyenKhoaChon;
      }).toList();

  List<CaKham> _caTheoNgay(DateTime ngay, [String? bacSiId]) {
    final ids = _bacSiLoc.map((b) => b.id).toSet();
    return _ca
        .where((c) =>
            cungNgay(c.ngay, ngay) &&
            (bacSiId == null ? ids.contains(c.bacSiId) : c.bacSiId == bacSiId))
        .toList();
  }

  Future<void> _chonCa(BacSi bacSi, CaKham ca) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManHinhXacNhan(
          hoSo: widget.hoSo,
          benhVien: widget.benhVien,
          bacSi: bacSi,
          ca: ca,
        ),
      ),
    );
    // Quay lại (vd. ca vừa hết chỗ) thì tải lại số chỗ còn
    if (mounted) _taiDuLieu();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đặt lịch khám')),
      body: _dangTai
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _taiDuLieu,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: _loi != null ? [_loiWidget()] : _noiDung(context),
              ),
            ),
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

  List<Widget> _noiDung(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final dsBacSi = _bacSiLoc
      ..sort((a, b) {
        // Bác sĩ có ca trong ngày đang chọn lên trước
        final ca = _caTheoNgay(_ngayChon, a.id).isEmpty ? 1 : 0;
        final cb = _caTheoNgay(_ngayChon, b.id).isEmpty ? 1 : 0;
        return ca != cb ? ca.compareTo(cb) : a.hoTen.compareTo(b.hoTen);
      });

    return [
      _TheBenhVienDau(benhVien: widget.benhVien),
      const SizedBox(height: 24),

      // Chuyên khoa
      if (widget.bacSiIdBanDau == null) ...[
        Row(
          children: [
            Expanded(
              child: Text('Chuyên khoa',
                  style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
            Text('${_khoa.length} chuyên khoa',
                style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _ChipKhoa(
                text: 'Tất cả',
                chon: _chuyenKhoaChon == null,
                onTap: () => setState(() => _chuyenKhoaChon = null),
              ),
              for (final k in _khoa)
                _ChipKhoa(
                  text: k.ten,
                  chon: _chuyenKhoaChon == k.chuyenKhoaId,
                  onTap: () => setState(() => _chuyenKhoaChon = k.chuyenKhoaId),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],

      // Ngày
      Text('Lịch khám tháng ${_ngayChon.month}',
          style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _cacNgay.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final d = _cacNgay[i];
            return _ONgay(
              ngay: d,
              laHomNay: i == 0,
              chon: cungNgay(d, _ngayChon),
              coCa: _caTheoNgay(d).isNotEmpty,
              onTap: () => setState(() => _ngayChon = d),
            );
          },
        ),
      ),
      const SizedBox(height: 24),

      // Bác sĩ
      Row(
        children: [
          Text('Bác sĩ', style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: const ShapeDecoration(color: AppTheme.mauChinhNhat, shape: StadiumBorder()),
            child: Text('${dsBacSi.length}',
                style: const TextStyle(color: AppTheme.mauChinh, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (dsBacSi.isEmpty)
        const TheTrang(
          child: Text('Chưa có bác sĩ nào ở khoa này.',
              textAlign: TextAlign.center, style: TextStyle(color: AppTheme.mauChuNhat)),
        )
      else
        for (final bs in dsBacSi) ...[
          _TheBacSi(
            bacSi: bs,
            cacCa: _caTheoNgay(_ngayChon, bs.id),
            laHomNay: cungNgay(_ngayChon, _homNay),
            onChonCa: (ca) => _chonCa(bs, ca),
          ),
          const SizedBox(height: 12),
        ],
    ];
  }
}

// ============================ WIDGET CON ============================

class _TheBenhVienDau extends StatelessWidget {
  final BenhVien benhVien;

  const _TheBenhVienDau({required this.benhVien});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final km = benhVien.khoangCachKm;
    return TheTrang(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.mauChinhNhat,
                  borderRadius: BorderRadius.circular(AppTheme.boGoc),
                ),
                child: const Icon(Icons.local_hospital_outlined, color: AppTheme.mauChinh),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(benhVien.ten,
                        style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(benhVien.diaChi,
                        style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (km != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const ShapeDecoration(
                      color: AppTheme.mauChinhNhat, shape: StadiumBorder()),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.near_me_outlined, size: 16, color: AppTheme.mauChinh),
                      const SizedBox(width: 4),
                      Text(khoangCach(km),
                          style: const TextStyle(
                              color: AppTheme.mauChinh, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => moChiDuong(context, benhVien),
                icon: const Icon(Icons.directions_outlined, size: 18),
                label: const Text('Chỉ đường'),
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.mauChinhNhat,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.boGoc)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipKhoa extends StatelessWidget {
  final String text;
  final bool chon;
  final VoidCallback onTap;

  const _ChipKhoa({required this.text, required this.chon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: chon ? AppTheme.mauChinh : Colors.white,
        shape: StadiumBorder(side: BorderSide(color: chon ? AppTheme.mauChinh : AppTheme.mauVien)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
            child: Text(text,
                style: TextStyle(
                  color: chon ? Colors.white : AppTheme.mauChuDam,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
      ),
    );
  }
}

class _ONgay extends StatelessWidget {
  final DateTime ngay;
  final bool laHomNay;
  final bool chon;
  final bool coCa;
  final VoidCallback onTap;

  const _ONgay({
    required this.ngay,
    required this.laHomNay,
    required this.chon,
    required this.coCa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final mauChu = chon
        ? Colors.white
        : coCa
            ? AppTheme.mauChuDam
            : AppTheme.mauChuNhat.withValues(alpha: 0.5);
    return Material(
      color: chon ? AppTheme.mauChinh : (coCa ? Colors.white : const Color(0xFFF1F5F9)),
      borderRadius: BorderRadius.circular(AppTheme.boGoc),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        onTap: onTap,
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(laHomNay ? 'Hôm nay' : thuNgan(ngay),
                  style: TextStyle(color: mauChu, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(haiSo(ngay.day),
                  style: TextStyle(color: mauChu, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              if (coCa)
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: chon ? Colors.white : AppTheme.mauChinh,
                    shape: BoxShape.circle,
                  ),
                )
              else
                Text('Nghỉ', style: TextStyle(color: mauChu, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TheBacSi extends StatelessWidget {
  final BacSi bacSi;
  final List<CaKham> cacCa;
  final bool laHomNay;
  final ValueChanged<CaKham> onChonCa;

  const _TheBacSi({
    required this.bacSi,
    required this.cacCa,
    required this.laHomNay,
    required this.onChonCa,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final coCa = cacCa.isNotEmpty;
    final cacTu = bacSi.hoTen.trim().split(' ');
    final chuDau = cacTu.isEmpty || cacTu.last.isEmpty ? '?' : cacTu.last.characters.first.toUpperCase();

    final (String nhan, Color mauNhan, Color nenNhan) = !coCa
        ? ('Không trực ngày này', AppTheme.mauChuNhat, const Color(0xFFF1F5F9))
        : laHomNay
            ? ('Đang trực', const Color(0xFF15803D), const Color(0xFFDCFCE7))
            : ('Có lịch trực', AppTheme.mauChinh, AppTheme.mauChinhNhat);

    return TheTrang(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.mauChinhNhat,
                  borderRadius: BorderRadius.circular(AppTheme.boGoc),
                ),
                child: Text(chuDau,
                    style: const TextStyle(
                        color: AppTheme.mauChinh, fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bacSi.tenDayDu,
                        style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Khoa ${bacSi.tenKhoa} · ${bacSi.soNamKinhNghiem} năm kinh nghiệm',
                        style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: ShapeDecoration(color: nenNhan, shape: const StadiumBorder()),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: mauNhan, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(nhan,
                              style: TextStyle(
                                  color: mauNhan, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!coCa)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy_outlined, size: 18, color: AppTheme.mauChuNhat),
                  SizedBox(width: 8),
                  Text('Chọn ngày khác để xem lịch trực',
                      style: TextStyle(color: AppTheme.mauChuNhat)),
                ],
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < cacCa.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _NutCa(ca: cacCa[i], onTap: () => onChonCa(cacCa[i]))),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _NutCa extends StatelessWidget {
  final CaKham ca;
  final VoidCallback onTap;

  const _NutCa({required this.ca, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final duoc = ca.datDuoc;
    final trangThai = ca.daKetThuc
        ? 'Đã kết thúc'
        : ca.hetCho
            ? 'Hết chỗ'
            : 'Còn ${ca.soConLai} chỗ';
    return Material(
      color: duoc ? AppTheme.mauChinhNhat : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(AppTheme.boGoc),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        onTap: duoc ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ca.tenCa,
                  style: TextStyle(
                      color: duoc ? AppTheme.mauChinh : AppTheme.mauChuNhat,
                      fontWeight: FontWeight.w700)),
              Text(ca.khungGio,
                  style: TextStyle(
                      color: duoc ? AppTheme.mauChinh : AppTheme.mauChuNhat, fontSize: 13)),
              const SizedBox(height: 4),
              Text(trangThai,
                  style: TextStyle(
                      color: duoc ? AppTheme.mauChuDam : AppTheme.mauChuNhat,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
