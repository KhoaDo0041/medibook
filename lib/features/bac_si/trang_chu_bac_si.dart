import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/anh_dai_dien.dart';
import '../../core/widgets/man_hinh_sap_co.dart';
import '../../core/widgets/the_trang.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../auth/tab_ho_so.dart';
import 'dich_vu_bac_si.dart';
import 'man_hinh_kham_benh.dart';
import 'mo_hinh.dart';
import 'widgets/danh_sach_ca.dart';
import 'widgets/o_thong_ke.dart';
import 'widgets/thanh_chon_ngay.dart';
import 'widgets/the_dang_kham.dart';

/// Dashboard bác sĩ: 3 tab ở thanh dưới.
class TrangChuBacSi extends StatefulWidget {
  final HoSo hoSo;

  const TrangChuBacSi({super.key, required this.hoSo});

  @override
  State<TrangChuBacSi> createState() => _TrangChuBacSiState();
}

class _TrangChuBacSiState extends State<TrangChuBacSi> {
  int _tabDangChon = 0;

  @override
  Widget build(BuildContext context) {
    final cacTab = [
      _TabLichKham(hoSo: widget.hoSo),
      const ManHinhSapCo(
        icon: Icons.groups_outlined,
        tieuDe: 'Bệnh nhân',
        moTa: 'Danh sách bệnh nhân bạn đã khám và hồ sơ của họ sẽ hiện ở đây.',
      ),
      TabHoSo(hoSo: widget.hoSo),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tabDangChon, children: cacTab)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabDangChon,
        onDestinationSelected: (i) => setState(() => _tabDangChon = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.mauChinhNhat,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note, color: AppTheme.mauChinh),
              label: 'Lịch khám'),
          NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups, color: AppTheme.mauChinh),
              label: 'Bệnh nhân'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.mauChinh),
              label: 'Hồ sơ'),
        ],
      ),
    );
  }
}

// ============================ TAB LỊCH KHÁM ============================

class _TabLichKham extends StatefulWidget {
  final HoSo hoSo;
  const _TabLichKham({required this.hoSo});

  @override
  State<_TabLichKham> createState() => _TabLichKhamState();
}

class _TabLichKhamState extends State<_TabLichKham> {
  final _dichVu = DichVuBacSi();

  DateTime _ngayDangChon = DateTime.now();
  String? _noiCongTac;
  List<CaKhamTrongNgay> _cacCa = [];
  bool _dangTai = true;
  bool _dangGoi = false;
  String? _loi;

  @override
  void initState() {
    super.initState();
    _dichVu.layNoiCongTac().then((v) {
      if (mounted) setState(() => _noiCongTac = v);
    }).catchError((_) {});
    _taiCa();
  }

  Future<void> _taiCa() async {
    final ngay = _ngayDangChon;
    setState(() => _loi = null);
    try {
      final ds = await _dichVu.layCaTrongNgay(ngay);
      if (!mounted || ngay != _ngayDangChon) return; // người dùng đã chọn ngày khác
      setState(() {
        _cacCa = ds;
        _dangTai = false;
      });
    } on LoiBacSi catch (e) {
      if (!mounted) return;
      setState(() {
        _loi = e.thongBao;
        _dangTai = false;
      });
    }
  }

  void _chonNgay(DateTime ngay) {
    setState(() {
      _ngayDangChon = ngay;
      _dangTai = true;
      _cacCa = [];
    });
    _taiCa();
  }

  /// Ca đang làm việc: ca hôm nay có bệnh nhân đang khám, nếu không thì ca sớm nhất còn người chờ.
  CaKhamTrongNgay? get _caHienTai {
    final homNay = _cacCa.where((c) => c.laHomNay).toList();
    for (final c in homNay) {
      if (c.dangKham != null) return c;
    }
    for (final c in homNay) {
      if (c.dangCho.isNotEmpty) return c;
    }
    return null;
  }

  Future<void> _moKhamBenh(LuotKhamTrongCa luot, CaKhamTrongNgay ca) async {
    final daLuu = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ManHinhKhamBenh(luot: luot, ca: ca)),
    );
    if (daLuu == true) _taiCa();
  }

  Future<void> _goiSoTiepTheo(CaKhamTrongNgay ca) async {
    setState(() => _dangGoi = true);
    try {
      final id = await _dichVu.goiSoTiepTheo(ca.id);
      await _taiCa();
      final caMoi = _cacCa.firstWhere((c) => c.id == ca.id, orElse: () => ca);
      final luot = caMoi.danhSach.where((l) => l.id == id).firstOrNull;
      if (luot != null && mounted) await _moKhamBenh(luot, caMoi);
    } on LoiBacSi catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.thongBao)));
    } finally {
      if (mounted) setState(() => _dangGoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final cacCa = _cacCa;
    final tatCaLuot = [for (final ca in cacCa) ...ca.danhSach];

    int dem(TrangThaiLuotKham t) => tatCaLuot.where((l) => l.trangThai == t).length;
    final tong = tatCaLuot.where((l) => l.trangThai != TrangThaiLuotKham.daHuy).length;
    final daKham = dem(TrangThaiLuotKham.daKham);
    final dangCho = dem(TrangThaiLuotKham.choKham) + dem(TrangThaiLuotKham.tamHoan);

    final caHienTai = _caHienTai;
    final dangKham = caHienTai?.dangKham;
    final soTiepTheo = (dangKham == null && caHienTai != null && caHienTai.dangCho.isNotEmpty)
        ? caHienTai.dangCho.first.soThuTu
        : null;

    return RefreshIndicator(
      onRefresh: _taiCa,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        // 1. Lời chào
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Xin chào bác sĩ,',
                      style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat)),
                  Text(widget.hoSo.hoTen.isEmpty ? 'Bác sĩ' : widget.hoSo.hoTen,
                      style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.local_hospital_outlined,
                        size: 16, color: AppTheme.mauChuNhat),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_noiCongTac ?? 'Chưa gán khoa · bệnh viện',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                    ),
                  ]),
                ],
              ),
            ),
            AnhDaiDien(hoTen: widget.hoSo.hoTen, banKinh: 28),
          ],
        ),
        const SizedBox(height: 20),

        // 2. Chọn ngày trong tuần
        ThanhChonNgay(
          ngayDangChon: _ngayDangChon,
          onChon: _chonNgay,
        ),
        const SizedBox(height: 16),

        // 3. Thống kê
        Row(
          children: [
            Expanded(
              child: OThongKe(
                  nhan: 'Tổng bệnh nhân',
                  giaTri: tong,
                  donVi: 'hồ sơ',
                  icon: Icons.groups_outlined,
                  mau: AppTheme.mauChinh),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OThongKe(
                  nhan: 'Đã khám',
                  giaTri: daKham,
                  donVi: 'xong',
                  icon: Icons.check_circle_outline,
                  mau: const Color(0xFF15803D)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OThongKe(
                  nhan: 'Đang chờ',
                  giaTri: dangCho,
                  donVi: 'lượt',
                  icon: Icons.schedule,
                  mau: const Color(0xFFB45309)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Đang khám
        if (cacCa.any((c) => c.laHomNay))
          TheDangKham(
            dangKham: dangKham,
            tenCa: caHienTai?.tenCa,
            soTiepTheo: _dangGoi ? null : soTiepTheo,
            onGoiTiep: () => _goiSoTiepTheo(caHienTai!),
            onMoBenhAn: () => _moKhamBenh(dangKham!, caHienTai!),
          ),
        const SizedBox(height: 24),

        // 5. Danh sách theo ca
        if (_dangTai)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loi != null)
          TheTrang(
            child: Column(children: [
              Text(_loi!, textAlign: TextAlign.center),
              TextButton(onPressed: _taiCa, child: const Text('Thử lại')),
            ]),
          )
        else if (cacCa.isEmpty)
          TheTrang(
            child: Row(
              children: [
                const Icon(Icons.event_busy_outlined, color: AppTheme.mauChuNhat),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Không có lịch khám trong ngày này.',
                      style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
                ),
              ],
            ),
          )
        else
          for (final ca in cacCa) ...[
            DanhSachCa(
              ca: ca,
              onChonBenhNhan: (luot) => _moKhamBenh(luot, ca),
            ),
            const SizedBox(height: 16),
          ],
      ],
    ),
    );
  }
}
