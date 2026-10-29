import 'package:flutter/material.dart';

import '../app_theme.dart';

/// Thẻ "Phiếu tiền khám" do Trợ lý AI tổng hợp (cột luot_kham.phieu_tien_kham).
/// Dùng chung cho: màn xác nhận đặt lịch (bệnh nhân), web bác sĩ, app bác sĩ.
class ThePhieuTienKham extends StatelessWidget {
  final Map<String, dynamic> phieu;

  const ThePhieuTienKham({super.key, required this.phieu});

  static const _cacMuc = [
    ('nguoi_benh', 'Người bệnh'),
    ('trieu_chung_chinh', 'Triệu chứng'),
    ('bat_dau_tu', 'Bắt đầu'),
    ('dien_bien', 'Diễn biến'),
    ('trieu_chung_kem', 'Kèm theo'),
    ('tien_su', 'Tiền sử'),
    ('mo_ta_anh', 'Ảnh gửi kèm'),
  ];

  static bool nenKhamSom(Map<String, dynamic>? p) =>
      p != null && (p['muc_do'] == 'nen_kham_som' || p['muc_do'] == 'cap_cuu');

  /// Một dòng tóm tắt cho danh sách bệnh nhân.
  static String? tomTat(Map<String, dynamic>? p) {
    if (p == null) return null;
    final tc = (p['trieu_chung_chinh'] as String?)?.trim() ?? '';
    final bd = (p['bat_dau_tu'] as String?)?.trim() ?? '';
    if (tc.isEmpty) return null;
    return bd.isEmpty ? tc : '$tc · $bd';
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final khoa = [
      for (final k in (phieu['khoa_goi_y'] as List? ?? [])) k.toString(),
    ];
    final dong = [
      for (final (khoaJson, nhan) in _cacMuc)
        if (((phieu[khoaJson] as String?) ?? '').trim().isNotEmpty)
          (nhan, (phieu[khoaJson] as String).trim()),
      if (khoa.isNotEmpty) ('AI gợi ý khoa', khoa.join(', ')),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
        border: Border.all(color: AppTheme.mauChinh.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 20, color: AppTheme.mauChinh),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Phiếu tiền khám · AI tổng hợp',
                  style: chu.titleSmall?.copyWith(
                    color: AppTheme.mauChinh,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (nenKhamSom(phieu))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: const ShapeDecoration(
                    color: Color(0xFFFFEDD5),
                    shape: StadiumBorder(),
                  ),
                  child: const Text(
                    'Nên khám sớm',
                    style: TextStyle(
                      color: Color(0xFFC2410C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (nhan, giaTri) in dong)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      nhan,
                      style: chu.bodySmall?.copyWith(
                        color: AppTheme.mauChuNhat,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Text(giaTri, style: chu.bodyMedium)),
                ],
              ),
            ),
          Text(
            'Thông tin do Trợ lý AI tổng hợp từ lời kể của bệnh nhân, chỉ để tham khảo.',
            style: chu.bodySmall?.copyWith(
              color: AppTheme.mauChuNhat,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
