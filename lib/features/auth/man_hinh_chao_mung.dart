import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_dang_nhap.dart';

/// Màn hình đầu tiên: người dùng chọn mình là Bệnh nhân hay Bác sĩ.
class ManHinhChaoMung extends StatelessWidget {
  const ManHinhChaoMung({super.key});

  void _moDangNhap(BuildContext context, String vaiTro) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ManHinhDangNhap(vaiTro: vaiTro)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.local_hospital_rounded,
                  size: 72, color: AppTheme.mauChinh),
              const SizedBox(height: 16),
              Text(
                'MediBook',
                textAlign: TextAlign.center,
                style: chu.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Tư vấn AI & đặt lịch khám bệnh viện',
                textAlign: TextAlign.center,
                style: chu.bodyLarge?.copyWith(color: AppTheme.mauChuNhat),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => _moDangNhap(context, VaiTro.benhNhan),
                child: const Text('Tôi là Bệnh nhân'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _moDangNhap(context, VaiTro.bacSi),
                child: const Text('Tôi là Bác sĩ'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
