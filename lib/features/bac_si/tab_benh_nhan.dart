import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import '../../core/widgets/hieu_ung.dart';
import '../../core/widgets/khung_cho_tai.dart';
import '../../core/dinh_dang.dart';
import '../../core/widgets/trang_thai.dart';
import 'dich_vu_bac_si.dart';
import 'man_hinh_ho_so_benh_nhan.dart';
import 'mo_hinh.dart';
import 'widgets/anh_benh_nhan.dart';

enum _Loc { tatCa, trongTuan, taiKham }

/// Tab "Bệnh nhân" của bác sĩ: những người đã khám với mình, tìm theo tên, xem hồ sơ.
class TabBenhNhan extends StatefulWidget {
  const TabBenhNhan({super.key});

  @override
  State<TabBenhNhan> createState() => _TabBenhNhanState();
}

class _TabBenhNhanState extends State<TabBenhNhan> {
  final _dichVu = DichVuBacSi();
  final _oTim = TextEditingController();

  List<BenhNhanCuaToi> _ds = [];
  bool _dangTai = true;
  String? _loi;
  _Loc _loc = _Loc.tatCa;

  @override
  void initState() {
    super.initState();
    _taiDuLieu();
  }

  @override
  void dispose() {
    _oTim.dispose();
    super.dispose();
  }

  Future<void> _taiDuLieu() async {
    setState(() => _loi = null);
    try {
      final ds = await _dichVu.layBenhNhanCuaToi();
      if (mounted) {
        setState(() {
          _ds = ds;
          _dangTai = false;
        });
      }
    } on LoiBacSi catch (e) {
      if (mounted) {
        setState(() {
          _loi = e.thongBao;
          _dangTai = false;
        });
      }
    }
  }

  bool _hopLoc(BenhNhanCuaToi b, _Loc loc) {
    switch (loc) {
      case _Loc.tatCa:
        return true;
      case _Loc.trongTuan:
        final g = b.lanGanNhat;
        return g != null && DateTime.now().difference(g.ngay).inDays < 7;
      case _Loc.taiKham:
        return b.soLanKham >= 2;
    }
  }

  List<BenhNhanCuaToi> get _dsLoc {
    final q = _oTim.text.trim().toLowerCase();
    return _ds
        .where(
          (b) =>
              _hopLoc(b, _loc) &&
              (q.isEmpty || b.hoTen.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final tongLuot = _ds.fold<int>(0, (t, b) => t + b.soLanKham);

    return RefreshIndicator(
      onRefresh: _taiDuLieu,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Tiêu đề
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Bệnh nhân của tôi',
                  style: chu.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!_dangTai && _loi == null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: const ShapeDecoration(
                    color: AppTheme.mauChinh,
                    shape: StadiumBorder(),
                  ),
                  child: Text(
                    '${_ds.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _dangTai
                ? 'Đang tải…'
                : '$tongLuot lượt khám đã hoàn tất · kết quả chỉ xem, không sửa',
            style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
          ),
          const SizedBox(height: 16),

          // Tìm kiếm
          TextField(
            controller: _oTim,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Tìm theo tên bệnh nhân…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _oTim.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_oTim.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Bộ lọc
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (loc, ten) in [
                  (_Loc.tatCa, 'Tất cả'),
                  (_Loc.trongTuan, 'Khám trong tuần'),
                  (_Loc.taiKham, 'Tái khám nhiều lần'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        '$ten (${_ds.where((b) => _hopLoc(b, loc)).length})',
                      ),
                      selected: _loc == loc,
                      onSelected: (_) => setState(() => _loc = loc),
                      showCheckmark: false,
                      selectedColor: AppTheme.mauChinh,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: _loc == loc ? Colors.white : AppTheme.mauChuDam,
                        fontWeight: FontWeight.w600,
                      ),
                      side: BorderSide(
                        color: _loc == loc
                            ? AppTheme.mauChinh
                            : AppTheme.mauVien,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ..._noiDung(),
        ],
      ),
    );
  }

  List<Widget> _noiDung() {
    if (_dangTai) {
      return const [KhungChoTai(soThe: 4)];
    }
    if (_loi != null) {
      return [TheLoi(thongBao: _loi!, onThuLai: _taiDuLieu)];
    }
    if (_ds.isEmpty) {
      return [
        const TrangThaiTrong(
          icon: Icons.groups_outlined,
          tieuDe: 'Chưa có bệnh nhân nào',
          moTa: 'Bệnh nhân sẽ xuất hiện ở đây sau khi bạn hoàn tất lượt khám đầu tiên.',
        ),
      ];
    }
    final ds = _dsLoc;
    if (ds.isEmpty) {
      return [
        const TrangThaiTrong(
          icon: Icons.search_off,
          tieuDe: 'Không tìm thấy',
          moTa: 'Thử tên khác hoặc đổi bộ lọc.',
        ),
      ];
    }
    return lanLuot([
      for (final b in ds) ...[
        _TheBenhNhan(
          benhNhan: b,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManHinhHoSoBenhNhan(benhNhan: b)),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

class _TheBenhNhan extends StatelessWidget {
  final BenhNhanCuaToi benhNhan;
  final VoidCallback onTap;

  const _TheBenhNhan({required this.benhNhan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final b = benhNhan;
    final gan = b.lanGanNhat;
    final dau = b.lanDauTien;
    final laMoi =
        dau != null &&
        DateTime.now().difference(dau.ngay).inDays < 7 &&
        b.soLanKham == 1;

    return TheTrang(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnhBenhNhan(id: b.id, hoTen: b.hoTen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            b.hoTen,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: chu.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (laMoi) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: const ShapeDecoration(
                              color: Color(0xFFFFEDD5),
                              shape: StadiumBorder(),
                            ),
                            child: const Text(
                              'Mới',
                              style: TextStyle(
                                color: Color(0xFFC2410C),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      gan == null
                          ? 'Chưa hoàn tất lượt khám nào'
                          : '${b.soLanKham} lần khám · Gần nhất ${haiSo(gan.ngay.day)}/${haiSo(gan.ngay.month)}',
                      style: chu.bodySmall?.copyWith(
                        color: AppTheme.mauChuNhat,
                      ),
                    ),
                  ],
                ),
              ),
              _DayNhip(cacLan: b.cacLan),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppTheme.mauChuNhat),
            ],
          ),
          if (gan?.chanDoan != null && gan!.chanDoan!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.mauChinhNhat,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    size: 16,
                    color: AppTheme.mauChinh,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gan.chanDoan!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.mauChinh,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dải chấm nhỏ thể hiện các lần đến gần nhất: xanh = đã khám, xám = vắng mặt.
class _DayNhip extends StatelessWidget {
  final List<LanKham> cacLan;

  const _DayNhip({required this.cacLan});

  @override
  Widget build(BuildContext context) {
    final gan = cacLan.take(5).toList().reversed.toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final l in gan)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(left: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: l.daKham
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFCBD5E1),
            ),
          ),
      ],
    );
  }
}
