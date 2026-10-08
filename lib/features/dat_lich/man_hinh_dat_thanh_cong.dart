import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../auth/dich_vu_tai_khoan.dart';
import 'dinh_dang.dart';
import 'mo_hinh.dart';
import 'the_trang_thai.dart';

/// Bước cuối: phiếu khám điện tử với số thứ tự.
class ManHinhDatThanhCong extends StatelessWidget {
  final HoSo hoSo;
  final BenhVien benhVien;
  final BacSi bacSi;
  final CaKham ca;
  final LuotKhamMoi luotKham;

  const ManHinhDatThanhCong({
    super.key,
    required this.hoSo,
    required this.benhVien,
    required this.bacSi,
    required this.ca,
    required this.luotKham,
  });

  void _veTrangChu(BuildContext context) =>
      Navigator.popUntil(context, (route) => route.isFirst);

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final gioCoMat = ca.thoiDiemBatDau.subtract(const Duration(minutes: 15));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (daPop, _) {
        if (!daPop) _veTrangChu(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Đặt lịch thành công'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _veTrangChu(context)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, size: 56, color: Color(0xFF16A34A)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Đặt lịch thành công!',
                textAlign: TextAlign.center,
                style: chu.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Lịch khám của bạn đã được ghi nhận tại ${benhVien.ten}.',
                textAlign: TextAlign.center,
                style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
            const SizedBox(height: 24),

            _PhieuKham(
              hoSo: hoSo,
              benhVien: benhVien,
              bacSi: bacSi,
              ca: ca,
              luotKham: luotKham,
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(AppTheme.boGocThe),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, color: Color(0xFFC2410C)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'Vui lòng có mặt lúc '),
                        TextSpan(
                            text: gioPhut(gioCoMat),
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(
                            text: ca.viTriPhong == null
                                ? ' và báo số thứ tự tại quầy tiếp đón của khoa.'
                                : ' tại ${ca.viTriPhong} và chờ gọi số thứ tự.'),
                      ]),
                      style: const TextStyle(color: Color(0xFF9A3412)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _veTrangChu(context),
              icon: const Icon(Icons.home_outlined),
              label: const Text('Về trang chủ'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhieuKham extends StatelessWidget {
  final HoSo hoSo;
  final BenhVien benhVien;
  final BacSi bacSi;
  final CaKham ca;
  final LuotKhamMoi luotKham;

  const _PhieuKham({
    required this.hoSo,
    required this.benhVien,
    required this.bacSi,
    required this.ca,
    required this.luotKham,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.boGocThe),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Đầu phiếu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppTheme.mauChinhNhat,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.boGocThe)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_hospital_outlined, size: 18, color: AppTheme.mauChinh),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('PHIẾU KHÁM ĐIỆN TỬ',
                      style: TextStyle(
                          color: AppTheme.mauChinh, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: const ShapeDecoration(color: Color(0xFFDCFCE7), shape: StadiumBorder()),
                  child: const Text('ĐÃ XÁC NHẬN',
                      style: TextStyle(
                          color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),

          // Số thứ tự
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Text('SỐ THỨ TỰ CỦA BẠN',
                    style: chu.labelMedium
                        ?.copyWith(color: AppTheme.mauChuNhat, letterSpacing: 1)),
                Text(haiSo(luotKham.soThuTu),
                    style: const TextStyle(
                        color: AppTheme.mauChinh, fontSize: 64, fontWeight: FontWeight.w800, height: 1.1)),
                Text('${ca.tenCa} · ${ca.khungGio}',
                    style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
                if (ca.viTriPhong != null) ...[
                  const SizedBox(height: 10),
                  NhanPhong(text: ca.viTriPhong!),
                ],
              ],
            ),
          ),

          const _DuongCatPhieu(),

          // Chi tiết
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Bệnh nhân',
                              style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                          Text(hoSo.hoTen,
                              style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Mã phiếu', style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                        Text('#MB-${luotKham.id.toString().padLeft(6, '0')}',
                            style: chu.titleSmall?.copyWith(
                                color: AppTheme.mauChinh, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ODong(
                  icon: Icons.apartment_outlined,
                  nhan: 'BỆNH VIỆN',
                  giaTri: benhVien.ten,
                  phu: benhVien.diaChi,
                ),
                _ODong(
                  icon: Icons.medical_services_outlined,
                  nhan: 'BÁC SĨ PHỤ TRÁCH',
                  giaTri: bacSi.tenDayDu,
                  phu: 'Khoa ${bacSi.tenKhoa}',
                ),
                _ODong(
                  icon: Icons.event_available_outlined,
                  nhan: 'THỜI GIAN KHÁM',
                  giaTri: ca.khungGio,
                  phu: ngayDayDu(ca.ngay),
                  cuoi: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Đường gạch đứt có 2 khuyết tròn hai bên, giống vé.
class _DuongCatPhieu extends StatelessWidget {
  const _DuongCatPhieu();

  @override
  Widget build(BuildContext context) {
    const khuyet = 10.0;
    return SizedBox(
      height: khuyet * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: khuyet + 6),
              child: LayoutBuilder(
                builder: (_, kt) {
                  final soGach = (kt.maxWidth / 10).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      soGach,
                      (_) => Container(width: 5, height: 1.5, color: AppTheme.mauVien),
                    ),
                  );
                },
              ),
            ),
          ),
          for (final trai in [true, false])
            Positioned(
              top: 0,
              left: trai ? -khuyet : null,
              right: trai ? null : -khuyet,
              child: Container(
                width: khuyet * 2,
                height: khuyet * 2,
                decoration: const BoxDecoration(color: AppTheme.mauNen, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

class _ODong extends StatelessWidget {
  final IconData icon;
  final String nhan;
  final String giaTri;
  final String phu;
  final bool cuoi;

  const _ODong({
    required this.icon,
    required this.nhan,
    required this.giaTri,
    required this.phu,
    this.cuoi = false,
  });

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Container(
      margin: EdgeInsets.only(bottom: cuoi ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.mauNen,
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.mauChinhNhat,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: AppTheme.mauChinh),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nhan,
                    style: chu.labelSmall?.copyWith(color: AppTheme.mauChuNhat, letterSpacing: 0.5)),
                Text(giaTri, style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(phu, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
