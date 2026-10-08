import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum TrangThaiViTri { coViTri, tatDinhVi, tuChoi, tuChoiVinhVien, loi }

class KetQuaViTri {
  final TrangThaiViTri trangThai;
  final double? viDo;
  final double? kinhDo;

  const KetQuaViTri(this.trangThai, {this.viDo, this.kinhDo});

  bool get co => trangThai == TrangThaiViTri.coViTri;

  String get loiNhan => switch (trangThai) {
        TrangThaiViTri.coViTri => 'Sắp xếp theo khoảng cách từ vị trí của bạn',
        TrangThaiViTri.tatDinhVi => 'Định vị đang tắt, danh sách sắp theo tên',
        TrangThaiViTri.tuChoi ||
        TrangThaiViTri.tuChoiVinhVien =>
          'Chưa cấp quyền vị trí, danh sách sắp theo tên',
        TrangThaiViTri.loi => 'Không lấy được vị trí, danh sách sắp theo tên',
      };
}

/// Lấy vị trí hiện tại (xin quyền nếu cần). Không bao giờ ném lỗi.
Future<KetQuaViTri> layViTri() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const KetQuaViTri(TrangThaiViTri.tatDinhVi);
    }
    var quyen = await Geolocator.checkPermission();
    if (quyen == LocationPermission.denied) {
      quyen = await Geolocator.requestPermission();
    }
    if (quyen == LocationPermission.deniedForever) {
      return const KetQuaViTri(TrangThaiViTri.tuChoiVinhVien);
    }
    if (quyen == LocationPermission.denied) {
      return const KetQuaViTri(TrangThaiViTri.tuChoi);
    }

    Position? vt;
    try {
      vt = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      vt = await Geolocator.getLastKnownPosition();
    }
    if (vt == null) return const KetQuaViTri(TrangThaiViTri.loi);
    return KetQuaViTri(TrangThaiViTri.coViTri, viDo: vt.latitude, kinhDo: vt.longitude);
  } catch (_) {
    return const KetQuaViTri(TrangThaiViTri.loi);
  }
}

/// Mở đúng trang cài đặt để người dùng bật lại vị trí.
Future<void> moCaiDatViTri(TrangThaiViTri trangThai) async {
  if (trangThai == TrangThaiViTri.tatDinhVi) {
    await Geolocator.openLocationSettings();
  } else if (trangThai == TrangThaiViTri.tuChoiVinhVien) {
    await Geolocator.openAppSettings();
  }
}
