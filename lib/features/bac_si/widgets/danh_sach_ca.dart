import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/widgets/the_trang.dart';
import '../mo_hinh.dart';

/// Một ca khám: tiêu đề ca + danh sách bệnh nhân theo số thứ tự.
class DanhSachCa extends StatelessWidget {
  final CaKhamTrongNgay ca;
  final ValueChanged<LuotKhamTrongCa> onChonBenhNhan;

  const DanhSachCa({super.key, required this.ca, required this.onChonBenhNhan});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final cacLuot = [...ca.danhSach]..sort((a, b) => a.soThuTu.compareTo(b.soThuTu));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ca.laCaSang ? const Color(0xFFFFF7ED) : AppTheme.mauChinhNhat,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                ca.laCaSang ? Icons.wb_sunny_outlined : Icons.wb_twilight,
                size: 18,
                color: ca.laCaSang ? AppTheme.mauCam : AppTheme.mauChinh,
              ),
            ),
            const SizedBox(width: 10),
            Text(ca.tenCa, style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text(ca.khungGio, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const ShapeDecoration(
                  color: AppTheme.mauChinhNhat, shape: StadiumBorder()),
              child: Text('${ca.soDaDangKy}/${ca.soToiDa} chỗ',
                  style: const TextStyle(
                      color: AppTheme.mauChinh, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        if (ca.phong != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Row(children: [
              const Icon(Icons.meeting_room_outlined, size: 16, color: AppTheme.mauChuNhat),
              const SizedBox(width: 6),
              Text(ca.phong!, style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
            ]),
          ),
        const SizedBox(height: 12),
        if (cacLuot.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Chưa có bệnh nhân đặt lịch trong ca này.',
                style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat)),
          )
        else
          for (final luot in cacLuot) ...[
            _DongBenhNhan(luot: luot, onTap: () => onChonBenhNhan(luot)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _DongBenhNhan extends StatelessWidget {
  final LuotKhamTrongCa luot;
  final VoidCallback onTap;

  const _DongBenhNhan({required this.luot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final kieu = _KieuTrangThai.cua(luot.trangThai);
    final daHuy = luot.trangThai == TrangThaiLuotKham.daHuy;

    return Opacity(
      opacity: luot.trangThai == TrangThaiLuotKham.daHuy || luot.trangThai == TrangThaiLuotKham.vangMat
          ? 0.6
          : 1,
      child: TheTrang(
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: kieu.nenSo, shape: BoxShape.circle),
              child: Text(luot.soThuTu.toString().padLeft(2, '0'),
                  style: TextStyle(
                      color: kieu.chuSo, fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          luot.tenBenhNhan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: chu.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: daHuy ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: ShapeDecoration(
                          color: kieu.nenNhan,
                          shape: const StadiumBorder(),
                        ),
                        child: Text(kieu.nhan,
                            style: TextStyle(
                                color: kieu.chuNhan,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      luot.trangThai == TrangThaiLuotKham.daKham && (luot.chanDoan ?? '').isNotEmpty
                          ? 'Chẩn đoán: ${luot.chanDoan}'
                          : luot.trieuChung.isEmpty
                              ? 'Không khai triệu chứng'
                              : luot.trieuChung,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.mauChuNhat),
          ],
        ),
      ),
    );
  }
}

/// Màu sắc cho từng trạng thái lượt khám.
class _KieuTrangThai {
  final String nhan;
  final Color nenNhan, chuNhan, nenSo, chuSo;

  const _KieuTrangThai(this.nhan, this.nenNhan, this.chuNhan, this.nenSo, this.chuSo);

  static _KieuTrangThai cua(TrangThaiLuotKham t) {
    switch (t) {
      case TrangThaiLuotKham.dangKham:
        return const _KieuTrangThai('Đang khám', Color(0xFFDBEAFE), AppTheme.mauChinh,
            AppTheme.mauChinh, Colors.white);
      case TrangThaiLuotKham.daKham:
        return const _KieuTrangThai('Đã khám', Color(0xFFDCFCE7), Color(0xFF15803D),
            Color(0xFFBBF7D0), Color(0xFF15803D));
      case TrangThaiLuotKham.daHuy:
        return const _KieuTrangThai('Đã huỷ', Color(0xFFFEE2E2), Color(0xFFB91C1C),
            Color(0xFFFEE2E2), Color(0xFFB91C1C));
      case TrangThaiLuotKham.tamHoan:
        return const _KieuTrangThai('Tạm hoãn', Color(0xFFFFEDD5), Color(0xFFC2410C),
            Color(0xFFFFEDD5), Color(0xFFC2410C));
      case TrangThaiLuotKham.vangMat:
        return const _KieuTrangThai('Vắng mặt', Color(0xFFF1F5F9), AppTheme.mauChuNhat,
            Color(0xFFE2E8F0), AppTheme.mauChuNhat);
      case TrangThaiLuotKham.choKham:
        return const _KieuTrangThai('Chờ khám', Color(0xFFF1F5F9), AppTheme.mauChuNhat,
            AppTheme.mauChinhNhat, AppTheme.mauChinh);
    }
  }
}
