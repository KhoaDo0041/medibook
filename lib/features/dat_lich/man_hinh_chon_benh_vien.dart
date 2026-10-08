import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import '../auth/dich_vu_tai_khoan.dart';
import 'dich_vu_dat_lich.dart';
import 'dinh_dang.dart';
import 'man_hinh_chon_bac_si.dart';
import 'mo_hinh.dart';
import 'vi_tri.dart';

/// Bước 1: chọn bệnh viện, sắp theo khoảng cách nếu có vị trí.
/// Trả về 'mo_ai' nếu người dùng bấm "Hỏi ngay" để mở tab Trợ lý AI.
class ManHinhChonBenhVien extends StatefulWidget {
  final HoSo hoSo;

  const ManHinhChonBenhVien({super.key, required this.hoSo});

  @override
  State<ManHinhChonBenhVien> createState() => _ManHinhChonBenhVienState();
}

class _ManHinhChonBenhVienState extends State<ManHinhChonBenhVien> {
  final _dichVu = DichVuDatLich();
  final _oTim = TextEditingController();

  KetQuaViTri? _viTri;
  List<BenhVien> _ds = [];
  bool _dangTai = true;
  String? _loi;

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
    setState(() {
      _dangTai = true;
      _loi = null;
    });
    final viTri = await layViTri();
    try {
      final ds = await _dichVu.layBenhVien(viDo: viTri.viDo, kinhDo: viTri.kinhDo);
      if (!mounted) return;
      setState(() {
        _viTri = viTri;
        _ds = ds;
        _dangTai = false;
      });
    } on LoiDatLich catch (e) {
      if (!mounted) return;
      setState(() {
        _viTri = viTri;
        _loi = e.thongBao;
        _dangTai = false;
      });
    }
  }

  Future<void> _batViTri() async {
    final tt = _viTri?.trangThai;
    if (tt != null) await moCaiDatViTri(tt);
    await _taiDuLieu();
  }

  List<BenhVien> get _dsLoc {
    final q = _oTim.text.trim().toLowerCase();
    if (q.isEmpty) return _ds;
    return _ds
        .where((b) => b.ten.toLowerCase().contains(q) || b.diaChi.toLowerCase().contains(q))
        .toList();
  }

  void _chon(BenhVien bv) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManHinhChonBacSi(hoSo: widget.hoSo, benhVien: bv)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chọn bệnh viện')),
      body: RefreshIndicator(
        onRefresh: _taiDuLieu,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            TextField(
              controller: _oTim,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm bệnh viện…',
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
            if (_viTri != null) _DongViTri(viTri: _viTri!, onBat: _batViTri),
            const SizedBox(height: 16),
            ..._noiDung(),
            const SizedBox(height: 8),
            _TheHoiAi(onHoi: () => Navigator.pop(context, 'mo_ai')),
          ],
        ),
      ),
    );
  }

  List<Widget> _noiDung() {
    if (_dangTai) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_loi != null) {
      return [
        _ThongBaoTrong(
          icon: Icons.wifi_off,
          text: _loi!,
          nut: TextButton(onPressed: _taiDuLieu, child: const Text('Thử lại')),
        ),
      ];
    }
    final ds = _dsLoc;
    if (ds.isEmpty) {
      return [const _ThongBaoTrong(icon: Icons.search_off, text: 'Không tìm thấy bệnh viện phù hợp.')];
    }
    final coViTri = _viTri?.co ?? false;
    return [
      for (var i = 0; i < ds.length; i++) ...[
        _TheBenhVien(
          benhVien: ds[i],
          ganNhat: coViTri && i == 0 && _oTim.text.trim().isEmpty,
          onTap: () => _chon(ds[i]),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _DongViTri extends StatelessWidget {
  final KetQuaViTri viTri;
  final VoidCallback onBat;

  const _DongViTri({required this.viTri, required this.onBat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppTheme.mauChinhNhat,
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
      ),
      child: Row(
        children: [
          Icon(viTri.co ? Icons.near_me_outlined : Icons.location_off_outlined,
              size: 18, color: AppTheme.mauChinh),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(viTri.loiNhan, style: const TextStyle(fontSize: 13)),
            ),
          ),
          if (!viTri.co)
            TextButton(onPressed: onBat, child: const Text('Bật vị trí')),
        ],
      ),
    );
  }
}

class _TheBenhVien extends StatelessWidget {
  final BenhVien benhVien;
  final bool ganNhat;
  final VoidCallback onTap;

  const _TheBenhVien({required this.benhVien, required this.ganNhat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final km = benhVien.khoangCachKm;
    return TheTrang(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.mauChinhNhat,
              borderRadius: BorderRadius.circular(AppTheme.boGoc),
            ),
            child: const Icon(Icons.local_hospital_outlined, color: AppTheme.mauChinh, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ganNhat) ...[
                  const _Nhan(
                    text: 'Gần nhất',
                    icon: Icons.bolt,
                    mauChu: Color(0xFFC2410C),
                    mauNen: Color(0xFFFFEDD5),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(benhVien.ten,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(benhVien.diaChi,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                if (km != null) ...[
                  const SizedBox(height: 8),
                  _Nhan(
                    text: khoangCach(km),
                    icon: Icons.near_me_outlined,
                    mauChu: AppTheme.mauChinh,
                    mauNen: AppTheme.mauChinhNhat,
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppTheme.mauChuNhat),
        ],
      ),
    );
  }
}

class _Nhan extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color mauChu;
  final Color mauNen;

  const _Nhan({required this.text, required this.icon, required this.mauChu, required this.mauNen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: ShapeDecoration(color: mauNen, shape: const StadiumBorder()),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: mauChu),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: mauChu, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ThongBaoTrong extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? nut;

  const _ThongBaoTrong({required this.icon, required this.text, this.nut});

  @override
  Widget build(BuildContext context) {
    return TheTrang(
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppTheme.mauChuNhat),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.mauChuNhat)),
          if (nut != null) nut!,
        ],
      ),
    );
  }
}

class _TheHoiAi extends StatelessWidget {
  final VoidCallback onHoi;

  const _TheHoiAi({required this.onHoi});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.mauChinh,
        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chưa rõ nên khám khoa nào?',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                SizedBox(height: 2),
                Text('Hỏi trợ lý AI để được gợi ý chuyên khoa',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onHoi,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.mauChinh,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: const Text('Hỏi ngay'),
          ),
        ],
      ),
    );
  }
}
