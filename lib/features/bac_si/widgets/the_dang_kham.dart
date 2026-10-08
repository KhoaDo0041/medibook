import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../mo_hinh.dart';

/// Khối xanh "Đang khám": bệnh nhân hiện tại và nút gọi số tiếp theo.
class TheDangKham extends StatelessWidget {
  final LuotKhamTrongCa? dangKham;
  final String? tenCa;
  final int? soTiepTheo;
  final VoidCallback onGoiTiep;
  final VoidCallback onMoBenhAn;

  const TheDangKham({
    super.key,
    required this.dangKham,
    required this.tenCa,
    required this.soTiepTheo,
    required this.onGoiTiep,
    required this.onMoBenhAn,
  });

  @override
  Widget build(BuildContext context) {
    final l = dangKham;

    return Container(
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
            color: AppTheme.mauChinh.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: l == null ? Colors.white54 : Colors.greenAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l == null ? 'CHƯA CÓ BỆNH NHÂN ĐANG KHÁM' : 'ĐANG KHÁM',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5),
                ),
              ),
              if (tenCa != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(tenCa!,
                      style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (l != null) ...[
            Text('Số ${l.soThuTu.toString().padLeft(2, '0')}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            Text(l.tenBenhNhan,
                style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(l.trieuChung,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
          ] else
            Text(
              soTiepTheo == null
                  ? 'Không có bệnh nhân nào đang chờ.'
                  : 'Bấm "Gọi số" để mời bệnh nhân đầu tiên vào khám.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: soTiepTheo == null ? null : onGoiTiep,
                  icon: const Icon(Icons.campaign_outlined),
                  label: Text(soTiepTheo == null
                      ? 'Hết bệnh nhân chờ'
                      : 'Gọi số tiếp theo (${soTiepTheo.toString().padLeft(2, '0')})'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.mauChinh,
                    disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
                    disabledForegroundColor: Colors.white70,
                  ),
                ),
              ),
              if (l != null) ...[
                const SizedBox(width: 12),
                Material(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.boGoc),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.boGoc),
                    onTap: onMoBenhAn,
                    child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(Icons.edit_note, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
