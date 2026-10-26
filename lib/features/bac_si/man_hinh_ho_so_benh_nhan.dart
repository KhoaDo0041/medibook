import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dinh_dang.dart';
import 'mo_hinh.dart';
import 'widgets/anh_benh_nhan.dart';

/// Hồ sơ một bệnh nhân: các lần khám với bác sĩ này theo dòng thời gian (chỉ xem).
class ManHinhHoSoBenhNhan extends StatelessWidget {
  final BenhNhanCuaToi benhNhan;

  const ManHinhHoSoBenhNhan({super.key, required this.benhNhan});

  @override
  Widget build(BuildContext context) {
    final b = benhNhan;
    final chu = Theme.of(context).textTheme;
    final soVang = b.cacLan.length - b.soLanKham;
    final dau = b.lanDauTien;

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ bệnh nhân')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Thẻ đầu
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), AppTheme.mauChinh],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppTheme.boGocThe),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.mauChinh.withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: AnhBenhNhan(
                        id: b.id,
                        hoTen: b.hoTen,
                        kichThuoc: 56,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.hoTen,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (b.gioiTinh != null || b.tuoi != null)
                            Text(
                              [
                                if (b.gioiTinh != null &&
                                    b.gioiTinh!.isNotEmpty)
                                  b.gioiTinh!,
                                if (b.tuoi != null) '${b.tuoi} tuổi',
                              ].join(' · '),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _OSo(giaTri: '${b.soLanKham}', nhan: 'Lần khám'),
                    _OSo(giaTri: '$soVang', nhan: 'Vắng mặt'),
                    _OSo(
                      giaTri: dau == null
                          ? '--'
                          : '${haiSo(dau.ngay.day)}/${haiSo(dau.ngay.month)}',
                      nhan: 'Lần đầu',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Icon(Icons.timeline, color: AppTheme.mauChinh),
              const SizedBox(width: 8),
              Text(
                'Lịch sử khám với bạn',
                style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),

          for (var i = 0; i < b.cacLan.length; i++)
            _MocThoiGian(lan: b.cacLan[i], cuoi: i == b.cacLan.length - 1),
        ],
      ),
    );
  }
}

class _OSo extends StatelessWidget {
  final String giaTri;
  final String nhan;

  const _OSo({required this.giaTri, required this.nhan});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.boGoc),
      ),
      child: Column(
        children: [
          Text(
            giaTri,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            nhan,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Một mốc trên dòng thời gian: chấm + đường dọc bên trái, thẻ nội dung bên phải.
class _MocThoiGian extends StatelessWidget {
  final LanKham lan;
  final bool cuoi;

  const _MocThoiGian({required this.lan, required this.cuoi});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final mauCham = lan.daKham ? AppTheme.mauChinh : const Color(0xFF94A3B8);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cột dòng thời gian
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: mauCham, width: 3),
                  ),
                ),
                if (!cuoi)
                  Expanded(child: Container(width: 2, color: AppTheme.mauVien)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Nội dung
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: cuoi ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: lan.daKham ? Colors.white : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(AppTheme.boGocThe),
                  boxShadow: lan.daKham
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A)
                                .withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${ngayDayDu(lan.ngay)} · ${lan.tenCa}',
                            style: chu.labelLarge?.copyWith(
                              color: mauCham,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (lan.daKham)
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                size: 14,
                                color: AppTheme.mauChuNhat,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Đã chốt',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.mauChuNhat,
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Vắng mặt',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.mauChuNhat,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    if (lan.trieuChung.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        '“${lan.trieuChung.trim()}”',
                        style: const TextStyle(
                          color: AppTheme.mauChuNhat,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (lan.daKham) ...[
                      const SizedBox(height: 8),
                      Text(
                        (lan.chanDoan ?? '').trim().isEmpty
                            ? '(không ghi chẩn đoán)'
                            : lan.chanDoan!.trim(),
                        style: chu.titleMedium?.copyWith(
                          color: AppTheme.mauChinh,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if ((lan.loiDan ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          lan.loiDan!.trim(),
                          style: const TextStyle(height: 1.45),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
