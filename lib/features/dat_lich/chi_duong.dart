import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ban_do/man_hinh_ban_do.dart';
import 'mo_hinh.dart';

/// Mở bản đồ trong app: đường đi ngắn nhất (OSRM) + ghi lại hành trình.
Future<void> moChiDuong(BuildContext context, BenhVien benhVien) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManHinhBanDo(dich: benhVien)),
    );

/// Mở Google Maps chỉ đường từ vị trí hiện tại tới bệnh viện.
/// Dùng tên + địa chỉ (Google tự tìm đúng toà nhà) thay vì toạ độ mẫu gần đúng.
Future<void> moGoogleMaps(BuildContext context, BenhVien benhVien) async {
  final dich = Uri.encodeComponent('${benhVien.ten}, ${benhVien.diaChi}');
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dich&travelmode=driving');
  final thongBao = ScaffoldMessenger.of(context);
  try {
    final mo = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mo) throw Exception();
  } catch (_) {
    thongBao.showSnackBar(
      const SnackBar(content: Text('Không mở được bản đồ. Kiểm tra Google Maps trên máy.')),
    );
  }
}
