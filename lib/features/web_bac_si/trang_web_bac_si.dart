import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

import '../../core/app_theme.dart';
import '../../core/dinh_dang.dart';
import '../../core/don_thuoc.dart';
import '../../core/widgets/hieu_ung.dart';
import '../../core/widgets/logo_medibook.dart';
import '../../core/widgets/the_phieu_tien_kham.dart';
import '../auth/dich_vu_tai_khoan.dart';
import '../auth/dieu_huong.dart';
import '../bac_si/dich_vu_bac_si.dart';
import '../bac_si/mo_hinh.dart';

/// Trang web dành cho bác sĩ (Flutter Web, màn hình máy tính).
/// - Bên trái (phần lớn trang): MÀN HÌNH GỌI SỐ — số đang mời thật to, số tiếp theo,
///   nút gọi số / tạm hoãn. (Giọng nói nhắc tới lượt phát trên điện thoại bệnh nhân.)
/// - Bên phải: thống kê hôm nay, bệnh nhân đang khám + lịch sử khám + nhập chẩn đoán,
///   danh sách bệnh nhân trong ca.
/// Dữ liệu tự cập nhật bằng Supabase Realtime khi có người đặt/huỷ lịch.
class TrangWebBacSi extends StatefulWidget {
  final HoSo hoSo;
  const TrangWebBacSi({super.key, required this.hoSo});

  @override
  State<TrangWebBacSi> createState() => _TrangWebBacSiState();
}

class _TrangWebBacSiState extends State<TrangWebBacSi> {
  final _dv = DichVuBacSi();
  List<CaKhamTrongNgay> _cacCa = [];
  int? _caChonId;
  String? _noiCongTac;
  bool _dangTai = true;
  String? _loi;
  bool _dangXuLy = false;
  RealtimeChannel? _kenh;
  Timer? _taiDinhKy;

  // Ô nhập kết quả của bệnh nhân đang khám
  final _oChanDoan = TextEditingController();
  final _oLoiDan = TextEditingController();
  int? _luotCuaForm;
  List<DongDonThuoc> _don = []; // đơn thuốc đang kê (thuốc mẫu)
  DateTime? _ngayTaiKham;
  List<LanKhamTruoc> _lichSu = [];
  bool _dangTaiLichSu = false;

  @override
  void initState() {
    super.initState();
    _tai();
    _dv.layNoiCongTac().then((v) {
      if (mounted) setState(() => _noiCongTac = v);
    }, onError: (_) {});
    _kenh = _dv.theoDoiCacCa(_tai);
    // Dự phòng khi mất Realtime + để ca tự chuyển trạng thái theo giờ
    _taiDinhKy = Timer.periodic(const Duration(seconds: 60), (_) => _tai());
  }

  @override
  void dispose() {
    _taiDinhKy?.cancel();
    final k = _kenh;
    if (k != null) _dv.boTheoDoi(k);
    _oChanDoan.dispose();
    _oLoiDan.dispose();
    super.dispose();
  }

  // ---------------- dữ liệu ----------------

  CaKhamTrongNgay? get _ca {
    for (final c in _cacCa) {
      if (c.id == _caChonId) return c;
    }
    return null;
  }

  static CaKhamTrongNgay? _caMacDinh(List<CaKhamTrongNgay> ds) {
    if (ds.isEmpty) return null;
    for (final c in ds) {
      if (c.dangDienRa) return c;
    }
    for (final c in ds) {
      if (!c.daKetThuc) return c;
    }
    return ds.last;
  }

  Future<void> _tai() async {
    try {
      final ds = await _dv.layCaTrongNgay(DateTime.now());
      if (!mounted) return;
      setState(() {
        _cacCa = ds;
        _loi = null;
        _dangTai = false;
        if (!ds.any((c) => c.id == _caChonId)) _caChonId = _caMacDinh(ds)?.id;
      });
      _dongBoForm();
    } on LoiBacSi catch (e) {
      if (mounted) {
        setState(() {
          _loi = e.thongBao;
          _dangTai = false;
        });
      }
    }
  }

  /// Bệnh nhân đang khám đổi → làm mới ô nhập và tải lịch sử khám của người đó.
  Future<void> _dongBoForm() async {
    final dk = _ca?.dangKham;
    if (dk?.id == _luotCuaForm) return;
    _luotCuaForm = dk?.id;
    _oChanDoan.text = dk?.chanDoan ?? '';
    _oLoiDan.text = dk?.loiDan ?? '';
    setState(() {
      _don = [];
      _ngayTaiKham = null;
      _lichSu = [];
      _dangTaiLichSu = dk != null;
    });
    if (dk == null) return;
    try {
      final ls = await _dv.layLichSuVoiBenhNhan(dk.benhNhanId, boQuaLuotId: dk.id);
      if (mounted && _luotCuaForm == dk.id) setState(() => _lichSu = ls);
    } on LoiBacSi {
      // không tải được lịch sử: vẫn khám bình thường
    } finally {
      if (mounted) setState(() => _dangTaiLichSu = false);
    }
  }

  // ---------------- thao tác ----------------

  Future<bool> _lam(Future<void> Function() viec, {String? thanhCong}) async {
    if (_dangXuLy) return false;
    setState(() => _dangXuLy = true);
    try {
      await viec();
      await _tai();
      if (thanhCong != null) _bao(thanhCong);
      return true;
    } on LoiBacSi catch (e) {
      _bao(e.thongBao, loi: true);
      return false;
    } finally {
      if (mounted) setState(() => _dangXuLy = false);
    }
  }

  void _bao(String noiDung, {bool loi = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(noiDung),
          backgroundColor: loi ? Colors.red.shade700 : null,
        ),
      );
  }

  Future<void> _goiSoTiepTheo(CaKhamTrongNgay ca) async {
    final ok = await _lam(() => _dv.goiSoTiepTheo(ca.id));
    final dk = _ca?.dangKham;
    if (ok && dk != null) _bao('Đã mời số ${haiSo(dk.soThuTu)} vào khám');
  }

  Future<void> _moiVao(LuotKhamTrongCa l) => _lam(
    () => _dv.batDauKham(l.id),
    thanhCong: 'Đã mời số ${haiSo(l.soThuTu)} vào khám',
  );

  Future<void> _tamHoan(LuotKhamTrongCa l) => _lam(
    () => _dv.tamHoan(l.id),
    thanhCong: 'Đã tạm hoãn số ${haiSo(l.soThuTu)}',
  );

  Future<void> _hoanTat(LuotKhamTrongCa l) async {
    final chanDoan = _oChanDoan.text.trim();
    if (chanDoan.isEmpty) {
      _bao('Vui lòng nhập chẩn đoán', loi: true);
      return;
    }
    await _lam(
      () => _dv.hoanTatKham(
        l.id,
        chanDoan,
        _oLoiDan.text.trim(),
        donThuoc: _don,
        ngayTaiKham: _ngayTaiKham,
      ),
      thanhCong: 'Đã lưu kết quả khám số ${haiSo(l.soThuTu)}',
    );
  }

  Future<void> _dangXuat() async {
    final dongY = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (dongY != true) return;
    await DichVuTaiKhoan.dangXuat();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushAndRemoveUntil(trangMem(manHinhChuaDangNhap()), (route) => false);
  }

  // ---------------- giao diện ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mauNen,
      body: SafeArea(
        child: Column(
          children: [
            _thanhTren(),
            Expanded(child: _noiDung()),
          ],
        ),
      ),
    );
  }

  Widget _thanhTren() {
    final chu = Theme.of(context).textTheme;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        children: [
          const LogoMediBook(kichThuoc: 40, hero: false),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MediBook · Bác sĩ',
                  style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                if (_noiCongTac != null)
                  Text(
                    _noiCongTac!,
                    overflow: TextOverflow.ellipsis,
                    style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                  ),
              ],
            ),
          ),
          const Spacer(),
          if (_cacCa.length > 1) ...[
            SegmentedButton<int>(
              segments: [
                for (final c in _cacCa)
                  ButtonSegment(value: c.id, label: Text(c.tenCa)),
              ],
              selected: {?_caChonId},
              emptySelectionAllowed: true,
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                setState(() => _caChonId = s.first);
                _dongBoForm();
              },
            ),
            const SizedBox(width: 16),
          ],
          const _DongHo(),
          const SizedBox(width: 16),
          Text(
            widget.hoSo.hoTen,
            style: chu.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _dangXuat,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _noiDung() {
    if (_dangTai) return const Center(child: CircularProgressIndicator());
    if (_loi != null && _cacCa.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loi!),
            const SizedBox(height: 12),
            FilledButton(onPressed: _tai, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final ca = _ca;
    if (ca == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy_outlined, size: 64, color: AppTheme.mauChuNhat),
            const SizedBox(height: 12),
            Text(
              'Hôm nay bạn không có ca khám nào',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    final cotPhai = [
      _thongKe(),
      const SizedBox(height: 16),
      _theDangKham(ca),
      const SizedBox(height: 16),
      _danhSachCa(ca),
    ];

    return LayoutBuilder(
      builder: (context, k) {
        if (k.maxWidth >= 1100) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _manHinhGoiSo(ca)),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: ListView(children: cotPhai)),
              ],
            ),
          );
        }
        // Màn hình hẹp (cửa sổ nhỏ, máy tính bảng): xếp dọc
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SizedBox(height: 560, child: _manHinhGoiSo(ca)),
            const SizedBox(height: 16),
            ...cotPhai,
          ],
        );
      },
    );
  }

  /// Màn hình gọi số: phần lớn nhất của trang.
  Widget _manHinhGoiSo(CaKhamTrongNgay ca) {
    final dk = ca.dangKham;
    final cho = ca.dangCho;
    final tamHoan =
        ca.danhSach.where((l) => l.trangThai == TrangThaiLuotKham.tamHoan).toList()
          ..sort((a, b) => a.soThuTu.compareTo(b.soThuTu));
    const trang70 = Colors.white70;

    final String goiY;
    if (ca.daKetThuc) {
      goiY = 'Ca khám đã kết thúc';
    } else if (!ca.dangDienRa) {
      goiY = 'Ca khám bắt đầu lúc ${gioCuaKhoang(ca.gioBatDau)}';
    } else if (cho.isEmpty) {
      goiY = 'Không còn bệnh nhân đang chờ';
    } else {
      goiY = 'Bấm "Gọi số tiếp theo" để mời bệnh nhân';
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.mauChinh, Color(0xFF1E3A8A)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'MÀN HÌNH GỌI SỐ',
                style: TextStyle(
                  color: trang70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              _Nhan('${ca.tenCa} · ${ca.khungGio}'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ca.phong ?? 'Phòng khám',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ĐANG MỜI SỐ',
                    style: TextStyle(
                      color: trang70,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (w, a) => ScaleTransition(
                          scale: a,
                          child: FadeTransition(opacity: a, child: w),
                        ),
                        child: Text(
                          dk == null ? '--' : haiSo(dk.soThuTu),
                          key: ValueKey(dk?.soThuTu),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 200,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    dk == null ? goiY : dk.tenBenhNhan,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: dk == null ? trang70 : Colors.white,
                      fontSize: dk == null ? 18 : 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: Colors.white24, height: 32),
          _HangSo(
            nhan: 'SỐ TIẾP THEO',
            cacSo: [for (final l in cho.take(8)) l.soThuTu],
            trong: 'Không còn ai chờ',
            mau: Colors.white,
          ),
          if (tamHoan.isNotEmpty) ...[
            const SizedBox(height: 12),
            _HangSo(
              nhan: 'TẠM HOÃN',
              cacSo: [for (final l in tamHoan) l.soThuTu],
              trong: '',
              mau: const Color(0xFFFDBA74),
            ),
          ],
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: ca.dangDienRa && dk == null && cho.isNotEmpty && !_dangXuLy
                    ? () => _goiSoTiepTheo(ca)
                    : null,
                icon: const Icon(Icons.campaign_rounded),
                label: const Text('Gọi số tiếp theo'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.mauChinh,
                  disabledBackgroundColor: Colors.white24,
                  disabledForegroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (dk != null) ...[
                _NutVien(
                  icon: Icons.pause_circle_outline,
                  nhan: 'Tạm hoãn (chưa có mặt)',
                  onPressed: _dangXuLy ? null : () => _tamHoan(dk),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _thongKe() {
    var tong = 0, daKham = 0, dangCho = 0, vangMat = 0;
    for (final c in _cacCa) {
      for (final l in c.danhSach) {
        switch (l.trangThai) {
          case TrangThaiLuotKham.daHuy:
            continue;
          case TrangThaiLuotKham.daKham:
            daKham++;
          case TrangThaiLuotKham.choKham:
          case TrangThaiLuotKham.dangKham:
          case TrangThaiLuotKham.tamHoan:
            dangCho++;
          case TrangThaiLuotKham.vangMat:
            vangMat++;
        }
        tong++;
      }
    }
    return _The(
      tieuDe: 'Thống kê hôm nay',
      child: Row(
        children: [
          _OThongKe(nhan: 'Tổng số', so: tong, mau: AppTheme.mauChinh),
          _OThongKe(nhan: 'Đã khám', so: daKham, mau: const Color(0xFF16A34A)),
          _OThongKe(nhan: 'Đang chờ', so: dangCho, mau: AppTheme.mauCam),
          _OThongKe(nhan: 'Vắng mặt', so: vangMat, mau: AppTheme.mauChuNhat),
        ],
      ),
    );
  }

  Widget _theDangKham(CaKhamTrongNgay ca) {
    final dk = ca.dangKham;
    final chu = Theme.of(context).textTheme;
    if (dk == null) {
      return _The(
        tieuDe: 'Bệnh nhân đang khám',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Chưa có bệnh nhân trong phòng',
              style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
            ),
          ),
        ),
      );
    }
    final thongTin = [
      if (dk.gioiTinh != null && dk.gioiTinh!.isNotEmpty) dk.gioiTinh!,
      if (dk.tuoi != null) '${dk.tuoi} tuổi',
    ].join(' · ');

    return _The(
      tieuDe: 'Bệnh nhân đang khám',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppTheme.mauChinh,
                child: Text(
                  haiSo(dk.soThuTu),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dk.tenBenhNhan,
                      style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (thongTin.isNotEmpty)
                      Text(
                        thongTin,
                        style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (dk.phieuTienKham != null) ...[
            ThePhieuTienKham(phieu: dk.phieuTienKham!),
            const SizedBox(height: 12),
            _Muc('Bệnh nhân ghi thêm'),
          ] else
            _Muc('Triệu chứng bệnh nhân khai'),
          Text(dk.trieuChung.isEmpty ? '(Không ghi)' : dk.trieuChung),
          const SizedBox(height: 16),
          _Muc('Lịch sử khám với bạn'),
          if (_dangTaiLichSu)
            const LinearProgressIndicator()
          else if (_lichSu.isEmpty)
            Text(
              'Lần đầu khám với bạn',
              style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
            )
          else
            for (final l in _lichSu.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        ngayDayDu(l.ngay),
                        style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                      ),
                    ),
                    Expanded(child: Text(l.chanDoan)),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          TextField(
            controller: _oChanDoan,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Chẩn đoán *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _oLoiDan,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Lời dặn',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          _phanKeDon(ca),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _dangXuLy ? null : () => _hoanTat(dk),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Hoàn tất khám'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- kê đơn thuốc mẫu + ngày tái khám ----------------

  Widget _phanKeDon(CaKhamTrongNgay ca) {
    final chu = Theme.of(context).textTheme;
    final ngayKham = ca.ngay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _Muc('Đơn thuốc (thuốc mẫu dùng cho demo)')),
            TextButton.icon(
              onPressed: _don.length >= 10 ? null : _moThemThuoc,
              icon: const Icon(Icons.add),
              label: const Text('Thêm thuốc'),
            ),
          ],
        ),
        if (_don.isEmpty)
          Text(
            'Chưa kê thuốc nào.',
            style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
          )
        else
          for (var i = 0; i < _don.length; i++)
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
                        Text(
                          _don[i].thuoc.ten,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(_don[i].moTa, style: chu.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xoá',
                    onPressed: () => setState(() => _don.removeAt(i)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        const _Muc('Ngày tái khám'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final soNgay in const [3, 7, 14, 30])
              ChoiceChip(
                label: Text('Sau $soNgay ngày'),
                selected: _ngayTaiKham != null &&
                    _ngayTaiKham!.difference(ngayKham).inDays == soNgay,
                onSelected: (_) => setState(
                  () => _ngayTaiKham = ngayKham.add(Duration(days: soNgay)),
                ),
              ),
            ActionChip(
              avatar: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text('Chọn ngày'),
              onPressed: () async {
                final chon = await showDatePicker(
                  context: context,
                  initialDate: _ngayTaiKham ?? ngayKham.add(const Duration(days: 7)),
                  firstDate: ngayKham.add(const Duration(days: 1)),
                  lastDate: ngayKham.add(const Duration(days: 180)),
                );
                if (chon != null) setState(() => _ngayTaiKham = chon);
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.event_repeat_rounded,
              size: 18,
              color: _ngayTaiKham == null ? AppTheme.mauChuNhat : AppTheme.mauCam,
            ),
            const SizedBox(width: 6),
            Text(
              _ngayTaiKham == null
                  ? 'Không hẹn tái khám'
                  : 'Tái khám: ${ngayDayDu(_ngayTaiKham!)}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _ngayTaiKham == null ? AppTheme.mauChuNhat : AppTheme.mauCam,
              ),
            ),
            if (_ngayTaiKham != null)
              TextButton(
                onPressed: () => setState(() => _ngayTaiKham = null),
                child: const Text('Bỏ hẹn'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _moThemThuoc() async {
    List<ThuocMau> danhMuc;
    try {
      danhMuc = await DichVuDonThuoc.danhMuc();
    } catch (_) {
      _bao('Không tải được danh mục thuốc (đã chạy file SQL 13 chưa?)', loi: true);
      return;
    }
    if (!mounted || danhMuc.isEmpty) return;

    var thuoc = danhMuc.first;
    var lieu = 1.0;
    var soLan = 2;
    var thoiDiem = ThoiDiemUong.sauAn;
    var soNgay = 5;
    const cacLieu = [0.5, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0];
    const cacSoNgay = [3, 5, 7, 10, 14, 30];

    final dong = await showDialog<DongDonThuoc>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, capNhat) => AlertDialog(
          title: const Text('Thêm thuốc vào đơn'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<ThuocMau>(
                  initialValue: thuoc,
                  decoration: const InputDecoration(
                    labelText: 'Thuốc',
                    border: OutlineInputBorder(),
                  ),
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
                        decoration: InputDecoration(
                          labelText: 'Mỗi lần (${thuoc.donVi})',
                          border: const OutlineInputBorder(),
                        ),
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
                        decoration: const InputDecoration(
                          labelText: 'Số ngày dùng',
                          border: OutlineInputBorder(),
                        ),
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Huỷ'),
            ),
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
              child: const Text('Thêm'),
            ),
          ],
        ),
      ),
    );
    if (dong != null && mounted) setState(() => _don.add(dong));
  }

  Widget _danhSachCa(CaKhamTrongNgay ca) {
    final ds = [...ca.danhSach]..sort((a, b) => a.soThuTu.compareTo(b.soThuTu));
    final coTheMoi = ca.dangDienRa && ca.dangKham == null && !_dangXuLy;
    return _The(
      tieuDe: 'Danh sách ${ca.tenCa.toLowerCase()} (${ca.soDaDangKy}/${ca.soToiDa})',
      child: ds.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Chưa có bệnh nhân đặt lịch'),
            )
          : Column(
              children: [
                for (final l in ds)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: _mauTrangThai(l.trangThai).withValues(alpha: 0.15),
                      child: Text(
                        haiSo(l.soThuTu),
                        style: TextStyle(
                          color: _mauTrangThai(l.trangThai),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(child: Text(l.tenBenhNhan)),
                        if (l.nenKhamSom) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'AI đánh giá: nên khám sớm',
                            child: Icon(Icons.circle, size: 10, color: AppTheme.mauCam),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      [_tenTrangThai(l.trangThai), if (l.tomTatKhai.isNotEmpty) l.tomTatKhai].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: coTheMoi &&
                            (l.trangThai == TrangThaiLuotKham.choKham ||
                                l.trangThai == TrangThaiLuotKham.tamHoan)
                        ? TextButton(
                            onPressed: () => _moiVao(l),
                            child: const Text('Mời vào'),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }

  static String _tenTrangThai(TrangThaiLuotKham t) => switch (t) {
    TrangThaiLuotKham.choKham => 'Đang chờ',
    TrangThaiLuotKham.dangKham => 'Đang khám',
    TrangThaiLuotKham.tamHoan => 'Tạm hoãn',
    TrangThaiLuotKham.daKham => 'Đã khám',
    TrangThaiLuotKham.daHuy => 'Đã huỷ',
    TrangThaiLuotKham.vangMat => 'Vắng mặt',
  };

  static Color _mauTrangThai(TrangThaiLuotKham t) => switch (t) {
    TrangThaiLuotKham.choKham => AppTheme.mauChinh,
    TrangThaiLuotKham.dangKham => const Color(0xFF16A34A),
    TrangThaiLuotKham.tamHoan => AppTheme.mauCam,
    TrangThaiLuotKham.daKham => const Color(0xFF16A34A),
    TrangThaiLuotKham.daHuy => AppTheme.mauChuNhat,
    TrangThaiLuotKham.vangMat => const Color(0xFFDC2626),
  };
}

// ---------------- widget nhỏ ----------------

/// Đồng hồ ở thanh trên, tự cập nhật mỗi giây.
class _DongHo extends StatefulWidget {
  const _DongHo();

  @override
  State<_DongHo> createState() => _DongHoState();
}

class _DongHoState extends State<_DongHo> {
  DateTime _bayGio = DateTime.now();
  late final Timer _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _bayGio = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${gioPhut(_bayGio)}:${haiSo(_bayGio.second)}',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          ngayDayDu(_bayGio),
          style: const TextStyle(color: AppTheme.mauChuNhat, fontSize: 12),
        ),
      ],
    );
  }
}

class _The extends StatelessWidget {
  final String tieuDe;
  final Widget child;
  const _The({required this.tieuDe, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
        border: Border.all(color: AppTheme.mauVien),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tieuDe,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Muc extends StatelessWidget {
  final String text;
  const _Muc(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.mauChuNhat,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _OThongKe extends StatelessWidget {
  final String nhan;
  final int so;
  final Color mau;
  const _OThongKe({required this.nhan, required this.so, required this.mau});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: mau.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.boGoc),
        ),
        child: Column(
          children: [
            Text(
              '$so',
              style: TextStyle(color: mau, fontSize: 26, fontWeight: FontWeight.w800),
            ),
            Text(
              nhan,
              style: const TextStyle(color: AppTheme.mauChuNhat, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hàng các số (số tiếp theo / tạm hoãn) trên màn hình gọi số.
class _HangSo extends StatelessWidget {
  final String nhan;
  final List<int> cacSo;
  final String trong;
  final Color mau;
  const _HangSo({
    required this.nhan,
    required this.cacSo,
    required this.trong,
    required this.mau,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            nhan,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: cacSo.isEmpty
              ? Text(trong, style: const TextStyle(color: Colors.white54))
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final so in cacSo)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: mau.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          haiSo(so),
                          style: TextStyle(
                            color: mau,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _Nhan extends StatelessWidget {
  final String text;
  const _Nhan(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: const ShapeDecoration(
      color: Colors.white12,
      shape: StadiumBorder(),
    ),
    child: Text(
      text,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
  );
}

class _NutVien extends StatelessWidget {
  final IconData icon;
  final String nhan;
  final VoidCallback? onPressed;
  const _NutVien({required this.icon, required this.nhan, this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(nhan),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Colors.white54),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
  );
}
