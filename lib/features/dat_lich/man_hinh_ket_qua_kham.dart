import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/widgets/the_trang.dart';
import 'dinh_dang.dart';
import 'mo_hinh.dart';
import 'the_trang_thai.dart';

/// Kết quả một lượt khám: triệu chứng đã khai, chẩn đoán và lời dặn của bác sĩ.
/// Trả về true nếu người dùng bấm "Đặt lại với bác sĩ này".
class ManHinhKetQuaKham extends StatelessWidget {
  final LuotKhamCuaToi luot;

  const ManHinhKetQuaKham({super.key, required this.luot});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;
    final trieuChung = luot.trieuChung?.trim() ?? '';
    final chanDoan = luot.chanDoan?.trim() ?? '';
    final loiDan = luot.ghiChuBacSi?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Kết quả khám')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Thông tin lượt khám
          TheTrang(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('MÃ PHIẾU',
                              style: chu.labelSmall
                                  ?.copyWith(color: AppTheme.mauChuNhat, letterSpacing: 0.5)),
                          Text('#MB-${luot.id.toString().padLeft(6, '0')}',
                              style: chu.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    NhanTrangThai(luot: luot),
                  ],
                ),
                const Divider(height: 24, color: AppTheme.mauVien),
                _Dong(
                  icon: Icons.event_outlined,
                  text: '${ngayDayDu(luot.ca.ngay)} · ${luot.ca.tenCa} ${luot.ca.khungGio}',
                ),
                const SizedBox(height: 6),
                _Dong(icon: Icons.local_hospital_outlined, text: luot.benhVien.ten),
                if (luot.ca.viTriPhong != null) ...[
                  const SizedBox(height: 6),
                  _Dong(icon: Icons.meeting_room_outlined, text: luot.ca.viTriPhong!),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.mauNen,
                    borderRadius: BorderRadius.circular(AppTheme.boGoc),
                  ),
                  child: Row(
                    children: [
                      OChuCaiBacSi(tenBacSi: luot.tenBacSi, kichThuoc: 44),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(luot.tenBacSi,
                                style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            Text(luot.tenKhoa,
                                style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Triệu chứng
          _TieuDe(icon: Icons.record_voice_over_outlined, text: 'Triệu chứng bạn khai'),
          TheTrang(
            padding: const EdgeInsets.all(16),
            child: Text(
              trieuChung.isEmpty ? 'Bạn không khai triệu chứng khi đặt lịch.' : '“$trieuChung”',
              style: TextStyle(
                color: trieuChung.isEmpty ? AppTheme.mauChuNhat : AppTheme.mauChuDam,
                fontStyle: trieuChung.isEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Chẩn đoán
          _TieuDe(icon: Icons.fact_check_outlined, text: 'Chẩn đoán của bác sĩ'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.mauChinhNhat,
              borderRadius: BorderRadius.circular(AppTheme.boGocThe),
              border: const Border(top: BorderSide(color: AppTheme.mauChinh, width: 3)),
            ),
            child: Text(
              chanDoan.isEmpty ? 'Bác sĩ chưa nhập chẩn đoán.' : chanDoan,
              style: chanDoan.isEmpty
                  ? const TextStyle(color: AppTheme.mauChuNhat)
                  : chu.titleLarge?.copyWith(color: AppTheme.mauChinh, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 20),

          // Lời dặn
          _TieuDe(icon: Icons.health_and_safety_outlined, text: 'Lời dặn của bác sĩ'),
          TheTrang(
            padding: const EdgeInsets.all(16),
            child: Text(
              loiDan.isEmpty ? 'Không có lời dặn thêm.' : loiDan,
              style: TextStyle(
                  color: loiDan.isEmpty ? AppTheme.mauChuNhat : AppTheme.mauChuDam, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(AppTheme.boGoc),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFB91C1C)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nếu triệu chứng nặng lên đột ngột (khó thở, đau ngực, sốt cao không hạ), '
                    'hãy đến cơ sở y tế gần nhất hoặc gọi 115.',
                    style: TextStyle(color: Color(0xFF991B1B)),
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
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.replay),
            label: const Text('Đặt lại với bác sĩ này'),
          ),
        ),
      ),
    );
  }
}

class _Dong extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Dong({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.mauChuNhat),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppTheme.mauChuNhat))),
        ],
      );
}

class _TieuDe extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TieuDe({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.mauChinh),
            const SizedBox(width: 8),
            Text(text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
