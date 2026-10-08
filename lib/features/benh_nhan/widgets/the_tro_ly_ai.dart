import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';
import '../../../core/widgets/the_trang.dart';

/// Thẻ mời dùng trợ lý AI: trò chuyện hoặc chụp ảnh.
class TheTroLyAi extends StatelessWidget {
  final VoidCallback onTroChuyen;
  final VoidCallback onChupAnh;

  const TheTroLyAi({super.key, required this.onTroChuyen, required this.onChupAnh});

  @override
  Widget build(BuildContext context) {
    final chu = Theme.of(context).textTheme;

    return TheTrang(
      mauNen: const Color(0xFFF5F7FF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.auto_awesome, size: 16, color: AppTheme.mauCam),
                      const SizedBox(width: 6),
                      Text('Trợ lý sức khoẻ thông minh',
                          style: chu.labelLarge?.copyWith(color: AppTheme.mauCam)),
                    ]),
                    const SizedBox(height: 8),
                    Text('Bạn đang thấy không khoẻ?',
                        style: chu.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.mauChinh,
                  borderRadius: BorderRadius.circular(AppTheme.boGoc),
                ),
                child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Kể triệu chứng cho trợ lý AI, hoặc chụp ảnh vùng da bị tổn thương',
            style: chu.bodyMedium?.copyWith(color: AppTheme.mauChuNhat),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onTroChuyen,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Trò chuyện với AI'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onChupAnh,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp ảnh'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.mauVien),
                    foregroundColor: AppTheme.mauChuDam,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
