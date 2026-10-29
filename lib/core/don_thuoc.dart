import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'supabase_client.dart';

/// Một loại thuốc trong danh mục THUỐC MẪU (bảng danh_muc_thuoc, dùng cho demo).
class ThuocMau {
  final int id;
  final String ten;
  final String donVi; // viên / gói / ml

  const ThuocMau({required this.id, required this.ten, required this.donVi});

  factory ThuocMau.tuJson(Map<String, dynamic> j) => ThuocMau(
    id: j['id'] as int,
    ten: j['ten'] as String,
    donVi: (j['don_vi'] as String?) ?? 'viên',
  );

  @override
  bool operator ==(Object other) => other is ThuocMau && other.id == id;
  @override
  int get hashCode => id;
}

enum ThoiDiemUong {
  sauAn('sau_an', 'Sau ăn'),
  truocAn('truoc_an', 'Trước ăn'),
  khongPhuThuoc('khong_phu_thuoc', 'Không phụ thuộc bữa ăn');

  final String ma;
  final String nhan;
  const ThoiDiemUong(this.ma, this.nhan);

  static ThoiDiemUong tuMa(String? ma) =>
      values.firstWhere((t) => t.ma == ma, orElse: () => sauAn);
}

/// Một dòng trong đơn thuốc (bảng don_thuoc_chi_tiet).
class DongDonThuoc {
  final ThuocMau thuoc;
  final double lieu; // số đơn vị mỗi lần uống
  final int soLan; // số lần mỗi ngày
  final ThoiDiemUong thoiDiem;
  final int soNgay;
  final String? ghiChu;

  const DongDonThuoc({
    required this.thuoc,
    required this.lieu,
    required this.soLan,
    required this.thoiDiem,
    required this.soNgay,
    this.ghiChu,
  });

  String get lieuChu =>
      lieu == lieu.roundToDouble() ? lieu.toInt().toString() : lieu.toString().replaceAll('.', ',');

  /// "1 viên × 2 lần/ngày · Sau ăn · 5 ngày"
  String get moTa =>
      '$lieuChu ${thuoc.donVi} × $soLan lần/ngày · ${thoiDiem.nhan} · $soNgay ngày';

  Map<String, dynamic> toJson() => {
    'thuoc_id': thuoc.id,
    'lieu_moi_lan': lieu,
    'so_lan_ngay': soLan,
    'thoi_diem': thoiDiem.ma,
    'so_ngay': soNgay,
    'ghi_chu': ghiChu ?? '',
  };

  factory DongDonThuoc.tuJson(Map<String, dynamic> j) => DongDonThuoc(
    thuoc: ThuocMau.tuJson(Map<String, dynamic>.from(j['danh_muc_thuoc'] as Map)),
    lieu: (j['lieu_moi_lan'] as num).toDouble(),
    soLan: j['so_lan_ngay'] as int,
    thoiDiem: ThoiDiemUong.tuMa(j['thoi_diem'] as String?),
    soNgay: j['so_ngay'] as int,
    ghiChu: j['ghi_chu'] as String?,
  );
}

/// Truy vấn đơn thuốc (dùng chung cho bệnh nhân và bác sĩ; RLS giới hạn quyền xem).
class DichVuDonThuoc {
  static List<ThuocMau>? _boNho;

  static Future<List<ThuocMau>> danhMuc() async {
    final daCo = _boNho;
    if (daCo != null) return daCo;
    final rows = await supabase
        .from('danh_muc_thuoc')
        .select('id, ten, don_vi')
        .order('id');
    return _boNho = [for (final r in rows) ThuocMau.tuJson(r)];
  }

  static Future<List<DongDonThuoc>> cuaLuotKham(int luotKhamId) async {
    final rows = await supabase
        .from('don_thuoc_chi_tiet')
        .select(
          'lieu_moi_lan, so_lan_ngay, thoi_diem, so_ngay, ghi_chu, danh_muc_thuoc(id, ten, don_vi)',
        )
        .eq('luot_kham_id', luotKhamId)
        .order('id');
    return [for (final r in rows) DongDonThuoc.tuJson(r)];
  }
}

/// Hiển thị đơn thuốc (chỉ đọc) + ngày tái khám.
class TheDonThuoc extends StatelessWidget {
  final List<DongDonThuoc> don;
  final DateTime? ngayTaiKham;

  const TheDonThuoc({super.key, required this.don, this.ngayTaiKham});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (don.isEmpty)
          Text(
            'Bác sĩ không kê thuốc.',
            style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
          )
        else
          for (final d in don)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.mauNen,
                borderRadius: BorderRadius.circular(AppTheme.boGoc),
                border: Border.all(color: AppTheme.mauVien),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.mauChinhNhat,
                    child: Icon(Icons.medication_outlined, color: AppTheme.mauChinh, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.thuoc.ten,
                          style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(d.moTa, style: chu.bodySmall),
                        if ((d.ghiChu ?? '').trim().isNotEmpty)
                          Text(
                            d.ghiChu!.trim(),
                            style: chu.bodySmall?.copyWith(
                              color: AppTheme.mauChuNhat,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        if (ngayTaiKham != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.event_repeat_rounded, color: AppTheme.mauCam, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tái khám: ${ngayTaiKham!.day.toString().padLeft(2, '0')}/'
                '${ngayTaiKham!.month.toString().padLeft(2, '0')}/${ngayTaiKham!.year}',
                style: chu.titleSmall?.copyWith(
                  color: AppTheme.mauCam,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
