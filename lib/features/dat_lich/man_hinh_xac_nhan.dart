import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import '../auth/dich_vu_tai_khoan.dart';
import 'dich_vu_dat_lich.dart';
import 'dinh_dang.dart';
import 'man_hinh_dat_thanh_cong.dart';
import 'mo_hinh.dart';

/// Bước 3: xem lại thông tin, nhập triệu chứng (tuỳ chọn) và xác nhận.
class ManHinhXacNhan extends StatefulWidget {
  final HoSo hoSo;
  final BenhVien benhVien;
  final BacSi bacSi;
  final CaKham ca;

  const ManHinhXacNhan({
    super.key,
    required this.hoSo,
    required this.benhVien,
    required this.bacSi,
    required this.ca,
  });

  @override
  State<ManHinhXacNhan> createState() => _ManHinhXacNhanState();
}

class _ManHinhXacNhanState extends State<ManHinhXacNhan> {
  static const _goiY = ['Sốt', 'Ho', 'Đau đầu', 'Đau họng', 'Đau bụng', 'Tái khám định kỳ'];

  final _trieuChung = TextEditingController();
  bool _dangGui = false;
  String? _loi;

  @override
  void dispose() {
    _trieuChung.dispose();
    super.dispose();
  }

  void _themGoiY(String g) {
    final hienTai = _trieuChung.text.trim();
    if (hienTai.toLowerCase().contains(g.toLowerCase())) return;
    _trieuChung.text = hienTai.isEmpty ? g : '$hienTai, ${g.toLowerCase()}';
    _trieuChung.selection = TextSelection.collapsed(offset: _trieuChung.text.length);
    setState(() {});
  }

  Future<void> _xacNhan() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _dangGui = true;
      _loi = null;
    });
    try {
      final kq = await DichVuDatLich().datLuotKham(widget.ca.id, trieuChung: _trieuChung.text);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ManHinhDatThanhCong(
            hoSo: widget.hoSo,
            benhVien: widget.benhVien,
            bacSi: widget.bacSi,
            ca: widget.ca,
            luotKham: kq,
          ),
        ),
      );
    } on LoiDatLich catch (e) {
      if (!mounted) return;
      setState(() {
        _loi = e.thongBao;
        _dangGui = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final ca = widget.ca;
    final bs = widget.bacSi;

    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận đặt lịch')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Thông tin lịch khám
          TheTrang(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppTheme.mauChinhNhat,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.boGocThe)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.mauChinh,
                        child: Text(
                          bs.hoTen.trim().isEmpty
                              ? '?'
                              : bs.hoTen.trim().split(' ').last.characters.first.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bs.tenDayDu,
                                style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                            Text('${bs.soNamKinhNghiem} năm kinh nghiệm · Khoa ${bs.tenKhoa}',
                                style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DongThongTin(
                        icon: Icons.local_hospital_outlined,
                        nhan: 'Bệnh viện',
                        giaTri: widget.benhVien.ten,
                        phu: widget.benhVien.diaChi,
                      ),
                      _DongThongTin(
                        icon: Icons.medical_services_outlined,
                        nhan: 'Chuyên khoa',
                        giaTri: 'Khoa ${bs.tenKhoa}',
                      ),
                      _DongThongTin(
                        icon: Icons.event_outlined,
                        nhan: 'Ngày khám',
                        giaTri: ngayDayDu(ca.ngay),
                      ),
                      _DongThongTin(
                        icon: Icons.schedule,
                        nhan: 'Ca khám',
                        giaTri: '${ca.tenCa} ${ca.khungGio}',
                        phu: [
                          if (ca.viTriPhong != null) ca.viTriPhong!,
                          'Còn ${ca.soConLai}/${ca.soToiDa} chỗ',
                        ].join(' · '),
                        cuoi: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Triệu chứng
          TheTrang(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Triệu chứng hoặc lý do khám',
                          style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text('Tuỳ chọn', style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Giúp bác sĩ chuẩn bị trước khi khám.',
                    style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in _goiY)
                      ActionChip(
                        label: Text('+ $g'),
                        onPressed: () => _themGoiY(g),
                        backgroundColor: AppTheme.mauChinhNhat,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _trieuChung,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'VD: sốt 2 ngày, đau họng…'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Lưu ý
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.mauChinhNhat,
              borderRadius: BorderRadius.circular(AppTheme.boGocThe),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppTheme.mauChinh),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Số thứ tự được cấp ngay khi bạn xác nhận. '
                    'Vui lòng đến trước giờ bắt đầu ca 15 phút.',
                    style: chu.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loi != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_loi!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ),
              FilledButton(
                onPressed: _dangGui ? null : _xacNhan,
                child: _dangGui
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Xác nhận đặt lịch'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DongThongTin extends StatelessWidget {
  final IconData icon;
  final String nhan;
  final String giaTri;
  final String? phu;
  final bool cuoi;

  const _DongThongTin({
    required this.icon,
    required this.nhan,
    required this.giaTri,
    this.phu,
    this.cuoi = false,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: cuoi ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: AppTheme.mauChinhNhat, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: AppTheme.mauChinh),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nhan, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                Text(giaTri, style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (phu != null)
                  Text(phu!, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
