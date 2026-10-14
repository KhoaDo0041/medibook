import 'package:flutter/material.dart';

import '../../core/widgets/duong_nhip_tim.dart';
import '../../core/widgets/logo_medibook.dart';
import '../../core/widgets/nen_chuyen_dong.dart';
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
      final hoSo = await DichVuTaiKhoan.layHoSoHienTai();
      // Bác sĩ đã nghỉ việc mà vẫn còn phiên đăng nhập cũ: đăng xuất luôn
      if (hoSo != null &&
          hoSo.laBacSi &&
          !await DichVuTaiKhoan.bacSiConHoatDong()) {
        await DichVuTaiKhoan.dangXuat();
        return null;
      }
      return hoSo;
    } catch (_) {
      return null; // mất mạng hoặc lỗi: coi như chưa đăng nhập
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HoSo?>(
      future: _hoSo,
      builder: (context, ketQua) {
        final Widget manHinh;
        if (ketQua.connectionState != ConnectionState.done) {
          manHinh = const _ManHinhKhoiDong();
        } else {
          final hoSo = ketQua.data;
          manHinh = hoSo == null
              ? const ManHinhChaoMung()
              : hoSo.laBacSi
              ? TrangChuBacSi(hoSo: hoSo)
              : TrangChuBenhNhan(hoSo: hoSo);
        }
        // Mờ dần từ màn khởi động sang màn tiếp theo
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: KeyedSubtree(
            key: ValueKey(ketQua.connectionState == ConnectionState.done),
            child: manHinh,
          ),
        );
      },
    );
  }
}

/// Màn chờ lúc mở app: logo đập nhịp tim trên nền xanh.
class _ManHinhKhoiDong extends StatelessWidget {
  const _ManHinhKhoiDong();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: NenChuyenDong(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LogoMediBook(hero: false),
              SizedBox(height: 8),
              Text(
                'MediBook',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 16),
              SizedBox(width: 200, child: DuongNhipTim()),
            ],
          ),
        ),
      ),
    );
  }
}
