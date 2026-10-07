import 'package:flutter/material.dart';

import '../bac_si/trang_chu_bac_si.dart';
import '../benh_nhan/trang_chu_benh_nhan.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_chao_mung.dart';

/// Màn hình đầu tiên khi mở app: quyết định đi đâu.
/// - Đã đăng nhập từ lần trước: vào thẳng trang chủ theo vai trò.
/// - Chưa đăng nhập: vào màn hình chào mừng.
class CongVaoApp extends StatefulWidget {
  const CongVaoApp({super.key});

  @override
  State<CongVaoApp> createState() => _CongVaoAppState();
}

class _CongVaoAppState extends State<CongVaoApp> {
  late final Future<HoSo?> _hoSo = _taiHoSo();

  Future<HoSo?> _taiHoSo() async {
    try {
      return await DichVuTaiKhoan.layHoSoHienTai();
    } catch (_) {
      return null; // mất mạng hoặc lỗi: coi như chưa đăng nhập
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HoSo?>(
      future: _hoSo,
      builder: (context, ketQua) {
        if (ketQua.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final hoSo = ketQua.data;
        if (hoSo == null) return const ManHinhChaoMung();
        return hoSo.laBacSi
            ? TrangChuBacSi(hoSo: hoSo)
            : TrangChuBenhNhan(hoSo: hoSo);
      },
    );
  }
}
