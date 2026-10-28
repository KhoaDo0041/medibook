import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import '../bac_si/trang_chu_bac_si.dart';
import '../benh_nhan/trang_chu_benh_nhan.dart';
import '../web_bac_si/trang_web_bac_si.dart';
import 'dich_vu_tai_khoan.dart';
import 'man_hinh_chao_mung.dart';
import 'man_hinh_dang_nhap.dart';

/// Chọn trang chủ theo vai trò và nền tảng:
/// - Điện thoại: bệnh nhân / bác sĩ như cũ.
/// - Trình duyệt (Flutter Web): chỉ dành cho bác sĩ, mở giao diện màn hình lớn.
Widget trangChuTheoVaiTro(HoSo hoSo) {
  if (!hoSo.laBacSi) return TrangChuBenhNhan(hoSo: hoSo);
  return kIsWeb ? TrangWebBacSi(hoSo: hoSo) : TrangChuBacSi(hoSo: hoSo);
}

/// Màn hình khi chưa đăng nhập. Bản web đi thẳng vào đăng nhập bác sĩ.
Widget manHinhChuaDangNhap() => kIsWeb
    ? const ManHinhDangNhap(vaiTro: VaiTro.bacSi)
    : const ManHinhChaoMung();
