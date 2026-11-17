import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/dinh_dang.dart';
import '../../core/widgets/the_trang.dart';
import 'dich_vu_cls.dart';
import 'man_hinh_so_do.dart';
import 'mo_hinh_cls.dart';

/// Lộ trình khám của bệnh nhân sau khi bác sĩ chỉ định cận lâm sàng:
/// thanh toán → đi từng khu (chỉ đường bằng sơ đồ) → quay lại phòng khám.
class ManHinhLoTrinh extends StatefulWidget {
  final int luotKhamId;

  const ManHinhLoTrinh({super.key, required this.luotKhamId});

  @override
  State<ManHinhLoTrinh> createState() => _ManHinhLoTrinhState();
}

class _ManHinhLoTrinhState extends State<ManHinhLoTrinh> {
  LoTrinhCls? _lt;
  String? _loi;
  bool _dangGui = false;

  @override
  void initState() {
    super.initState();
    _tai();
  }

  Future<void> _tai() async {
    try {
      final lt = await DichVuCls.loTrinh(widget.luotKhamId);
      if (mounted) {
        setState(() {
          _lt = lt;
          _loi = null;
        });
      }
    } on LoiCls catch (e) {
      if (mounted) setState(() => _loi = e.thongBao);
    }
  }

  void _bao(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  Future<void> _lam(Future<void> Function() viec) async {
    setState(() => _dangGui = true);
    try {
      await viec();
    } on LoiCls catch (e) {
      _bao(e.thongBao);
    }
    await _tai();
    if (mounted) setState(() => _dangGui = false);
  }

  // ---------- các thao tác ----------

  Future<void> _thanhToan(LoTrinhCls lt) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _HoaDon(lt: lt),
    );
    if (ok != true || !mounted) return;
    await _lam(() async {
      final tien = await DichVuCls.thanhToan(lt.luotKhamId);
      _bao('Đã thanh toán ${tienVnd(tien)}. Bắt đầu đi theo lộ trình nhé!');
    });
  }

  /// Mở sơ đồ chỉ đường; nếu bấm "Tôi đã đến" thì làm bước tương ứng.
  Future<void> _chiDuong({
    required String tu,
    required String den,
    String? nhanDen,
    String? viec,
    required Future<void> Function() khiDen,
  }) async {
    final daDen = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ManHinhSoDo(
          maTu: tu,
          maDen: den,
          nhanDen: nhanDen,
          viec: viec,
          coNutDaDen: true,
        ),
      ),
    );
    if (daDen == true && mounted) await khiDen();
  }

  /// Bệnh nhân đã tới khu: mô phỏng việc chụp / xét nghiệm vài giây rồi lưu kết quả mẫu.
  Future<void> _denKhu(ChiDinhCls cd) async {
    HapticFeedback.mediumImpact();
    final xong = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DangThucHien(chiDinh: cd),
    );
    if (xong != true || !mounted) return;
    await _lam(() async {
      await DichVuCls.hoanThanh(cd.id);
      _bao('Đã xong "${cd.dichVu.ten}". Kết quả đã gửi cho bác sĩ.');
    });
  }

  Future<void> _quayLai(LoTrinhCls lt) => _lam(() async {
    await DichVuCls.quayLai(lt.luotKhamId);
    HapticFeedback.heavyImpact();
    _bao('Đã báo bác sĩ. Bạn sẽ được ưu tiên gọi vào ${lt.tenPhong}.');
  });

  // ---------- giao diện ----------

  @override
  Widget build(BuildContext context) {
    final lt = _lt;
    return Scaffold(
      appBar: AppBar(title: const Text('Lộ trình khám hôm nay')),
      body: lt == null
          ? Center(
              child: _loi == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_loi!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _tai, child: const Text('Thử lại')),
                        ],
                      ),
                    ),
            )
          : RefreshIndicator(onRefresh: _tai, child: _danhSach(lt)),
    );
  }

  Widget _danhSach(LoTrinhCls lt) {
    final chu = Theme.of(context).textTheme;
    final dangLam = lt.trangThai == 'lam_cls';
    final hienTai = !lt.daThanhToan ? -1 : lt.chiDinh.indexWhere((c) => !c.xong);
    final daQuayLai = lt.trangThai != 'lam_cls';

    // Vị trí trước mỗi bước: phòng khám → khu của chỉ định trước → …
    String viTriTruoc(int i) => i == 0 ? lt.maPhongKham : lt.chiDinh[i - 1].dichVu.maKhu;

    final buoc = <Widget>[
      _Buoc(
        so: 1,
        trangThai: _TT.xong,
        tieuDe: 'Khám ban đầu',
        moTa: '${lt.tenPhong[0].toUpperCase()}${lt.tenPhong.substring(1)}'
            '${lt.tang == null ? '' : ' · Tầng ${lt.tang}'} · ${lt.tenBacSi}',
      ),
      _Buoc(
        so: 2,
        trangThai: lt.daThanhToan ? _TT.xong : _TT.hienTai,
        tieuDe: 'Thanh toán cận lâm sàng',
        moTa: lt.daThanhToan
            ? 'Đã thanh toán ${tienVnd(lt.tongTien)} trong ứng dụng'
            : '${lt.chiDinh.length} dịch vụ · ${tienVnd(lt.tongTien)}',
        hanhDong: !lt.daThanhToan && dangLam
            ? FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.mauNhan),
                onPressed: _dangGui ? null : () => _thanhToan(lt),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Thanh toán trong app'),
              )
            : null,
      ),
      for (var i = 0; i < lt.chiDinh.length; i++)
        _buocChiDinh(lt, i, i == hienTai && dangLam, viTriTruoc(i)),
      _Buoc(
        so: lt.chiDinh.length + 3,
        trangThai: daQuayLai
            ? _TT.xong
            : (lt.daThanhToan && lt.xongHet ? _TT.hienTai : _TT.cho),
        tieuDe: 'Quay lại ${lt.tenPhong} đưa kết quả',
        moTa: daQuayLai
            ? 'Đã báo bác sĩ, bạn được ưu tiên gọi vào'
            : 'Được ưu tiên gọi lại, không phải xếp hàng từ đầu',
        hanhDong: dangLam && lt.daThanhToan && lt.xongHet
            ? _HaiNut(
                dangGui: _dangGui,
                chiDuong: () => _chiDuong(
                  tu: lt.chiDinh.isEmpty ? lt.maPhongKham : lt.chiDinh.last.dichVu.maKhu,
                  den: lt.maPhongKham,
                  nhanDen: lt.soPhong == null ? null : 'Phòng ${lt.soPhong}',
                  viec: 'Đưa kết quả cho bác sĩ',
                  khiDen: () => _quayLai(lt),
                ),
                daDen: () => _quayLai(lt),
              )
            : null,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          '${lt.tenBacSi} chỉ định ${lt.chiDinh.length} cận lâm sàng',
          style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
        ),
        const SizedBox(height: 4),
        Text(
          daQuayLai
              ? 'Bạn đã hoàn thành lộ trình'
              : '${lt.soXong}/${lt.chiDinh.length} cận lâm sàng đã xong',
          style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: lt.chiDinh.isEmpty ? 0 : (lt.soXong + (daQuayLai ? 1 : 0)) / (lt.chiDinh.length + 1),
            backgroundColor: const Color(0xFFEEF2F6),
            color: AppTheme.mauNhan,
          ),
        ),
        const SizedBox(height: 18),
        ...buoc,
        if (daQuayLai) ...[
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Về trang chủ chờ gọi số'),
          ),
        ],
      ],
    );
  }

  Widget _buocChiDinh(LoTrinhCls lt, int i, bool laHienTai, String tu) {
    final cd = lt.chiDinh[i];
    final dv = cd.dichVu;
    return _Buoc(
      so: i + 3,
      trangThai: cd.xong ? _TT.xong : (laHienTai ? _TT.hienTai : _TT.cho),
      tieuDe: dv.ten,
      moTa: cd.xong
          ? '${dv.tenKhu} · đã xong, kết quả đã gửi bác sĩ'
          : '${dv.tenKhu} · Tầng ${dv.tang} · có kết quả sau khoảng ${dv.thoiGianPhut} phút',
      chiTiet: laHienTai ? _HuongDanChuanBi(dichVu: dv) : null,
      hanhDong: laHienTai
          ? _HaiNut(
              dangGui: _dangGui,
              chiDuong: () => _chiDuong(
                tu: tu,
                den: dv.maKhu,
                viec: dv.ten,
                khiDen: () => _denKhu(cd),
              ),
              daDen: () => _denKhu(cd),
            )
          : null,
    );
  }
}

enum _TT { xong, hienTai, cho }

/// Một bước trên dòng thời gian của lộ trình.
class _Buoc extends StatelessWidget {
  final int so;
  final _TT trangThai;
  final String tieuDe;
  final String moTa;
  final Widget? chiTiet;
  final Widget? hanhDong;

  const _Buoc({
    required this.so,
    required this.trangThai,
    required this.tieuDe,
    required this.moTa,
    this.chiTiet,
    this.hanhDong,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final xong = trangThai == _TT.xong;
    final hienTai = trangThai == _TT.hienTai;
    final mauTron = xong
        ? AppTheme.mauChinh
        : hienTai
        ? AppTheme.mauNhan
        : Colors.white;

    final noiDung = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tieuDe,
          style: chu.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: hienTai ? AppTheme.mauNhan : AppTheme.mauChuDam,
          ),
        ),
        const SizedBox(height: 2),
        Text(moTa, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
        if (chiTiet != null) ...[const SizedBox(height: 10), chiTiet!],
        if (hanhDong != null) ...[const SizedBox(height: 12), hanhDong!],
      ],
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: mauTron,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: xong || hienTai ? mauTron : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                    boxShadow: hienTai
                        ? [BoxShadow(color: AppTheme.mauNhan.withValues(alpha: 0.25), blurRadius: 10)]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: xong
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : Text(
                          '$so',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: hienTai ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: xong ? AppTheme.mauChinh : AppTheme.mauVien,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: hienTai
                  ? Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
                        border: Border.all(color: AppTheme.mauNhan, width: 1.6),
                      ),
                      child: noiDung,
                    )
                  : Padding(padding: const EdgeInsets.only(top: 6), child: noiDung),
            ),
          ),
        ],
      ),
    );
  }
}

class _HaiNut extends StatelessWidget {
  final bool dangGui;
  final VoidCallback chiDuong;
  final VoidCallback daDen;

  const _HaiNut({required this.dangGui, required this.chiDuong, required this.daDen});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: dangGui ? null : daDen,
            icon: const Icon(Icons.where_to_vote_outlined, size: 18),
            label: const Text('Tôi đã đến'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.mauNhan,
              minimumSize: const Size.fromHeight(46),
            ),
            onPressed: dangGui ? null : chiDuong,
            icon: const Icon(Icons.near_me_rounded, size: 18),
            label: const Text('Chỉ đường'),
          ),
        ),
      ],
    );
  }
}

/// Mục đích và cách chuẩn bị của dịch vụ (lấy từ danh mục, không do AI tự sinh).
class _HuongDanChuanBi extends StatelessWidget {
  final DichVuClsMuc dichVu;

  const _HuongDanChuanBi({required this.dichVu});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFEEF7FD), Color(0xFFFBEFF6)]),
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppTheme.mauChinh),
              const SizedBox(width: 6),
              Text(
                'Cần biết trước khi làm',
                style: chu.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (dichVu.canNhinAn) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: const ShapeDecoration(
                    color: AppTheme.mauNhanNhat,
                    shape: StadiumBorder(),
                  ),
                  child: const Text(
                    'Cần nhịn ăn',
                    style: TextStyle(
                      color: AppTheme.mauNhan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text('Để làm gì: ${dichVu.mucDich}', style: chu.bodySmall),
          const SizedBox(height: 4),
          Text('Chuẩn bị: ${dichVu.chuanBi}', style: chu.bodySmall),
        ],
      ),
    );
  }
}

/// Hoá đơn cận lâm sàng trước khi thanh toán (mô phỏng, chưa nối cổng thanh toán).
class _HoaDon extends StatelessWidget {
  final LoTrinhCls lt;

  const _HoaDon({required this.lt});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thanh toán cận lâm sàng',
              style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Lượt khám số ${haiSo(lt.soThuTu)} · ${lt.tenBacSi}',
              style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
            ),
            const SizedBox(height: 14),
            TheTrang(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final c in lt.chiDinh)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: Text(c.dichVu.ten)),
                          Text(
                            tienVnd(c.dichVu.gia),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tổng cộng',
                          style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        tienVnd(lt.tongTien),
                        style: chu.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.mauNhan,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Thanh toán mô phỏng cho đồ án, chưa kết nối cổng thanh toán thật.',
              style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.mauNhan),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.lock_outline_rounded),
              label: Text('Xác nhận thanh toán ${tienVnd(lt.tongTien)}'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại mô phỏng đang chụp / xét nghiệm (vài giây) rồi tự đóng.
class _DangThucHien extends StatefulWidget {
  final ChiDinhCls chiDinh;

  const _DangThucHien({required this.chiDinh});

  @override
  State<_DangThucHien> createState() => _DangThucHienState();
}

class _DangThucHienState extends State<_DangThucHien>
    with SingleTickerProviderStateMixin {
  late final _ac = AnimationController(vsync: this, duration: const Duration(seconds: 4))
    ..forward().whenComplete(() {
      if (mounted) Navigator.pop(context, true);
    });

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dv = widget.chiDinh.dichVu;
    return AlertDialog(
      title: Text(dv.tenKhu, style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.biotech_outlined, size: 44, color: AppTheme.mauChinh),
          const SizedBox(height: 12),
          Text(
            'Đang thực hiện: ${dv.ten}…',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _ac,
            builder: (_, _) => LinearProgressIndicator(
              value: _ac.value,
              color: AppTheme.mauNhan,
              backgroundColor: AppTheme.mauNhanNhat,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Mô phỏng cho demo: kết quả mẫu sẽ được gửi cho bác sĩ.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.mauChuNhat),
          ),
        ],
      ),
    );
  }
}
