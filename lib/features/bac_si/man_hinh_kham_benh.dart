import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import '../dat_lich/dinh_dang.dart';
import 'dich_vu_bac_si.dart';
import 'mo_hinh.dart';

/// Bác sĩ khám một bệnh nhân: xem triệu chứng, lịch sử, nhập chẩn đoán và lời dặn.
/// Trả về true nếu đã lưu thay đổi (để màn trước tải lại).
class ManHinhKhamBenh extends StatefulWidget {
  final LuotKhamTrongCa luot;
  final CaKhamTrongNgay ca;

  const ManHinhKhamBenh({super.key, required this.luot, required this.ca});

  @override
  State<ManHinhKhamBenh> createState() => _ManHinhKhamBenhState();
}

class _ManHinhKhamBenhState extends State<ManHinhKhamBenh> {
  static const _goiY = [
    'Tái khám sau 5 ngày',
    'Uống nhiều nước',
    'Nghỉ ngơi, ăn uống đầy đủ',
    'Tái khám ngay nếu triệu chứng nặng hơn',
  ];

  final _dichVu = DichVuBacSi();
  late final _chanDoan = TextEditingController(text: widget.luot.chanDoan ?? '');
  late final _loiDan = TextEditingController(text: widget.luot.loiDan ?? '');
  late final Future<List<LanKhamTruoc>> _lichSu =
      _dichVu.layLichSuVoiBenhNhan(widget.luot.benhNhanId, boQuaLuotId: widget.luot.id);

  late TrangThaiLuotKham _trangThai = widget.luot.trangThai;
  bool _daThayDoi = false; // để màn trước biết cần tải lại
  bool _dangGui = false;
  String? _loiChanDoan;

  bool get _dangKham => _trangThai == TrangThaiLuotKham.dangKham;
  bool get _choMoiVao =>
      (_trangThai == TrangThaiLuotKham.choKham || _trangThai == TrangThaiLuotKham.tamHoan) &&
      widget.ca.dangDienRa;

  @override
  void dispose() {
    _chanDoan.dispose();
    _loiDan.dispose();
    super.dispose();
  }

  void _chen(String g) {
    final t = _loiDan.text.trim();
    if (t.contains(g)) return;
    _loiDan.text = t.isEmpty ? '$g.' : '$t\n$g.';
    _loiDan.selection = TextSelection.collapsed(offset: _loiDan.text.length);
  }

  Future<void> _hoanTat() async {
    if (_chanDoan.text.trim().isEmpty) {
      setState(() => _loiChanDoan = 'Vui lòng nhập chẩn đoán');
      return;
    }
    await _thucHien(
      () => _dichVu.hoanTatKham(widget.luot.id, _chanDoan.text, _loiDan.text),
      'Đã lưu kết quả khám số ${haiSo(widget.luot.soThuTu)}',
    );
  }

  Future<void> _tamHoan() => _thucHien(
        () => _dichVu.tamHoan(widget.luot.id),
        'Đã tạm hoãn số ${haiSo(widget.luot.soThuTu)}. Bệnh nhân vẫn giữ số đến hết ca.',
      );

  Future<void> _moiVaoKham() async {
    setState(() => _dangGui = true);
    final thongBao = ScaffoldMessenger.of(context);
    try {
      await _dichVu.batDauKham(widget.luot.id);
      thongBao.showSnackBar(SnackBar(content: Text('Đã mời số ${haiSo(widget.luot.soThuTu)} vào khám')));
      if (mounted) {
        setState(() {
          _trangThai = TrangThaiLuotKham.dangKham;
          _daThayDoi = true;
          _dangGui = false;
        });
      }
    } on LoiBacSi catch (e) {
      thongBao.showSnackBar(SnackBar(content: Text(e.thongBao)));
      if (mounted) setState(() => _dangGui = false);
    }
  }

  Future<void> _thucHien(Future<void> Function() viec, String thanhCong) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _dangGui = true;
      _loiChanDoan = null;
    });
    final thongBao = ScaffoldMessenger.of(context);
    try {
      await viec();
      thongBao.showSnackBar(SnackBar(content: Text(thanhCong)));
      if (mounted) Navigator.pop(context, true);
    } on LoiBacSi catch (e) {
      thongBao.showSnackBar(SnackBar(content: Text(e.thongBao)));
      if (mounted) setState(() => _dangGui = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final l = widget.luot;
    final ca = widget.ca;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (daPop, _) {
        if (!daPop) Navigator.pop(context, _daThayDoi);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Khám bệnh'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const ShapeDecoration(color: AppTheme.mauChinhNhat, shape: StadiumBorder()),
            child: Text('${ca.tenCa} · ${ca.khungGio}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _TheBenhNhan(luot: l, trangThai: _trangThai),
          const SizedBox(height: 16),

          // Triệu chứng
          _Khoi(
            icon: Icons.assignment_ind_outlined,
            tieuDe: 'Triệu chứng bệnh nhân khai',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.mauNen,
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
              ),
              child: Text(
                l.trieuChung.trim().isEmpty ? 'Bệnh nhân không khai triệu chứng.' : '“${l.trieuChung.trim()}”',
                style: TextStyle(
                  color: l.trieuChung.trim().isEmpty ? AppTheme.mauChuNhat : AppTheme.mauChuDam,
                  fontStyle: l.trieuChung.trim().isEmpty ? FontStyle.normal : FontStyle.italic,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Lịch sử
          FutureBuilder<List<LanKhamTruoc>>(
            future: _lichSu,
            builder: (_, snap) {
              final ds = snap.data ?? const <LanKhamTruoc>[];
              return _Khoi(
                icon: Icons.history,
                tieuDe: 'Lịch sử khám với bạn',
                phai: snap.hasData
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: const ShapeDecoration(
                            color: AppTheme.mauChinhNhat, shape: StadiumBorder()),
                        child: Text('${ds.length} lần khám',
                            style: const TextStyle(
                                color: AppTheme.mauChinh, fontSize: 12, fontWeight: FontWeight.w700)),
                      )
                    : null,
                child: !snap.hasData && !snap.hasError
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : ds.isEmpty
                        ? const Text('Lần đầu bệnh nhân khám với bạn.',
                            style: TextStyle(color: AppTheme.mauChuNhat))
                        : Column(
                            children: [
                              for (final k in ds.take(5))
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.mauNen,
                                    borderRadius: BorderRadius.circular(AppTheme.boGoc),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${haiSo(k.ngay.day)}/${haiSo(k.ngay.month)}/${k.ngay.year}',
                                          style: chu.labelMedium?.copyWith(
                                              color: AppTheme.mauChinh, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(k.chanDoan.isEmpty ? '(không ghi chẩn đoán)' : k.chanDoan,
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Kết quả khám
          _Khoi(
            icon: Icons.medical_services_outlined,
            tieuDe: 'Kết quả khám',
            child: _trangThai == TrangThaiLuotKham.daHuy || _trangThai == TrangThaiLuotKham.vangMat
                ? Text(
                    _trangThai == TrangThaiLuotKham.daHuy
                        ? 'Bệnh nhân đã huỷ lượt khám này.'
                        : 'Bệnh nhân không đến khám trước khi ca kết thúc.',
                    style: const TextStyle(color: AppTheme.mauChuNhat))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_trangThai == TrangThaiLuotKham.daKham)
                        const _GhiChu(
                          icon: Icons.lock_outline,
                          text: 'Kết quả đã được chốt và gửi cho bệnh nhân, không thể chỉnh sửa.',
                        )
                      else if (!_dangKham)
                        _GhiChu(
                          icon: Icons.info_outline,
                          text: _choMoiVao
                              ? 'Mời bệnh nhân vào khám để nhập kết quả.'
                              : 'Chỉ nhập kết quả trong thời gian của ca khám.',
                        ),
                      Text.rich(TextSpan(children: [
                        const TextSpan(text: 'Chẩn đoán ', style: TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: '*', style: TextStyle(color: Colors.red.shade700)),
                      ])),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _chanDoan,
                        enabled: _dangKham,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (_loiChanDoan != null) setState(() => _loiChanDoan = null);
                        },
                        decoration: InputDecoration(hintText: 'VD: Viêm họng cấp', errorText: _loiChanDoan),
                      ),
                      const SizedBox(height: 14),
                      const Text('Lời dặn cho bệnh nhân', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _loiDan,
                        enabled: _dangKham,
                        minLines: 4,
                        maxLines: 8,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(hintText: 'Thuốc, chế độ ăn, lịch tái khám…'),
                      ),
                      if (_dangKham) ...[
                      const SizedBox(height: 10),
                      Text('CHÈN NHANH',
                          style: chu.labelSmall?.copyWith(color: AppTheme.mauChuNhat, letterSpacing: 0.5)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final g in _goiY)
                            ActionChip(
                              label: Text('+ $g'),
                              onPressed: () => _chen(g),
                              backgroundColor: AppTheme.mauChinhNhat,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                            ),
                        ],
                      ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _thanhNut(),
    ),
    );
  }

  Widget? _thanhNut() {
    Widget dangXuLy(Widget icon) => _dangGui
        ? const SizedBox(
            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : icon;

    final List<Widget> nut;
    if (_dangKham) {
      nut = [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _dangGui || !widget.ca.dangDienRa ? null : _tamHoan,
            icon: const Icon(Icons.pause_circle_outline),
            label: const Text('Tạm hoãn'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFC2410C),
              side: const BorderSide(color: Color(0xFFFED7AA)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _dangGui ? null : _hoanTat,
            icon: dangXuLy(const Icon(Icons.check_circle_outline)),
            label: const Text('Hoàn tất khám'),
          ),
        ),
      ];
    } else if (_choMoiVao) {
      nut = [
        Expanded(
          child: FilledButton.icon(
            onPressed: _dangGui ? null : _moiVaoKham,
            icon: dangXuLy(const Icon(Icons.login)),
            label: Text(_trangThai == TrangThaiLuotKham.tamHoan
                ? 'Bệnh nhân đã đến – Mời vào khám'
                : 'Mời vào khám'),
          ),
        ),
      ];
    } else {
      return null;
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(children: nut),
      ),
    );
  }
}

class _GhiChu extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GhiChu({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.mauNen,
          borderRadius: BorderRadius.circular(AppTheme.boGoc),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppTheme.mauChuNhat),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.mauChuNhat))),
        ]),
      );
}

class _TheBenhNhan extends StatelessWidget {
  final LuotKhamTrongCa luot;
  final TrangThaiLuotKham trangThai;

  const _TheBenhNhan({required this.luot, required this.trangThai});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final (nhan, mau, nen) = switch (trangThai) {
      TrangThaiLuotKham.choKham => ('Chờ khám', const Color(0xFF475569), const Color(0xFFE2E8F0)),
      TrangThaiLuotKham.dangKham => ('Đang khám', AppTheme.mauChinh, AppTheme.mauChinhNhat),
      TrangThaiLuotKham.tamHoan => ('Tạm hoãn', const Color(0xFFC2410C), const Color(0xFFFFEDD5)),
      TrangThaiLuotKham.daKham => ('Đã khám', const Color(0xFF15803D), const Color(0xFFDCFCE7)),
      TrangThaiLuotKham.daHuy => ('Đã huỷ', const Color(0xFFB91C1C), const Color(0xFFFEE2E2)),
      TrangThaiLuotKham.vangMat => ('Vắng mặt', AppTheme.mauChuNhat, const Color(0xFFF1F5F9)),
    };
    final thongTin = [
      if (luot.gioiTinh != null && luot.gioiTinh!.isNotEmpty) luot.gioiTinh!,
      if (luot.tuoi != null) '${luot.tuoi} tuổi',
    ].join(' · ');
    final dat = luot.ngayDat;

    return TheTrang(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.mauChinh,
              borderRadius: BorderRadius.circular(AppTheme.boGoc),
            ),
            child: Column(
              children: [
                const Text('STT',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(haiSo(luot.soThuTu),
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(luot.tenBenhNhan, style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: ShapeDecoration(color: nen, shape: const StadiumBorder()),
                  child: Text(nhan, style: TextStyle(color: mau, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                if (thongTin.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(thongTin, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                ],
                if (dat != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.schedule, size: 14, color: AppTheme.mauChuNhat),
                    const SizedBox(width: 4),
                    Text('Đặt lúc ${gioPhut(dat)}, ${haiSo(dat.day)}/${haiSo(dat.month)}',
                        style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Khoi extends StatelessWidget {
  final IconData icon;
  final String tieuDe;
  final Widget child;
  final Widget? phai;

  const _Khoi({required this.icon, required this.tieuDe, required this.child, this.phai});

  @override
  Widget build(BuildContext context) {
    return TheTrang(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.mauChinhNhat,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: AppTheme.mauChinh),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tieuDe,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
              if (phai != null) phai!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
